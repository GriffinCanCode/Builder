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
import errors;
import cli;

void main(string[] args)
{
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
                initCommand();
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

void printHelp()
{
    writeln("Builder - Smart Build System for Mixed-Language Monorepos\n");
    writeln("Usage:");
    writeln("  builder <command> [options] [target]\n");
    writeln("Commands:");
    writeln("  build [target]    Build all targets or specific target");
    writeln("  clean             Clean build cache");
    writeln("  graph [target]    Show dependency graph");
    writeln("  init              Initialize a new BUILD file\n");
    writeln("Options:");
    writeln("  -v, --verbose     Enable verbose output");
    writeln("  -g, --graph       Show dependency graph during build");
    writeln("  -m, --mode MODE   CLI mode: auto, interactive, plain, verbose, quiet\n");
    writeln("Examples:");
    writeln("  builder build                    # Build all targets");
    writeln("  builder build //path/to:target   # Build specific target");
    writeln("  builder graph //path/to:target   # Show dependencies");
}

void buildCommand(string target, bool showGraph, string modeStr)
{
    Logger.info("Starting build...");
    
    // Parse configuration with error handling
    auto configResult = ConfigParser.parseWorkspace(".");
    if (configResult.isErr)
    {
        Logger.error("Failed to parse workspace configuration");
        import errors.format : format;
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
    RenderMode renderMode = parseRenderMode(modeStr);
    
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

RenderMode parseRenderMode(string mode)
{
    import std.string : toLower;
    switch (mode.toLower)
    {
        case "auto":
            return RenderMode.Auto;
        case "interactive":
            return RenderMode.Interactive;
        case "plain":
            return RenderMode.Plain;
        case "verbose":
            return RenderMode.Verbose;
        case "quiet":
            return RenderMode.Quiet;
        default:
            Logger.warning("Unknown render mode: " ~ mode ~ ", using auto");
            return RenderMode.Auto;
    }
}

void cleanCommand()
{
    Logger.info("Cleaning build cache...");
    
    import std.file : rmdirRecurse, exists;
    
    if (exists(".builder-cache"))
        rmdirRecurse(".builder-cache");
    
    if (exists("bin"))
        rmdirRecurse("bin");
    
    Logger.success("Clean completed!");
}

void graphCommand(string target)
{
    Logger.info("Analyzing dependency graph...");
    
    // Parse configuration with error handling
    auto configResult = ConfigParser.parseWorkspace(".");
    if (configResult.isErr)
    {
        Logger.error("Failed to parse workspace configuration");
        import errors.format : format;
        Logger.error(format(configResult.unwrapErr()));
        import core.stdc.stdlib : exit;
        exit(1);
    }
    
    auto config = configResult.unwrap();
    auto analyzer = new DependencyAnalyzer(config);
    auto graph = analyzer.analyze(target);
    
    graph.print();
}

void initCommand()
{
    Logger.info("Initializing BUILD file...");
    
    import std.file : write, exists;
    
    if (exists("BUILD"))
    {
        Logger.error("BUILD file already exists");
        return;
    }
    
    string template_content = `// BUILD configuration file
// Define your build targets here

import builder.config;

// Example library target
target("my-lib",
    type: TargetType.Library,
    sources: ["src/**/*.d"],
    deps: []
);

// Example executable target
target("my-app",
    type: TargetType.Executable,
    sources: ["app.d"],
    deps: [":my-lib"]
);
`;
    
    write("BUILD", template_content);
    Logger.success("Created BUILD file");
}

