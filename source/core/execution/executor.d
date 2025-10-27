module core.execution.executor;

import std.stdio;
import std.parallelism;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import core.sync.mutex;
import core.sync.condition;
import core.atomic;
import core.graph.graph;
import core.caching.cache;
import config.schema.schema;
import languages.base.base;
import languages.scripting.python;
import languages.web.javascript;
import languages.web.typescript;
import languages.scripting.go;
import languages.compiled.rust : RustHandler;
import languages.compiled.d : DHandler;
import languages.compiled.cpp : CppHandler, CHandler;
import languages.jvm.java;
import languages.jvm.kotlin;
import languages.dotnet.csharp;
import languages.compiled.zig;
import languages.compiled.swift;
import languages.scripting.ruby;
import languages.scripting.php;
import languages.jvm.scala;
import languages.scripting.elixir;
import languages.compiled.nim;
import languages.scripting.lua;
import languages.scripting.r;
import utils.logging.logger;
import utils.concurrency.pool;
import utils.concurrency.lockfree;
import utils.concurrency.scheduler;
import utils.concurrency.priority;
import errors;
import cli.events.events;
import core.execution.retry;
import core.execution.checkpoint;
import core.execution.resume;

/// Executes builds based on the dependency graph
/// 
/// Thread Safety:
/// - activeTasks, failedTasks: atomic operations only
/// - BuildNode.status: atomic property accessors (thread-safe)
/// - readyQueue: lock-free queue for ready nodes (no contention)
/// - Node dependency counters: atomic decrements for detecting readiness
/// - ThreadPool handles parallel task execution with internal synchronization
/// - BuildCache: internally synchronized, safe for concurrent access from buildNode()
final class BuildExecutor
{
    /// Configuration constants
    private enum size_t LARGE_BUILD_THRESHOLD = 100;  // Target count for GC control
    private enum size_t BYTES_PER_KB = 1024;          // Bytes in a kilobyte
    private enum size_t KB_PER_MB = 1024;             // KB in a megabyte
    private enum size_t MB_PER_GB = 1024;             // MB in a gigabyte
    private enum size_t MAX_STAT_STRING_LENGTH = 4;   // Max chars for percentage display
    private enum size_t MIN_STAT_STRING_LENGTH = 5;   // Max chars for savings estimate
    private enum size_t READY_QUEUE_SIZE = 1024;      // Lock-free queue capacity
    
    private BuildGraph graph;
    private WorkspaceConfig config;
    private BuildCache cache;
    private LanguageHandler[TargetLanguage] handlers;
    private ThreadPool pool;
    private LockFreeQueue!BuildNode readyQueue;  // Lock-free ready queue for scalability
    private WorkStealingScheduler!BuildNode workStealingScheduler;  // Optional work-stealing scheduler
    private size_t[string] criticalPathCosts;  // Precomputed critical path costs
    private shared size_t activeTasks;  // Atomic: number of currently executing tasks
    private shared size_t failedTasks;  // Atomic: number of failed tasks
    private immutable size_t workerCount;
    private EventPublisher eventPublisher;
    private RetryOrchestrator retryOrchestrator;
    private CheckpointManager checkpointManager;
    private bool enableCheckpoints;
    private bool enableRetries;
    private bool useWorkStealing;  // Enable work-stealing scheduler
    
    this(BuildGraph graph, WorkspaceConfig config, size_t maxParallelism = 0, EventPublisher eventPublisher = null, bool enableCheckpoints = true, bool enableRetries = true, bool useWorkStealing = true) @trusted
    {
        this.graph = graph;
        this.config = config;
        this.eventPublisher = eventPublisher;
        this.enableCheckpoints = enableCheckpoints;
        this.enableRetries = enableRetries;
        this.useWorkStealing = useWorkStealing;
        
        // Initialize cache with configuration from environment
        const cacheConfig = CacheConfig.fromEnvironment();
        this.cache = new BuildCache(".builder-cache", cacheConfig);
        
        // Initialize retry orchestrator
        this.retryOrchestrator = new RetryOrchestrator();
        this.retryOrchestrator.setEnabled(enableRetries);
        
        // Initialize checkpoint manager
        this.checkpointManager = new CheckpointManager(".", enableCheckpoints);
        
        // Initialize lock-free ready queue
        this.readyQueue = LockFreeQueue!BuildNode(READY_QUEUE_SIZE);
        
        this.workerCount = maxParallelism == 0 ? totalCPUs : maxParallelism;
        this.pool = new ThreadPool(workerCount);
        
        // Initialize work-stealing scheduler if enabled
        if (useWorkStealing)
        {
            this.workStealingScheduler = new WorkStealingScheduler!BuildNode(
                workerCount,
                (BuildNode node) @trusted => buildNodeWithScheduler(node)
            );
            Logger.debugLog("Work-stealing scheduler enabled for critical path optimization");
        }
        
        // Register language handlers
        handlers[TargetLanguage.Python] = new PythonHandler();
        handlers[TargetLanguage.JavaScript] = new JavaScriptHandler();
        handlers[TargetLanguage.TypeScript] = new TypeScriptHandler();
        handlers[TargetLanguage.Go] = new GoHandler();
        handlers[TargetLanguage.Rust] = new RustHandler();
        handlers[TargetLanguage.D] = new DHandler();
        handlers[TargetLanguage.Cpp] = new CppHandler();
        handlers[TargetLanguage.C] = new CHandler();
        handlers[TargetLanguage.Java] = new JavaHandler();
        handlers[TargetLanguage.Kotlin] = new KotlinHandler();
        handlers[TargetLanguage.CSharp] = new CSharpHandler();
        handlers[TargetLanguage.Zig] = new ZigHandler();
        handlers[TargetLanguage.Swift] = new SwiftHandler();
        handlers[TargetLanguage.Ruby] = new RubyHandler();
        handlers[TargetLanguage.PHP] = new PHPHandler();
        handlers[TargetLanguage.Scala] = new ScalaHandler();
        handlers[TargetLanguage.Elixir] = new ElixirHandler();
        handlers[TargetLanguage.Nim] = new NimHandler();
        handlers[TargetLanguage.Lua] = new LuaHandler();
        handlers[TargetLanguage.R] = new RHandler();
    }
    
    ~this()
    {
        shutdown();
    }
    
    /// Explicitly shutdown the executor and thread pool
    /// 
    /// IMPORTANT: Always call this before program termination to ensure
    /// cache data is properly flushed to disk and no data is lost.
    void shutdown()
    {
        if (workStealingScheduler !is null)
        {
            workStealingScheduler.shutdown();
            workStealingScheduler = null;
        }
        
        if (pool !is null)
        {
            pool.shutdown();
            pool = null;
        }
        
        // Explicitly close cache to prevent data loss
        // This is critical - don't rely on destructor which may fail during GC
        if (cache !is null)
        {
            cache.close();
        }
    }
    
    /// Estimate build cost for a node (for critical path calculation)
    private size_t estimateBuildCost(BuildNode node) @safe
    {
        // Heuristic: base cost + source file count * weight
        enum size_t BASE_COST = 100;  // Base cost in arbitrary units
        enum size_t PER_FILE_COST = 50;  // Cost per source file
        enum size_t PER_DEP_COST = 10;   // Cost per dependency
        
        size_t cost = BASE_COST;
        cost += node.target.sources.length * PER_FILE_COST;
        cost += node.dependencies.length * PER_DEP_COST;
        
        // Language-specific multipliers
        switch (node.target.language)
        {
            case TargetLanguage.Cpp:
            case TargetLanguage.Rust:
                cost = cast(size_t)(cost * 2.0);  // Slower to compile
                break;
            case TargetLanguage.TypeScript:
            case TargetLanguage.JavaScript:
                cost = cast(size_t)(cost * 1.5);  // Type checking overhead
                break;
            case TargetLanguage.Python:
            case TargetLanguage.Ruby:
                cost = cast(size_t)(cost * 0.5);  // Faster (interpreted)
                break;
            default:
                break;
        }
        
        return cost;
    }
    
    /// Build a node using the work-stealing scheduler
    private void buildNodeWithScheduler(BuildNode node) @trusted
    {
        try
        {
            buildNode(node);
        }
        catch (Exception e)
        {
            Logger.error("Build failed for " ~ node.id ~ ": " ~ e.msg);
            atomicOp!"+="(failedTasks, 1);
        }
    }
    
    /// Execute the build with event-driven scheduling
    void execute()
    {
        import core.memory : GC;
        
        auto sw = StopWatch(AutoStart.yes);
        
        auto sortResult = graph.topologicalSort();
        if (sortResult.isErr)
        {
            auto error = sortResult.unwrapErr();
            Logger.error("Cannot build: " ~ format(error));
            
            if (eventPublisher !is null)
            {
                auto event = new BuildFailedEvent(error.message(), 0, sw.peek(), sw.peek());
                eventPublisher.publish(event);
            }
            return;
        }
        
        auto sorted = sortResult.unwrap();
        Logger.info("Building " ~ sorted.length.to!string ~ " targets...");
        
        // Check for checkpoint and attempt resume
        if (enableCheckpoints && checkpointManager.exists())
        {
            auto checkpointResult = checkpointManager.load();
            if (checkpointResult.isOk)
            {
                auto checkpoint = checkpointResult.unwrap();
                
                if (checkpoint.isValid(graph) && !checkpointManager.isStale())
                {
                    Logger.info("Found valid checkpoint from " ~ 
                               checkpoint.timestamp.toSimpleString());
                    
                    // Attempt resume with smart strategy
                    auto planner = new ResumePlanner(ResumeConfig.fromEnvironment());
                    auto planResult = planner.plan(checkpoint, graph);
                    
                    if (planResult.isOk)
                    {
                        auto plan = planResult.unwrap();
                        plan.print();
                        
                        Logger.info("Resuming build (saving ~" ~ 
                                   plan.estimatedSavings().to!string[0..min(MIN_STAT_STRING_LENGTH, plan.estimatedSavings().to!string.length)] ~ "% time)...");
                    }
                }
                else
                {
                    Logger.info("Checkpoint stale or invalid, rebuilding...");
                    checkpointManager.clear();
                }
            }
        }
        
        // For large builds, disable GC during execution to avoid pauses
        immutable bool useGcControl = sorted.length > LARGE_BUILD_THRESHOLD;
        if (useGcControl)
        {
            GC.disable();
            Logger.debugLog("GC disabled for large build (" ~ sorted.length.to!string ~ " targets)");
        }
        
        // Ensure GC is re-enabled on exit
        scope(exit) 
        {
            if (useGcControl)
            {
                GC.enable();
                GC.collect(); // Cleanup after build
                Logger.debugLog("GC re-enabled and collected");
            }
        }
        
        // Publish build started event
        if (eventPublisher !is null)
        {
            auto event = new BuildStartedEvent(sorted.length, workerCount, sw.peek());
            eventPublisher.publish(event);
        }
        
        size_t built = 0;
        size_t cached = 0;
        
        atomicStore(activeTasks, cast(size_t)0);
        atomicStore(failedTasks, cast(size_t)0);
        
        auto stats = graph.getStats();
        Logger.info("Max parallelism: " ~ workerCount.to!string ~ " jobs");
        
        // Initialize pending dependency counters for lock-free execution
        foreach (node; sorted)
            node.initPendingDeps();
        
        // Enqueue initially ready nodes (those with no dependencies)
        foreach (node; sorted)
        {
            if (node.pendingDeps == 0)
            {
                if (!readyQueue.enqueue(node))
                {
                    Logger.error("Failed to enqueue initial node: " ~ node.id);
                }
            }
        }
        
        // Lock-free execution: workers dequeue and build in parallel
        // Pre-allocate batch buffer to avoid repeated allocations
        BuildNode[] currentBatch;
        currentBatch.reserve(workerCount);
        size_t batchSize = 0;  // Track batch size without changing array length
        
        while (atomicLoad(failedTasks) == 0)
        {
            batchSize = 0;  // Reset batch size
            
            // Dequeue a batch of ready nodes for parallel execution
            // Reuse buffer to avoid allocation
            foreach (i; 0 .. workerCount)
            {
                auto node = readyQueue.tryDequeue();
                if (node is null)
                    break;
                
                // Mark as building
                node.status = BuildStatus.Building;
                
                // Grow array only if needed, reuse existing capacity
                if (batchSize >= currentBatch.length)
                    currentBatch.length = batchSize + 1;
                currentBatch[batchSize++] = node;
            }
            
            // If no ready nodes and no active tasks, we're done
            if (batchSize == 0 && atomicLoad(activeTasks) == 0)
                break;
            
            // If batch is empty but tasks are active, wait briefly
            if (batchSize == 0)
            {
                import core.thread : Thread;
                import core.time : msecs;
                Thread.sleep(1.msecs);
                continue;
            }
            
            // Use slice of actual batch (avoid processing empty slots)
            auto batch = currentBatch[0 .. batchSize];
            Logger.debugLog("Building batch: " ~ batch.map!(n => n.id).join(", "));
            
            atomicOp!"+="(activeTasks, cast(size_t)batchSize);
            
            // Execute batch in parallel using persistent pool
            auto results = pool.map(batch, (BuildNode node) {
                auto result = buildNode(node);
                
                // On completion, enqueue ready dependents atomically
                if (result.success)
                {
                    foreach (dependent; node.dependents)
                    {
                        immutable remaining = dependent.decrementPendingDeps();
                        if (remaining == 0)
                        {
                            // All dependencies satisfied, enqueue for building
                            if (!readyQueue.enqueue(dependent))
                            {
                                Logger.error("Failed to enqueue dependent: " ~ dependent.id);
                            }
                        }
                    }
                }
                else
                {
                    // Mark all dependents as failed (cascading failure)
                    foreach (dependent; node.dependents)
                    {
                        if (dependent.status == BuildStatus.Pending)
                        {
                            dependent.status = BuildStatus.Failed;
                            atomicOp!"+="(failedTasks, cast(size_t)1);
                        }
                    }
                }
                
                return result;
            });
            
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
                }
                else
                {
                    node.status = BuildStatus.Failed;
                    atomicOp!"+="(failedTasks, cast(size_t)1);
                    Logger.error("Failed to build " ~ node.id ~ ": " ~ result.error);
                }
            }
            
            atomicOp!"-="(activeTasks, cast(size_t)batchSize);
        }
        
        sw.stop();
        
        auto failed = atomicLoad(failedTasks);
        
        // Flush cache to disk (lazy write optimization)
        cache.flush();
        
        // Get cache statistics
        auto cacheStats = cache.getStats();
        
        // Publish build completed/failed event
        if (eventPublisher !is null)
        {
            if (failed > 0)
            {
                auto event = new BuildFailedEvent("Build failed", failed, sw.peek(), sw.peek());
                eventPublisher.publish(event);
            }
            else
            {
                auto event = new BuildCompletedEvent(built, cached, failed, sw.peek(), sw.peek());
                eventPublisher.publish(event);
            }
            
            // Publish statistics
            CacheStats cliCacheStats;
            cliCacheStats.hits = cacheStats.metadataHits;
            cliCacheStats.misses = cacheStats.contentHashes;
            cliCacheStats.totalEntries = cacheStats.totalEntries;
            cliCacheStats.totalSize = cacheStats.totalSize;
            cliCacheStats.hitRate = cacheStats.metadataHitRate;
            
            BuildStats buildStats;
            buildStats.totalTargets = sorted.length;
            buildStats.completedTargets = built;
            buildStats.cachedTargets = cached;
            buildStats.failedTargets = failed;
            buildStats.elapsed = sw.peek();
            buildStats.targetsPerSecond = sorted.length > 0 ? 
                (sorted.length * 1000.0) / sw.peek().total!"msecs" : 0.0;
            
            auto statsEvent = new StatisticsEvent(cliCacheStats, buildStats, sw.peek());
            eventPublisher.publish(statsEvent);
        }
        
        // Print summary (legacy)
        writeln();
        Logger.info("Build Summary:");
        Logger.info("  Built: " ~ built.to!string);
        Logger.info("  Cached: " ~ cached.to!string);
        Logger.info("  Failed: " ~ failed.to!string);
        Logger.info("  Time: " ~ sw.peek().total!"msecs".to!string ~ "ms");
        
        // Print cache performance statistics
        if (cacheStats.metadataHits + cacheStats.contentHashes > 0)
        {
            Logger.info("Cache Performance:");
            Logger.info("  Total entries: " ~ cacheStats.totalEntries.to!string);
            Logger.info("  Cache size: " ~ formatSize(cacheStats.totalSize));
            Logger.info("  Metadata hit rate: " ~ cacheStats.metadataHitRate.to!string[0..min(MAX_STAT_STRING_LENGTH, cacheStats.metadataHitRate.to!string.length)] ~ "%");
            
            if (cacheStats.hashCacheHits + cacheStats.hashCacheMisses > 0)
            {
                Logger.info("  Hash cache hit rate: " ~ cacheStats.hashCacheHitRate.to!string[0..min(MAX_STAT_STRING_LENGTH, cacheStats.hashCacheHitRate.to!string.length)] ~ "%");
                Logger.info("  Hash cache saves: " ~ cacheStats.hashCacheHits.to!string ~ " duplicate hashes avoided");
            }
        }
        
        // No longer throw exception - let caller check failed count
        // Errors are already logged and events published
    }
    
    /// Format size in human-readable format
    private static string formatSize(in size_t bytes) pure @safe
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
    
    /// Build a single node
    private BuildResult buildNode(BuildNode node)
    {
        BuildResult result;
        result.targetId = node.id;
        auto nodeTimer = StopWatch(AutoStart.yes);
        
        try
        {
            Logger.info("Building " ~ node.id ~ "...");
            
            // Publish target started event
            if (eventPublisher !is null)
            {
                auto sortedResult = graph.topologicalSort();
                if (sortedResult.isOk)
                {
                    auto sorted = sortedResult.unwrap();
                    auto index = sorted.countUntil(node) + 1;
                    auto event = new TargetStartedEvent(node.id, index, sorted.length, nodeTimer.peek());
                    eventPublisher.publish(event);
                }
            }
            
            auto target = node.target;
            auto deps = node.dependencies.map!(d => d.id).array;
            
            // Check cache
            if (cache.isCached(node.id, target.sources, deps))
            {
                Logger.success("  ✓ " ~ node.id ~ " (cached)");
                result.success = true;
                result.cached = true;
                
                // Publish cached event
                if (eventPublisher !is null)
                {
                    auto event = new TargetCachedEvent(node.id, nodeTimer.peek());
                    eventPublisher.publish(event);
                }
                
                return result;
            }
            
            // Get language handler
            auto handler = handlers.get(target.language, null);
            if (handler is null)
            {
                auto error = new BuildFailureError(
                    node.id,
                    "No handler for language: " ~ target.language.to!string,
                    ErrorCode.HandlerNotFound
                );
                result.error = error.message();
                Logger.error(format(error));
                return result;
            }
            
            // Build the target using new Result-based API with retry logic
            Result!(string, BuildError) buildResult;
            
            if (enableRetries)
            {
                // Wrap build in retry logic
                auto policy = retryOrchestrator.policyFor(new BuildFailureError(node.id, ""));
                buildResult = retryOrchestrator.withRetry(
                    node.id,
                    () {
                        immutable attempt = node.retryAttempts;
                        if (attempt > 0)
                            Logger.info("  Retry attempt " ~ attempt.to!string ~ " for " ~ node.id);
                        
                        node.incrementRetries();
                        return handler.build(target, config);
                    },
                    policy
                );
            }
            else
            {
                buildResult = handler.build(target, config);
            }
            
            if (buildResult.isOk)
            {
                auto outputHash = buildResult.unwrap();
                cache.update(node.id, target.sources, deps, outputHash);
                
                // Show retry success if retried
                if (node.retryAttempts > 1)
                    Logger.success("  ✓ " ~ node.id ~ " (succeeded after " ~ (node.retryAttempts - 1).to!string ~ " retries)");
                else
                    Logger.success("  ✓ " ~ node.id);
                
                result.success = true;
                node.resetRetries();
                
                // Publish target completed event
                if (eventPublisher !is null)
                {
                    nodeTimer.stop();
                    auto event = new TargetCompletedEvent(node.id, nodeTimer.peek(), 0, nodeTimer.peek());
                    eventPublisher.publish(event);
                }
            }
            else
            {
                auto error = buildResult.unwrapErr();
                node.lastError = error.message();
                result.error = error.message();
                Logger.error(format(error));
                
                // Publish target failed event
                if (eventPublisher !is null)
                {
                    nodeTimer.stop();
                    auto event = new TargetFailedEvent(node.id, error.message(), nodeTimer.peek(), nodeTimer.peek());
                    eventPublisher.publish(event);
                }
            }
        }
        catch (Exception e)
        {
            auto error = new BuildFailureError(node.id, e.msg);
            error.addContext(ErrorContext("building node", "exception caught"));
            result.error = error.message();
            Logger.error(format(error));
            
            // Publish target failed event
            if (eventPublisher !is null)
            {
                nodeTimer.stop();
                auto event = new TargetFailedEvent(node.id, error.message(), nodeTimer.peek(), nodeTimer.peek());
                eventPublisher.publish(event);
            }
        }
        
        return result;
    }
}

/// Result of building a single target
struct BuildResult
{
    string targetId;
    bool success = false;
    bool cached = false;
    string error;
}

