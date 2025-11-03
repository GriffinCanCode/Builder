module engine.distributed.worker.queue;

import std.datetime : Duration, MonoTime;
import std.datetime : msecs;
import std.conv : to;
import core.atomic;
import core.sync.mutex : Mutex;
import infrastructure.utils.concurrency.deque : WorkStealingDeque;
import engine.distributed.protocol.protocol;
import engine.distributed.protocol.transport;
import engine.distributed.worker.peers;
import infrastructure.errors : Result, Ok, Err;
import infrastructure.utils.logging.logger;

/// Distributed queue manager
/// Bridges local work-stealing deque with network steal protocol
/// Optimized for minimal contention and zero-copy operations
final class DistributedQueue
{
    private WorkStealingDeque!ActionRequest* localQueue;
    private PeerRegistry peers;
    private Transport transport;
    private WorkerId selfId;
    private Mutex mutex;
    
    // Statistics
    private shared size_t localPushes;
    private shared size_t localPops;
    private shared size_t stealsGiven;
    private shared size_t stealsReceived;
    
    // Configuration
    private immutable size_t minLocalReserve;  // Min work to keep before allowing steals
    private immutable size_t maxStealBatch;    // Max items to give per steal request
    
    this(
        ref WorkStealingDeque!ActionRequest localQueue,
        PeerRegistry peers,
        Transport transport,
        WorkerId selfId,
        size_t minLocalReserve = 2,
        size_t maxStealBatch = 1) @trusted
    {
        this.localQueue = &localQueue;
        this.peers = peers;
        this.transport = transport;
        this.selfId = selfId;
        this.minLocalReserve = minLocalReserve;
        this.maxStealBatch = maxStealBatch;
        this.mutex = new Mutex();
    }
    
    /// Push work to local queue
    /// Fast path - no synchronization with remote workers
    void push(ActionRequest action) @trusted
    {
        localQueue.push(action);
        atomicOp!"+="(localPushes, 1);
    }
    
    /// Pop work from local queue (owner-only operation)
    /// O(1) operation, lock-free
    ActionRequest pop() @trusted
    {
        auto action = localQueue.pop();
        if (action !is null)
            atomicOp!"+="(localPops, 1);
        return action;
    }
    
    /// Attempt to steal work from remote peer
    /// Returns action if successful, null otherwise
    ActionRequest stealFromPeer(WorkerId victimId) @trusted
    {
        // Get victim's address
        auto peerResult = peers.getPeer(victimId);
        if (peerResult.isErr)
            return null;
        
        auto peer = peerResult.unwrap();
        
        // Create steal request
        StealRequest req;
        req.thief = selfId;
        req.victim = victimId;
        req.minPriority = Priority.Low;
        
        try
        {
            // Send steal request via transport
            auto sendResult = transport.sendStealRequest(victimId, req);
            if (sendResult.isErr)
            {
                peers.markDead(victimId);
                return null;
            }
            
            // Wait for response (with timeout)
            auto receiveResult = transport.receiveStealResponse(100.msecs);
            if (receiveResult.isErr)
                return null;
            
            auto envelope = receiveResult.unwrap();
            auto response = envelope.payload;
            
            if (response.hasWork)
            {
                atomicOp!"+="(stealsReceived, 1);
                Logger.debugLog("Successfully stole work from " ~ victimId.toString());
                return response.action;
            }
        }
        catch (Exception e)
        {
            Logger.error("Steal from peer failed: " ~ e.msg);
            peers.markDead(victimId);
        }
        
        return null;
    }
    
    /// Handle incoming steal request from remote peer
    /// Returns action to give, or null if insufficient work
    ActionRequest handleStealRequest(StealRequest req) @trusted
    {
        // Check if we have enough work to share
        immutable queueSize = localQueue.size();
        if (queueSize <= minLocalReserve)
        {
            Logger.debugLog("Rejecting steal from " ~ req.thief.toString() ~ 
                          " (queue too small: " ~ queueSize.to!string ~ ")");
            return null;
        }
        
        // Steal from bottom of our deque (FIFO for stealing)
        // This gives away "oldest" work, keeping recent work local
        auto stolen = localQueue.steal();
        
        if (stolen !is null)
        {
            atomicOp!"+="(stealsGiven, 1);
            Logger.debugLog("Gave work to " ~ req.thief.toString());
            
            // Update peer metrics
            peers.updateMetrics(
                selfId,
                localQueue.size(),
                calculateLoadFactor()
            );
        }
        
        return stolen;
    }
    
    /// Get current queue depth
    size_t depth() @trusted const
    {
        return localQueue.size();
    }
    
    /// Calculate load factor [0.0, 1.0]
    /// Used for peer selection and load balancing
    float calculateLoadFactor() @trusted const
    {
        immutable size = localQueue.size();
        immutable capacity = localQueue.capacity();
        
        if (capacity == 0)
            return 0.0f;
        
        return cast(float)size / cast(float)capacity;
    }
    
    /// Check if queue is empty
    bool empty() @trusted const
    {
        return localQueue.empty();
    }
    
    /// Get queue statistics
    struct QueueStats
    {
        size_t localPushes;
        size_t localPops;
        size_t stealsGiven;
        size_t stealsReceived;
        size_t currentDepth;
        float loadFactor;
        float stealEfficiency;  // stealsReceived / (stealsReceived + rejections)
    }
    
    QueueStats getStats() @trusted const
    {
        QueueStats stats;
        stats.localPushes = atomicLoad(localPushes);
        stats.localPops = atomicLoad(localPops);
        stats.stealsGiven = atomicLoad(stealsGiven);
        stats.stealsReceived = atomicLoad(stealsReceived);
        stats.currentDepth = localQueue.size();
        stats.loadFactor = calculateLoadFactor();
        
        // Calculate steal efficiency
        immutable received = stats.stealsReceived;
        immutable total = received + (atomicLoad(localPops) - received);
        if (total > 0)
            stats.stealEfficiency = cast(float)received / cast(float)total;
        
        return stats;
    }
    
    /// Reset statistics
    void resetStats() @trusted
    {
        atomicStore(localPushes, cast(size_t)0);
        atomicStore(localPops, cast(size_t)0);
        atomicStore(stealsGiven, cast(size_t)0);
        atomicStore(stealsReceived, cast(size_t)0);
    }
}

/// Queue metrics for observability
struct QueueMetrics
{
    size_t depth;               // Current queue depth
    float loadFactor;           // Utilization [0.0, 1.0]
    size_t stealsPerSecond;     // Steal rate
    float stealSuccessRate;     // Successful steals / attempts
}

/// Multi-queue manager for worker with multiple priorities
/// Implements priority-based work distribution
final class PriorityQueueManager
{
    private DistributedQueue[Priority] queues;
    private PeerRegistry peers;
    private Transport transport;
    private WorkerId selfId;
    
    this(PeerRegistry peers, Transport transport, WorkerId selfId, size_t queueCapacity) @trusted
    {
        this.peers = peers;
        this.transport = transport;
        this.selfId = selfId;
        
        // Create queue for each priority level
        foreach (priority; [Priority.Critical, Priority.High, Priority.Normal, Priority.Low])
        {
            auto localQueue = WorkStealingDeque!ActionRequest(queueCapacity);
            queues[priority] = new DistributedQueue(
                localQueue, peers, transport, selfId
            );
        }
    }
    
    /// Push action to appropriate priority queue
    void push(ActionRequest action) @trusted
    {
        if (auto queue = action.priority in queues)
            queue.push(action);
        else
            queues[Priority.Normal].push(action);
    }
    
    /// Pop highest priority available work
    /// Checks queues in priority order
    ActionRequest pop() @trusted
    {
        // Try critical first
        if (auto queue = Priority.Critical in queues)
        {
            auto action = queue.pop();
            if (action !is null)
                return action;
        }
        
        // Try high
        if (auto queue = Priority.High in queues)
        {
            auto action = queue.pop();
            if (action !is null)
                return action;
        }
        
        // Try normal
        if (auto queue = Priority.Normal in queues)
        {
            auto action = queue.pop();
            if (action !is null)
                return action;
        }
        
        // Try low
        if (auto queue = Priority.Low in queues)
            return queue.pop();
        
        return null;
    }
    
    /// Steal from peer
    ActionRequest stealFromPeer(WorkerId victimId) @trusted
    {
        // Try to steal highest priority work available
        foreach (priority; [Priority.Critical, Priority.High, Priority.Normal, Priority.Low])
        {
            if (auto queue = priority in queues)
            {
                auto action = queue.stealFromPeer(victimId);
                if (action !is null)
                    return action;
            }
        }
        
        return null;
    }
    
    /// Handle incoming steal request
    ActionRequest handleStealRequest(StealRequest req) @trusted
    {
        // Give away lowest priority work first
        foreach (priority; [Priority.Low, Priority.Normal, Priority.High, Priority.Critical])
        {
            if (auto queue = priority in queues)
            {
                auto action = queue.handleStealRequest(req);
                if (action !is null)
                    return action;
            }
        }
        
        return null;
    }
    
    /// Get total depth across all queues
    size_t totalDepth() @trusted const
    {
        size_t total = 0;
        foreach (queue; queues.values)
            total += queue.depth();
        return total;
    }
    
    /// Calculate aggregate load factor
    float loadFactor() @trusted const
    {
        if (queues.length == 0)
            return 0.0f;
        
        float total = 0.0f;
        foreach (queue; queues.values)
            total += queue.calculateLoadFactor();
        
        return total / queues.length;
    }
}



