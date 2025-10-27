import std.stdio;
import std.getopt;
import std.algorithm;
import std.array;
import std.conv;
import core.graph.graph;
import core.execution.executor;
import config.parsing.parser;
import analysis.inference.analyzer;
import utils.logging.logger;
import utils.simd;
import errors;
import cli;
import cli.commands;
import tools;

/// Initialize SIMD acceleration system
void initializeSIMD() @trusted
{
    SIMDDispatch.initialize();
    
    version(Verbose) {
        Logger.debug_("SIMD initialized: " ~ CPU.simdLevelName());
    }
}

void main(string[] args)
{
    // Initialize SIMD dispatch system
    initializeSIMD();
    
    Logger.initialize();
    
    string command = "build";
    string target = "";
    bool verbose = false;
    bool showGraph = false;
    string mode = "auto"; // CLI render mode
    
    auto helpInfo = getopt(
        args,
        "verbose|v", "Enable verbose output", &verbose,
        "graph|g", "Show dependency graph", &showGraph,
        "mode|m", "CLI mode: auto, interactive, plain, verbose, quiet", &mode
    );
    
    if (helpInfo.helpWanted || args.length < 2)
    {
        printHelp();
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
            case "resume":
                resumeCommand(mode);
                break;
            case "install-extension":
                installExtensionCommand();
                break;
            default:
                Logger.error("Unknown command: " ~ command);
                printHelp();
        }
    }
    catch (Exception e)
    {
        Logger.error("Build failed: " ~ e.msg);
        import core.stdc.stdlib : exit;
        exit(1);
    }
}

void printHelp() @safe
{
    writeln("Builder - Build System for Mixed-Language Projects\n");
    writeln("Usage:");
    writeln("  builder <command> [options] [target]\n");
    writeln("Commands:");
    writeln("  build [target]    Build all targets or specific target (zero-config supported!)");
    writeln("  resume            Resume failed build from checkpoint");
    writeln("  clean             Clean build cache (includes checkpoints)");
    writeln("  graph [target]    Show dependency graph");
    writeln("  init              Initialize a new Builderfile with auto-detection");
    writeln("  infer             Show what targets would be auto-detected (dry-run)");
    writeln("  install-extension Install Builder VS Code extension\n");
    writeln("Options:");
    writeln("  -v, --verbose     Enable verbose output");
    writeln("  -g, --graph       Show dependency graph during build");
    writeln("  -m, --mode MODE   CLI mode: auto, interactive, plain, verbose, quiet\n");
    writeln("Zero-Config:");
    writeln("  Builder can automatically detect project structure and build without");
    writeln("  a Builderfile. Simply run 'builder build' in any supported project!\n");
    writeln("Examples:");
    writeln("  builder build                    # Build all targets (auto-detects if no Builderfile)");
    writeln("  builder infer                    # Preview what would be auto-detected");
    writeln("  builder init                     # Create Builderfile based on project structure");
    writeln("  builder build //path/to:target   # Build specific target");
    writeln("  builder graph //path/to:target   # Show dependencies");
}

void buildCommand(in string target, in bool showGraph, in string modeStr) @trusted
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
    
    // Analyze dependencies
    auto analyzer = new DependencyAnalyzer(config);
    auto graph = analyzer.analyze(target);
    
    if (showGraph)
    {
        Logger.info("\nDependency Graph:");
        graph.print();
    }
    
    // Determine render mode
    immutable renderMode = parseRenderMode(modeStr);
    
    // Create event publisher and renderer
    auto publisher = new SimpleEventPublisher();
    auto renderer = RendererFactory.createWithPublisher(publisher, renderMode);
    
    // Execute build with event publishing
    auto executor = new BuildExecutor(graph, config, 0, publisher);
    executor.execute();
    executor.shutdown();
    
    // Flush any remaining output
    renderer.flush();
    
    Logger.success("Build completed successfully!");
}

RenderMode parseRenderMode(in string mode) @safe pure
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

void cleanCommand() @trusted
{
    Logger.info("Cleaning build cache...");
    
    import std.file : rmdirRecurse, exists;
    
    if (exists(".builder-cache"))
        rmdirRecurse(".builder-cache");
    
    if (exists("bin"))
        rmdirRecurse("bin");
    
    Logger.success("Clean completed!");
}

void graphCommand(in string target) @trusted
{
    Logger.info("Analyzing dependency graph...");
    
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
    auto analyzer = new DependencyAnalyzer(config);
    auto graph = analyzer.analyze(target);
    
    graph.print();
}

void resumeCommand(in string modeStr) @trusted
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
    
    // Rebuild graph
    auto analyzer = new DependencyAnalyzer(config);
    auto graph = analyzer.analyze("");
    
    // Validate checkpoint
    if (!checkpoint.isValid(graph))
    {
        Logger.error("Checkpoint invalid for current project state. Run 'builder clean' and rebuild.");
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    Logger.info("Resuming build...");
    
    // Determine render mode
    immutable renderMode = parseRenderMode(modeStr);
    
    // Create event publisher and renderer
    auto publisher = new SimpleEventPublisher();
    auto renderer = RendererFactory.createWithPublisher(publisher, renderMode);
    
    // Execute build with checkpoint resume
    auto executor = new BuildExecutor(graph, config, 0, publisher);
    executor.execute();
    executor.shutdown();
    
    // Flush any remaining output
    renderer.flush();
    
    Logger.success("Build resumed and completed successfully!");
}

void installExtensionCommand() @trusted
{
    VSCodeExtension.install();
}

