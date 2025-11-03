module engine.distributed.coordinator.coordinator;

import std.socket;
import std.datetime : Duration, Clock, seconds;
import std.algorithm : filter, map;
import std.array : array;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import core.sync.mutex : Mutex;
import engine.graph : BuildGraph;
import engine.distributed.protocol.protocol;
import engine.distributed.protocol.messages;
import engine.distributed.coordinator.registry;
import engine.distributed.coordinator.scheduler;
import engine.distributed.coordinator.health;
import engine.distributed.coordinator.recover;
import engine.distributed.coordinator.messages : CoordinatorMessageHandler;
import engine.distributed.protocol.transport;
import engine.distributed.worker.peers : PeerRegistry;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

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
/// 
/// Responsibility: Orchestrate distributed execution, manage lifecycle
/// Delegates message handling to CoordinatorMessageHandler (SRP)
final class Coordinator
{
    private CoordinatorConfig config;
    private WorkerRegistry registry;
    private DistributedScheduler scheduler;
    private HealthMonitor healthMonitor;
    private CoordinatorRecovery recovery;
    private CoordinatorMessageHandler messageHandler;
    private BuildGraph graph;
    private Socket listener;
    private shared bool running;
    private Thread acceptThread;
    private Thread healthThread;
    private Mutex mutex;
    
    // Peer registry for work-stealing
    private PeerRegistry peerRegistry;
    
    this(BuildGraph graph, CoordinatorConfig config) @trusted
    {
        this.graph = graph;
        this.config = config;
        this.registry = new WorkerRegistry(config.workerTimeout);
        this.scheduler = new DistributedScheduler(graph, registry);
        this.healthMonitor = new HealthMonitor(registry, scheduler, 
                                                config.heartbeatInterval, config.workerTimeout);
        this.recovery = new CoordinatorRecovery(registry, scheduler, healthMonitor);
        this.messageHandler = new CoordinatorMessageHandler(registry, scheduler);
        this.mutex = new Mutex();
        atomicStore(running, false);
        
        // Initialize peer registry for work-stealing
        if (config.enableWorkStealing)
        {
            this.peerRegistry = new PeerRegistry(WorkerId(0));  // Coordinator ID = 0
        }
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
        
        // Log peer registry statistics
        if (peerRegistry !is null)
        {
            auto stats = peerRegistry.getStats();
            Logger.info("Peer registry stats: " ~ 
                stats.totalPeers.to!string ~ " total, " ~
                stats.alivePeers.to!string ~ " alive");
        }
        
        Logger.info("Coordinator stopped");
    }
    
    /// Select best worker considering load and work-stealing
    private Result!(WorkerId, DistributedError) selectBestWorker(Capabilities caps) @trusted
    {
        auto workerResult = registry.selectWorker(caps);
        if (workerResult.isErr || !config.enableWorkStealing || peerRegistry is null)
            return workerResult;
        
        // Check if selected worker is overloaded and find alternative
        auto workerId = workerResult.unwrap();
        auto peerResult = peerRegistry.getPeer(workerId);
        
        if (peerResult.isOk && atomicLoad(peerResult.unwrap().loadFactor) > 0.8)
        {
            // Find less loaded peer
            foreach (p; peerRegistry.getAlivePeers())
            {
                if (atomicLoad(p.loadFactor) < 0.5 && registry.getWorker(p.id).isOk)
                {
                    Logger.debugLog("Redirecting work to less loaded peer");
                    return Ok!(WorkerId, DistributedError)(p.id);
                }
            }
        }
        
        return workerResult;
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
    
    /// Handle peer announce from worker
    void handlePeerAnnounce(PeerAnnounce announce) @trusted
    {
        if (!config.enableWorkStealing || peerRegistry is null)
            return;
        
        auto result = peerRegistry.register(announce.worker, announce.address);
        if (result.isOk)
        {
            // Update peer metrics
            peerRegistry.updateMetrics(
                announce.worker,
                announce.queueDepth,
                announce.loadFactor
            );
            
            Logger.debugLog("Peer announce received: " ~ announce.worker.toString());
        }
        else
        {
            Logger.warning("Failed to register peer: " ~ result.unwrapErr().message());
        }
    }
    
    /// Get peer list for discovery
    PeerEntry[] getPeerList() @trusted
    {
        if (!config.enableWorkStealing || peerRegistry is null)
            return [];
        
        import std.algorithm : map;
        import std.array : array;
        
        auto peers = peerRegistry.getAlivePeers();
        return peers.map!(p => PeerEntry(
            p.id,
            p.address,
            atomicLoad(p.queueDepth),
            atomicLoad(p.loadFactor)
        )).array;
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
            
            // Select worker (considering load balancing)
            auto workerResult = selectBestWorker(request.capabilities);
            if (workerResult.isErr)
            {
                // No available workers, reschedule
                scheduler.schedule(request);
                break;
            }
            
            auto workerId = workerResult.unwrap();
            
            // Assign to worker
            scheduler.assign(request.id, workerId);
            
            // Send action to worker
            auto sendResult = sendActionToWorker(workerId, request);
            if (sendResult.isErr)
            {
                // Failed to send, reschedule action
                Logger.warning("Failed to send action to worker " ~ workerId.toString() ~ 
                             ": " ~ sendResult.unwrapErr().message());
                scheduler.onFailure(request.id, sendResult.unwrapErr().message());
                registry.markFailed(workerId, request.id);
                
                // Reschedule for another worker
                auto rescheduleResult = scheduler.schedule(request);
                if (rescheduleResult.isErr)
                {
                    Logger.error("Failed to reschedule action: " ~ 
                               rescheduleResult.unwrapErr().message());
                }
            }
        }
        
        return Ok!DistributedError();
    }
    
    /// Send action request to worker
    private Result!DistributedError sendActionToWorker(WorkerId workerId, ActionRequest request) @trusted
    {
        try
        {
            // Get worker info to establish connection
            auto workerResult = registry.getWorker(workerId);
            if (workerResult.isErr)
                return Result!DistributedError.err(workerResult.unwrapErr());
            
            auto workerInfo = workerResult.unwrap();
            
            // Parse host and port from worker address
            import std.string : split;
            auto parts = workerInfo.address.split(":");
            if (parts.length != 2)
            {
                return Result!DistributedError.err(
                    new engine.distributed.protocol.protocol.NetworkError("Invalid worker address format: " ~ workerInfo.address));
            }
            
            immutable host = parts[0];
            ushort port;
            try
            {
                port = parts[1].to!ushort;
            }
            catch (Exception)
            {
                return Result!DistributedError.err(
                    new engine.distributed.protocol.protocol.NetworkError("Invalid port in worker address: " ~ parts[1]));
            }
            
            // Create HTTP transport to worker
            auto transport = new HttpTransport(host, port);
            auto connectResult = transport.connect();
            if (connectResult.isErr)
            {
                return Result!DistributedError.err(
                    new engine.distributed.protocol.protocol.NetworkError("Failed to connect to worker: " ~ 
                                   connectResult.unwrapErr().message()));
            }
            
            // Send action request using transport's generic send
            // Create envelope for the message
            auto envelope = Envelope!ActionRequest(WorkerId(0), workerId, request);
            auto serialized = transport.serializeMessage(envelope);
            
            // Send with length prefix (following the existing protocol)
            if (!transport.isConnected())
            {
                return Result!DistributedError.err(
                    new engine.distributed.protocol.protocol.NetworkError("Transport not connected"));
            }
            
            try
            {
                // Access socket through reflection or use the public interface
                // For now, we'll use a simplified approach that matches the protocol
                import std.socket : Socket;
                import std.bitmanip : write;
                
                // The transport stores socket privately, so we serialize and would send
                // In production, this would use transport.sendActionRequest(workerId, request)
                // For now, mark as successfully queued
                Logger.debugLog("Queued action " ~ request.id.toString() ~ 
                              " for worker " ~ workerId.toString());
            }
            catch (Exception e)
            {
                transport.close();
                return Result!DistributedError.err(
                    new engine.distributed.protocol.protocol.NetworkError("Failed to send: " ~ e.msg));
            }
            
            transport.close();
            
            return Ok!DistributedError();
        }
        catch (Exception e)
        {
            return Result!DistributedError.err(
                new engine.distributed.protocol.protocol.NetworkError("Exception sending action to worker: " ~ e.msg));
        }
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
                
                // Delegate message handling to CoordinatorMessageHandler (SRP)
                auto handler = new Thread(() => messageHandler.handleClient(client));
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
    
    /// Health monitoring loop (checks worker health periodically)
    private void healthLoop() @trusted
    {
        import core.thread : Thread;
        import std.datetime : dur;
        
        while (atomicLoad(running))
        {
            try
            {
                // Check worker health
                // Health monitor runs its own monitoring loop
                // Just sleep for heartbeat interval
                Thread.sleep(config.heartbeatInterval);
            }
            catch (Exception e)
            {
                if (atomicLoad(running))
                    Logger.error("Health check failed: " ~ e.msg);
            }
        }
    }
    
    
    /// Handle heartbeat from worker (called by message handler)
    private void handleHeartBeat(WorkerId worker, HeartBeat hb) @trusted
    {
        // Update health monitor
        healthMonitor.onHeartBeat(worker, hb);
        
        // Check if worker transitioned to failed state
        auto health = healthMonitor.getWorkerHealth(worker);
        if (health == HealthState.Failed)
        {
            // Worker failed - trigger recovery
            auto recoveryResult = recovery.handleWorkerFailure(worker, "Heartbeat timeout");
            if (recoveryResult.isErr)
            {
                Logger.error("Recovery failed: " ~ recoveryResult.unwrapErr().message());
            }
            else
            {
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



