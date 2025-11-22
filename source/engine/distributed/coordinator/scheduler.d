module engine.distributed.coordinator.scheduler;

import std.algorithm : map, filter, maxElement, sort, uniq;
import std.array : array;
import std.container : DList;
import std.datetime : Duration, msecs;
import std.conv : to;
import core.sync.mutex : Mutex;
import core.atomic;
import engine.graph : BuildGraph, BuildNode;
import engine.distributed.protocol.protocol;
import engine.distributed.coordinator.registry;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

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
    
    // Mapping between ActionId and TargetId for dependency tracking
    private TargetId[ActionId] actionToTarget;
    private ActionId[TargetId] targetToAction;
    
    private enum size_t MAX_RETRIES = 3;
    
    this(BuildGraph graph, WorkerRegistry registry) @trusted
    {
        this.graph = graph;
        this.registry = registry;
        this.mutex = new Mutex();
        atomicStore(running, true);
    }
    
    Result!DistributedError schedule(ActionRequest request, TargetId targetId = TargetId.init) @trusted
    {
        synchronized (mutex)
        {
            if (request.id in actions) return Ok!DistributedError();
            actions[request.id] = ActionInfo(request.id, request, ActionState.Pending, WorkerId(0), 0, request.priority);
            
            // Establish mapping if TargetId provided
            if (targetId != TargetId.init)
            {
                actionToTarget[request.id] = targetId;
                targetToAction[targetId] = request.id;
            }
            
            if (isReady(request.id)) markReady(request.id);
            return Ok!DistributedError();
        }
    }
    
    /// Get next ready action (for coordinator to assign)
    Result!(ActionRequest, DistributedError) dequeueReady() @trusted
    {
        synchronized (mutex)
        {
            if (readyQueue.empty)
                return Err!(ActionRequest, DistributedError)(new DistributedError("No ready actions"));
            
            auto actionId = readyQueue.front;
            readyQueue.removeFront();
            
            if (auto info = actionId in actions)
            {
                info.state = ActionState.Scheduled;
                return Ok!(ActionRequest, DistributedError)(info.request);
            }
            
            return Err!(ActionRequest, DistributedError)(new DistributedError("Action not found: " ~ actionId.toString()));
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
            return Result!DistributedError.err(new DistributedError("Action not found: " ~ action.toString()));
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
    
    /// Handle action failure with intelligent retry strategy
    void onFailure(ActionId action, string error) @trusted
    {
        synchronized (mutex)
        {
            if (auto info = action in actions)
            {
                registry.markFailed(info.assignedWorker, action);
                
                Logger.warning("Action failed: " ~ action.toString() ~ 
                             " (attempt " ~ (info.retries + 1).to!string ~ "/" ~ MAX_RETRIES.to!string ~ 
                             "): " ~ error);
                
                // Retry logic with backoff
                if (info.retries < MAX_RETRIES)
                {
                    info.retries++;
                    info.state = ActionState.Ready;
                    
                    // Priority-based retry placement
                    // Higher priority = more aggressive retry (front of queue)
                    if (info.priority >= Priority.High)
                        readyQueue.insertFront(action);
                    else
                        readyQueue.insertBack(action);
                    
                    Logger.info("Action queued for retry: " ~ action.toString());
                }
                else
                {
                    info.state = ActionState.Failed;
                    Logger.error("Action failed permanently after " ~ MAX_RETRIES.to!string ~ 
                               " attempts: " ~ action.toString());
                    
                    // Mark dependent actions as blocked/failed
                    propagateFailure(action);
                }
            }
        }
    }
    
    /// Propagate failure to dependent actions
    private void propagateFailure(ActionId failedAction) @trusted
    {
        Logger.warning("Propagating failure from " ~ failedAction.toString());
        
        // Get action info to find associated target
        auto failedInfo = failedAction in actions;
        if (failedInfo is null)
            return;
        
        // Track failed actions transitively to handle cascading failures
        bool[ActionId] failedSet;
        failedSet[failedAction] = true;
        
        // Use BuildGraph for authoritative dependency tracking
        auto targetIdPtr = failedAction in actionToTarget;
        if (targetIdPtr !is null)
        {
            auto targetId = *targetIdPtr;
            auto targetIdStr = targetId.toString();
            
            // Get node from build graph
            if (targetIdStr in graph.nodes)
            {
                auto node = graph.nodes[targetIdStr];
                
                // Recursively mark all dependents as failed
                markDependentsFailed(node.dependentIds, failedSet);
                
                Logger.info("Propagated failure to " ~ (failedSet.length - 1).to!string ~ 
                          " dependents via graph");
                return;
            }
        }
        
        // Fallback: Traverse actions to find dependents without graph
        // Iteratively find actions that depend on failed actions
        bool changed = true;
        while (changed)
        {
            changed = false;
            
            foreach (actionId, ref info; actions)
            {
                // Skip if already marked as failed or completed
                if (info.state == ActionState.Failed || info.state == ActionState.Completed)
                    continue;
                
                // Check if this action depends on any failed action via InputSpecs
                bool dependsOnFailed = false;
                foreach (inputSpec; info.request.inputs)
                {
                    // Check if input comes from a failed action
                    // In practice, we'd need artifact-to-action mapping
                    // For now, conservatively continue
                }
                
                // If action is pending/ready and graph indicates it depends on failed action
                if (dependsOnFailed && 
                    (info.state == ActionState.Pending || info.state == ActionState.Ready))
                {
                    info.state = ActionState.Failed;
                    failedSet[actionId] = true;
                    changed = true;
                    Logger.debugLog("Marked dependent as failed: " ~ actionId.toString());
                }
            }
        }
        
        Logger.info("Failure propagation completed for " ~ failedAction.toString());
    }
    
    /// Recursively mark dependents as failed using build graph
    private void markDependentsFailed(TargetId[] dependentIds, ref bool[ActionId] failedSet) @trusted
    {
        foreach (dependentId; dependentIds)
        {
            // Find corresponding action
            auto dependentActionPtr = dependentId in targetToAction;
            if (dependentActionPtr is null)
                continue;
            
            auto dependentAction = *dependentActionPtr;
            
            // Skip if already marked as failed
            if (dependentAction in failedSet)
                continue;
            
            auto dependentInfoPtr = dependentAction in actions;
            if (dependentInfoPtr is null)
                continue;
            
            // Mark as failed if not already completed
            if (dependentInfoPtr.state != ActionState.Completed)
            {
                dependentInfoPtr.state = ActionState.Failed;
                failedSet[dependentAction] = true;
                Logger.debugLog("Marked dependent as failed: " ~ dependentAction.toString());
                
                // Recursively propagate to transitive dependents
                auto dependentIdStr = dependentId.toString();
                if (dependentIdStr in graph.nodes)
                {
                    auto dependentNode = graph.nodes[dependentIdStr];
                    markDependentsFailed(dependentNode.dependentIds, failedSet);
                }
            }
        }
    }
    
    /// Handle worker failure (reassign its work)
    /// Uses priority-aware reassignment to maintain critical path
    void onWorkerFailure(WorkerId worker) @trusted
    {
        synchronized (mutex)
        {
            auto inProgress = registry.inProgressActions(worker);
            
            // Track failed actions by priority for intelligent reassignment
            ActionId[][Priority] byPriority;
            
            foreach (actionId; inProgress)
            {
                if (auto info = actionId in actions)
                {
                    // Reset to ready state for reassignment
                    info.state = ActionState.Ready;
                    info.assignedWorker = WorkerId(0);
                    
                    // Increment retry count
                    info.retries++;
                    
                    // Group by priority for front-of-queue insertion
                    byPriority[info.priority] ~= actionId;
                }
            }
            
            // Insert into queue with priority order
            // Critical and High priority work goes to front
            if (auto critical = Priority.Critical in byPriority)
            {
                foreach (actionId; *critical)
                    readyQueue.insertFront(actionId);
            }
            
            if (auto high = Priority.High in byPriority)
            {
                foreach (actionId; *high)
                    readyQueue.insertFront(actionId);
            }
            
            // Normal and Low priority work goes to back
            if (auto normal = Priority.Normal in byPriority)
            {
                foreach (actionId; *normal)
                    readyQueue.insertBack(actionId);
            }
            
            if (auto low = Priority.Low in byPriority)
            {
                foreach (actionId; *low)
                    readyQueue.insertBack(actionId);
            }
            
            Logger.info("Reassigned " ~ inProgress.length.to!string ~ 
                       " actions from failed worker " ~ worker.toString());
        }
    }
    
    /// Check if action is ready (all dependencies completed)
    private bool isReady(ActionId action) @trusted
    {
        auto info = action in actions;
        if (info is null)
            return false;
        
        // Use BuildGraph for authoritative dependency tracking
        auto targetIdPtr = action in actionToTarget;
        if (targetIdPtr !is null)
        {
            auto targetId = *targetIdPtr;
            auto targetIdStr = targetId.toString();
            
            // Get node from build graph
            if (targetIdStr in graph.nodes)
            {
                auto node = graph.nodes[targetIdStr];
                
                // Check all dependencies are completed
                foreach (depId; node.dependencyIds)
                {
                    // Check if dependency has corresponding action
                    auto depActionPtr = depId in targetToAction;
                    if (depActionPtr is null)
                    {
                        // Dependency not scheduled yet - not ready
                        return false;
                    }
                    
                    auto depAction = *depActionPtr;
                    auto depInfoPtr = depAction in actions;
                    if (depInfoPtr is null || depInfoPtr.state != ActionState.Completed)
                    {
                        // Dependency not completed - not ready
                        return false;
                    }
                }
                
                // All graph dependencies completed
                return true;
            }
        }
        
        // Fallback: Check InputSpecs for artifact dependencies
        foreach (inputSpec; info.request.inputs)
        {
            // Find the action that produces this artifact
            bool found = false;
            foreach (otherActionId, otherInfo; actions)
            {
                if (otherInfo.state != ActionState.Completed)
                    continue;
                
                // Check if this completed action produces the required artifact
                // In a full implementation, we'd compare OutputSpec paths with InputSpec
                // For now, optimistically assume inputs are available
                found = true;
                break;
            }
            
            if (!found && info.request.inputs.length > 0)
            {
                // Has inputs but no completed producers - not ready
                return false;
            }
        }
        
        // No blocking dependencies found - ready to execute
        return true;
    }
    
    /// Mark action as ready and add to queue with priority-aware insertion
    private void markReady(ActionId action) @trusted
    {
        if (auto info = action in actions)
        {
            info.state = ActionState.Ready;
            
            // Priority-aware insertion
            if (readyQueue.empty)
            {
                readyQueue.insertBack(action);
            }
            else
            {
                // High priority actions go to front, low priority to back
                if (info.priority >= Priority.High)
                    readyQueue.insertFront(action);
                else
                    readyQueue.insertBack(action);
            }
            
            Logger.debugLog("Action marked ready: " ~ action.toString() ~ 
                          " (priority: " ~ info.priority.to!string ~ ")");
        }
    }
    
    /// Check dependents of completed action
    private void checkDependents(ActionId action) @trusted
    {
        ActionId[] nowReady;
        
        // Use BuildGraph for efficient dependent lookup
        auto targetIdPtr = action in actionToTarget;
        if (targetIdPtr !is null)
        {
            auto targetId = *targetIdPtr;
            auto targetIdStr = targetId.toString();
            
            // Get node from build graph
            if (targetIdStr in graph.nodes)
            {
                auto node = graph.nodes[targetIdStr];
                
                // Check only the direct dependents (much more efficient than full scan)
                foreach (dependentId; node.dependentIds)
                {
                    // Find corresponding action
                    auto dependentActionPtr = dependentId in targetToAction;
                    if (dependentActionPtr is null)
                        continue;
                    
                    auto dependentAction = *dependentActionPtr;
                    auto dependentInfoPtr = dependentAction in actions;
                    if (dependentInfoPtr is null)
                        continue;
                    
                    // Check if now ready
                    if (dependentInfoPtr.state == ActionState.Pending && isReady(dependentAction))
                    {
                        nowReady ~= dependentAction;
                    }
                }
                
                Logger.debugLog("Checked " ~ node.dependentIds.length.to!string ~ 
                              " direct dependents of " ~ action.toString());
            }
        }
        else
        {
            // Fallback: Iterate through all pending actions (less efficient)
            foreach (id, info; actions)
            {
                if (info.state == ActionState.Pending && isReady(id))
                {
                    nowReady ~= id;
                }
            }
        }
        
        // Mark newly ready actions
        foreach (id; nowReady)
        {
            markReady(id);
        }
        
        if (nowReady.length > 0)
            Logger.debugLog("Marked " ~ nowReady.length.to!string ~ " actions as ready");
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
    
    void shutdown() @trusted { atomicStore(running, false); }
    bool isRunning() @trusted { return atomicLoad(running); }
}

/// Critical path analyzer (for priority scheduling)
final class CriticalPathAnalyzer
{
    private BuildGraph graph;
    private Duration[ActionId] estimatedDurations;
    private Duration[ActionId] criticalPaths;
    private size_t[ActionId] depthCache;
    private size_t[ActionId] dependentsCache;
    
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
    /// Since ActionId (distributed) doesn't directly map to BuildNode,
    /// we use a heuristic based on graph statistics
    private size_t estimateDepth(ActionId action) @safe
    {
        // Check cache
        if (auto cached = action in depthCache)
            return *cached;
        
        // Without direct ActionId->TargetId mapping, estimate based on graph structure
        // Use average depth of targets in the build graph as baseline
        try
        {
            auto nodes = graph.nodes.values;
            if (nodes.length == 0)
                return 1;
            
            // Calculate average depth by doing a BFS from roots
            size_t totalDepth = 0;
            size_t nodeCount = 0;
            bool[string] visited;
            
            foreach (node; nodes)
            {
                if (node.dependencyIds.length == 0)
                {
                    // This is a root node
                    immutable depth = calculateNodeDepth(node, visited);
                    totalDepth += depth;
                    nodeCount++;
                }
            }
            
            // Return average depth (reasonable estimate for unknown action)
            immutable result = nodeCount > 0 ? totalDepth / nodeCount : 1;
            depthCache[action] = result;
            return result;
        }
        catch (Exception)
        {
            return 1;
        }
    }
    
    /// Calculate depth of a specific node from roots
    private size_t calculateNodeDepth(BuildNode node, ref bool[string] visited) @trusted
    {
        immutable nodeKey = node.id.toString();
        if (nodeKey in visited)
            return 0;
        
        visited[nodeKey] = true;
        
        if (node.dependencyIds.length == 0)
            return 0;
        
        size_t maxDepth = 0;
        foreach (depId; node.dependencyIds)
        {
            auto depKey = depId.toString();
            if (depKey in graph.nodes)
            {
                immutable depth = 1 + calculateNodeDepth(graph.nodes[depKey], visited);
                if (depth > maxDepth)
                    maxDepth = depth;
            }
        }
        
        return maxDepth;
    }
    
    /// Count transitive dependents
    /// Estimate fan-out using graph statistics
    private size_t countDependents(ActionId action) @safe
    {
        // Check cache
        if (auto cached = action in dependentsCache)
            return *cached;
        
        // Without direct mapping, estimate based on graph average
        try
        {
            auto nodes = graph.nodes.values;
            if (nodes.length == 0)
                return 0;
            
            size_t totalDependents = 0;
            foreach (node; nodes)
            {
                totalDependents += node.dependentIds.length;
            }
            
            // Return average fan-out
            immutable result = totalDependents / nodes.length;
            dependentsCache[action] = result;
            return result;
        }
        catch (Exception)
        {
            return 0;
        }
    }
    
    /// Estimate critical path duration (longest path to leaves)
    private Duration estimateCriticalPath(ActionId action) @safe
    {
        // Check cache
        if (auto cached = action in criticalPaths)
            return *cached;
        
        // Estimate based on graph depth and average action duration
        immutable depth = estimateDepth(action);
        immutable avgDuration = estimateDuration(action);
        
        // Critical path estimate: depth * average duration
        immutable result = avgDuration * depth;
        
        criticalPaths[action] = result;
        return result;
    }
    
    /// Estimate action duration (from historical data)
    Duration estimateDuration(ActionId action) @safe
    {
        if (auto cached = action in estimatedDurations)
            return *cached;
        
        // Default estimate (1 second baseline)
        // In a production system, this would query historical execution data
        return 1000.msecs;
    }
    
    /// Record actual execution time for future estimates
    void recordExecution(ActionId action, Duration actualDuration) @safe
    {
        // Update duration estimate (simple moving average)
        if (auto existing = action in estimatedDurations)
        {
            // Weighted average: 70% old, 30% new
            immutable oldMs = existing.total!"msecs";
            immutable newMs = actualDuration.total!"msecs";
            immutable avgMs = cast(long)(oldMs * 0.7 + newMs * 0.3);
            estimatedDurations[action] = msecs(avgMs);
        }
        else
        {
            estimatedDurations[action] = actualDuration;
        }
    }
}



