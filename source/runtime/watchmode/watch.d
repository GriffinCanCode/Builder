module runtime.watchmode.watch;

import std.stdio;
import std.datetime;
import std.algorithm;
import std.array;
import std.conv;
import std.path;
import core.thread;
import core.time;
import graph.graph;
import runtime.core.engine;
import runtime.services.services;
import caching.targets.cache;
import config.schema.schema;
import config.parsing.parser;
import utils.files.watch;
import utils.logging.logger;
import cli.events.events;
import analysis.incremental.watcher;
import errors;

/// Watch mode configuration
struct WatchModeConfig
{
    Duration debounceDelay = 300.msecs;     /// Delay before triggering rebuild
    bool clearScreen = true;                 /// Clear screen between builds
    bool showGraph = false;                  /// Show dependency graph
    string renderMode = "auto";              /// CLI render mode
    bool failFast = false;                   /// Stop on first error
    bool verbose = false;                    /// Verbose output
}

/// Watch mode service - orchestrates file watching and incremental builds
final class WatchModeService
{
    private string _workspaceRoot;
    private WorkspaceConfig _config;
    private BuildServices _services;
    private FileWatcher _watcher;
    private AnalysisWatcher _analysisWatcher;
    private WatchModeConfig _watchConfig;
    private bool _isRunning;
    private size_t _buildNumber;
    private SysTime _lastBuildTime;
    private bool _lastBuildSuccess;
    
    /// Create watch mode service
    this(string workspaceRoot, WatchModeConfig config) @system
    {
        _workspaceRoot = workspaceRoot;
        _watchConfig = config;
        _buildNumber = 0;
        _isRunning = false;
        _lastBuildSuccess = true;
    }
    
    /// Start watch mode
    Result!BuildError start(string target = "") @system
    {
        // Parse workspace configuration
        auto configResult = ConfigParser.parseWorkspace(_workspaceRoot);
        if (configResult.isErr)
        {
            return Result!BuildError.err(configResult.unwrapErr());
        }
        
        _config = configResult.unwrap();
        
        // Initialize build services
        _services = new BuildServices(_config, _config.options);
        
        // Initialize analysis watcher for proactive cache invalidation
        if (_services.analyzer.hasIncremental())
        {
            _analysisWatcher = new AnalysisWatcher(
                _services.analyzer.getIncrementalAnalyzer(),
                _config
            );
            
            auto watcherResult = _analysisWatcher.start(_workspaceRoot);
            if (watcherResult.isOk)
            {
                Logger.debugLog("Analysis watcher started for proactive cache invalidation");
            }
            else
            {
                Logger.debugLog("Analysis watcher not available");
            }
        }
        
        // Create file watcher with config
        WatchConfig watchConfig;
        watchConfig.debounceDelay = _watchConfig.debounceDelay;
        watchConfig.recursive = true;
        watchConfig.useNativeWatcher = true;
        
        _watcher = new FileWatcher(watchConfig);
        
        // Perform initial build
        printWatchHeader();
        Logger.info("Performing initial build...");
        writeln();
        
        performBuild(target);
        
        // Start watching
        Logger.info("Watching for changes... (Press Ctrl+C to stop)");
        Logger.info("Using watcher: " ~ _watcher.implName());
        writeln();
        
        _isRunning = true;
        
        auto watchResult = _watcher.watch(_workspaceRoot, () {
            handleFileChanges(target);
        });
        
        if (watchResult.isErr)
        {
            return Result!BuildError.err(watchResult.unwrapErr());
        }
        
        // Keep running until interrupted
        while (_isRunning)
        {
            Thread.sleep(100.msecs);
        }
        
        return Result!BuildError.ok();
    }
    
    /// Stop watch mode
    void stop() @system
    {
        _isRunning = false;
        
        if (_watcher !is null)
        {
            _watcher.stop();
        }
        
        if (_analysisWatcher !is null)
        {
            _analysisWatcher.stop();
        }
        
        if (_services !is null)
        {
            _services.shutdown();
        }
        
        Logger.info("Watch mode stopped");
    }
    
    /// Handle file changes and trigger rebuild
    private void handleFileChanges(string target) @system
    {
        _buildNumber++;
        
        if (_watchConfig.clearScreen)
        {
            clearScreen();
        }
        
        printBuildHeader();
        
        performBuild(target);
        
        writeln();
        if (_lastBuildSuccess)
        {
            Logger.success("Build #" ~ _buildNumber.to!string ~ " completed successfully");
        }
        else
        {
            Logger.error("Build #" ~ _buildNumber.to!string ~ " failed");
        }
        
        Logger.info("Watching for changes...");
        writeln();
    }
    
    /// Perform a build
    private void performBuild(string target) @system
    {
        import std.datetime.stopwatch : StopWatch, AutoStart;
        
        auto sw = StopWatch(AutoStart.yes);
        _lastBuildSuccess = false;
        
        try
        {
            // Re-parse configuration to pick up any changes
            auto configResult = ConfigParser.parseWorkspace(_workspaceRoot);
            if (configResult.isErr)
            {
                Logger.error("Failed to parse workspace configuration");
                import errors.formatting.format : format;
                Logger.error(format(configResult.unwrapErr()));
                return;
            }
            
            _config = configResult.unwrap();
            
            // Recreate services to pick up config changes
            if (_services !is null)
            {
                _services.shutdown();
            }
            _services = new BuildServices(_config, _config.options);
            
            // Set render mode
            import app : parseRenderMode;
            auto renderMode = parseRenderMode(_watchConfig.renderMode);
            _services.setRenderMode(renderMode);
            
            // Analyze dependencies
            auto graphResult = _services.analyzer.analyze(target);
            if (graphResult.isErr)
            {
                Logger.error("Failed to analyze dependencies");
                import errors.formatting.format : format;
                Logger.error(format(graphResult.unwrapErr()));
                return;
            }
            auto graph = graphResult.unwrap();
            
            if (_watchConfig.showGraph)
            {
                Logger.info("\nDependency Graph:");
                graph.print();
            }
            
            // Execute build
            auto engine = _services.createEngine(graph);
            _lastBuildSuccess = engine.execute();
            engine.shutdown();
            
            sw.stop();
            _lastBuildTime = Clock.currTime();
            
            // Print timing
            auto elapsed = sw.peek();
            Logger.info("Build time: " ~ elapsed.total!"msecs".to!string ~ "ms");
        }
        catch (Exception e)
        {
            Logger.error("Build failed with exception: " ~ e.msg);
            _lastBuildSuccess = false;
        }
    }
    
    /// Print watch mode header
    private void printWatchHeader() @system
    {
        writeln();
        writeln("═══════════════════════════════════════════════════════════");
        writeln("  Builder Watch Mode");
        writeln("═══════════════════════════════════════════════════════════");
        writeln();
    }
    
    /// Print build header
    private void printBuildHeader() @system
    {
        auto now = Clock.currTime();
        writeln();
        writeln("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        writeln("  Build #" ~ _buildNumber.to!string ~ " - " ~ now.toSimpleString());
        writeln("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        writeln();
    }
    
    /// Clear the terminal screen
    private void clearScreen() @system
    {
        version(Windows)
        {
            import std.process : execute;
            execute(["cmd", "/c", "cls"]);
        }
        else
        {
            // ANSI escape code to clear screen and move cursor to top
            write("\033[2J\033[H");
            stdout.flush();
        }
    }
}

/// Intelligent change detector that maps file changes to affected targets
final class ChangeDetector
{
    private WorkspaceConfig _config;
    private BuildGraph _graph;
    private BuildCache _cache;
    
    this(WorkspaceConfig config, BuildGraph graph, BuildCache cache) @system
    {
        _config = config;
        _graph = graph;
        _cache = cache;
    }
    
    /// Determine which targets are affected by file changes
    string[] getAffectedTargets(const string[] changedFiles) @system
    {
        bool[string] affected;
        
        // For each changed file, find targets that reference it
        foreach (changedFile; changedFiles)
        {
            auto normalizedPath = buildNormalizedPath(absolutePath(changedFile));
            
            // Check each target
            foreach (target; _config.targets)
            {
                // Check if file is in target's sources
                foreach (source; target.sources)
                {
                    auto sourcePath = buildNormalizedPath(absolutePath(source));
                    
                    if (sourcePath == normalizedPath || 
                        normalizedPath.startsWith(dirName(sourcePath)))
                    {
                        affected[target.name] = true;
                        
                        // Also mark dependent targets
                        markDependents(target.name, affected);
                        break;
                    }
                }
            }
        }
        
        return affected.keys.array;
    }
    
    /// Recursively mark dependent targets as affected
    private void markDependents(string targetId, ref bool[string] affected) @system
    {
        import config.schema.schema : TargetId;
        auto node = _graph.getNode(TargetId(targetId));
        if (node is null)
            return;
        
        foreach (dependentId; node.dependentIds)
        {
            auto depIdStr = dependentId.toString();
            if (depIdStr !in affected)
            {
                affected[depIdStr] = true;
                markDependents(depIdStr, affected);
            }
        }
    }
}

/// Watch statistics tracker
struct WatchStats
{
    size_t totalBuilds;
    size_t successfulBuilds;
    size_t failedBuilds;
    Duration totalBuildTime;
    Duration averageBuildTime;
    SysTime startTime;
    
    /// Record a build
    void recordBuild(bool success, Duration buildTime) @system
    {
        totalBuilds++;
        if (success)
            successfulBuilds++;
        else
            failedBuilds++;
        
        totalBuildTime += buildTime;
        
        if (totalBuilds > 0)
        {
            averageBuildTime = totalBuildTime / totalBuilds;
        }
    }
    
    /// Print statistics
    void print() const @system
    {
        writeln("\nWatch Mode Statistics:");
        writeln("  Total builds: " ~ totalBuilds.to!string);
        writeln("  Successful: " ~ successfulBuilds.to!string);
        writeln("  Failed: " ~ failedBuilds.to!string);
        writeln("  Average build time: " ~ averageBuildTime.total!"msecs".to!string ~ "ms");
        
        auto uptime = Clock.currTime() - startTime;
        writeln("  Uptime: " ~ uptime.total!"seconds".to!string ~ "s");
    }
}

