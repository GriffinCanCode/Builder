module core.distributed.coordinator.scheduler;

import std.algorithm : map, filter, maxElement, sort, uniq;
import std.array : array;
import std.container : DList;
import std.datetime : Duration, msecs;
import core.sync.mutex : Mutex;
import core.atomic;
import core.graph.graph : BuildGraph, BuildNode;
import core.distributed.protocol.protocol;
import core.distributed.coordinator.registry;
import errors;

/// Action scheduling state
private enum ActionState
{
    Pending,    // Waiting for dependencies
    Ready,      // Ready to execute
    Scheduled,  // Assigned to worker
    Executing,  // Currently running
    Completed,  // Finished successfully
    Failed      // Execution failed
}

/// Internal action tracking
private struct ActionInfo
{
    ActionId id;
    ActionRequest request;
    ActionState state;
    WorkerId assignedWorker;
    size_t retries;
    Priority priority;
}

/// Distributed scheduler
/// Coordinates action execution across worker pool
final class DistributedScheduler
{
    private BuildGraph graph;
    private WorkerRegistry registry;
    private ActionInfo[ActionId] actions;
    private DList!ActionId readyQueue;
    private Mutex mutex;
    private shared bool running;
    
    private enum size_t MAX_RETRIES = 3;
    
    this(BuildGraph graph, WorkerRegistry registry) @trusted
    {
        this.graph = graph;
        this.registry = registry;
        this.mutex = new Mutex();
        atomicStore(running, true);
    }
    
    /// Schedule action for execution
    Result!DistributedError schedule(ActionRequest request) @trusted
    {
        synchronized (mutex)
        {
            // Check if already scheduled
            if (request.id in actions)
                return Ok!DistributedError();
            
            // Create action info
            ActionInfo info;
            info.id = request.id;
            info.request = request;
            info.state = ActionState.Pending;
            info.priority = request.priority;
            
            actions[request.id] = info;
            
            // Check if ready to execute
            if (isReady(request.id))
            {
                markReady(request.id);
            }
            
            return Ok!DistributedError();
        }
    }
    
    /// Get next ready action (for coordinator to assign)
    Result!(ActionRequest, DistributedError) dequeueReady() @trusted
    {
        synchronized (mutex)
        {
            if (readyQueue.empty)
                return Err!(ActionRequest, DistributedError)(
                    new DistributedError("No ready actions"));
            
            auto actionId = readyQueue.front;
            readyQueue.removeFront();
            
            if (auto info = actionId in actions)
            {
                info.state = ActionState.Scheduled;
                return Ok!(ActionRequest, DistributedError)(info.request);
            }
            else
            {
                return Err!(ActionRequest, DistributedError)(
                    new DistributedError("Action not found: " ~ actionId.toString()));
            }
        }
    }
    
    /// Assign action to worker
    Result!DistributedError assign(ActionId action, WorkerId worker) @trusted
    {
        synchronized (mutex)
        {
            if (auto info = action in actions)
            {
                info.assignedWorker = worker;
                info.state = ActionState.Executing;
                registry.markInProgress(worker, action);
                return Ok!DistributedError();
            }
            else
            {
                return Err!DistributedError(
                    new DistributedError("Action not found: " ~ action.toString()));
            }
        }
    }
    
    /// Handle action completion
    void onComplete(ActionId action, ActionResult result) @trusted
    {
        synchronized (mutex)
        {
            if (auto info = action in actions)
            {
                info.state = ActionState.Completed;
                registry.markCompleted(info.assignedWorker, action, result.duration);
                
                // Mark dependents as potentially ready
                checkDependents(action);
            }
        }
    }
    
    /// Handle action failure
    void onFailure(ActionId action, string error) @trusted
    {
        synchronized (mutex)
        {
            if (auto info = action in actions)
            {
                registry.markFailed(info.assignedWorker, action);
                
                // Retry logic
                if (info.retries < MAX_RETRIES)
                {
                    info.retries++;
                    info.state = ActionState.Ready;
                    readyQueue.insertBack(action);
                }
                else
                {
                    info.state = ActionState.Failed;
                    // TODO: Propagate failure to dependents
                }
            }
        }
    }
    
    /// Handle worker failure (reassign its work)
    void onWorkerFailure(WorkerId worker) @trusted
    {
        synchronized (mutex)
        {
            auto inProgress = registry.inProgressActions(worker);
            
            foreach (actionId; inProgress)
            {
                if (auto info = actionId in actions)
                {
                    // Reset to ready state for reassignment
                    info.state = ActionState.Ready;
                    info.assignedWorker = WorkerId(0);
                    readyQueue.insertBack(actionId);
                }
            }
        }
    }
    
    /// Check if action is ready (all dependencies completed)
    private bool isReady(ActionId action) @trusted
    {
        // TODO: Check build graph for dependency completion
        // For now, assume ready
        return true;
    }
    
    /// Mark action as ready and add to queue
    private void markReady(ActionId action) @trusted
    {
        if (auto info = action in actions)
        {
            info.state = ActionState.Ready;
            readyQueue.insertBack(action);
        }
    }
    
    /// Check dependents of completed action
    private void checkDependents(ActionId action) @trusted
    {
        // TODO: Query build graph for dependents
        // For each dependent, check if all its dependencies are complete
        // If so, mark as ready
    }
    
    /// Get scheduler statistics
    struct SchedulerStats
    {
        size_t pending;
        size_t ready;
        size_t executing;
        size_t completed;
        size_t failed;
    }
    
    SchedulerStats getStats() @trusted
    {
        synchronized (mutex)
        {
            SchedulerStats stats;
            
            foreach (info; actions.values)
            {
                final switch (info.state)
                {
                    case ActionState.Pending:
                        stats.pending++;
                        break;
                    case ActionState.Ready:
                    case ActionState.Scheduled:
                        stats.ready++;
                        break;
                    case ActionState.Executing:
                        stats.executing++;
                        break;
                    case ActionState.Completed:
                        stats.completed++;
                        break;
                    case ActionState.Failed:
                        stats.failed++;
                        break;
                }
            }
            
            return stats;
        }
    }
    
    /// Shutdown scheduler
    void shutdown() @trusted
    {
        atomicStore(running, false);
    }
    
    /// Check if scheduler is running
    bool isRunning() @trusted
    {
        return atomicLoad(running);
    }
}

/// Critical path analyzer (for priority scheduling)
final class CriticalPathAnalyzer
{
    private BuildGraph graph;
    private Duration[ActionId] estimatedDurations;
    private Duration[ActionId] criticalPaths;
    
    this(BuildGraph graph) @safe
    {
        this.graph = graph;
    }
    
    /// Compute priority based on critical path heuristic
    Priority computePriority(ActionId action) @safe
    {
        // 1. Estimate depth (longest path from roots)
        immutable depth = estimateDepth(action);
        
        // 2. Count transitive dependents (fan-out)
        immutable dependents = countDependents(action);
        
        // 3. Estimate critical path duration
        immutable criticalPath = estimateCriticalPath(action);
        
        // 4. Weighted scoring
        immutable score = 
            depth * 1.0 +
            dependents * 0.5 +
            criticalPath.total!"msecs" * 0.001;
        
        // 5. Map to priority enum
        if (score > 100)
            return Priority.Critical;
        else if (score > 50)
            return Priority.High;
        else if (score > 10)
            return Priority.Normal;
        else
            return Priority.Low;
    }
    
    /// Estimate action depth in graph
    private size_t estimateDepth(ActionId action) @safe
    {
        // TODO: Query build graph
        return 0;
    }
    
    /// Count transitive dependents
    private size_t countDependents(ActionId action) @safe
    {
        // TODO: Query build graph
        return 0;
    }
    
    /// Estimate critical path duration (longest path to leaves)
    private Duration estimateCriticalPath(ActionId action) @safe
    {
        // Check cache
        if (auto cached = action in criticalPaths)
            return *cached;
        
        // TODO: Compute from build graph
        immutable result = 1000.msecs;
        
        criticalPaths[action] = result;
        return result;
    }
    
    /// Estimate action duration (from historical data)
    Duration estimateDuration(ActionId action) @safe
    {
        if (auto cached = action in estimatedDurations)
            return *cached;
        
        // Default estimate
        return 1000.msecs;
    }
}



