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
import languages.scripting.javascript;
import languages.scripting.typescript;
import languages.scripting.go;
import languages.compiled.rust : RustHandler, DHandler;
import languages.compiled.cpp : CppHandler, CHandler;
import languages.jvm.java;
import languages.jvm.kotlin;
import languages.dotnet.csharp;
import languages.compiled.zig;
import languages.dotnet.swift;
import languages.scripting.ruby;
import languages.scripting.php;
import languages.jvm.scala;
import languages.scripting.elixir;
import languages.compiled.nim;
import languages.scripting.lua;
import utils.logging.logger;
import utils.concurrency.pool;
import errors;
import cli.events.events;

/// Executes builds based on the dependency graph
class BuildExecutor
{
    private BuildGraph graph;
    private WorkspaceConfig config;
    private BuildCache cache;
    private LanguageHandler[TargetLanguage] handlers;
    private ThreadPool pool;
    private Mutex stateMutex;
    private Condition tasksReady;
    private shared size_t activeTasks;
    private shared size_t failedTasks;
    private size_t workerCount;
    private EventPublisher eventPublisher;
    
    this(BuildGraph graph, WorkspaceConfig config, size_t maxParallelism = 0, EventPublisher eventPublisher = null)
    {
        this.graph = graph;
        this.config = config;
        this.eventPublisher = eventPublisher;
        
        // Initialize cache with configuration from environment
        auto cacheConfig = CacheConfig.fromEnvironment();
        this.cache = new BuildCache(".builder-cache", cacheConfig);
        
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
        auto sw = StopWatch(AutoStart.yes);
        
        auto sorted = graph.topologicalSort();
        Logger.info("Building " ~ sorted.length.to!string ~ " targets...");
        
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
            
            synchronized (stateMutex)
            {
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
                foreach (node; ready)
                {
                    Logger.debug_("Marking " ~ node.id ~ " as Building (was " ~ node.status.to!string ~ ")");
                    node.status = BuildStatus.Building;
                }
                
                Logger.debug_("Ready nodes: " ~ ready.map!(n => n.id).join(", "));
                
                atomicOp!"+="(activeTasks, ready.length);
            }
            
            // Execute ready nodes in parallel using persistent pool
            auto results = pool.map(ready, &buildNode);
            
            synchronized (stateMutex)
            {
                foreach (i, result; results)
                {
                    auto node = ready[i];
                    
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
                tasksReady.notifyAll();
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
        
        if (failed > 0)
            throw new Exception("Build failed with " ~ failed.to!string ~ " errors");
    }
    
    /// Format size in human-readable format
    private string formatSize(size_t bytes)
    {
        if (bytes < 1024)
            return bytes.to!string ~ " B";
        if (bytes < 1024 * 1024)
            return (bytes / 1024).to!string ~ " KB";
        if (bytes < 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024)).to!string ~ " MB";
        return (bytes / (1024 * 1024 * 1024)).to!string ~ " GB";
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
                auto sorted = graph.topologicalSort();
                auto index = sorted.countUntil(node) + 1;
                auto event = new TargetStartedEvent(node.id, index, sorted.length, nodeTimer.peek());
                eventPublisher.publish(event);
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
            
            // Build the target using new Result-based API
            auto buildResult = handler.build(target, config);
            
            if (buildResult.isOk)
            {
                auto outputHash = buildResult.unwrap();
                cache.update(node.id, target.sources, deps, outputHash);
                Logger.success("  ✓ " ~ node.id);
                result.success = true;
                
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

struct BuildResult
{
    string targetId;
    bool success;
    bool cached;
    string error;
}

