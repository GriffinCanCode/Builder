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
/// - stateMutex: protects graph traversal and node status updates
/// - All node status changes are synchronized to ensure consistency
/// - ThreadPool handles parallel task execution with internal synchronization
/// - BuildCache: internally synchronized, safe for concurrent access from buildNode()
final class BuildExecutor
{
    private BuildGraph graph;
    private WorkspaceConfig config;
    private BuildCache cache;
    private LanguageHandler[TargetLanguage] handlers;
    private ThreadPool pool;
    private Mutex stateMutex;  // Protects graph state and coordinated status changes
    private Condition tasksReady;
    private shared size_t activeTasks;  // Atomic: number of currently executing tasks
    private shared size_t failedTasks;  // Atomic: number of failed tasks
    private immutable size_t workerCount;
    private EventPublisher eventPublisher;
    private RetryOrchestrator retryOrchestrator;
    private CheckpointManager checkpointManager;
    private bool enableCheckpoints;
    private bool enableRetries;
    
    this(BuildGraph graph, WorkspaceConfig config, size_t maxParallelism = 0, EventPublisher eventPublisher = null, bool enableCheckpoints = true, bool enableRetries = true) @trusted
    {
        this.graph = graph;
        this.config = config;
        this.eventPublisher = eventPublisher;
        this.enableCheckpoints = enableCheckpoints;
        this.enableRetries = enableRetries;
        
        // Initialize cache with configuration from environment
        const cacheConfig = CacheConfig.fromEnvironment();
        this.cache = new BuildCache(".builder-cache", cacheConfig);
        
        // Initialize retry orchestrator
        this.retryOrchestrator = new RetryOrchestrator();
        this.retryOrchestrator.setEnabled(enableRetries);
        
        // Initialize checkpoint manager
        this.checkpointManager = new CheckpointManager(".", enableCheckpoints);
        
        this.stateMutex = new Mutex();
        this.tasksReady = new Condition(stateMutex);
        
        this.workerCount = maxParallelism == 0 ? totalCPUs : maxParallelism;
        this.pool = new ThreadPool(workerCount);
        
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
    void shutdown()
    {
        if (pool !is null)
        {
            pool.shutdown();
            pool = null;
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
                                   plan.estimatedSavings().to!string[0..min(5, plan.estimatedSavings().to!string.length)] ~ "% time)...");
                    }
                }
                else
                {
                    Logger.info("Checkpoint stale or invalid, rebuilding...");
                    checkpointManager.clear();
                }
            }
        }
        
        // For large builds (>100 targets), disable GC during execution to avoid pauses
        immutable bool useGcControl = sorted.length > 100;
        if (useGcControl)
        {
            GC.disable();
            Logger.debug_("GC disabled for large build (" ~ sorted.length.to!string ~ " targets)");
        }
        
        // Ensure GC is re-enabled on exit
        scope(exit) 
        {
            if (useGcControl)
            {
                GC.enable();
                GC.collect(); // Cleanup after build
                Logger.debug_("GC re-enabled and collected");
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
        
        synchronized (stateMutex)
        {
            atomicStore(activeTasks, cast(size_t)0);
            atomicStore(failedTasks, cast(size_t)0);
        }
        
        auto stats = graph.getStats();
        Logger.info("Max parallelism: " ~ workerCount.to!string ~ " jobs");
        
        // Event-driven execution: submit ready nodes immediately
        while (atomicLoad(failedTasks) == 0)
        {
            BuildNode[] ready;
            
            // CRITICAL SECTION: Graph traversal and status coordination
            synchronized (stateMutex)
            {
                // getReadyNodes() reads node status atomically (thread-safe)
                ready = graph.getReadyNodes();
                
                if (ready.empty && atomicLoad(activeTasks) == 0)
                    break; // All done
                
                if (ready.empty)
                {
                    // Wait for tasks to complete and free up dependencies
                    tasksReady.wait();
                    continue;
                }
                
                // Mark nodes as Building BEFORE submitting to prevent duplicates
                // Status is updated atomically via property accessor
                foreach (node; ready)
                {
                    Logger.debug_("Marking " ~ node.id ~ " as Building (was " ~ node.status.to!string ~ ")");
                    node.status = BuildStatus.Building;
                }
                
                Logger.debug_("Ready nodes: " ~ ready.map!(n => n.id).join(", "));
                
                atomicOp!"+="(activeTasks, ready.length);
            }
            
            // Execute ready nodes in parallel using persistent pool
            // Each thread builds independently, reading BuildNode.status atomically
            auto results = pool.map(ready, &buildNode);
            
            // CRITICAL SECTION: Update node status with build results
            synchronized (stateMutex)
            {
                foreach (i, result; results)
                {
                    auto node = ready[i];
                    
                    // Status updates are atomic via property accessor
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
                        atomicOp!"+="(failedTasks, 1);
                        Logger.error("Failed to build " ~ node.id ~ ": " ~ result.error);
                    }
                }
                
                atomicOp!"-="(activeTasks, ready.length);
                tasksReady.notifyAll();  // Wake waiting threads
            }
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
            Logger.info("  Metadata hit rate: " ~ cacheStats.metadataHitRate.to!string[0..min(4, cacheStats.metadataHitRate.to!string.length)] ~ "%");
        }
        
        // No longer throw exception - let caller check failed count
        // Errors are already logged and events published
    }
    
    /// Format size in human-readable format
    private static string formatSize(in size_t bytes) pure @safe
    {
        import std.format : format;
        
        if (bytes < 1024)
            return format("%d B", bytes);
        else if (bytes < 1024 * 1024)
            return format("%d KB", bytes / 1024);
        else if (bytes < 1024 * 1024 * 1024)
            return format("%d MB", bytes / (1024 * 1024));
        else
            return format("%d GB", bytes / (1024 * 1024 * 1024));
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

