module infrastructure.utils.concurrency.lockfree;

import core.atomic;
import core.sync.mutex;
import std.algorithm;
import std.range;


/// Lock-free SPMC (Single Producer Multiple Consumer) queue using atomic operations
/// Optimized for the build executor's ready queue pattern
/// 
/// Thread Safety:
/// - Single producer (main scheduling thread) enqueues ready nodes
/// - Multiple consumers (worker threads) dequeue and process nodes
/// - All operations are lock-free using atomic compare-and-swap
/// 
/// Performance:
/// - Zero allocation after initialization
/// - No mutex contention between workers
/// - Cache-friendly circular buffer design
struct LockFreeQueue(T) if (is(T == class))
{
    private struct Node
    {
        shared T item;
        shared size_t sequence;
    }
    
    private Node[] buffer;
    private shared size_t enqueuePos;
    private shared size_t dequeuePos;
    private immutable size_t mask;
    
    @disable this(this); // Non-copyable
    
    /// Constructor: Initialize queue with power-of-2 capacity
    /// 
    /// Safety: This constructor is @system because:
    /// 1. Buffer allocation is safe (GC-managed array)
    /// 2. atomicStore() for position initialization
    /// 3. Power-of-2 enforcement for efficient modulo via mask
    /// 
    /// Invariants:
    /// - Capacity must be power of 2 (enforced by assertion)
    /// - Buffer is fully initialized before use
    /// - Positions start at 0
    @system
    this(size_t capacity)
    {
        import std.math : isPowerOf2;
        assert(isPowerOf2(capacity), "Capacity must be power of 2");
        
        buffer.length = capacity;
        mask = capacity - 1;
        
        // Initialize sequences
        foreach (i; 0 .. capacity)
            atomicStore(buffer[i].sequence, i);
        
        atomicStore(enqueuePos, cast(size_t)0);
        atomicStore(dequeuePos, cast(size_t)0);
    }
    
    /// Enqueue an item (producer side)
    /// Returns true if successful, false if queue is full
    /// 
    /// Safety: This function is @system because:
    /// 1. atomicLoad/Store/Cas operations ensure thread-safe access
    /// 2. Mask operation keeps index within bounds
    /// 3. Sequence checking prevents ABA problems
    /// 4. Compare-and-swap prevents race conditions
    /// 
    /// Invariants:
    /// - pos & mask is always < buffer.length
    /// - Sequence numbers prevent slot reuse conflicts
    /// - CAS ensures only one thread updates position
    @system
    bool enqueue(T item)
    {
        size_t pos;
        Node* node;
        size_t seq;
        
        while (true)
        {
            pos = atomicLoad(enqueuePos);
            node = &buffer[pos & mask];
            seq = atomicLoad(node.sequence);
            
            immutable diff = cast(ptrdiff_t)(seq - pos);
            
            if (diff == 0)
            {
                // Slot is available, try to claim it
                if (cas(&enqueuePos, pos, pos + 1))
                {
                    atomicStore(node.item, cast(shared)item);
                    atomicStore(node.sequence, pos + 1);
                    return true;
                }
            }
            else if (diff < 0)
            {
                // Queue is full
                return false;
            }
            // else: another thread got this slot, retry
        }
    }
    
    /// Dequeue an item (consumer side)
    /// Returns the item if successful, null if queue is empty
    /// 
    /// Safety: This function is @system because:
    /// 1. atomicLoad/Store/Cas operations ensure thread-safe access
    /// 2. Mask operation keeps index within bounds
    /// 3. Sequence checking prevents ABA problems
    /// 4. Cast from shared is safe after successful dequeue
    /// 
    /// Invariants:
    /// - pos & mask is always < buffer.length
    /// - Sequence numbers prevent reading before write completes
    /// - CAS ensures only one consumer gets each item
    @system
    T tryDequeue()
    {
        size_t pos;
        Node* node;
        size_t seq;
        
        while (true)
        {
            pos = atomicLoad(dequeuePos);
            node = &buffer[pos & mask];
            seq = atomicLoad(node.sequence);
            
            immutable diff = cast(ptrdiff_t)(seq - (pos + 1));
            
            if (diff == 0)
            {
                // Item is available, try to claim it
                if (cas(&dequeuePos, pos, pos + 1))
                {
                    auto item = cast(T)atomicLoad(node.item);
                    atomicStore(node.sequence, pos + mask + 1);
                    return item;
                }
            }
            else if (diff < 0)
            {
                // Queue is empty
                return null;
            }
            // else: item not ready yet, retry
        }
    }
    
    /// Check if queue is empty (approximate - may be stale immediately)
    @system
    bool empty() const
    {
        immutable enq = atomicLoad(enqueuePos);
        immutable deq = atomicLoad(dequeuePos);
        return enq == deq;
    }
    
    /// Get approximate size (may be stale immediately)
    @system
    size_t length() const
    {
        immutable enq = atomicLoad(enqueuePos);
        immutable deq = atomicLoad(dequeuePos);
        return enq - deq;
    }
}

/// Hash cache for per-build-session memoization
/// Thread-safe for concurrent reads and writes
/// Optimized for the pattern: compute once, read many times
struct FastHashCache
{
    private struct CacheEntry
    {
        shared string contentHash;
        shared string metadataHash;
        shared bool valid;
    }
    
    private CacheEntry[string] cache;
    private shared size_t hits;
    private shared size_t misses;
    private Mutex cacheMutex;  // Protects cache AA access
    
    @disable this(this); // Non-copyable
    
    /// Explicitly initialize the cache (must be called before use)
    @system
    void initialize()
    {
        cacheMutex = new Mutex();
    }
    
    /// Get cached hash if available
    /// Returns tuple: (found, contentHash, metadataHash)
    /// 
    /// Safety: This function is @system because:
    /// 1. Associative array lookup is bounds-checked
    /// 2. atomicLoad ensures thread-safe read of shared data
    /// 3. String casts are safe (strings are immutable)
    /// 4. Synchronized access to AA via mutex
    @system
    auto get(string path)
    {
        struct Result
        {
            bool found;
            string contentHash;
            string metadataHash;
        }
        
        assert(cacheMutex !is null, "FastHashCache not initialized - call initialize() first");
        
        synchronized (cacheMutex)
        {
            if (auto entry = path in cache)
            {
                if (atomicLoad(entry.valid))
                {
                    atomicOp!"+="(hits, 1);
                    return Result(
                        true,
                        cast(string)atomicLoad(entry.contentHash),
                        cast(string)atomicLoad(entry.metadataHash)
                    );
                }
            }
        }
        
        atomicOp!"+="(misses, 1);
        return Result(false, "", "");
    }
    
    /// Store hash in cache
    /// 
    /// Safety: This function is @system because:
    /// 1. Associative array insert is memory-safe when synchronized
    /// 2. atomicStore ensures thread-safe write to entry fields
    /// 3. String to shared string cast is safe (immutable data)
    /// 4. Mutex protects concurrent AA modifications
    @system
    void put(string path, string contentHash, string metadataHash)
    {
        if (cacheMutex is null)
        {
            import std.stdio : stderr;
            stderr.writeln("ERROR: FastHashCache.put called with null mutex!");
            return; // Fail gracefully instead of crashing
        }
        
        try
        {
            synchronized (cacheMutex)
            {
                CacheEntry entry;
                entry.contentHash = cast(shared)contentHash;
                entry.metadataHash = cast(shared)metadataHash;
                entry.valid = cast(shared)true;
                cache[path] = entry;
            }
        }
        catch (Exception e)
        {
            import std.stdio : stderr;
            stderr.writeln("ERROR in FastHashCache.put: ", e.msg);
        }
    }
    
    /// Check if cache entry exists and is valid
    @system
    bool isValid(string path) const
    {
        assert(cacheMutex !is null, "FastHashCache not initialized - call initialize() first");
        
        synchronized (cast(Mutex)cacheMutex)
        {
            if (auto entry = path in cache)
                return atomicLoad(entry.valid);
        }
        return false;
    }
    
    /// Clear the cache (typically at build end)
    @system
    void clear()
    {
        assert(cacheMutex !is null, "FastHashCache not initialized - call initialize() first");
        
        synchronized (cacheMutex)
        {
            cache.clear();
        }
        atomicStore(hits, cast(size_t)0);
        atomicStore(misses, cast(size_t)0);
    }
    
    /// Get cache statistics
    @system
    auto getStats() const
    {
        struct Stats
        {
            size_t hits;
            size_t misses;
            size_t entries;
            float hitRate;
        }
        
        Stats stats;
        stats.hits = atomicLoad(hits);
        stats.misses = atomicLoad(misses);
        stats.entries = cache.length;
        
        immutable total = stats.hits + stats.misses;
        if (total > 0)
            stats.hitRate = (stats.hits * 100.0) / total;
        
        return stats;
    }
}


