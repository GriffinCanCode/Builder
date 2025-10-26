module core.executor;

import std.stdio;
import std.parallelism;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import core.graph;
import core.cache;
import config.schema;
import languages.base;
import languages.python;
import languages.javascript;
import languages.go;
import languages.rust;
import utils.logger;
import utils.parallel;

/// Executes builds based on the dependency graph
class BuildExecutor
{
    private BuildGraph graph;
    private WorkspaceConfig config;
    private BuildCache cache;
    private LanguageHandler[TargetLanguage] handlers;
    private size_t maxParallelism;
    
    this(BuildGraph graph, WorkspaceConfig config, size_t maxParallelism = 0)
    {
        this.graph = graph;
        this.config = config;
        this.cache = new BuildCache();
        this.maxParallelism = maxParallelism == 0 ? totalCPUs : maxParallelism;
        
        // Register language handlers
        handlers[TargetLanguage.Python] = new PythonHandler();
        handlers[TargetLanguage.JavaScript] = new JavaScriptHandler();
        handlers[TargetLanguage.Go] = new GoHandler();
        handlers[TargetLanguage.Rust] = new RustHandler();
        handlers[TargetLanguage.D] = new DHandler();
    }
    
    /// Execute the build
    void execute()
    {
        auto sw = StopWatch(AutoStart.yes);
        
        auto sorted = graph.topologicalSort();
        Logger.info("Building " ~ sorted.length.to!string ~ " targets...");
        
        size_t built = 0;
        size_t cached = 0;
        size_t failed = 0;
        
        // Build in waves (by depth) for maximum parallelism
        auto stats = graph.getStats();
        Logger.info("Max parallelism: " ~ min(maxParallelism, stats.parallelism).to!string ~ " jobs");
        
        while (true)
        {
            auto ready = graph.getReadyNodes();
            if (ready.empty)
                break;
            
            // Build ready nodes in parallel
            auto results = ParallelExecutor.execute(ready, &buildNode, maxParallelism);
            
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
                    failed++;
                    Logger.error("Failed to build " ~ node.id ~ ": " ~ result.error);
                }
            }
            
            if (failed > 0)
                break;
        }
        
        sw.stop();
        
        // Print summary
        writeln();
        Logger.info("Build Summary:");
        Logger.info("  Built: " ~ built.to!string);
        Logger.info("  Cached: " ~ cached.to!string);
        Logger.info("  Failed: " ~ failed.to!string);
        Logger.info("  Time: " ~ sw.peek().total!"msecs".to!string ~ "ms");
        
        if (failed > 0)
            throw new Exception("Build failed with " ~ failed.to!string ~ " errors");
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
                result.error = "No handler for language: " ~ target.language.to!string;
                return result;
            }
            
            // Build the target
            auto buildResult = handler.build(target, config);
            
            if (buildResult.success)
            {
                // Update cache
                cache.update(node.id, target.sources, deps, buildResult.outputHash);
                Logger.success("  ✓ " ~ node.id);
                result.success = true;
            }
            else
            {
                result.error = buildResult.error;
            }
        }
        catch (Exception e)
        {
            result.error = e.msg;
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

