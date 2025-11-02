module core.distributed.worker.worker;

import std.datetime : Duration, Clock, seconds, msecs;
import core.time : MonoTime;
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
        
        if (coordinatorTransport !is null)
            coordinatorTransport.close();
        
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
    
    /// Try to steal work from peer
    private ActionRequest tryStealWork() @trusted
    {
        atomicStore(state, WorkerState.Stealing);
        scope(exit) atomicStore(state, WorkerState.Idle);
        
        // Work stealing not yet fully implemented
        // Would need peer discovery and steal protocol
        // For now, return null
        
        return null;
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
            
            // Create envelope
            auto envelope = Envelope!HeartBeat(id, WorkerId(0), hb);
            
            // Serialize
            auto http = cast(HttpTransport)coordinatorTransport;
            if (http is null)
                return;
            
            auto msgData = http.serializeMessage(envelope);
            
            // Send via transport (simplified)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.HeartBeat];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)msgData.length;
            
            // Would send via socket
            
            Logger.debugLog("Heartbeat sent");
        }
        catch (Exception e)
        {
            Logger.error("Heartbeat send failed: " ~ e.msg);
        }
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



