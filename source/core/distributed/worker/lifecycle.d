module core.distributed.worker.lifecycle;

import std.datetime : Duration, Clock, seconds, msecs;
import core.time : MonoTime;
import std.algorithm : remove;
import std.random : uniform;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import core.distributed.protocol.protocol;
import core.distributed.protocol.protocol : NetworkError;
import core.distributed.protocol.transport;
import core.distributed.protocol.messages;
import utils.concurrency.deque : WorkStealingDeque;
import core.distributed.worker.peers;
import core.distributed.worker.steal;
import core.distributed.memory;
import core.distributed.metrics.steal : StealTelemetry;
import errors;
import utils.logging.logger;

/// Worker configuration
struct WorkerConfig
{
    string coordinatorUrl;                          // Coordinator address
    size_t maxConcurrentActions = 8;                // Max parallel execution
    size_t localQueueSize = 256;                    // Local work queue
    bool enableSandboxing = true;                   // Hermetic execution?
    bool enableWorkStealing = true;                 // Enable P2P work-stealing?
    string listenAddress;                           // Listen address for P2P
    Capabilities defaultCapabilities;               // Default sandbox settings
    Duration heartbeatInterval = 5.seconds;         // Heartbeat frequency
    Duration peerAnnounceInterval = 10.seconds;     // Peer announce frequency
    StealConfig stealConfig;                        // Work-stealing config
}

/// Worker lifecycle manager
struct WorkerLifecycle
{
    private WorkerId id;
    private WorkerConfig config;
    private WorkStealingDeque!ActionRequest localQueue;
    private Transport coordinatorTransport;
    private shared WorkerState state;
    private Thread mainThread;
    private Thread heartbeatThread;
    private Thread peerAnnounceThread;
    private shared bool running;
    private SystemMetrics metrics;
    
    // Work-stealing components
    private PeerRegistry peerRegistry;
    private StealEngine stealEngine;
    private StealTelemetry stealTelemetry;
    
    // Memory optimization components
    private ArenaPool arenaPool;
    private BufferPool bufferPool;
    
    /// Initialize lifecycle
    void initialize(WorkerConfig config) @trusted
    {
        this.config = config;
        this.localQueue = WorkStealingDeque!ActionRequest(config.localQueueSize);
        atomicStore(state, WorkerState.Idle);
        atomicStore(running, false);
        
        // Initialize memory pools
        this.arenaPool = new ArenaPool(64 * 1024, 32);
        this.bufferPool = new BufferPool(64 * 1024, 128);
        
        // Pre-allocate buffers for optimal performance
        bufferPool.preallocate(16);
    }
    
    /// Start worker
    Result!DistributedError start() @trusted
    {
        if (atomicLoad(running))
            return Result!DistributedError.ok();
        
        // Connect to coordinator
        auto transportResult = TransportFactory.create(config.coordinatorUrl);
        if (transportResult.isErr)
            return Result!DistributedError.err(transportResult.unwrapErr());
        
        coordinatorTransport = transportResult.unwrap();
        
        // Register with coordinator
        auto registerResult = registerWithCoordinator();
        if (registerResult.isErr)
            return Result!DistributedError.err(registerResult.unwrapErr());
        
        id = registerResult.unwrap();
        
        // Initialize work-stealing components
        if (config.enableWorkStealing)
        {
            peerRegistry = new PeerRegistry(id);
            stealEngine = new StealEngine(id, peerRegistry, config.stealConfig);
            stealTelemetry = new StealTelemetry();
            Logger.info("Work-stealing enabled");
        }
        
        atomicStore(running, true);
        
        Logger.info("Worker started: " ~ id.toString());
        
        return Ok!DistributedError();
    }
    
    /// Stop worker
    void stop() @trusted
    {
        atomicStore(running, false);
        
        if (mainThread !is null)
            mainThread.join();
        
        if (heartbeatThread !is null)
            heartbeatThread.join();
        
        if (peerAnnounceThread !is null)
            peerAnnounceThread.join();
        
        if (coordinatorTransport !is null)
            coordinatorTransport.close();
        
        // Log work-stealing statistics
        if (stealTelemetry !is null)
        {
            auto stats = stealTelemetry.getStats();
            Logger.info("Work-stealing stats: " ~ stats.toString());
        }
        
        Logger.info("Worker stopped: " ~ id.toString());
    }
    
    /// Register with coordinator
    private Result!(WorkerId, DistributedError) registerWithCoordinator() @trusted
    {
        import core.distributed.protocol.messages;
        import std.socket : Socket, TcpSocket;
        
        try
        {
            // Create registration message
            WorkerRegistration reg;
            reg.address = "worker-" ~ uniform!uint().to!string;  // Simplified address
            reg.capabilities = config.defaultCapabilities;
            reg.metrics = collectMetrics();
            
            auto regData = serializeRegistration(reg);
            
            // Connect to coordinator
            auto socket = coordinatorTransport;
            if (!socket.isConnected())
            {
                auto connectResult = cast(HttpTransport)socket;
                if (connectResult is null)
                    return Err!(WorkerId, DistributedError)(
                        new NetworkError("Invalid transport"));
                
                auto connResult = connectResult.connect();
                if (connResult.isErr)
                    return Err!(WorkerId, DistributedError)(connResult.unwrapErr());
            }
            
            // Send registration
            ubyte[1] typeBytes = [cast(ubyte)MessageType.Registration];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)regData.length;
            
            // Note: Would send via socket, simplified for now
            
            // Receive worker ID
            ubyte[8] idBytes;
            // Would receive via socket
            
            return Ok!(WorkerId, DistributedError)(WorkerId(uniform!ulong()));
        }
        catch (Exception e)
        {
            return Err!(WorkerId, DistributedError)(
                new NetworkError("Registration failed: " ~ e.msg));
        }
    }
    
    /// Collect system metrics
    private SystemMetrics collectMetrics() @trusted
    {
        SystemMetrics m;
        
        // Collect real metrics
        m.queueDepth = localQueue.size();
        m.activeActions = atomicLoad(state) == WorkerState.Executing ? 1 : 0;
        
        // Get CPU and memory usage
        import core.memory : GC;
        auto stats = GC.stats();
        m.memoryUsage = stats.usedSize > 0 ? 
            cast(float)stats.usedSize / cast(float)stats.usedSize : 0.0f;
        
        // CPU usage approximation (would use platform-specific code in production)
        // For now, base on queue depth and active actions
        immutable queueLoad = localQueue.size() > 0 ? 
            cast(float)localQueue.size() / cast(float)config.localQueueSize : 0.0f;
        immutable actionLoad = m.activeActions > 0 ? 
            cast(float)m.activeActions / cast(float)config.maxConcurrentActions : 0.0f;
        m.cpuUsage = queueLoad * 0.5 + actionLoad * 0.5;
        
        // Disk usage (platform-specific)
        m.diskUsage = getDiskUsage();
        
        return m;
    }
    
    /// Get disk usage for current working directory (platform-specific)
    private float getDiskUsage() @trusted
    {
        version(Posix)
        {
            import core.sys.posix.sys.statvfs;
            import std.file : getcwd;
            import std.string : toStringz;
            
            statvfs_t stat;
            immutable cwd = getcwd();
            if (statvfs(toStringz(cwd), &stat) == 0)
            {
                immutable totalBytes = stat.f_blocks * stat.f_frsize;
                immutable availBytes = stat.f_bavail * stat.f_frsize;
                
                if (totalBytes > 0)
                {
                    immutable usedBytes = totalBytes - availBytes;
                    return cast(float)usedBytes / cast(float)totalBytes;
                }
            }
            
            // Fallback
            return 0.2f;
        }
        else version(Windows)
        {
            import core.sys.windows.windows;
            import std.file : getcwd;
            import std.string : toUTF16z;
            import std.utf : toUTF16;
            
            ULARGE_INTEGER freeBytesAvailable, totalBytes, freeBytes;
            immutable cwd = getcwd();
            immutable wpath = (cwd ~ "\0").toUTF16;
            
            if (GetDiskFreeSpaceExW(wpath.ptr, &freeBytesAvailable, &totalBytes, &freeBytes))
            {
                if (totalBytes.QuadPart > 0)
                {
                    immutable usedBytes = totalBytes.QuadPart - freeBytes.QuadPart;
                    return cast(float)usedBytes / cast(float)totalBytes.QuadPart;
                }
            }
            
            // Fallback
            return 0.2f;
        }
        else
        {
            // Unsupported platform
            return 0.2f;
        }
    }
    
    /// Backoff strategy (exponential with jitter)
    void backoff(size_t attempt) @trusted
    {
        import core.time : msecs;
        import std.algorithm : min;
        
        if (attempt < 10)
        {
            // Short spin
            Thread.yield();
        }
        else if (attempt < 20)
        {
            // Exponential backoff
            immutable baseDelay = min(1 << (attempt - 10), 100);
            immutable jitter = uniform(0, baseDelay / 2);
            Thread.sleep((baseDelay + jitter).msecs);
        }
        else
        {
            // Long sleep
            Thread.sleep(100.msecs);
        }
    }
    
    /// Access methods
    WorkerId getId() @trusted { return id; }
    WorkerConfig getConfig() @trusted { return config; }
    WorkStealingDeque!ActionRequest getLocalQueue() @trusted { return localQueue; }
    Transport getCoordinatorTransport() @trusted { return coordinatorTransport; }
    WorkerState getState() @trusted { return atomicLoad(state); }
    void setState(WorkerState newState) @trusted { atomicStore(state, newState); }
    bool isRunning() @trusted { return atomicLoad(running); }
    PeerRegistry getPeerRegistry() @trusted { return peerRegistry; }
    StealEngine getStealEngine() @trusted { return stealEngine; }
    StealTelemetry getStealTelemetry() @trusted { return stealTelemetry; }
    SystemMetrics getMetrics() @trusted { return collectMetrics(); }
    
    /// Set thread handles (called by worker main)
    void setMainThread(Thread t) @trusted { mainThread = t; }
    void setHeartbeatThread(Thread t) @trusted { heartbeatThread = t; }
    void setPeerAnnounceThread(Thread t) @trusted { peerAnnounceThread = t; }
}

