module core.distributed.coordinator.coordinator;

import std.socket;
import std.datetime : Duration, Clock, seconds;
import std.algorithm : filter, map;
import std.array : array;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import core.sync.mutex : Mutex;
import core.graph.graph : BuildGraph;
import core.distributed.protocol.protocol;
import core.distributed.coordinator.registry;
import core.distributed.coordinator.scheduler;
import core.distributed.protocol.transport;
import errors;
import utils.logging.logger;

/// Coordinator configuration
struct CoordinatorConfig
{
    string host = "0.0.0.0";
    ushort port = 9000;
    size_t maxWorkers = 1000;
    Duration workerTimeout = 30.seconds;
    bool enableWorkStealing = true;
    Duration heartbeatInterval = 5.seconds;
}

/// Build coordinator (manages distributed build execution)
final class Coordinator
{
    private CoordinatorConfig config;
    private WorkerRegistry registry;
    private DistributedScheduler scheduler;
    private BuildGraph graph;
    private Socket listener;
    private shared bool running;
    private Thread acceptThread;
    private Thread healthThread;
    private Mutex mutex;
    
    this(BuildGraph graph, CoordinatorConfig config) @trusted
    {
        this.graph = graph;
        this.config = config;
        this.registry = new WorkerRegistry(config.workerTimeout);
        this.scheduler = new DistributedScheduler(graph, registry);
        this.mutex = new Mutex();
        atomicStore(running, false);
    }
    
    /// Start coordinator server
    Result!DistributedError start() @trusted
    {
        synchronized (mutex)
        {
            if (atomicLoad(running))
                return Ok!DistributedError();
            
            try
            {
                // Bind server socket
                auto addr = new InternetAddress(config.host, config.port);
                listener = new TcpSocket();
                listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, 1);
                listener.bind(addr);
                listener.listen(cast(int)config.maxWorkers);
                
                atomicStore(running, true);
                
                // Start accept thread
                acceptThread = new Thread(&acceptLoop);
                acceptThread.start();
                
                // Start health monitor thread
                healthThread = new Thread(&healthLoop);
                healthThread.start();
                
                Logger.info("Coordinator started on " ~ config.host ~ ":" ~ config.port.to!string);
                
                return Ok!DistributedError();
            }
            catch (Exception e)
            {
                return Result!DistributedError.err(
                    new DistributedError("Failed to start coordinator: " ~ e.msg));
            }
        }
    }
    
    /// Stop coordinator
    void stop() @trusted
    {
        atomicStore(running, false);
        
        if (listener !is null)
        {
            try
            {
                listener.shutdown(SocketShutdown.BOTH);
                listener.close();
            }
            catch (Exception) {}
        }
        
        if (acceptThread !is null)
            acceptThread.join();
        
        if (healthThread !is null)
            healthThread.join();
        
        scheduler.shutdown();
        
        Logger.info("Coordinator stopped");
    }
    
    /// Schedule build action
    Result!DistributedError scheduleAction(ActionRequest request) @trusted
    {
        // Add to scheduler
        auto scheduleResult = scheduler.schedule(request);
        if (scheduleResult.isErr)
            return scheduleResult;
        
        // Try to assign to worker immediately
        return assignActions();
    }
    
    /// Assign ready actions to workers
    private Result!DistributedError assignActions() @trusted
    {
        while (true)
        {
            // Get next ready action
            auto actionResult = scheduler.dequeueReady();
            if (actionResult.isErr)
                break;  // No more ready actions
            
            auto request = actionResult.unwrap();
            
            // Select worker
            auto workerResult = registry.selectWorker(request.capabilities);
            if (workerResult.isErr)
            {
                // No available workers, reschedule
                scheduler.schedule(request);
                break;
            }
            
            auto workerId = workerResult.unwrap();
            
            // Assign to worker
            scheduler.assign(request.id, workerId);
            
            // Send to worker (TODO: implement transport)
            // auto sendResult = sendToWorker(workerId, request);
            // if (sendResult.isErr) ...
        }
        
            return Ok!DistributedError();
    }
    
    /// Accept loop (handles worker connections)
    private void acceptLoop() @trusted
    {
        while (atomicLoad(running))
        {
            try
            {
                // Accept connection with timeout
                listener.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, 1.seconds);
                auto client = listener.accept();
                
                // Handle in separate thread (or thread pool)
                auto handler = new Thread(() => handleClient(client));
                handler.start();
            }
            catch (SocketAcceptException)
            {
                // Timeout, continue
            }
            catch (Exception e)
            {
                if (atomicLoad(running))
                    Logger.error("Accept failed: " ~ e.msg);
            }
        }
    }
    
    private void cleanupSocket(Socket client) nothrow
    {
        try { client.shutdown(SocketShutdown.BOTH); } catch (Exception) {}
        try { client.close(); } catch (Exception) {}
    }
    
    /// Handle client connection
    private void handleClient(Socket client) @trusted
    {
        scope(exit)
        {
            cleanupSocket(client);
        }
        
        try
        {
            import core.distributed.protocol.messages;
            
            // Receive message type
            ubyte[1] typeBytes;
            auto received = client.receive(typeBytes);
            if (received != 1)
                return;
            
            immutable msgType = cast(MessageType)typeBytes[0];
            
            // Handle based on message type
            final switch (msgType)
            {
                case MessageType.Registration:
                    handleRegistration(client);
                    break;
                    
                case MessageType.HeartBeat:
                    handleHeartBeat(client);
                    break;
                    
                case MessageType.ActionResult:
                    handleActionResult(client);
                    break;
                    
                case MessageType.WorkRequest:
                    handleWorkRequest(client);
                    break;
                    
                case MessageType.ActionRequest:
                case MessageType.StealRequest:
                case MessageType.StealResponse:
                case MessageType.Shutdown:
                    // These are coordinator → worker, not expected here
                    Logger.warning("Unexpected message type from client");
                    break;
            }
        }
        catch (Exception e)
        {
            Logger.error("Client handler failed: " ~ e.msg);
        }
    }
    
    /// Handle worker registration
    private void handleRegistration(Socket client) @trusted
    {
        import core.distributed.protocol.messages;
        
        try
        {
            // Receive message length
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            
            // Receive registration data
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto regResult = deserializeRegistration(data);
            if (regResult.isErr)
            {
                Logger.error("Failed to deserialize registration: " ~ regResult.unwrapErr().message());
                return;
            }
            
            auto registration = regResult.unwrap();
            
            // Register worker
            auto workerIdResult = registry.register(registration.address);
            if (workerIdResult.isErr)
            {
                Logger.error("Failed to register worker: " ~ workerIdResult.unwrapErr().message());
                return;
            }
            
            auto workerId = workerIdResult.unwrap();
            
            // Send worker ID back
            ubyte[8] idBytes;
            *cast(ulong*)idBytes.ptr = workerId.value;
            client.send(idBytes);
            
            Logger.info("Worker registered: " ~ workerId.toString() ~ " (" ~ registration.address ~ ")");
        }
        catch (Exception e)
        {
            Logger.error("Registration handling failed: " ~ e.msg);
        }
    }
    
    /// Handle heartbeat
    private void handleHeartBeat(Socket client) @trusted
    {
        import core.distributed.protocol.transport;
        
        try
        {
            // Receive message
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize envelope
            auto http = new HttpTransport("", 0);
            auto envResult = http.deserializeMessage!HeartBeat(data);
            if (envResult.isErr)
                return;
            
            auto envelope = envResult.unwrap();
            registry.updateHeartbeat(envelope.payload.worker, envelope.payload);
            
            Logger.debugLog("Heartbeat from worker " ~ envelope.payload.worker.toString());
        }
        catch (Exception e)
        {
            Logger.error("Heartbeat handling failed: " ~ e.msg);
        }
    }
    
    /// Handle action result
    private void handleActionResult(Socket client) @trusted
    {
        import core.distributed.protocol.transport;
        
        try
        {
            // Receive message
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto http = new HttpTransport("", 0);
            auto envResult = http.deserializeMessage!ActionResult(data);
            if (envResult.isErr)
            {
                Logger.error("Failed to deserialize result");
                return;
            }
            
            auto envelope = envResult.unwrap();
            auto result = envelope.payload;
            
            // Process result
            if (result.status == ResultStatus.Success)
                scheduler.onComplete(result.id, result);
            else
                scheduler.onFailure(result.id, result.stderr);
            
            Logger.info("Action completed: " ~ result.id.toString());
            
            // Try to assign more work
            assignActions();
        }
        catch (Exception e)
        {
            Logger.error("Result handling failed: " ~ e.msg);
        }
    }
    
    /// Handle work request
    private void handleWorkRequest(Socket client) @trusted
    {
        import core.distributed.protocol.messages;
        
        try
        {
            // Receive message
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto reqResult = deserializeWorkRequest(data);
            if (reqResult.isErr)
                return;
            
            auto request = reqResult.unwrap();
            
            // Get ready actions
            ActionRequest[] actions;
            foreach (_; 0 .. request.desiredBatchSize)
            {
                auto actionResult = scheduler.dequeueReady();
                if (actionResult.isErr)
                    break;
                actions ~= actionResult.unwrap();
            }
            
            // Send batch
            if (actions.length > 0)
            {
                // Send count
                ubyte[4] countBytes;
                *cast(uint*)countBytes.ptr = cast(uint)actions.length;
                client.send(countBytes);
                
                // Send each action
                foreach (action; actions)
                {
                    scheduler.assign(action.id, request.worker);
                    
                    auto serialized = action.serialize();
                    ubyte[4] lenBytes;
                    *cast(uint*)lenBytes.ptr = cast(uint)serialized.length;
                    client.send(lenBytes);
                    client.send(serialized);
                }
                
                Logger.debugLog("Sent " ~ actions.length.to!string ~ " actions to worker " ~ request.worker.toString());
            }
            else
            {
                // No work available
                ubyte[4] countBytes;
                *cast(uint*)countBytes.ptr = 0;
                client.send(countBytes);
            }
        }
        catch (Exception e)
        {
            Logger.error("Work request handling failed: " ~ e.msg);
        }
    }
    
    /// Health monitoring loop
    private void healthLoop() @trusted
    {
        import core.time : msecs;
        
        while (atomicLoad(running))
        {
            try
            {
                checkWorkerHealth();
                Thread.sleep(config.heartbeatInterval);
            }
            catch (Exception e)
            {
                Logger.error("Health check failed: " ~ e.msg);
            }
        }
    }
    
    /// Check worker health and handle failures
    private void checkWorkerHealth() @trusted
    {
        auto workers = registry.allWorkers();
        
        foreach (worker; workers)
        {
            if (!worker.healthy(config.workerTimeout))
            {
                Logger.warning("Worker timeout: " ~ worker.id.toString());
                
                // Mark as failed
                registry.markWorkerFailed(worker.id);
                
                // Reassign its work
                scheduler.onWorkerFailure(worker.id);
                
                // Try to reassign immediately
                assignActions();
            }
        }
    }
    
    /// Get coordinator statistics
    struct CoordinatorStats
    {
        size_t workerCount;
        size_t healthyWorkerCount;
        size_t pendingActions;
        size_t executingActions;
        size_t completedActions;
        size_t failedActions;
    }
    
    CoordinatorStats getStats() @trusted
    {
        CoordinatorStats stats;
        stats.workerCount = registry.count();
        stats.healthyWorkerCount = registry.healthyCount();
        
        auto schedulerStats = scheduler.getStats();
        stats.pendingActions = schedulerStats.pending + schedulerStats.ready;
        stats.executingActions = schedulerStats.executing;
        stats.completedActions = schedulerStats.completed;
        stats.failedActions = schedulerStats.failed;
        
        return stats;
    }
}



