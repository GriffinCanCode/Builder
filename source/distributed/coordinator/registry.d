module distributed.coordinator.registry;

import std.datetime : SysTime, Clock, Duration, seconds;
import std.algorithm : filter, map, maxElement, minElement, sort, sum;
import std.array : array;
import std.range : empty;
import std.container : RedBlackTree;
import core.sync.mutex : Mutex;
import distributed.protocol.protocol;
import errors;

/// Worker information (registration and health)
struct WorkerInfo
{
    WorkerId id;                // Unique identifier
    string address;             // Network address (host:port)
    WorkerState state;          // Current state
    SystemMetrics metrics;      // Latest metrics
    SysTime lastSeen;           // Last heartbeat time
    SysTime registered;         // When worker joined
    ActionId[] inProgress;      // Currently executing actions
    size_t completed;           // Total actions completed
    size_t failed;              // Total actions failed
    Duration totalExecutionTime;  // Cumulative execution time
    
    /// Estimated load (for scheduling decisions)
    float load() const pure nothrow @safe @nogc
    {
        // Weighted combination of queue depth and CPU usage
        return metrics.queueDepth * 0.6 + metrics.cpuUsage * 0.4;
    }
    
    /// Is worker healthy?
    bool healthy(Duration timeout) const @safe
    {
        immutable elapsed = Clock.currTime - lastSeen;
        return state != WorkerState.Failed && elapsed < timeout;
    }
}

/// Worker registry (maintains worker pool state)
/// Thread-safe via mutex protection
final class WorkerRegistry
{
    private WorkerInfo[WorkerId] workers;
    private Mutex mutex;
    private Duration heartbeatTimeout;
    private size_t nextWorkerId;
    
    this(Duration heartbeatTimeout = 15.seconds) @trusted
    {
        this.mutex = new Mutex();
        this.heartbeatTimeout = heartbeatTimeout;
        this.nextWorkerId = 1;  // 0 is reserved for broadcast
    }
    
    /// Register new worker
    Result!(WorkerId, DistributedError) register(string address) @trusted
    {
        synchronized (mutex)
        {
            // Allocate worker ID
            immutable id = WorkerId(nextWorkerId++);
            
            // Create worker info
            WorkerInfo info;
            info.id = id;
            info.address = address;
            info.state = WorkerState.Idle;
            info.registered = Clock.currTime;
            info.lastSeen = Clock.currTime;
            
            workers[id] = info;
            
            return Ok!(WorkerId, DistributedError)(id);
        }
    }
    
    /// Unregister worker
    Result!DistributedError unregister(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (id !in workers)
            {
                DistributedError err = new WorkerError("Worker not found: " ~ id.toString());
                return Result!DistributedError.err(err);
            }
            
            workers.remove(id);
            return Ok!DistributedError();
        }
    }
    
    /// Update worker heartbeat
    void updateHeartbeat(WorkerId id, HeartBeat hb) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
            {
                worker.state = hb.state;
                worker.metrics = hb.metrics;
                worker.lastSeen = Clock.currTime;
            }
        }
    }
    
    /// Get worker information
    Result!(WorkerInfo, DistributedError) getWorker(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
                return Ok!(WorkerInfo, DistributedError)(*worker);
            else
                return Err!(WorkerInfo, DistributedError)(
                    new WorkerError("Worker not found: " ~ id.toString()));
        }
    }
    
    /// Get all workers
    WorkerInfo[] allWorkers() @trusted
    {
        synchronized (mutex)
        {
            return workers.values.dup;
        }
    }
    
    /// Get healthy workers only
    WorkerInfo[] healthyWorkers() @trusted
    {
        synchronized (mutex)
        {
            return workers.values
                .filter!(w => w.healthy(heartbeatTimeout))
                .array;
        }
    }
    
    /// Select best worker for action (capability-aware, load-balanced)
    Result!(WorkerId, DistributedError) selectWorker(Capabilities caps) @trusted
    {
        synchronized (mutex)
        {
            // 1. Filter healthy workers
            auto healthy = workers.values
                .filter!(w => w.healthy(heartbeatTimeout))
                .array;
            
            if (healthy.empty)
                return Err!(WorkerId, DistributedError)(
                    new WorkerError("No healthy workers available"));
            
            // 2. Filter by capabilities - check if worker can meet resource requirements
            auto capable = healthy
                .filter!(w => canMeetCapabilities(w, caps))
                .array;
            
            if (capable.empty)
                return Err!(WorkerId, DistributedError)(
                    new WorkerError("No capable workers available"));
            
            // 3. Select least loaded
            auto selected = capable.minElement!"a.load()";
            
            return Ok!(WorkerId, DistributedError)(selected.id);
        }
    }
    
    /// Check if worker can meet the required capabilities
    private bool canMeetCapabilities(in WorkerInfo worker, in Capabilities caps) const pure @safe
    {
        // Check memory constraints
        // If action requires specific memory and worker is already heavily loaded, skip
        if (caps.maxMemory > 0)
        {
            // Worker should have headroom for memory-intensive tasks
            if (worker.metrics.memoryUsage > 0.85)
                return false;
        }
        
        // Check CPU constraints
        // If worker is CPU-bound and action has CPU requirements, prefer less loaded workers
        if (caps.maxCpu > 0)
        {
            // Skip heavily loaded workers for CPU-intensive tasks
            if (worker.metrics.cpuUsage > 0.90)
                return false;
        }
        
        // Check disk space for tasks that may write large outputs
        // Ensure worker has sufficient disk space
        if (worker.metrics.diskUsage > 0.95)
            return false;
        
        // All capability checks passed
        return true;
    }
    
    /// Mark action as in-progress on worker
    void markInProgress(WorkerId id, ActionId action) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
            {
                worker.inProgress ~= action;
                worker.state = WorkerState.Executing;
            }
        }
    }
    
    /// Mark action as completed on worker
    void markCompleted(WorkerId id, ActionId action, Duration duration) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
            {
                // Remove from in-progress
                import std.algorithm : remove;
                worker.inProgress = worker.inProgress.remove!(a => a == action);
                
                // Update stats
                worker.completed++;
                worker.totalExecutionTime += duration;
                
                // Update state
                if (worker.inProgress.empty)
                    worker.state = WorkerState.Idle;
            }
        }
    }
    
    /// Mark action as failed on worker
    void markFailed(WorkerId id, ActionId action) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
            {
                // Remove from in-progress
                import std.algorithm : remove;
                worker.inProgress = worker.inProgress.remove!(a => a == action);
                
                // Update stats
                worker.failed++;
                
                // Update state
                if (worker.inProgress.empty)
                    worker.state = WorkerState.Idle;
            }
        }
    }
    
    /// Mark worker as failed (health check timeout)
    void markWorkerFailed(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
            {
                worker.state = WorkerState.Failed;
            }
        }
    }
    
    /// Get in-progress actions for worker (for failure recovery)
    ActionId[] inProgressActions(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers)
                return worker.inProgress.dup;
            else
                return [];
        }
    }
    
    /// Get worker count
    size_t count() @trusted
    {
        synchronized (mutex)
        {
            return workers.length;
        }
    }
    
    /// Get healthy worker count
    size_t healthyCount() @trusted
    {
        synchronized (mutex)
        {
            return workers.values
                .filter!(w => w.healthy(heartbeatTimeout))
                .array
                .length;
        }
    }
    
    /// Check if any workers are idle
    bool hasIdleWorkers() @trusted
    {
        synchronized (mutex)
        {
            return workers.values
                .filter!(w => w.state == WorkerState.Idle && w.healthy(heartbeatTimeout))
                .array
                .length > 0;
        }
    }
    
    /// Get worker load statistics (for monitoring)
    struct LoadStats
    {
        size_t totalWorkers;
        size_t healthyWorkers;
        size_t idleWorkers;
        float avgLoad;
        float maxLoad;
        float minLoad;
        size_t totalInProgress;
    }
    
    LoadStats getLoadStats() @trusted
    {
        synchronized (mutex)
        {
            LoadStats stats;
            stats.totalWorkers = workers.length;
            
            auto healthy = workers.values
                .filter!(w => w.healthy(heartbeatTimeout))
                .array;
            
            stats.healthyWorkers = healthy.length;
            stats.idleWorkers = healthy.filter!(w => w.state == WorkerState.Idle).array.length;
            
            if (healthy.length > 0)
            {
                auto loads = healthy.map!"a.load()".array;
                stats.avgLoad = loads.sum / loads.length;
                stats.maxLoad = loads.maxElement;
                stats.minLoad = loads.minElement;
            }
            
            stats.totalInProgress = workers.values
                .map!(w => w.inProgress.length)
                .sum;
            
            return stats;
        }
    }
}



