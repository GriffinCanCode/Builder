module core.execution.resume;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.range;
import core.graph.graph;
import core.execution.checkpoint;
import errors;

/// Resume strategy - determines how to handle checkpoint
enum ResumeStrategy
{
    /// Retry all failed targets
    RetryFailed,
    
    /// Skip failed targets, continue with pending
    SkipFailed,
    
    /// Rebuild everything (ignore checkpoint)
    RebuildAll,
    
    /// Smart resume - analyze what changed
    Smart
}

/// Resume configuration
struct ResumeConfig
{
    ResumeStrategy strategy = ResumeStrategy.Smart;
    bool clearOnSuccess = true;      // Clear checkpoint after successful build
    bool validateDependencies = true; // Re-check if dependencies changed
    Duration maxCheckpointAge = 24.hours;
    
    /// Create config from environment
    static ResumeConfig fromEnvironment() @safe
    {
        import std.process : environment;
        
        ResumeConfig config;
        
        if (auto strategy = environment.get("BUILDER_RESUME_STRATEGY"))
        {
            switch (strategy)
            {
                case "retry": config.strategy = ResumeStrategy.RetryFailed; break;
                case "skip": config.strategy = ResumeStrategy.SkipFailed; break;
                case "rebuild": config.strategy = ResumeStrategy.RebuildAll; break;
                case "smart": config.strategy = ResumeStrategy.Smart; break;
                default: break;
            }
        }
        
        return config;
    }
}

/// Resume planner - decides what to rebuild
final class ResumePlanner
{
    private ResumeConfig config;
    
    this(ResumeConfig config = ResumeConfig.init) @safe
    {
        this.config = config;
    }
    
    /// Plan resume from checkpoint
    Result!(ResumePlan, string) plan(
        const ref Checkpoint checkpoint,
        BuildGraph graph
    ) @trusted
    {
        // Validate checkpoint
        if (!checkpoint.isValid(graph))
            return Result!(ResumePlan, string).err("Checkpoint invalid for current graph");
        
        // Check age
        if (Clock.currTime() - checkpoint.timestamp > config.maxCheckpointAge)
            return Result!(ResumePlan, string).err("Checkpoint too old");
        
        // Build plan based on strategy
        ResumePlan plan;
        plan.strategy = config.strategy;
        plan.checkpointAge = Clock.currTime() - checkpoint.timestamp;
        
        final switch (config.strategy)
        {
            case ResumeStrategy.RetryFailed:
                planRetryFailed(checkpoint, graph, plan);
                break;
            
            case ResumeStrategy.SkipFailed:
                planSkipFailed(checkpoint, graph, plan);
                break;
            
            case ResumeStrategy.RebuildAll:
                planRebuildAll(graph, plan);
                break;
            
            case ResumeStrategy.Smart:
                planSmart(checkpoint, graph, plan);
                break;
        }
        
        return Result!(ResumePlan, string).ok(plan);
    }
    
    private void planRetryFailed(
        const ref Checkpoint checkpoint,
        BuildGraph graph,
        ref ResumePlan plan
    ) @safe
    {
        // Restore successful builds
        checkpoint.mergeWith(graph);
        
        // Retry all failed targets
        foreach (targetId; checkpoint.failedTargetIds)
        {
            if (targetId in graph.nodes)
            {
                auto node = graph.nodes[targetId];
                node.status = BuildStatus.Pending;
                plan.targetsToRetry ~= targetId;
            }
        }
        
        // Mark dependent targets as pending
        markDependentsPending(graph, checkpoint.failedTargetIds, plan);
        
        plan.targetsToSkip = checkpoint.nodeStates.keys
            .filter!(id => checkpoint.nodeStates[id] == BuildStatus.Success)
            .array;
    }
    
    private void planSkipFailed(
        const ref Checkpoint checkpoint,
        BuildGraph graph,
        ref ResumePlan plan
    ) @safe
    {
        // Restore successful builds
        checkpoint.mergeWith(graph);
        
        // Skip failed targets entirely
        foreach (targetId; checkpoint.failedTargetIds)
        {
            if (targetId in graph.nodes)
                plan.targetsToSkip ~= targetId;
        }
        
        plan.targetsToSkip ~= checkpoint.nodeStates.keys
            .filter!(id => checkpoint.nodeStates[id] == BuildStatus.Success)
            .array;
    }
    
    private void planRebuildAll(BuildGraph graph, ref ResumePlan plan) @safe
    {
        // Clear all node states
        foreach (node; graph.nodes.values)
            node.status = BuildStatus.Pending;
        
        plan.message = "Rebuilding all targets (checkpoint ignored)";
    }
    
    private void planSmart(
        const ref Checkpoint checkpoint,
        BuildGraph graph,
        ref ResumePlan plan
    ) @safe
    {
        // Restore successful builds
        checkpoint.mergeWith(graph);
        
        if (config.validateDependencies)
        {
            // Check if any dependencies changed
            auto invalidated = findInvalidated(checkpoint, graph);
            
            foreach (targetId; invalidated)
            {
                if (targetId in graph.nodes)
                {
                    auto node = graph.nodes[targetId];
                    node.status = BuildStatus.Pending;
                    plan.targetsToRetry ~= targetId;
                }
            }
        }
        
        // Retry failed targets
        foreach (targetId; checkpoint.failedTargetIds)
        {
            if (targetId in graph.nodes && !canFind(plan.targetsToRetry, targetId))
            {
                auto node = graph.nodes[targetId];
                node.status = BuildStatus.Pending;
                plan.targetsToRetry ~= targetId;
            }
        }
        
        // Mark dependent targets as pending
        markDependentsPending(graph, plan.targetsToRetry, plan);
        
        plan.targetsToSkip = checkpoint.nodeStates.keys
            .filter!((id) {
                auto status = checkpoint.nodeStates[id];
                return (status == BuildStatus.Success || status == BuildStatus.Cached) &&
                       !canFind(plan.targetsToRetry, id);
            })
            .array;
        
        plan.message = "Smart resume: " ~ plan.targetsToRetry.length.to!string ~ 
                       " targets to rebuild, " ~ plan.targetsToSkip.length.to!string ~ " cached";
    }
    
    private string[] findInvalidated(
        const ref Checkpoint checkpoint,
        BuildGraph graph
    ) const @safe
    {
        import core.caching.cache : BuildCache, CacheConfig;
        
        string[] invalidated;
        
        // Use cache to check if sources changed
        auto cache = new BuildCache(".builder-cache", CacheConfig.fromEnvironment());
        
        foreach (targetId, node; graph.nodes)
        {
            // Skip if not in checkpoint
            if (targetId !in checkpoint.nodeStates)
                continue;
            
            // Skip if was failed/pending
            immutable status = checkpoint.nodeStates[targetId];
            if (status != BuildStatus.Success && status != BuildStatus.Cached)
                continue;
            
            // Check cache validity
            auto target = node.target;
            auto deps = node.dependencies.map!(d => d.id).array;
            
            if (!cache.isCached(targetId, target.sources, deps))
                invalidated ~= targetId;
        }
        
        return invalidated;
    }
    
    private void markDependentsPending(
        BuildGraph graph,
        const string[] changedTargets,
        ref ResumePlan plan
    ) @safe
    {
        import std.range : chain;
        
        bool[string] visited;
        
        void markRecursive(BuildNode node)
        {
            if (node.id in visited)
                return;
            
            visited[node.id] = true;
            
            // Mark as pending and add to retry list
            node.status = BuildStatus.Pending;
            plan.targetsToRetry ~= node.id;
            
            // Recursively mark dependents
            foreach (dependent; node.dependents)
                markRecursive(dependent);
        }
        
        // Start from changed targets
        foreach (targetId; changedTargets)
        {
            if (targetId !in graph.nodes)
                continue;
            
            auto node = graph.nodes[targetId];
            foreach (dependent; node.dependents)
                markRecursive(dependent);
        }
    }
}

/// Resume plan - output from planner
struct ResumePlan
{
    ResumeStrategy strategy;
    Duration checkpointAge;
    string[] targetsToRetry;
    string[] targetsToSkip;
    string message;
    
    /// Print summary
    void print() const @safe
    {
        writeln("\n=== Resume Plan ===");
        writeln("Strategy: ", strategy);
        writeln("Checkpoint age: ", checkpointAge.total!"seconds", " seconds");
        
        if (!targetsToRetry.empty)
        {
            writeln("\nTargets to rebuild (", targetsToRetry.length, "):");
            foreach (target; targetsToRetry.take(10))
                writeln("  - ", target);
            if (targetsToRetry.length > 10)
                writeln("  ... and ", targetsToRetry.length - 10, " more");
        }
        
        if (!targetsToSkip.empty)
        {
            writeln("\nTargets to skip (cached) (", targetsToSkip.length, "):");
            foreach (target; targetsToSkip.take(5))
                writeln("  - ", target);
            if (targetsToSkip.length > 5)
                writeln("  ... and ", targetsToSkip.length - 5, " more");
        }
        
        if (!message.empty)
            writeln("\n", message);
        
        writeln("===================\n");
    }
    
    /// Get estimated time savings
    float estimatedSavings() const pure nothrow @nogc @safe
    {
        immutable total = targetsToRetry.length + targetsToSkip.length;
        if (total == 0)
            return 0.0;
        
        return (cast(float)targetsToSkip.length / cast(float)total) * 100.0;
    }
}

