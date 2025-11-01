module cli.commands.help;

import std.stdio;
import std.string : toLower;
import utils.logging.logger;

/// Help command - provides detailed documentation for Builder commands
struct HelpCommand
{
    /// Execute the help command
    static void execute(string command = "")
    {
        if (command.length == 0)
        {
            showGeneralHelp();
        }
        else
        {
            showCommandHelp(command.toLower());
        }
    }
    
    /// Show general help overview
    private static void showGeneralHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                    Builder - Mixed-Language Build System                 ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("Builder is a modern, zero-configuration build system that automatically");
        writeln("detects and builds projects in multiple languages with intelligent");
        writeln("dependency management and caching.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder <command> [options] [arguments]");
        writeln();
        
        writeln("CORE COMMANDS:");
        writeln("  build [target]        Build all targets or a specific target");
        writeln("  resume                Resume a failed build from checkpoint");
        writeln("  clean                 Remove build artifacts and cache");
        writeln("  graph [target]        Visualize dependency graph");
        writeln("  query <expression>    Query targets and dependencies");
        writeln();
        
        writeln("PROJECT SETUP:");
        writeln("  init                  Initialize Builderfile with auto-detection");
        writeln("  infer                 Preview auto-detected targets (dry-run)");
        writeln();
        
        writeln("MONITORING & TOOLS:");
        writeln("  telemetry             View build analytics and performance insights");
        writeln("  install-extension     Install Builder VS Code extension");
        writeln();
        
        writeln("INFORMATION:");
        writeln("  help [command]        Show detailed help for a command");
        writeln();
        
        writeln("GLOBAL OPTIONS:");
        writeln("  -v, --verbose         Enable verbose output");
        writeln("  -g, --graph           Show dependency graph during build");
        writeln("  -m, --mode <MODE>     CLI mode: auto, interactive, plain, verbose, quiet");
        writeln();
        
        writeln("ZERO-CONFIG MODE:");
        writeln("  Builder can automatically detect and build projects without a Builderfile.");
        writeln("  Simply run 'builder build' in any supported project directory!");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder build                    # Auto-detect and build all targets");
        writeln("  builder init                     # Create Builderfile from project structure");
        writeln("  builder build //path/to:target   # Build specific target");
        writeln("  builder graph                    # Show complete dependency graph");
        writeln("  builder telemetry                # View build performance analytics");
        writeln("  builder help build               # Show detailed help for build command");
        writeln();
        
        writeln("For detailed help on any command, run:");
        writeln("  builder help <command>");
        writeln();
        
        writeln("SUPPORTED LANGUAGES:");
        writeln("  Compiled:   C, C++, D, Zig, Rust, Go, Nim");
        writeln("  JVM:        Java, Kotlin, Scala, Groovy, Clojure");
        writeln("  .NET:       C#, F#, VB.NET");
        writeln("  Scripting:  Python, Ruby, Perl, PHP, Lua, R");
        writeln("  Web:        JavaScript, TypeScript, React, Vue, Angular");
        writeln();
        
        writeln("DOCUMENTATION:");
        writeln("  README:     See README.md for getting started");
        writeln("  Docs:       Check docs/ directory for comprehensive guides");
        writeln("  Examples:   Explore examples/ directory for sample projects");
        writeln();
    }
    
    /// Show help for a specific command
    private static void showCommandHelp(string command)
    {
        switch (command)
        {
            case "build":
                showBuildHelp();
                break;
            case "resume":
                showResumeHelp();
                break;
            case "clean":
                showCleanHelp();
                break;
            case "graph":
                showGraphHelp();
                break;
            case "query":
                showQueryHelp();
                break;
            case "init":
                showInitHelp();
                break;
            case "infer":
                showInferHelp();
                break;
            case "telemetry":
                showTelemetryHelp();
                break;
            case "install-extension":
                showInstallExtensionHelp();
                break;
            case "help":
                showHelpHelp();
                break;
            default:
                Logger.error("Unknown command: " ~ command);
                writeln("Run 'builder help' to see available commands.");
        }
    }
    
    private static void showBuildHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                           builder build [target]                          ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Build all targets in the workspace or a specific target. Builder");
        writeln("  automatically detects project structure and builds without configuration.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder build [options] [target]");
        writeln();
        
        writeln("OPTIONS:");
        writeln("  -v, --verbose         Show detailed build output");
        writeln("  -g, --graph           Display dependency graph before building");
        writeln("  -m, --mode <MODE>     Set CLI rendering mode");
        writeln();
        
        writeln("RENDER MODES:");
        writeln("  auto                  Auto-detect best mode (default)");
        writeln("  interactive           Rich, real-time progress display");
        writeln("  plain                 Simple text output for CI/CD");
        writeln("  verbose               Detailed output with all commands");
        writeln("  quiet                 Minimal output (errors only)");
        writeln();
        
        writeln("TARGET SYNTAX:");
        writeln("  //path/to:target      Absolute target reference");
        writeln("  :target               Target in current directory");
        writeln("  //path/to:*           All targets in directory");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder build                    # Build all targets");
        writeln("  builder build -v                 # Build with verbose output");
        writeln("  builder build --graph            # Show graph, then build");
        writeln("  builder build //src:myapp        # Build specific target");
        writeln("  builder build -m plain           # Use plain mode for CI");
        writeln("  builder build -m interactive     # Rich interactive mode");
        writeln();
        
        writeln("ZERO-CONFIG:");
        writeln("  If no Builderfile exists, Builder will:");
        writeln("  1. Scan the project directory");
        writeln("  2. Detect languages and frameworks");
        writeln("  3. Infer build targets automatically");
        writeln("  4. Build without any configuration!");
        writeln();
        
        writeln("FEATURES:");
        writeln("  • Parallel builds with intelligent scheduling");
        writeln("  • BLAKE3-based content hashing for fast caching");
        writeln("  • Automatic checkpoint creation for recovery");
        writeln("  • Build telemetry and performance tracking");
        writeln("  • Multi-language and mixed-language projects");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder resume        Resume from checkpoint");
        writeln("  builder graph         Visualize dependencies");
        writeln("  builder telemetry     View build analytics");
        writeln();
    }
    
    private static void showResumeHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                             builder resume                                ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Resume a failed build from the last checkpoint. Builder automatically");
        writeln("  saves checkpoints during builds, allowing you to continue from where");
        writeln("  a build failed without rebuilding already-completed targets.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder resume [options]");
        writeln();
        
        writeln("OPTIONS:");
        writeln("  -m, --mode <MODE>     Set CLI rendering mode");
        writeln();
        
        writeln("HOW IT WORKS:");
        writeln("  1. Builder saves a checkpoint after each successful target build");
        writeln("  2. If a build fails, the checkpoint is preserved");
        writeln("  3. 'builder resume' loads the checkpoint and continues from there");
        writeln("  4. Completed targets are skipped automatically");
        writeln();
        
        writeln("CHECKPOINT VALIDATION:");
        writeln("  Builder validates that:");
        writeln("  • Project structure hasn't changed significantly");
        writeln("  • Target dependencies remain the same");
        writeln("  • Checkpoint is compatible with current configuration");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder resume                   # Resume last failed build");
        writeln("  builder resume -m verbose        # Resume with detailed output");
        writeln();
        
        writeln("NOTES:");
        writeln("  • Checkpoints are stored in .builder-cache/");
        writeln("  • Use 'builder clean' to remove checkpoints");
        writeln("  • Checkpoints are automatically invalidated when dependencies change");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder build         Start a new build");
        writeln("  builder clean         Remove cache and checkpoints");
        writeln();
    }
    
    private static void showCleanHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                             builder clean                                 ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Remove all build artifacts, cache files, and checkpoints. This forces");
        writeln("  a complete rebuild on the next build command.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder clean");
        writeln();
        
        writeln("WHAT GETS REMOVED:");
        writeln("  .builder-cache/       Build cache and checkpoints");
        writeln("  bin/                  Compiled binaries and artifacts");
        writeln();
        
        writeln("WHEN TO USE:");
        writeln("  • After major project restructuring");
        writeln("  • To free up disk space");
        writeln("  • When cache appears corrupted");
        writeln("  • To force complete rebuild");
        writeln("  • When checkpoint validation fails");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder clean                    # Clean everything");
        writeln("  builder clean && builder build   # Clean then rebuild");
        writeln();
        
        writeln("NOTES:");
        writeln("  • Source files are never touched");
        writeln("  • Telemetry data is preserved");
        writeln("  • Operation cannot be undone");
        writeln();
    }
    
    private static void showGraphHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                           builder graph [target]                          ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Visualize the dependency graph for all targets or a specific target.");
        writeln("  Shows build order, dependencies, and target relationships.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder graph [target]");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder graph                    # Show complete dependency graph");
        writeln("  builder graph //src:myapp        # Show dependencies for specific target");
        writeln("  builder graph :lib               # Show dependencies for local target");
        writeln();
        
        writeln("GRAPH OUTPUT INCLUDES:");
        writeln("  • Target names and types");
        writeln("  • Dependency relationships");
        writeln("  • Build order (topological sort)");
        writeln("  • Parallel build opportunities");
        writeln();
        
        writeln("USE CASES:");
        writeln("  • Understanding project structure");
        writeln("  • Debugging build issues");
        writeln("  • Identifying circular dependencies");
        writeln("  • Planning incremental builds");
        writeln("  • Optimizing build parallelization");
        writeln();
        
        writeln("NOTES:");
        writeln("  • Graph generation is fast and doesn't build anything");
        writeln("  • Works with both Builderfile and zero-config projects");
        writeln("  • Can be combined with build: 'builder build --graph'");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder build --graph    Show graph before building");
        writeln("  builder infer            Preview auto-detected targets");
        writeln("  builder query            Query targets and dependencies");
        writeln();
    }
    
    private static void showQueryHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                        builder query <expression>                         ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Execute powerful graph queries to explore target relationships,");
        writeln("  dependencies, and project structure. Similar to Bazel query.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder query '<expression>'");
        writeln();
        
        writeln("QUERY SYNTAX:");
        writeln("  //...                    All targets in the workspace");
        writeln("  //path/...               All targets under path");
        writeln("  //path:target            Specific target");
        writeln("  //path:*                 All targets in directory");
        writeln();
        writeln("  deps(expr)               Direct dependencies of expr");
        writeln("  deps(expr, depth)        Dependencies up to depth levels");
        writeln("  rdeps(expr)              Reverse deps (what depends on expr)");
        writeln("  allpaths(from, to)       All paths between two targets");
        writeln("  kind(type, expr)         Filter by target type");
        writeln("  attr(name, value, expr)  Filter by attribute");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder query '//...'");
        writeln("    # List all targets");
        writeln();
        writeln("  builder query 'deps(//src:app)'");
        writeln("    # Show all dependencies of //src:app");
        writeln();
        writeln("  builder query 'deps(//src:app, 1)'");
        writeln("    # Show only direct dependencies");
        writeln();
        writeln("  builder query 'rdeps(//lib:utils)'");
        writeln("    # Show what depends on //lib:utils");
        writeln();
        writeln("  builder query 'kind(binary, //...)'");
        writeln("    # Find all binary targets");
        writeln();
        writeln("  builder query 'allpaths(//src:app, //lib:core)'");
        writeln("    # Show all dependency paths from app to core");
        writeln();
        
        writeln("TARGET TYPES:");
        writeln("  binary, library, test, custom, and language-specific types");
        writeln();
        
        writeln("USE CASES:");
        writeln("  • Explore dependency relationships");
        writeln("  • Find unused targets (no rdeps)");
        writeln("  • Identify build bottlenecks");
        writeln("  • Analyze impact of changes");
        writeln("  • Audit target types and structure");
        writeln("  • Debug circular dependencies");
        writeln();
        
        writeln("NOTES:");
        writeln("  • Query expressions should be quoted in shell");
        writeln("  • Queries are fast - only analyze graph, don't build");
        writeln("  • Works with both Builderfile and zero-config projects");
        writeln("  • Results are sorted alphabetically");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder graph            Visualize full dependency graph");
        writeln("  builder infer            Preview auto-detected targets");
        writeln();
    }
    
    private static void showInitHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                              builder init                                 ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Initialize a new Builder project by creating a Builderfile, Builderspace,");
        writeln("  and .builderignore based on automatic project detection.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder init [options]");
        writeln();
        
        writeln("GENERATED FILES:");
        writeln("  Builderfile           Build configuration with detected targets");
        writeln("  Builderspace          Workspace-level configuration");
        writeln("  .builderignore        Patterns to exclude from scanning");
        writeln();
        
        writeln("DETECTION FEATURES:");
        writeln("  • Automatic language detection (20+ languages)");
        writeln("  • Framework detection (React, Vue, Spring Boot, etc.)");
        writeln("  • Manifest file parsing (package.json, Cargo.toml, etc.)");
        writeln("  • Dependency inference");
        writeln("  • Project structure analysis");
        writeln();
        
        writeln("WHAT HAPPENS:");
        writeln("  1. Scans project directory recursively");
        writeln("  2. Detects languages and confidence levels");
        writeln("  3. Identifies frameworks and tools");
        writeln("  4. Generates appropriate build targets");
        writeln("  5. Creates .builderignore with language-specific patterns");
        writeln("  6. Shows preview of generated files");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder init                     # Initialize in current directory");
        writeln("  cd my-project && builder init    # Initialize in specific directory");
        writeln();
        
        writeln("AFTER INITIALIZATION:");
        writeln("  1. Review and customize the generated Builderfile");
        writeln("  2. Adjust .builderignore if needed");
        writeln("  3. Run 'builder build' to build your project");
        writeln();
        
        writeln("NOTES:");
        writeln("  • Existing files are not overwritten");
        writeln("  • Use --force flag to overwrite (if implemented)");
        writeln("  • Generated files are meant to be edited");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder infer         Preview detection without creating files");
        writeln("  builder build         Build after initialization");
        writeln();
    }
    
    private static void showInferHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                             builder infer                                 ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Preview what targets would be automatically detected and inferred from");
        writeln("  your project structure without creating any files. This is a dry-run");
        writeln("  of Builder's zero-config detection system.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder infer");
        writeln();
        
        writeln("OUTPUT SHOWS:");
        writeln("  • Detected target names and types");
        writeln("  • Programming languages");
        writeln("  • Source files for each target");
        writeln("  • Language-specific configuration");
        writeln("  • Build commands that would be used");
        writeln();
        
        writeln("USE CASES:");
        writeln("  • Verify Builder can detect your project");
        writeln("  • See what targets would be created");
        writeln("  • Compare detection with manual Builderfile");
        writeln("  • Debug detection issues");
        writeln("  • Understand zero-config behavior");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder infer                    # Show inferred targets");
        writeln("  builder infer > targets.txt      # Save to file");
        writeln();
        
        writeln("NEXT STEPS:");
        writeln("  builder build         Build using auto-detected targets");
        writeln("  builder init          Create Builderfile from inference");
        writeln();
        
        writeln("NOTES:");
        writeln("  • No files are created or modified");
        writeln("  • Results show what 'builder build' would use");
        writeln("  • Helps verify project is compatible with zero-config");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder init          Generate Builderfile from detection");
        writeln("  builder build         Build using zero-config");
        writeln();
    }
    
    private static void showTelemetryHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                          builder telemetry [cmd]                          ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  View build analytics, performance insights, and telemetry data collected");
        writeln("  during builds. Helps identify bottlenecks and track build performance");
        writeln("  over time.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder telemetry [subcommand]");
        writeln();
        
        writeln("SUBCOMMANDS:");
        writeln("  summary               Comprehensive analytics report (default)");
        writeln("  recent [n]            Show last n builds (default: 10)");
        writeln("  export                Export data as JSON");
        writeln("  clear                 Remove all telemetry data");
        writeln();
        
        writeln("SUMMARY METRICS:");
        writeln("  • Total builds and success rate");
        writeln("  • Average build duration");
        writeln("  • Cache hit rates");
        writeln("  • Slowest targets and bottlenecks");
        writeln("  • Performance trends");
        writeln("  • Regression detection");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder telemetry                # Show summary");
        writeln("  builder telemetry recent 20      # Show last 20 builds");
        writeln("  builder telemetry export > data.json");
        writeln("  builder telemetry clear          # Remove all data");
        writeln();
        
        writeln("DATA COLLECTION:");
        writeln("  • Build duration and timestamps");
        writeln("  • Target execution times");
        writeln("  • Cache hit/miss statistics");
        writeln("  • Success/failure rates");
        writeln("  • System resource usage");
        writeln();
        
        writeln("PRIVACY:");
        writeln("  • All data stored locally in .builder-cache/telemetry/");
        writeln("  • No data sent to external servers");
        writeln("  • Can be disabled in workspace configuration");
        writeln();
        
        writeln("USE CASES:");
        writeln("  • Identify build bottlenecks");
        writeln("  • Track build performance over time");
        writeln("  • Detect performance regressions");
        writeln("  • Optimize build configurations");
        writeln("  • Generate build reports for CI/CD");
        writeln();
        
        writeln("SEE ALSO:");
        writeln("  builder build         Builds collect telemetry data");
        writeln("  builder clean         Does NOT clear telemetry");
        writeln();
    }
    
    private static void showInstallExtensionHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                      builder install-extension                            ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Install the Builder VS Code extension for syntax highlighting,");
        writeln("  autocompletion, and other IDE features for Builderfile editing.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder install-extension");
        writeln();
        
        writeln("FEATURES:");
        writeln("  • Syntax highlighting for Builderfile and Builderspace");
        writeln("  • Code completion for target types and commands");
        writeln("  • Validation and error checking");
        writeln("  • Snippets for common patterns");
        writeln("  • Documentation on hover");
        writeln();
        
        writeln("REQUIREMENTS:");
        writeln("  • Visual Studio Code must be installed");
        writeln("  • 'code' command must be available in PATH");
        writeln();
        
        writeln("WHAT IT DOES:");
        writeln("  1. Locates the Builder extension package");
        writeln("  2. Verifies VS Code installation");
        writeln("  3. Installs extension using VS Code CLI");
        writeln("  4. Confirms successful installation");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder install-extension        # Install VS Code extension");
        writeln();
        
        writeln("MANUAL INSTALLATION:");
        writeln("  If automatic installation fails:");
        writeln("  1. Locate tools/vscode/builder-lang-*.vsix");
        writeln("  2. Open VS Code");
        writeln("  3. Go to Extensions view");
        writeln("  4. Click '...' menu → Install from VSIX");
        writeln("  5. Select the .vsix file");
        writeln();
        
        writeln("NOTES:");
        writeln("  • Requires VS Code 1.60.0 or higher");
        writeln("  • Extension updates must be installed manually");
        writeln();
    }
    
    private static void showHelpHelp()
    {
        writeln();
        writeln("╔══════════════════════════════════════════════════════════════════════════╗");
        writeln("║                          builder help [command]                           ║");
        writeln("╚══════════════════════════════════════════════════════════════════════════╝");
        writeln();
        writeln("DESCRIPTION:");
        writeln("  Display help information for Builder commands.");
        writeln();
        
        writeln("USAGE:");
        writeln("  builder help [command]");
        writeln();
        
        writeln("EXAMPLES:");
        writeln("  builder help                     # Show general help");
        writeln("  builder help build               # Help for build command");
        writeln("  builder help telemetry           # Help for telemetry command");
        writeln();
        
        writeln("AVAILABLE COMMANDS:");
        writeln("  build, resume, clean, graph, query, init, infer, telemetry,");
        writeln("  install-extension, help");
        writeln();
    }
}

