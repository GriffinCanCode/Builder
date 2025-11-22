/**
 * API layer for data processing and external integrations
 */

const { EventEmitter } = require('events');

class DataAPI extends EventEmitter {
    constructor(config = {}) {
        super();
        this.config = config;
        this.endpoints = new Map();
        this.middleware = [];
        this.rateLimits = new Map();
    }

    registerEndpoint(path, handler, options = {}) {
        this.endpoints.set(path, {
            handler,
            method: options.method || 'GET',
            authenticated: options.authenticated || false,
            rateLimit: options.rateLimit || null
        });
        console.log(`Registered endpoint: ${options.method || 'GET'} ${path}`);
    }

    use(middleware) {
        this.middleware.push(middleware);
    }

    async handleRequest(path, data = {}, context = {}) {
        const endpoint = this.endpoints.get(path);
        
        if (!endpoint) {
            throw new Error(`Endpoint not found: ${path}`);
        }

        // Apply rate limiting
        if (endpoint.rateLimit && !this._checkRateLimit(path, context)) {
            throw new Error('Rate limit exceeded');
        }

        // Apply middleware
        let processedData = data;
        for (const mw of this.middleware) {
            processedData = await mw(processedData, context);
        }

        // Execute handler
        const result = await endpoint.handler(processedData, context);
        this.emit('requestProcessed', { path, result });
        
        return result;
    }

    _checkRateLimit(path, context) {
        const limit = this.endpoints.get(path).rateLimit;
        const key = `${path}:${context.clientId || 'anonymous'}`;
        
        if (!this.rateLimits.has(key)) {
            this.rateLimits.set(key, { count: 0, resetTime: Date.now() + 60000 });
        }

        const limiter = this.rateLimits.get(key);
        
        if (Date.now() > limiter.resetTime) {
            limiter.count = 0;
            limiter.resetTime = Date.now() + 60000;
        }

        if (limiter.count >= limit) {
            return false;
        }

        limiter.count++;
        return true;
    }
}

class WebSocketServer extends EventEmitter {
    constructor(port, options = {}) {
        super();
        this.port = port;
        this.options = options;
        this.clients = new Set();
        this.rooms = new Map();
        this.isRunning = false;
    }

    start() {
        console.log(`WebSocket server starting on port ${this.port}`);
        this.isRunning = true;
        this.emit('started');
    }

    stop() {
        console.log('WebSocket server stopping');
        this.clients.clear();
        this.rooms.clear();
        this.isRunning = false;
        this.emit('stopped');
    }

    broadcast(message, room = null) {
        const clients = room ? this.rooms.get(room) : this.clients;
        
        if (!clients) {
            console.error(`Room not found: ${room}`);
            return;
        }

        console.log(`Broadcasting to ${clients.size} clients:`, message);
        this.emit('broadcast', { message, room, clientCount: clients.size });
    }

    addClientToRoom(clientId, room) {
        if (!this.rooms.has(room)) {
            this.rooms.set(room, new Set());
        }
        this.rooms.get(room).add(clientId);
    }

    removeClientFromRoom(clientId, room) {
        const roomClients = this.rooms.get(room);
        if (roomClients) {
            roomClients.delete(clientId);
            if (roomClients.size === 0) {
                this.rooms.delete(room);
            }
        }
    }
}

class Cache {
    constructor(options = {}) {
        this.maxSize = options.maxSize || 1000;
        this.ttl = options.ttl || 3600000; // 1 hour default
        this.store = new Map();
        this.accessLog = new Map();
    }

    set(key, value, ttl = null) {
        if (this.store.size >= this.maxSize) {
            this._evict();
        }

        const expiresAt = Date.now() + (ttl || this.ttl);
        this.store.set(key, { value, expiresAt });
        this.accessLog.set(key, Date.now());
    }

    get(key) {
        const entry = this.store.get(key);
        
        if (!entry) {
            return null;
        }

        if (Date.now() > entry.expiresAt) {
            this.store.delete(key);
            this.accessLog.delete(key);
            return null;
        }

        this.accessLog.set(key, Date.now());
        return entry.value;
    }

    has(key) {
        return this.get(key) !== null;
    }

    delete(key) {
        this.store.delete(key);
        this.accessLog.delete(key);
    }

    clear() {
        this.store.clear();
        this.accessLog.clear();
    }

    _evict() {
        // LRU eviction
        let oldestKey = null;
        let oldestTime = Infinity;

        for (const [key, time] of this.accessLog.entries()) {
            if (time < oldestTime) {
                oldestTime = time;
                oldestKey = key;
            }
        }

        if (oldestKey) {
            this.delete(oldestKey);
        }
    }

    getStats() {
        return {
            size: this.store.size,
            maxSize: this.maxSize,
            utilization: (this.store.size / this.maxSize) * 100
        };
    }
}

class RequestQueue {
    constructor(concurrency = 5) {
        this.concurrency = concurrency;
        this.queue = [];
        this.active = 0;
        this.completed = 0;
        this.failed = 0;
    }

    async add(task) {
        return new Promise((resolve, reject) => {
            this.queue.push({ task, resolve, reject });
            this._process();
        });
    }

    async _process() {
        if (this.active >= this.concurrency || this.queue.length === 0) {
            return;
        }

        this.active++;
        const { task, resolve, reject } = this.queue.shift();

        try {
            const result = await task();
            this.completed++;
            resolve(result);
        } catch (error) {
            this.failed++;
            reject(error);
        } finally {
            this.active--;
            this._process();
        }
    }

    getStats() {
        return {
            queued: this.queue.length,
            active: this.active,
            completed: this.completed,
            failed: this.failed
        };
    }

    clear() {
        this.queue = [];
    }
}

module.exports = {
    DataAPI,
    WebSocketServer,
    Cache,
    RequestQueue
};

