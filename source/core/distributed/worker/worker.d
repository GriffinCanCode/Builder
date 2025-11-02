module core.distributed.worker.worker;

import std.datetime : Duration, Clock, seconds, msecs;
import std.algorithm : remove;
import std.random : uniform;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import core.distributed.protocol.protocol;
import core.distributed.protocol.transport;
import utils.concurrency.deque : WorkStealingDeque;
import errors;
import utils.logging.logger;

/// Worker configuration
struct WorkerConfig
{
    string coordinatorUrl;                          // Coordinator address
    size_t maxConcurrentActions = 8;                // Max parallel execution
    size_t localQueueSize = 256;                    // Local work queue
    bool enableSandboxing = true;                   // Hermetic execution?
    Capabilities defaultCapabilities;               // Default sandbox settings
    Duration heartbeatInterval = 5.seconds;         // Heartbeat frequency
    Duration stealTimeout = 100.msecs;              // Work steal timeout
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
    private shared bool running;
    private SystemMetrics metrics;
    
    this(WorkerConfig config) @trusted
    {
        this.config = config;
        this.localQueue = WorkStealingDeque!ActionRequest(config.localQueueSize);
        atomicStore(state, WorkerState.Idle);
        atomicStore(running, false);
    }
    
    /// Start worker
    Result!DistributedError start() @trusted
    {
        if (atomicLoad(running))
            return Ok!DistributedError();
        
        // Connect to coordinator
        auto transportResult = TransportFactory.create(config.coordinatorUrl);
        if (transportResult.isErr)
            return Err!DistributedError(transportResult.unwrapErr());
        
        coordinatorTransport = transportResult.unwrap();
        
        // Register with coordinator
        auto registerResult = registerWithCoordinator();
        if (registerResult.isErr)
            return Err!DistributedError(registerResult.unwrapErr());
        
        id = registerResult.unwrap();
        
        atomicStore(running, true);
        
        // Start main loop
        mainThread = new Thread(&mainLoop);
        mainThread.start();
        
        // Start heartbeat
        heartbeatThread = new Thread(&heartbeatLoop);
        heartbeatThread.start();
        
        Logger.infoLog("Worker started: " ~ id.toString());
        
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
        
        if (coordinatorTransport !is null)
            coordinatorTransport.close();
        
        Logger.infoLog("Worker stopped: " ~ id.toString());
    }
    
    /// Register with coordinator
    private Result!(WorkerId, DistributedError) registerWithCoordinator() @trusted
    {
        // TODO: Implement registration protocol
        // For now, generate random ID
        import std.random : uniform;
        return Ok!(WorkerId, DistributedError)(WorkerId(uniform!ulong()));
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
            if (config.enableSandboxing)
            {
                auto stolenAction = tryStealWork();
                if (stolenAction !is null)
                {
                    executeAction(stolenAction);
                    consecutiveIdle = 0;
                    continue;
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
        
        atomicStore(state, WorkerState.Executing);
        auto startTime = MonoTime.currTime;
        
        Logger.debugLog("Executing action: " ~ request.id.toString());
        
        try
        {
            // TODO: Implement actual execution
            // 1. Fetch input artifacts
            // 2. Prepare sandbox
            // 3. Execute command
            // 4. Upload outputs
            // 5. Send result to coordinator
            
            // Placeholder: simulate execution
            Thread.sleep(100.msecs);
            
            auto duration = MonoTime.currTime - startTime;
            
            // Report success
            ActionResult result;
            result.id = request.id;
            result.status = ResultStatus.Success;
            result.duration = duration;
            
            sendResult(result);
        }
        catch (Exception e)
        {
            Logger.errorLog("Action failed: " ~ e.msg);
            
            // Report failure
            ActionResult result;
            result.id = request.id;
            result.status = ResultStatus.Error;
            result.stderr = e.msg;
            
            sendResult(result);
        }
        finally
        {
            atomicStore(state, WorkerState.Idle);
        }
    }
    
    /// Request work from coordinator
    private ActionRequest requestWork() @trusted
    {
        // TODO: Implement work request protocol
        return null;
    }
    
    /// Try to steal work from peer
    private ActionRequest tryStealWork() @trusted
    {
        atomicStore(state, WorkerState.Stealing);
        scope(exit) atomicStore(state, WorkerState.Idle);
        
        // TODO: Implement work stealing protocol
        // 1. Select random peer
        // 2. Send steal request
        // 3. Receive response
        
        return null;
    }
    
    /// Send result to coordinator
    private void sendResult(ActionResult result) @trusted
    {
        // TODO: Implement result reporting
        Logger.debugLog("Action completed: " ~ result.id.toString());
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
                Logger.errorLog("Heartbeat failed: " ~ e.msg);
            }
        }
    }
    
    /// Send heartbeat to coordinator
    private void sendHeartbeat() @trusted
    {
        HeartBeat hb;
        hb.worker = id;
        hb.state = atomicLoad(state);
        hb.metrics = collectMetrics();
        hb.timestamp = Clock.currTime;
        
        // TODO: Send via transport
    }
    
    /// Collect system metrics
    private SystemMetrics collectMetrics() @trusted
    {
        SystemMetrics m;
        
        // TODO: Collect real metrics
        // For now, placeholder values
        m.cpuUsage = 0.5;
        m.memoryUsage = 0.3;
        m.diskUsage = 0.2;
        m.queueDepth = localQueue.size();
        m.activeActions = atomicLoad(state) == WorkerState.Executing ? 1 : 0;
        
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



