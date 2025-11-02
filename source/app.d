import std.stdio;
import std.getopt;
import std.algorithm;
import std.array;
import std.conv;
import core.graph.graph;
import core.execution.engine;
import core.services;
import core.shutdown;
import core.telemetry;
import config.parsing.parser;
import analysis.inference.analyzer;
import utils.logging.logger;
import utils.simd;
import errors;
import cli;
import cli.commands;
import tools;

enum VERSION = "1.0.0";

void main(string[] args)
{
    // Initialize shutdown coordinator for explicit cleanup
    auto shutdownGuard = ShutdownGuard.create();
    scope(exit) ShutdownCoordinator.instance().shutdown();
    
    // Install signal handlers for graceful shutdown on SIGINT/SIGTERM
    installSignalHandlers();
    
    // SIMD now auto-initializes on first use (see utils.simd.dispatch)
    Logger.initialize();
    
    string command = "build";
    string target = "";
    bool verbose = false;
    bool showGraph = false;
    bool showVersion = false;
    string mode = "auto"; // CLI render mode
    
    auto helpInfo = getopt(
        args,
        "verbose|v", "Enable verbose output", &verbose,
        "graph|g", "Show dependency graph", &showGraph,
        "mode|m", "CLI mode: auto, interactive, plain, verbose, quiet", &mode,
        "version", "Show version information", &showVersion
    );
    
    if (showVersion)
    {
        writeln("Builder version ", VERSION);
        writeln("High-performance build system for mixed-language monorepos");
        return;
    }
    
    if (helpInfo.helpWanted || args.length < 2)
    {
        HelpCommand.execute();
        return;
    }
    
    command = args[1];
    if (args.length > 2)
        target = args[2];
    
    Logger.setVerbose(verbose);
    
    try
    {
        switch (command)
        {
            case "build":
                buildCommand(target, showGraph, mode);
                break;
            case "clean":
                cleanCommand();
                break;
            case "graph":
                graphCommand(target);
                break;
            case "init":
                InitCommand.execute();
                break;
            case "infer":
                InferCommand.execute();
                break;
            case "wizard":
                WizardCommand.execute();
                break;
            case "resume":
                resumeCommand(mode);
                break;
            case "install-extension":
                installExtensionCommand();
                break;
            case "query":
                if (args.length < 3)
                {
                    Logger.error("Query expression required");
                    Logger.info("Usage: builder query '<expression>'");
                    Logger.info("Example: builder query 'deps(//...)'");
                }
                else
                {
                    QueryCommand.execute(args[2]);
                }
                break;
            case "telemetry":
                auto subcommand = args.length > 2 ? args[2] : "summary";
                TelemetryCommand.execute(subcommand);
                break;
            case "help":
                auto helpCommand = args.length > 2 ? args[2] : "";
                HelpCommand.execute(helpCommand);
                break;
            case "version":
                writeln("Builder version ", VERSION);
                writeln("High-performance build system for mixed-language monorepos");
                break;
            default:
                Logger.error("Unknown command: " ~ command);
                HelpCommand.execute();
        }
    }
    catch (Exception e)
    {
        Logger.error("Build failed: " ~ e.msg);
        import core.stdc.stdlib : exit;
        exit(1);
    }
}

/// Build command handler (refactored to use dependency injection)
void buildCommand(in string target, in bool showGraph, in string modeStr) @system
{
    Logger.info("Starting build...");
    
    // Parse configuration with error handling
    auto configResult = ConfigParser.parseWorkspace(".");
    if (configResult.isErr)
    {
        Logger.error("Failed to parse workspace configuration");
        import errors.formatting.format : format;
        Logger.error(format(configResult.unwrapErr()));
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    auto config = configResult.unwrap();
    Logger.info("Found " ~ config.targets.length.to!string ~ " targets");
    
    // Create services with dependency injection
    auto services = new BuildServices(config, config.options);
    
    // Register cache for explicit cleanup
    auto coordinator = ShutdownCoordinator.instance();
    coordinator.registerCache(services.cache);
    
    // Set render mode
    immutable renderMode = parseRenderMode(modeStr);
    services.setRenderMode(renderMode);
    auto renderer = services.getRenderer();
    
    // Analyze dependencies
    auto graphResult = services.analyzer.analyze(target);
    if (graphResult.isErr)
    {
        Logger.error("Failed to analyze dependencies");
        import errors.formatting.format : format;
        Logger.error(format(graphResult.unwrapErr()));
        import core.stdc.stdlib : exit;
        exit(1);
    }
    auto graph = graphResult.unwrap();
    
    if (showGraph)
    {
        Logger.info("\nDependency Graph:");
        graph.print();
    }
    
    // Execute build with modern service-based architecture
    auto engine = services.createEngine(graph);
    bool success = engine.execute();
    engine.shutdown();
    
    // Cleanup and persist telemetry
    services.shutdown();
    
    // Report final status
    if (success)
    {
        Logger.success("Build completed successfully!");
    }
    else
    {
        Logger.error("Build failed!");
        import core.stdc.stdlib : exit;
        exit(1);
    }
}

RenderMode parseRenderMode(in string mode) @system pure
{
    import std.string : toLower;
    import std.uni : sicmp;
    
    if (sicmp(mode, "auto") == 0)
        return RenderMode.Auto;
    else if (sicmp(mode, "interactive") == 0)
        return RenderMode.Interactive;
    else if (sicmp(mode, "plain") == 0)
        return RenderMode.Plain;
    else if (sicmp(mode, "verbose") == 0)
        return RenderMode.Verbose;
    else if (sicmp(mode, "quiet") == 0)
        return RenderMode.Quiet;
    else
        return RenderMode.Auto; // Default fallback
}

/// Clean command handler - removes build artifacts and cache
/// 
/// Safety: This function is @system because:
/// 1. exists() and rmdirRecurse() are file system operations (inherently @system)
/// 2. Hardcoded directory names prevent path traversal
/// 3. Checks existence before attempting deletion
/// 4. rmdirRecurse is safe for non-existent paths
/// 
/// Invariants:
/// - Only removes .builder-cache and bin directories
/// - No user-provided paths (prevents injection)
/// - Existence checked before deletion
/// 
/// What could go wrong:
/// - Permission denied: exception thrown (safe failure)
/// - Directory in use: exception thrown (safe failure)
/// - Hardcoded paths ensure no accidental deletion of user data
void cleanCommand() @system
{
    Logger.info("Cleaning build cache...");
    
    import std.file : rmdirRecurse, exists;
    
    if (exists(".builder-cache"))
        rmdirRecurse(".builder-cache");
    
    if (exists("bin"))
        rmdirRecurse("bin");
    
    Logger.success("Clean completed!");
}

/// Graph command handler - visualizes dependency graph (refactored with DI)
void graphCommand(in string target) @system
{
    import core.stdc.signal : signal, SIGSEGV, SIGABRT;
    import core.stdc.stdlib : exit;
    
    Logger.info("Analyzing dependency graph...");
    
    try
    {
        // Parse configuration with error handling
        auto configResult = ConfigParser.parseWorkspace(".");
        if (configResult.isErr)
        {
            Logger.error("Failed to parse workspace configuration");
            import errors.formatting.format : format;
            Logger.error(format(configResult.unwrapErr()));
            exit(1);
        }
        
        auto config = configResult.unwrap();
        
        // Validate configuration has targets
        if (config.targets.length == 0)
        {
            Logger.warning("No targets found in workspace configuration");
            return;
        }
        
        // Create services (lightweight for analysis-only operation)
        auto services = new BuildServices(config, config.options);
        
        // Register cache for explicit cleanup
        auto coordinator = ShutdownCoordinator.instance();
        coordinator.registerCache(services.cache);
        
        // Analyze with error recovery
        auto graphResult = services.analyzer.analyze(target);
        if (graphResult.isErr)
        {
            Logger.error("Failed to analyze dependencies: " ~ format(graphResult.unwrapErr()));
            import core.stdc.stdlib : exit;
            exit(1);
        }
        auto graph = graphResult.unwrap();
        
        // Print with error handling
        graph.print();
    }
    catch (Exception e)
    {
        Logger.error("Fatal error during graph analysis: " ~ e.msg);
        Logger.error("Stack trace:");
        Logger.error(e.toString());
        Logger.error("\nThis is a bug in Builder. Please report it at:");
        Logger.error("https://github.com/your-org/builder/issues");
        exit(1);
    }
    catch (Error e)
    {
        Logger.error("Critical error (segfault/assertion failure): " ~ e.msg);
        Logger.error("Stack trace:");
        Logger.error(e.toString());
        Logger.error("\nThis is a critical bug in Builder. Please report it at:");
        Logger.error("https://github.com/your-org/builder/issues");
        exit(139); // SIGSEGV exit code
    }
}

/// Resume command handler - continues build from checkpoint (refactored with DI)
void resumeCommand(in string modeStr) @system
{
    import core.execution.checkpoint : CheckpointManager;
    import core.execution.resume : ResumePlanner, ResumeConfig;
    
    Logger.info("Checking for build checkpoint...");
    
    auto checkpointManager = new CheckpointManager(".", true);
    
    if (!checkpointManager.exists())
    {
        Logger.error("No checkpoint found. Run 'builder build' first.");
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    auto checkpointResult = checkpointManager.load();
    if (checkpointResult.isErr)
    {
        Logger.error("Failed to load checkpoint: " ~ checkpointResult.unwrapErr());
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    auto checkpoint = checkpointResult.unwrap();
    Logger.info("Found checkpoint from " ~ checkpoint.timestamp.toSimpleString());
    Logger.info("Progress: " ~ checkpoint.completedTargets.to!string ~ "/" ~ 
               checkpoint.totalTargets.to!string ~ " targets (" ~ 
               checkpoint.completion().to!string[0..min(5, checkpoint.completion().to!string.length)] ~ "%)");
    
    if (checkpoint.failedTargets > 0)
    {
        Logger.info("Failed targets:");
        foreach (target; checkpoint.failedTargetIds)
            Logger.error("  - " ~ target);
    }
    
    writeln();
    
    // Parse configuration
    auto configResult = ConfigParser.parseWorkspace(".");
    if (configResult.isErr)
    {
        Logger.error("Failed to parse workspace configuration");
        import errors.formatting.format : format;
        Logger.error(format(configResult.unwrapErr()));
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    auto config = configResult.unwrap();
    
    // Create services with dependency injection
    auto services = new BuildServices(config, config.options);
    
    // Register cache for explicit cleanup
    auto coordinator = ShutdownCoordinator.instance();
    coordinator.registerCache(services.cache);
    
    // Set render mode
    immutable renderMode = parseRenderMode(modeStr);
    services.setRenderMode(renderMode);
    auto renderer = services.getRenderer();
    
    // Rebuild graph
        auto graphResult = services.analyzer.analyze("");
        if (graphResult.isErr)
        {
            Logger.error("Failed to analyze dependencies: " ~ format(graphResult.unwrapErr()));
            import core.stdc.stdlib : exit;
            exit(1);
        }
        auto graph = graphResult.unwrap();
    
    // Validate checkpoint
    if (!checkpoint.isValid(graph))
    {
        Logger.error("Checkpoint invalid for current project state. Run 'builder clean' and rebuild.");
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    Logger.info("Resuming build...");
    
    // Execute build with modern service-based architecture
    auto engine = services.createEngine(graph);
    engine.execute();
    engine.shutdown();
    
    // Cleanup and persist telemetry
    services.shutdown();
    
    Logger.success("Build resumed and completed successfully!");
}

/// Install VS Code extension command
/// 
/// Safety: This function is @system because:
/// 1. VSCodeExtension.install() performs validated file I/O
/// 2. Extension installation uses verified paths
/// 3. Process execution for VS Code CLI is validated
/// 4. Installation is handled atomically by VSCodeExtension
/// 
/// Invariants:
/// - Extension files are verified before installation
/// - VS Code presence is detected before attempting install
/// - Installation errors are reported via exceptions
/// 
/// What could go wrong:
/// - VS Code not installed: detected by VSCodeExtension
/// - Permission denied: exception thrown and caught
/// - Extension files missing: validated before install
void installExtensionCommand() @system
{
    VSCodeExtension.install();
}

