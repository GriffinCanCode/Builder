module core.distributed.coordinator.recover;

import std.datetime : Duration, Clock, SysTime, seconds;
import std.algorithm : filter, map, sort, remove;
import std.array : array;
import std.container : DList;
import core.atomic;
import core.sync.mutex : Mutex;
import core.distributed.protocol.protocol;
import core.distributed.coordinator.registry;
import core.distributed.coordinator.scheduler;
import core.distributed.coordinator.health;
import errors;
import utils.logging.logger;

/// Work reassignment strategy
enum ReassignStrategy
{
    RoundRobin,     // Distribute evenly
    LeastLoaded,    // Assign to least loaded worker
    Affinity,       // Try to maintain locality
    Priority        // Prioritize critical work
}

/// Coordinator-side failure recovery
/// Handles work reassignment and worker blacklisting
final class CoordinatorRecovery
{
    private WorkerRegistry registry;
    private DistributedScheduler scheduler;
    private HealthMonitor healthMonitor;
    private Mutex mutex;
    
    // Blacklist management
    private WorkerBlacklist[WorkerId] blacklist;
    private immutable Duration maxBlacklistDuration = 300.seconds;
    
    // Reassignment queue (high priority for failed work)
    private DList!ActionId reassignmentQueue;
    private ReassignStrategy strategy;
    
    // Statistics
    private shared size_t totalFailures;
    private shared size_t successfulReassignments;
    private shared size_t failedReassignments;
    private shared size_t blacklistedWorkers;
    
    this(
        WorkerRegistry registry,
        DistributedScheduler scheduler,
        HealthMonitor healthMonitor,
        ReassignStrategy strategy = ReassignStrategy.Priority) @trusted
    {
        this.registry = registry;
        this.scheduler = scheduler;
        this.healthMonitor = healthMonitor;
        this.strategy = strategy;
        this.mutex = new Mutex();
    }
    
    /// Handle worker failure
    Result!DistributedError handleWorkerFailure(WorkerId worker, string reason) @trusted
    {
        atomicOp!"+="(totalFailures, 1);
        
        Logger.warning("Handling worker failure: " ~ worker.toString() ~ " (" ~ reason ~ ")");
        
        synchronized (mutex)
        {
            // Get in-progress actions from failed worker
            auto inProgressActions = registry.inProgressActions(worker);
            
            if (inProgressActions.length == 0)
            {
                Logger.info("No work to reassign from " ~ worker.toString());
                return Ok!DistributedError();
            }
            
            Logger.info("Reassigning " ~ inProgressActions.length.to!string ~ 
                       " actions from " ~ worker.toString());
            
            // Add to reassignment queue (high priority)
            foreach (action; inProgressActions)
            {
                reassignmentQueue.insertBack(action);
            }
            
            // Notify scheduler of worker failure
            scheduler.onWorkerFailure(worker);
            
            // Add worker to blacklist
            blacklistWorker(worker, reason);
            
            // Attempt immediate reassignment
            return reassignActions();
        }
    }
    
    /// Reassign actions from queue
    Result!DistributedError reassignActions() @trusted
    {
        synchronized (mutex)
        {
            while (!reassignmentQueue.empty)
            {
                auto action = reassignmentQueue.front;
                reassignmentQueue.removeFront();
                
                // Select best available worker
                auto workerResult = selectWorkerForReassignment(action);
                if (workerResult.isErr)
                {
                    // No workers available - put back in queue
                    reassignmentQueue.insertFront(action);
                    atomicOp!"+="(failedReassignments, 1);
                    
                    Logger.warning("No workers available for reassignment");
                    return Err!DistributedError(
                        new DistributedError("No available workers for reassignment"));
                }
                
                auto worker = workerResult.unwrap();
                
                // Reassign action
                auto assignResult = scheduler.assign(action, worker);
                if (assignResult.isErr)
                {
                    atomicOp!"+="(failedReassignments, 1);
                    Logger.error("Failed to reassign action: " ~ assignResult.unwrapErr().message());
                    return assignResult;
                }
                
                atomicOp!"+="(successfulReassignments, 1);
                Logger.info("Reassigned action " ~ action.toString() ~ " to worker " ~ worker.toString());
            }
            
            return Ok!DistributedError();
        }
    }
    
    /// Check if worker is blacklisted
    bool isBlacklisted(WorkerId worker) @trusted
    {
        synchronized (mutex)
        {
            if (auto entry = worker in blacklist)
            {
                // Check if blacklist has expired
                if (entry.shouldRetry(Clock.currTime))
                {
                    removeFromBlacklist(worker);
                    return false;
                }
                return true;
            }
            return false;
        }
    }
    
    /// Remove worker from blacklist
    void removeFromBlacklist(WorkerId worker) @trusted
    {
        synchronized (mutex)
        {
            if (worker in blacklist)
            {
                blacklist.remove(worker);
                atomicOp!"-="(blacklistedWorkers, 1);
                Logger.info("Worker removed from blacklist: " ~ worker.toString());
            }
        }
    }
    
    /// Get reassignment queue size
    size_t pendingReassignments() @trusted
    {
        synchronized (mutex)
        {
            return reassignmentQueue.length;
        }
    }
    
    /// Get recovery statistics
    struct RecoveryStats
    {
        size_t totalFailures;
        size_t successfulReassignments;
        size_t failedReassignments;
        size_t pendingReassignments;
        size_t blacklistedWorkers;
        float reassignmentSuccessRate;
    }
    
    RecoveryStats getStats() @trusted
    {
        RecoveryStats stats;
        
        stats.totalFailures = atomicLoad(totalFailures);
        stats.successfulReassignments = atomicLoad(successfulReassignments);
        stats.failedReassignments = atomicLoad(failedReassignments);
        stats.blacklistedWorkers = atomicLoad(blacklistedWorkers);
        
        synchronized (mutex)
        {
            stats.pendingReassignments = reassignmentQueue.length;
        }
        
        immutable total = stats.successfulReassignments + stats.failedReassignments;
        if (total > 0)
            stats.reassignmentSuccessRate = 
                cast(float)stats.successfulReassignments / cast(float)total;
        
        return stats;
    }
    
    /// Reset statistics
    void resetStats() @trusted
    {
        atomicStore(totalFailures, cast(size_t)0);
        atomicStore(successfulReassignments, cast(size_t)0);
        atomicStore(failedReassignments, cast(size_t)0);
    }
    
    private:
    
    /// Blacklist worker with exponential backoff
    void blacklistWorker(WorkerId worker, string reason) @trusted
    {
        if (auto entry = worker in blacklist)
        {
            // Worker already blacklisted - extend duration
            entry.failureCount++;
            entry.lastFailure = Clock.currTime;
            
            // Exponential backoff
            immutable backoffSeconds = 1 << min(entry.failureCount, 8);
            immutable duration = min(
                seconds(backoffSeconds),
                maxBlacklistDuration
            );
            entry.nextRetryTime = Clock.currTime + duration;
            
            Logger.warning("Worker blacklist extended: " ~ worker.toString() ~ 
                         " (failures: " ~ entry.failureCount.to!string ~ 
                         ", next retry: " ~ backoffSeconds.to!string ~ "s)");
        }
        else
        {
            // First failure - add to blacklist
            blacklist[worker] = WorkerBlacklist(
                worker,
                reason,
                Clock.currTime,
                Clock.currTime + 5.seconds,  // Initial 5 second backoff
                1
            );
            
            atomicOp!"+="(blacklistedWorkers, 1);
            Logger.info("Worker blacklisted: " ~ worker.toString() ~ " (reason: " ~ reason ~ ")");
        }
    }
    
    /// Select worker for reassignment based on strategy
    Result!(WorkerId, DistributedError) selectWorkerForReassignment(ActionId action) @trusted
    {
        // Get healthy, non-blacklisted workers
        auto candidates = registry.healthyWorkers()
            .filter!(w => !isBlacklisted(w.id))
            .array;
        
        if (candidates.length == 0)
            return Err!(WorkerId, DistributedError)(
                new WorkerError("No healthy workers available"));
        
        final switch (strategy)
        {
            case ReassignStrategy.RoundRobin:
                return selectRoundRobin(candidates);
            
            case ReassignStrategy.LeastLoaded:
                return selectLeastLoaded(candidates);
            
            case ReassignStrategy.Affinity:
                return selectAffinity(action, candidates);
            
            case ReassignStrategy.Priority:
                return selectPriority(action, candidates);
        }
    }
    
    /// Round-robin selection
    Result!(WorkerId, DistributedError) selectRoundRobin(WorkerInfo[] candidates) @trusted
    {
        static size_t nextIndex = 0;
        immutable idx = nextIndex % candidates.length;
        nextIndex++;
        return Ok!(WorkerId, DistributedError)(candidates[idx].id);
    }
    
    /// Select least loaded worker
    Result!(WorkerId, DistributedError) selectLeastLoaded(WorkerInfo[] candidates) @trusted
    {
        import std.algorithm : minElement;
        auto selected = candidates.minElement!"a.load()";
        return Ok!(WorkerId, DistributedError)(selected.id);
    }
    
    /// Select worker with affinity (locality)
    Result!(WorkerId, DistributedError) selectAffinity(
        ActionId action,
        WorkerInfo[] candidates) @trusted
    {
        // For now, just select least loaded
        // In future, could track which worker has related artifacts cached
        return selectLeastLoaded(candidates);
    }
    
    /// Select worker prioritizing health and capacity
    Result!(WorkerId, DistributedError) selectPriority(
        ActionId action,
        WorkerInfo[] candidates) @trusted
    {
        import std.algorithm : maxElement;
        
        // Score each worker based on:
        // - Health state (prefer healthy over degraded)
        // - Load (prefer less loaded)
        // - Recent completion rate (prefer successful workers)
        
        struct ScoredWorker
        {
            WorkerId id;
            float score;
        }
        
        ScoredWorker[] scored;
        scored.reserve(candidates.length);
        
        foreach (worker; candidates)
        {
            float score = 0.0f;
            
            // Health score (0-100)
            auto health = healthMonitor.getWorkerHealth(worker.id);
            final switch (health)
            {
                case HealthState.Healthy:
                    score += 100.0f;
                    break;
                case HealthState.Degraded:
                    score += 50.0f;
                    break;
                case HealthState.Failing:
                    score += 25.0f;
                    break;
                case HealthState.Failed:
                    score += 0.0f;
                    break;
                case HealthState.Recovering:
                    score += 40.0f;
                    break;
            }
            
            // Load score (0-50) - less load = higher score
            score += (1.0f - worker.load()) * 50.0f;
            
            // Success rate score (0-50)
            immutable total = worker.completed + worker.failed;
            if (total > 0)
            {
                immutable successRate = cast(float)worker.completed / cast(float)total;
                score += successRate * 50.0f;
            }
            
            scored ~= ScoredWorker(worker.id, score);
        }
        
        auto best = scored.maxElement!"a.score";
        return Ok!(WorkerId, DistributedError)(best.id);
    }
}

/// Worker blacklist entry
struct WorkerBlacklist
{
    WorkerId worker;
    string reason;
    SysTime lastFailure;
    SysTime nextRetryTime;
    size_t failureCount;
    
    /// Should we retry this worker now?
    bool shouldRetry(SysTime now) const pure @safe nothrow @nogc
    {
        return now >= nextRetryTime;
    }
}

/// Work reassignment manager
/// Handles bulk reassignment operations
final class ReassignmentManager
{
    private CoordinatorRecovery recovery;
    private WorkerRegistry registry;
    private Mutex mutex;
    
    // Reassignment batching
    private ActionId[] batchQueue;
    private immutable size_t batchSize = 10;
    
    this(CoordinatorRecovery recovery, WorkerRegistry registry) @trusted
    {
        this.recovery = recovery;
        this.registry = registry;
        this.mutex = new Mutex();
    }
    
    /// Add action to reassignment batch
    void addToBatch(ActionId action) @trusted
    {
        synchronized (mutex)
        {
            batchQueue ~= action;
            
            // Process batch if full
            if (batchQueue.length >= batchSize)
            {
                processBatch();
            }
        }
    }
    
    /// Force process current batch
    void flush() @trusted
    {
        synchronized (mutex)
        {
            if (batchQueue.length > 0)
            {
                processBatch();
            }
        }
    }
    
    private:
    
    /// Process batch of reassignments
    void processBatch() @trusted
    {
        if (batchQueue.length == 0)
            return;
        
        Logger.info("Processing reassignment batch: " ~ batchQueue.length.to!string ~ " actions");
        
        // Group actions by priority
        ActionId[][Priority] byPriority;
        
        // For now, simplified - just reassign in order
        foreach (action; batchQueue)
        {
            // Would get priority from scheduler
            // byPriority[priority] ~= action;
        }
        
        // Clear batch
        batchQueue.length = 0;
    }
}



