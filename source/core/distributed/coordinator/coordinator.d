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
                listener.listen(config.maxWorkers);
                
                atomicStore(running, true);
                
                // Start accept thread
                acceptThread = new Thread(&acceptLoop);
                acceptThread.start();
                
                // Start health monitor thread
                healthThread = new Thread(&healthLoop);
                healthThread.start();
                
                Logger.infoLog("Coordinator started on " ~ config.host ~ ":" ~ config.port.to!string);
                
                return Ok!DistributedError();
            }
            catch (Exception e)
            {
                return Err!DistributedError(
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
        
        Logger.infoLog("Coordinator stopped");
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
                    Logger.errorLog("Accept failed: " ~ e.msg);
            }
        }
    }
    
    /// Handle client connection
    private void handleClient(Socket client) @trusted
    {
        scope(exit)
        {
            try
            {
                client.shutdown(SocketShutdown.BOTH);
                client.close();
            }
            catch (Exception) {}
        }
        
        try
        {
            // TODO: Implement message handling
            // 1. Worker registration
            // 2. Heartbeat processing
            // 3. Action result handling
            // 4. Work steal coordination
        }
        catch (Exception e)
        {
            Logger.errorLog("Client handler failed: " ~ e.msg);
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
                Logger.errorLog("Health check failed: " ~ e.msg);
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
                Logger.warnLog("Worker timeout: " ~ worker.id.toString());
                
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



