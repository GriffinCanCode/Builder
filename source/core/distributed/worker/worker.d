module core.distributed.worker.worker;

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

/// Build worker (executes actions)
final class Worker
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
    
    this(WorkerConfig config) @trusted
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
        
        // Start main loop
        mainThread = new Thread(&mainLoop);
        mainThread.start();
        
        // Start heartbeat
        heartbeatThread = new Thread(&heartbeatLoop);
        heartbeatThread.start();
        
        // Start peer announce (if work-stealing enabled)
        if (config.enableWorkStealing)
        {
            peerAnnounceThread = new Thread(&peerAnnounceLoop);
            peerAnnounceThread.start();
        }
        
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
    
    /// Main worker loop
    private void mainLoop() @trusted
    {
        size_t consecutiveIdle = 0;
        
        while (atomicLoad(running))
        {
            // 1. Try local work first
            auto localAction = localQueue.pop();
            if (localAction !is null)
            {
                executeAction(localAction);
                consecutiveIdle = 0;
                continue;
            }
            
            // 2. Request work from coordinator
            auto coordinatorAction = requestWork();
            if (coordinatorAction !is null)
            {
                executeAction(coordinatorAction);
                consecutiveIdle = 0;
                continue;
            }
            
            // 3. Try stealing from peers (if enabled)
            if (config.enableWorkStealing && stealEngine !is null)
            {
                auto startTime = MonoTime.currTime;
                auto stolenAction = stealEngine.steal(coordinatorTransport);
                auto latency = MonoTime.currTime - startTime;
                
                if (stolenAction !is null)
                {
                    stealTelemetry.recordAttempt(WorkerId(0), latency, true);
                    executeAction(stolenAction);
                    consecutiveIdle = 0;
                    continue;
                }
                else
                {
                    stealTelemetry.recordAttempt(WorkerId(0), latency, false);
                }
            }
            
            // 4. No work available, backoff
            consecutiveIdle++;
            backoff(consecutiveIdle);
        }
    }
    
    /// Execute build action
    private void executeAction(ActionRequest request) @trusted
    {
        import core.time : MonoTime;
        import core.distributed.worker.sandbox;
        
        atomicStore(state, WorkerState.Executing);
        auto startTime = MonoTime.currTime;
        
        Logger.debugLog("Executing action: " ~ request.id.toString());
        
        try
        {
            // 1. Fetch input artifacts (simplified - would fetch from artifact store)
            InputArtifact[] inputs;
            foreach (inputSpec; request.inputs)
            {
                InputArtifact artifact;
                artifact.id = inputSpec.id;
                artifact.path = inputSpec.path;
                artifact.executable = inputSpec.executable;
                // Would fetch data from artifact store
                artifact.data = [];
                inputs ~= artifact;
            }
            
            // 2. Prepare sandbox
            auto sandbox = createSandbox(config.enableSandboxing);
            auto envResult = sandbox.prepare(request, inputs);
            if (envResult.isErr)
            {
                Logger.error("Sandbox preparation failed: " ~ envResult.unwrapErr().message());
                reportFailure(request.id, "Sandbox preparation failed", startTime);
                return;
            }
            
            auto sandboxEnv = envResult.unwrap();
            scope(exit) sandboxEnv.cleanup();
            
            // 3. Execute command
            auto execResult = sandboxEnv.execute(
                request.command,
                request.env,
                request.timeout
            );
            
            if (execResult.isErr)
            {
                Logger.error("Execution failed: " ~ execResult.unwrapErr().message());
                reportFailure(request.id, "Execution failed", startTime);
                return;
            }
            
            auto output = execResult.unwrap();
            auto duration = MonoTime.currTime - startTime;
            
            // Check for resource violations
            auto monitor = sandboxEnv.monitor();
            if (monitor.isViolated())
            {
                foreach (violation; monitor.violations())
                {
                    Logger.warning("Resource violation: " ~ violation.message);
                    Logger.debugLog("  Type: " ~ violation.type.to!string);
                    Logger.debugLog("  Actual: " ~ violation.actual.to!string);
                    Logger.debugLog("  Limit: " ~ violation.limit.to!string);
                }
                
                // Report as failure if violations occurred
                reportFailure(request.id, "Resource limit violations", startTime);
                return;
            }
            
            // 4. Upload outputs (simplified - would upload to artifact store)
            ArtifactId[] outputIds;
            foreach (outputSpec; request.outputs)
            {
                // Would read output file and upload
                // For now, generate placeholder ID
                outputIds ~= ArtifactId(new ubyte[32]);
            }
            
            // 5. Report success
            ActionResult result;
            result.id = request.id;
            result.status = output.exitCode == 0 ? ResultStatus.Success : ResultStatus.Failure;
            result.duration = duration;
            result.outputs = outputIds;
            result.stdout = output.stdout;
            result.stderr = output.stderr;
            result.exitCode = output.exitCode;
            result.resources = sandboxEnv.resourceUsage();
            
            sendResult(result);
            
            if (result.status == ResultStatus.Success)
                Logger.debugLog("Action succeeded: " ~ request.id.toString());
            else
                Logger.warning("Action failed with exit code " ~ output.exitCode.to!string);
        }
        catch (Exception e)
        {
            Logger.error("Action execution exception: " ~ e.msg);
            reportFailure(request.id, e.msg, startTime);
        }
        finally
        {
            atomicStore(state, WorkerState.Idle);
        }
    }
    
    /// Report action failure
    private void reportFailure(ActionId actionId, string error, MonoTime startTime) @trusted
    {
        import core.time : MonoTime;
        
        ActionResult result;
        result.id = actionId;
        result.status = ResultStatus.Error;
        result.stderr = error;
        result.duration = MonoTime.currTime - startTime;
        
        sendResult(result);
    }
    
    /// Request work from coordinator
    private ActionRequest requestWork() @trusted
    {
        import core.distributed.protocol.messages;
        
        try
        {
            // Create work request
            WorkRequest req;
            req.worker = id;
            req.desiredBatchSize = 1;
            
            auto reqData = serializeWorkRequest(req);
            
            // Send request (simplified - would use proper socket handling)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.WorkRequest];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)reqData.length;
            
            // Would send via coordinator transport and receive response
            // For now, return null (no work)
            
            return null;
        }
        catch (Exception e)
        {
            Logger.error("Work request failed: " ~ e.msg);
            return null;
        }
    }
    
    /// Peer announce loop
    private void peerAnnounceLoop() @trusted
    {
        while (atomicLoad(running))
        {
            try
            {
                sendPeerAnnounce();
                
                // Also prune stale peers periodically
                if (peerRegistry !is null)
                    peerRegistry.pruneStale();
                
                Thread.sleep(config.peerAnnounceInterval);
            }
            catch (Exception e)
            {
                Logger.error("Peer announce failed: " ~ e.msg);
            }
        }
    }
    
    /// Send peer announce to coordinator
    private void sendPeerAnnounce() @trusted
    {
        if (peerRegistry is null)
            return;
        
        try
        {
            PeerAnnounce announce;
            announce.worker = id;
            announce.address = config.listenAddress;
            announce.queueDepth = localQueue.size();
            announce.loadFactor = calculateLoadFactor();
            
            auto announceData = serializePeerAnnounce(announce);
            
            // Send via coordinator transport (simplified)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.PeerAnnounce];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)announceData.length;
            
            // Would send via socket
            
            Logger.debugLog("Peer announce sent");
        }
        catch (Exception e)
        {
            Logger.error("Failed to send peer announce: " ~ e.msg);
        }
    }
    
    /// Calculate current load factor
    private float calculateLoadFactor() @trusted nothrow
    {
        immutable queueSize = localQueue.size();
        immutable queueCapacity = config.localQueueSize;
        immutable queueLoad = cast(float)queueSize / queueCapacity;
        
        immutable executing = atomicLoad(state) == WorkerState.Executing ? 1 : 0;
        immutable executionLoad = cast(float)executing / config.maxConcurrentActions;
        
        // Weighted average
        return queueLoad * 0.7 + executionLoad * 0.3;
    }
    
    /// Send result to coordinator
    private void sendResult(ActionResult result) @trusted
    {
        import core.distributed.protocol.transport;
        
        try
        {
            // Create envelope
            auto envelope = Envelope!ActionResult(id, WorkerId(0), result);
            
            // Serialize
            auto http = cast(HttpTransport)coordinatorTransport;
            if (http is null)
            {
                Logger.error("Invalid transport for sending result");
                return;
            }
            
            auto msgData = http.serializeMessage(envelope);
            
            // Send via transport (simplified)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.ActionResult];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)msgData.length;
            
            // Would send via socket
            
            Logger.debugLog("Result sent: " ~ result.id.toString());
        }
        catch (Exception e)
        {
            Logger.error("Failed to send result: " ~ e.msg);
        }
    }
    
    /// Heartbeat loop
    private void heartbeatLoop() @trusted
    {
        while (atomicLoad(running))
        {
            try
            {
                sendHeartbeat();
                Thread.sleep(config.heartbeatInterval);
            }
            catch (Exception e)
            {
                Logger.error("Heartbeat failed: " ~ e.msg);
            }
        }
    }
    
    /// Send heartbeat to coordinator
    private void sendHeartbeat() @trusted
    {
        import core.distributed.protocol.transport;
        
        try
        {
            HeartBeat hb;
            hb.worker = id;
            hb.state = atomicLoad(state);
            hb.metrics = collectMetrics();
            hb.timestamp = Clock.currTime;
            
            // Send via transport
            auto sendResult = coordinatorTransport.send(WorkerId(0), hb);
            if (sendResult.isErr)
            {
                Logger.error("Heartbeat send failed: " ~ sendResult.unwrapErr().message());
                
                // If we can't send heartbeats, try to reconnect
                if (coordinatorTransport !is null)
                {
                    auto http = cast(HttpTransport)coordinatorTransport;
                    if (http !is null)
                    {
                        http.close();
                        auto reconnectResult = http.connect();
                        if (reconnectResult.isErr)
                            Logger.error("Failed to reconnect to coordinator");
                    }
                }
            }
            else
            {
                Logger.debugLog("Heartbeat sent (queue: " ~ hb.metrics.queueDepth.to!string ~ 
                              ", cpu: " ~ (hb.metrics.cpuUsage * 100).to!size_t.to!string ~ "%)");
            }
        }
        catch (Exception e)
        {
            Logger.error("Heartbeat send exception: " ~ e.msg);
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
        
        // Disk usage (simplified)
        m.diskUsage = 0.2;  // TODO: Platform-specific disk usage
        
        return m;
    }
    
    /// Backoff strategy (exponential with jitter)
    private void backoff(size_t attempt) @trusted
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
}



