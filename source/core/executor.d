module core.executor;

import std.stdio;
import std.parallelism;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import core.sync.mutex;
import core.sync.condition;
import core.atomic;
import core.graph;
import core.cache;
import config.schema;
import languages.base;
import languages.python;
import languages.javascript;
import languages.go;
import languages.rust : RustHandler, DHandler;
import languages.cpp : CppHandler, CHandler;
import languages.java;
import languages.kotlin;
import languages.csharp;
import languages.zig;
import languages.swift;
import languages.ruby;
import languages.php;
import languages.scala;
import languages.elixir;
import languages.nim;
import languages.lua;
import utils.logger;
import utils.pool;
import errors;

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
    
    this(BuildGraph graph, WorkspaceConfig config, size_t maxParallelism = 0)
    {
        this.graph = graph;
        this.config = config;
        
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
        handlers[TargetLanguage.TypeScript] = new JavaScriptHandler();
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
        
        // Print summary
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
        
        try
        {
            Logger.info("Building " ~ node.id ~ "...");
            
            auto target = node.target;
            auto deps = node.dependencies.map!(d => d.id).array;
            
            // Check cache
            if (cache.isCached(node.id, target.sources, deps))
            {
                Logger.success("  ✓ " ~ node.id ~ " (cached)");
                result.success = true;
                result.cached = true;
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
            }
            else
            {
                auto error = buildResult.unwrapErr();
                result.error = error.message();
                Logger.error(format(error));
            }
        }
        catch (Exception e)
        {
            auto error = new BuildFailureError(node.id, e.msg);
            error.addContext(ErrorContext("building node", "exception caught"));
            result.error = error.message();
            Logger.error(format(error));
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

