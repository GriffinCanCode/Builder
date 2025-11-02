module core.execution.core.engine;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import core.atomic;
import core.memory : GC;
import core.graph.graph;
import config.schema.schema;
import languages.base.base;
import core.execution.services;
import cli.events.events;
import core.telemetry.distributed.tracing : Span, SpanKind, SpanStatus;
import utils.logging.logger;
import utils.simd.capabilities;
import errors;

/// Thin orchestration layer for build execution
/// Composes specialized services to execute build graph
/// 
/// Design: Pure coordination - all work delegated to services
/// - SchedulingService: parallelism and task queueing
/// - CacheService: caching decisions
/// - ObservabilityService: events, tracing, logging
/// - ResilienceService: retry and checkpoint logic
/// - HandlerRegistry: language handler dispatch
final class ExecutionEngine
{
    private enum size_t LARGE_BUILD_THRESHOLD = 100;
    private enum size_t BYTES_PER_KB = 1024;
    private enum size_t KB_PER_MB = 1024;
    private enum size_t MB_PER_GB = 1024;
    private enum size_t MAX_STAT_STRING_LENGTH = 4;
    
    private BuildGraph graph;
    private WorkspaceConfig config;
    private ISchedulingService scheduling;
    private ICacheService cache;
    private IObservabilityService observability;
    private IResilienceService resilience;
    private IHandlerRegistry handlers;
    private SIMDCapabilities simdCaps;
    
    private shared size_t activeTasks;
    private shared size_t failedTasks;
    private bool _isShutdown = false;
    
    this(
        BuildGraph graph,
        WorkspaceConfig config,
        ISchedulingService scheduling,
        ICacheService cache,
        IObservabilityService observability,
        IResilienceService resilience,
        IHandlerRegistry handlers,
        SIMDCapabilities simdCaps = null
    ) @trusted
    {
        this.graph = graph;
        this.config = config;
        this.scheduling = scheduling;
        this.cache = cache;
        this.observability = observability;
        this.resilience = resilience;
        this.handlers = handlers;
        this.simdCaps = simdCaps;
        
        atomicStore(activeTasks, cast(size_t)0);
        atomicStore(failedTasks, cast(size_t)0);
    }
    
    ~this()
    {
        shutdown();
    }
    
    /// Shutdown engine and cleanup resources
    void shutdown() @trusted
    {
        if (_isShutdown)
            return;
        
        _isShutdown = true;
        
        scheduling.shutdown();
        cache.close();
        observability.flush();
        
        // Shutdown SIMD capabilities
        if (simdCaps !is null)
            simdCaps.shutdown();
    }
    
    /// Execute the build
    bool execute() @trusted
    {
        auto sw = StopWatch(AutoStart.yes);
        
        // Start distributed trace
        observability.startTrace();
        auto buildSpan = observability.startSpan("build-execute", SpanKind.Internal);
        scope(exit) {
            observability.finishSpan(buildSpan);
            observability.flush();
        }
        
        // Topological sort
        auto sortResult = graph.topologicalSort();
        if (sortResult.isErr)
        {
            auto error = sortResult.unwrapErr();
            observability.recordException(buildSpan, new Exception(error.message()));
            observability.setSpanStatus(buildSpan, SpanStatus.Error, error.message());
            
            string[string] fields;
            fields["error.type"] = "topological_sort_failed";
            observability.logError("Cannot build: " ~ format(error), fields);
            
            observability.publishEvent(new BuildFailedEvent(error.message(), 0, sw.peek(), sw.peek()));
            return false;
        }
        
        auto sorted = sortResult.unwrap();
        observability.setSpanAttribute(buildSpan, "build.total_targets", sorted.length.to!string);
        observability.setSpanAttribute(buildSpan, "build.max_parallelism", scheduling.workerCount().to!string);
        
        string[string] fields;
        fields["total_targets"] = sorted.length.to!string;
        fields["parallelism"] = scheduling.workerCount().to!string;
        observability.logInfo("Building targets", fields);
        
        // Handle checkpoint/resume
        if (!handleCheckpointResume(buildSpan, sorted.length))
        {
            // Checkpoint handling failed but we can continue
        }
        
        // GC control for large builds
        immutable bool useGcControl = sorted.length > LARGE_BUILD_THRESHOLD;
        if (useGcControl)
        {
            GC.disable();
            observability.setSpanAttribute(buildSpan, "gc.disabled", "true");
            observability.addSpanEvent(buildSpan, "gc-disabled");
            
            string[string] gcFields;
            gcFields["target_count"] = sorted.length.to!string;
            observability.logDebug("GC disabled for large build", gcFields);
        }
        
        scope(exit)
        {
            if (useGcControl)
            {
                GC.enable();
                GC.collect();
                observability.addSpanEvent(buildSpan, "gc-enabled");
                observability.logDebug("GC re-enabled and collected");
            }
        }
        
        // Initialize scheduling
        scheduling.initialize(0); // 0 = auto-detect CPU count
        
        // Publish build started event
        observability.publishEvent(new BuildStartedEvent(sorted.length, scheduling.workerCount(), sw.peek()));
        
        size_t built = 0;
        size_t cached = 0;
        
        Logger.info("Max parallelism: " ~ scheduling.workerCount().to!string ~ " jobs");
        
        // Initialize pending dependency counters
        foreach (node; sorted)
            node.initPendingDeps();
        
        // Enqueue initially ready nodes
        foreach (node; sorted)
        {
            if (node.pendingDeps == 0)
                scheduling.submit(node);
        }
        
        // Main execution loop
        while (atomicLoad(failedTasks) == 0)
        {
            // Dequeue batch of ready nodes
            auto batch = scheduling.dequeueReady(scheduling.workerCount());
            
            // If no ready nodes and no active tasks, we're done
            if (batch.length == 0 && atomicLoad(activeTasks) == 0)
                break;
            
            // Wait briefly if no ready nodes but tasks are active
            if (batch.length == 0)
            {
                import core.thread : Thread;
                import core.time : msecs;
                Thread.sleep(1.msecs);
                continue;
            }
            
            Logger.debugLog("Building batch: " ~ batch.map!(n => n.idString).join(", "));
            
            atomicOp!"+="(activeTasks, batch.length);
            
            // Mark nodes as building
            foreach (node; batch)
                node.status = BuildStatus.Building;
            
            // Execute batch in parallel
            auto results = scheduling.executeBatch(batch, (BuildNode node) => buildNode(node));
            
            // Process results
            foreach (i, result; results)
            {
                auto node = batch[i];
                
                if (result.success)
                {
                    node.status = result.cached ? BuildStatus.Cached : BuildStatus.Success;
                    if (result.cached)
                        cached++;
                    else
                        built++;
                    
                    // Enqueue ready dependents
                    foreach (dependentId; node.dependentIds)
                    {
                        auto dependent = graph.getNode(dependentId);
                        if (dependent !is null)
                        {
                            immutable remaining = dependent.decrementPendingDeps();
                            if (remaining == 0)
                                scheduling.submit(*dependent);
                        }
                    }
                }
                else
                {
                    node.status = BuildStatus.Failed;
                    atomicOp!"+="(failedTasks, cast(size_t)1);
                    Logger.error("Failed to build " ~ node.idString ~ ": " ~ result.error);
                    
                    // Mark all dependents as failed (cascading failure)
                    foreach (dependentId; node.dependentIds)
                    {
                        auto dependent = graph.getNode(dependentId);
                        if (dependent !is null && dependent.status == BuildStatus.Pending)
                        {
                            dependent.status = BuildStatus.Failed;
                            atomicOp!"+="(failedTasks, cast(size_t)1);
                        }
                    }
                }
            }
            
            atomicOp!"-="(activeTasks, batch.length);
        }
        
        sw.stop();
        
        auto failed = atomicLoad(failedTasks);
        
        // Flush caches
        cache.flush();
        
        // Publish events and statistics
        publishCompletionEvents(sorted.length, built, cached, failed, sw.peek());
        
        // Print summary
        printSummary(built, cached, failed, sw.peek());
        
        return failed == 0;
    }
    
    /// Handle checkpoint and resume logic
    private bool handleCheckpointResume(Span buildSpan, size_t totalTargets) @trusted
    {
        if (!resilience.hasCheckpoint())
            return false;
        
        auto checkpointSpan = observability.startSpan("checkpoint-load", SpanKind.Internal, buildSpan);
        scope(exit) observability.finishSpan(checkpointSpan);
        
        auto checkpointResult = resilience.loadCheckpoint();
        if (checkpointResult.isErr)
            return false;
        
        auto checkpoint = checkpointResult.unwrap();
        
        if (checkpoint.isValid(graph) && !resilience.isCheckpointStale())
        {
            observability.setSpanAttribute(checkpointSpan, "checkpoint.valid", "true");
            observability.setSpanAttribute(checkpointSpan, "checkpoint.timestamp", checkpoint.timestamp.toSimpleString());
            
            string[string] cpFields;
            cpFields["checkpoint.timestamp"] = checkpoint.timestamp.toSimpleString();
            observability.logInfo("Found valid checkpoint", cpFields);
            
            // Plan resume
            auto planResult = resilience.planResume(graph);
            if (planResult.isOk)
            {
                auto plan = planResult.unwrap();
                plan.print();
                
                observability.setSpanAttribute(checkpointSpan, "checkpoint.savings_pct", plan.estimatedSavings().to!string);
                cpFields["savings_percent"] = plan.estimatedSavings().to!string;
                observability.logInfo("Resuming build", cpFields);
                return true;
            }
        }
        else
        {
            observability.setSpanAttribute(checkpointSpan, "checkpoint.valid", "false");
            observability.logInfo("Checkpoint stale or invalid, rebuilding");
            resilience.clearCheckpoint();
        }
        
        return false;
    }
    
    /// Build a single node
    private BuildResult buildNode(BuildNode node) @trusted
    {
        auto targetSpan = observability.startSpan("build-target", SpanKind.Internal);
        scope(exit) observability.finishSpan(targetSpan);
        
        observability.setSpanAttribute(targetSpan, "target.id", node.idString);
        observability.setSpanAttribute(targetSpan, "target.language", node.target.language.to!string);
        observability.setSpanAttribute(targetSpan, "target.type", node.target.type.to!string);
        
        BuildResult result;
        result.targetId = node.id.toString();
        auto nodeTimer = StopWatch(AutoStart.yes);
        
        try
        {
            string[string] fields;
            fields["target.language"] = node.target.language.to!string;
            fields["target.type"] = node.target.type.to!string;
            observability.logInfo("Building target", fields);
            
            // Publish target started event
            publishTargetStarted(node, nodeTimer.peek());
            
            auto target = node.target;
            auto deps = node.dependencyIds;
            
            // Check cache
            auto cacheSpan = observability.startSpan("cache-check", SpanKind.Internal, targetSpan);
            bool isCached = cache.isCached(node.id.toString(), target.sources, deps.map!(d => d.toString()).array);
            observability.setSpanAttribute(cacheSpan, "cache.hit", isCached.to!string);
            observability.finishSpan(cacheSpan);
            
            if (isCached)
            {
                observability.setSpanAttribute(targetSpan, "build.cached", "true");
                observability.setSpanStatus(targetSpan, SpanStatus.Ok);
                
                result.success = true;
                result.cached = true;
                
                observability.publishEvent(new TargetCachedEvent(node.idString, nodeTimer.peek()));
                return result;
            }
            
            // Get language handler
            auto handler = handlers.get(target.language);
            if (handler is null)
            {
                result.error = "No language handler found for: " ~ target.language.to!string;
                observability.recordException(targetSpan, new Exception(result.error));
                observability.setSpanStatus(targetSpan, SpanStatus.Error, result.error);
                return result;
            }
            
            // Build with action-level caching
            auto compileSpan = observability.startSpan("compile", SpanKind.Internal, targetSpan);
            observability.setSpanAttribute(compileSpan, "target.sources_count", target.sources.length.to!string);
            
            // Create build context with action recorder and SIMD capabilities
            BuildContext buildContext;
            buildContext.target = target;
            buildContext.config = config;
            buildContext.simd = simdCaps;
            buildContext.recorder = (actionId, inputs, outputs, metadata, success) {
                cache.recordAction(actionId, inputs, outputs, metadata, success);
            };
            
            // Execute with retry logic
            auto policy = resilience.policyFor(new BuildFailureError(node.idString, ""));
            auto buildResult = resilience.withRetryString(
                node.idString,
                () {
                    node.incrementRetries();
                    return handler.buildWithContext(buildContext);
                },
                policy
            );
            
            observability.finishSpan(compileSpan);
            
            if (buildResult.isOk)
            {
                auto outputHash = buildResult.unwrap();
                
                // Update cache
                auto cacheUpdateSpan = observability.startSpan("cache-update", SpanKind.Internal, targetSpan);
                cache.update(node.id.toString(), target.sources, deps.map!(d => d.toString()).array, outputHash);
                observability.finishSpan(cacheUpdateSpan);
                
                observability.setSpanStatus(targetSpan, SpanStatus.Ok);
                
                result.success = true;
                node.resetRetries();
                
                observability.publishEvent(new TargetCompletedEvent(node.idString, nodeTimer.peek(), 0, nodeTimer.peek()));
            }
            else
            {
                auto error = buildResult.unwrapErr();
                result.error = error.message();
                
                observability.recordException(targetSpan, new Exception(error.message()));
                observability.setSpanStatus(targetSpan, SpanStatus.Error, error.message());
                
                observability.publishEvent(new TargetFailedEvent(node.idString, error.message(), nodeTimer.peek(), nodeTimer.peek()));
            }
        }
        catch (Exception e)
        {
            result.error = "Build failed with exception: " ~ e.msg;
            observability.recordException(targetSpan, e);
            observability.setSpanStatus(targetSpan, SpanStatus.Error, e.msg);
            observability.logException(e, "Build failed with exception");
            
            observability.publishEvent(new TargetFailedEvent(node.idString, result.error, nodeTimer.peek(), nodeTimer.peek()));
        }
        
        return result;
    }
    
    /// Publish target started event
    private void publishTargetStarted(BuildNode node, Duration elapsed) @trusted
    {
        auto sortedResult = graph.topologicalSort();
        if (sortedResult.isOk)
        {
            auto sorted = sortedResult.unwrap();
            auto index = sorted.countUntil(node) + 1;
            observability.publishEvent(new TargetStartedEvent(node.idString, index, sorted.length, elapsed));
        }
    }
    
    /// Publish completion events and statistics
    private void publishCompletionEvents(size_t total, size_t built, size_t cached, size_t failed, Duration elapsed) @trusted
    {
        if (failed > 0)
        {
            observability.publishEvent(new BuildFailedEvent("Build failed", failed, elapsed, elapsed));
        }
        else
        {
            observability.publishEvent(new BuildCompletedEvent(built, cached, failed, elapsed, elapsed));
        }
        
        // Publish statistics
        auto cacheStats = cache.getStats();
        
        BuildStats buildStats;
        buildStats.totalTargets = total;
        buildStats.completedTargets = built;
        buildStats.cachedTargets = cached;
        buildStats.failedTargets = failed;
        buildStats.elapsed = elapsed;
        buildStats.targetsPerSecond = total > 0 ? (total * 1000.0) / elapsed.total!"msecs" : 0.0;
        
        // Map to event cache stats
        cli.events.events.CacheStats cliCacheStats;
        cliCacheStats.hits = cacheStats.metadataHits;
        cliCacheStats.misses = cacheStats.contentHashes;
        cliCacheStats.totalEntries = cacheStats.totalEntries;
        cliCacheStats.totalSize = cacheStats.totalSize;
        cliCacheStats.hitRate = cacheStats.metadataHitRate;
        
        observability.publishEvent(new StatisticsEvent(cliCacheStats, buildStats, elapsed));
    }
    
    /// Print build summary to console
    private void printSummary(size_t built, size_t cached, size_t failed, Duration elapsed) @trusted
    {
        import std.format : format;
        
        writeln();
        Logger.info("Build Summary:");
        Logger.info("  Built: " ~ built.to!string);
        Logger.info("  Cached: " ~ cached.to!string);
        Logger.info("  Failed: " ~ failed.to!string);
        Logger.info("  Time: " ~ elapsed.total!"msecs".to!string ~ "ms");
        
        // Print cache performance
        auto cacheStats = cache.getStats();
        if (cacheStats.metadataHits + cacheStats.contentHashes > 0)
        {
            Logger.info("Cache Performance:");
            Logger.info("  Total entries: " ~ cacheStats.totalEntries.to!string);
            Logger.info("  Cache size: " ~ formatSize(cacheStats.totalSize));
            Logger.info("  Metadata hit rate: " ~ formatPercent(cacheStats.metadataHitRate));
            
            if (cacheStats.hashCacheHits + cacheStats.hashCacheMisses > 0)
            {
                Logger.info("  Hash cache hit rate: " ~ formatPercent(cacheStats.hashCacheHitRate));
                Logger.info("  Hash cache saves: " ~ cacheStats.hashCacheHits.to!string ~ " duplicate hashes avoided");
            }
        }
        
        // Print action cache stats
        if (cacheStats.actionEntries > 0)
        {
            Logger.info("Action-Level Cache:");
            Logger.info("  Total actions: " ~ cacheStats.actionEntries.to!string);
            Logger.info("  Cache size: " ~ formatSize(cacheStats.actionSize));
            if (cacheStats.actionHits + cacheStats.actionMisses > 0)
            {
                Logger.info("  Hit rate: " ~ formatPercent(cacheStats.actionHitRate));
            }
            Logger.info("  Successful actions: " ~ cacheStats.successfulActions.to!string);
            Logger.info("  Failed actions: " ~ cacheStats.failedActions.to!string);
        }
    }
    
    /// Format size in human-readable format
    private static string formatSize(size_t bytes) pure @system
    {
        import std.format : format;
        
        if (bytes < BYTES_PER_KB)
            return format("%d B", bytes);
        else if (bytes < BYTES_PER_KB * KB_PER_MB)
            return format("%d KB", bytes / BYTES_PER_KB);
        else if (bytes < BYTES_PER_KB * KB_PER_MB * MB_PER_GB)
            return format("%d MB", bytes / (BYTES_PER_KB * KB_PER_MB));
        else
            return format("%d GB", bytes / (BYTES_PER_KB * KB_PER_MB * MB_PER_GB));
    }
    
    /// Format percentage
    private static string formatPercent(float rate) pure @system
    {
        import std.format : format;
        import std.algorithm : min;
        
        auto str = rate.to!string;
        return str[0..min(MAX_STAT_STRING_LENGTH, str.length)] ~ "%";
    }
}

