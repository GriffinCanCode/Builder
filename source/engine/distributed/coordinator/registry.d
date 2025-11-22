module engine.distributed.coordinator.registry;

import std.datetime : SysTime, Clock, Duration, seconds;
import std.algorithm : filter, map, maxElement, minElement, sort, sum;
import std.array : array;
import std.range : empty;
import std.container : RedBlackTree;
import core.sync.mutex : Mutex;
import engine.distributed.protocol.protocol;
import infrastructure.errors;

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
    float load() const pure nothrow @safe @nogc => metrics.queueDepth * 0.6 + metrics.cpuUsage * 0.4;
    
    /// Is worker healthy?
    bool healthy(Duration timeout) const @safe => state != WorkerState.Failed && (Clock.currTime - lastSeen) < timeout;
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
            immutable id = WorkerId(nextWorkerId++), now = Clock.currTime;
            workers[id] = WorkerInfo(id, address, WorkerState.Idle, SystemMetrics.init, now, now, [], 0, 0, Duration.zero);
            return Ok!(WorkerId, DistributedError)(id);
        }
    }
    
    /// Unregister worker
    Result!DistributedError unregister(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (id !in workers) return Result!DistributedError.err(new WorkerError("Worker not found: " ~ id.toString()));
            workers.remove(id);
            return Ok!DistributedError();
        }
    }
    
    /// Update worker heartbeat
    void updateHeartbeat(WorkerId id, HeartBeat hb) @trusted
    {
        synchronized (mutex) if (auto worker = id in workers)
        {
            worker.state = hb.state;
            worker.metrics = hb.metrics;
            worker.lastSeen = Clock.currTime;
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
    
    WorkerInfo[] allWorkers() @trusted
    {
        synchronized (mutex) return workers.values.dup;
    }
    
    WorkerInfo[] healthyWorkers() @trusted
    {
        synchronized (mutex) return workers.values.filter!(w => w.healthy(heartbeatTimeout)).array;
    }
    
    /// Select best worker for action (capability-aware, load-balanced)
    Result!(WorkerId, DistributedError) selectWorker(Capabilities caps) @trusted
    {
        synchronized (mutex)
        {
            auto healthy = workers.values.filter!(w => w.healthy(heartbeatTimeout)).array;
            if (healthy.empty) return Err!(WorkerId, DistributedError)(new WorkerError("No healthy workers available"));
            
            auto capable = healthy.filter!(w => canMeetCapabilities(w, caps)).array;
            if (capable.empty) return Err!(WorkerId, DistributedError)(new WorkerError("No capable workers available"));
            
            return Ok!(WorkerId, DistributedError)(capable.minElement!"a.load()".id);
        }
    }
    
    /// Check if worker can meet the required capabilities
    private bool canMeetCapabilities(in WorkerInfo worker, in Capabilities caps) const pure @safe
    {
        if (caps.maxMemory > 0 && worker.metrics.memoryUsage > 0.85) return false;
        if (caps.maxCpu > 0 && worker.metrics.cpuUsage > 0.90) return false;
        if (worker.metrics.diskUsage > 0.95) return false;
        return true;
    }
    
    void markInProgress(WorkerId id, ActionId action) @trusted
    {
        synchronized (mutex) if (auto worker = id in workers)
        {
            worker.inProgress ~= action;
            worker.state = WorkerState.Executing;
        }
    }
    
    /// Mark action as completed on worker
    void markCompleted(WorkerId id, ActionId action, Duration duration) @trusted
    {
        synchronized (mutex) if (auto worker = id in workers)
        {
            import std.algorithm : remove;
            worker.inProgress = worker.inProgress.remove!(a => a == action);
            worker.completed++;
            worker.totalExecutionTime += duration;
            if (worker.inProgress.empty) worker.state = WorkerState.Idle;
        }
    }
    
    /// Mark action as failed on worker
    void markFailed(WorkerId id, ActionId action) @trusted
    {
        synchronized (mutex) if (auto worker = id in workers)
        {
            import std.algorithm : remove;
            worker.inProgress = worker.inProgress.remove!(a => a == action);
            worker.failed++;
            if (worker.inProgress.empty) worker.state = WorkerState.Idle;
        }
    }
    
    void markWorkerFailed(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers) worker.state = WorkerState.Failed;
        }
    }
    
    ActionId[] inProgressActions(WorkerId id) @trusted
    {
        synchronized (mutex)
            return (id in workers) ? workers[id].inProgress.dup : [];
    }
    
    size_t count() @trusted
    {
        synchronized (mutex)
            return workers.length;
    }
    
    size_t healthyCount() @trusted
    {
        import std.range : walkLength;
        synchronized (mutex)
            return workers.values.filter!(w => w.healthy(heartbeatTimeout)).walkLength;
    }
    
    bool hasIdleWorkers() @trusted
    {
        synchronized (mutex)
            return !workers.values.filter!(w => w.state == WorkerState.Idle && w.healthy(heartbeatTimeout)).empty;
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
    
    /// Get least utilized workers for scale-down operations (returns workers sorted by utilization, preferring: lower load, higher failure rate, recently joined)
    WorkerId[] getLeastUtilizedWorkers(size_t count) @trusted
    {
        synchronized (mutex)
        {
            import std.algorithm : sort;
            import std.range : take;
            
            auto available = workers.values.filter!(w => w.healthy(heartbeatTimeout) && w.inProgress.empty).array;
            if (available.empty) return [];
            
            available.sort!((a, b) {
                immutable aUtil = a.load() + (a.failed > 0 ? a.failed / cast(float)(a.completed + 1) : 0);
                immutable bUtil = b.load() + (b.failed > 0 ? b.failed / cast(float)(b.completed + 1) : 0);
                return aUtil < bUtil;
            });
            
            return available.take(count).map!(w => w.id).array;
        }
    }
    
    /// Mark worker as draining (no new work assigned)
    void markDraining(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers) worker.state = WorkerState.Draining;
        }
    }
    
    /// Check if worker has completed draining (no in-progress actions)
    bool isDrained(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto worker = id in workers) return worker.inProgress.empty;
            return true;
        }
    }
}



