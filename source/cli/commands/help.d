module cli.commands.help;

import std.stdio;
import std.string : toLower;
import utils.logging.logger;
import cli.control.terminal;
import cli.display.format;
import cli.commands.watch : WatchCommand;
import languages.registry : LanguageCategory, getLanguageCategoryList;

/// Help command - provides detailed documentation for Builder commands
struct HelpCommand
{
    private static Terminal terminal;
    private static Formatter formatter;
    private static bool initialized = false;
    
    /// Initialize terminal and formatter
    private static void init()
    {
        if (!initialized)
        {
            auto caps = Capabilities.detect();
            terminal = Terminal(caps);
            formatter = Formatter(caps);
            initialized = true;
        }
    }
    
    /// Execute the help command
    static void execute(string command = "")
    {
        init();
        
        if (command.length == 0)
        {
            showGeneralHelp();
        }
        else
        {
            showCommandHelp(command.toLower());
        }
        
        terminal.flush();
    }
    
    /// Show general help overview
    private static void showGeneralHelp()
    {
        terminal.writeln();
        
        // Title box
        string[] titleContent = [
            "Builder is a modern, zero-configuration build system that automatically",
            "detects and builds projects in multiple languages with intelligent",
            "dependency management and caching."
        ];
        terminal.writeln(formatter.formatBox("Builder - Mixed-Language Build System", titleContent));
        terminal.writeln();
        
        // Usage section
        printSectionHeader("USAGE");
        terminal.writeColored("  builder", Color.Cyan, Style.Bold);
        terminal.write(" <command> [options] [arguments]");
        terminal.writeln();
        terminal.writeln();
        
        // Core commands
        printSectionHeader("CORE COMMANDS");
        printCommand("build", "[target]", "Build all targets or a specific target");
        printCommand("test", "[target]", "Run test targets with reporting");
        printCommand("watch", "[target]", "Watch for changes and rebuild automatically");
        printCommand("resume", "", "Resume a failed build from checkpoint");
        printCommand("clean", "", "Remove build artifacts and cache");
        printCommand("graph", "[target]", "Visualize dependency graph");
        printCommand("query", "<expression>", "Query targets and dependencies");
        terminal.writeln();
        
        // Project setup
        printSectionHeader("PROJECT SETUP");
        printCommand("wizard", "", "Project setup wizard");
        printCommand("init", "", "Initialize Builderfile with auto-detection");
        printCommand("infer", "", "Preview auto-detected targets (dry-run)");
        terminal.writeln();
        
        // Monitoring & tools
        printSectionHeader("MONITORING & TOOLS");
        printCommand("telemetry", "", "View build analytics and performance insights");
        printCommand("cache-server", "[options]", "Start remote cache server");
        printCommand("install-extension", "", "Install Builder VS Code extension");
        terminal.writeln();
        
        // Distributed builds
        printSectionHeader("DISTRIBUTED BUILDS");
        printCommand("coordinator", "[options]", "Start distributed build coordinator");
        printCommand("worker", "[options]", "Start distributed build worker");
        terminal.writeln();
        
        // Information
        printSectionHeader("INFORMATION");
        printCommand("help", "[command]", "Show detailed help for a command");
        terminal.writeln();
        
        // Global options
        printSectionHeader("GLOBAL OPTIONS");
        printOption("-v, --verbose", "Enable verbose output");
        printOption("-g, --graph", "Show dependency graph during build");
        printOption("-m, --mode <MODE>", "CLI mode: auto, interactive, plain, verbose, quiet");
        printOption("-w, --watch", "Enable watch mode (rebuild on file changes)");
        printOption("--debounce <MS>", "Debounce delay in milliseconds for watch mode");
        printOption("--clear", "Clear screen between builds in watch mode");
        terminal.writeln();
        
        // Zero-config mode highlight
        printHighlight("⚡ ZERO-CONFIG MODE", 
            "Builder can automatically detect and build projects without a Builderfile.\n" ~
            "  Simply run 'builder build' in any supported project directory!");
        terminal.writeln();
        
        // Examples
        printSectionHeader("EXAMPLES");
        printExample("builder build", "Auto-detect and build all targets");
        printExample("builder build --watch", "Watch mode - rebuild on file changes");
        printExample("builder init", "Create Builderfile from project structure");
        printExample("builder build //path/to:target", "Build specific target");
        printExample("builder graph", "Show complete dependency graph");
        printExample("builder telemetry", "View build performance analytics");
        printExample("builder help build", "Show detailed help for build command");
        terminal.writeln();
        
        terminal.writeColored("For detailed help on any command, run: ", Color.Cyan);
        terminal.writeColored("builder help <command>", Color.Yellow, Style.Bold);
        terminal.writeln();
        terminal.writeln();
        
        // Supported languages - dynamically generated from registry
        printSectionHeader("SUPPORTED LANGUAGES");
        printLanguages("Compiled", getLanguageCategoryList(LanguageCategory.Compiled));
        printLanguages("JVM", getLanguageCategoryList(LanguageCategory.JVM));
        printLanguages(".NET", getLanguageCategoryList(LanguageCategory.DotNet));
        printLanguages("Scripting", getLanguageCategoryList(LanguageCategory.Scripting));
        printLanguages("Web", getLanguageCategoryList(LanguageCategory.Web));
        terminal.writeln();
        
        // Documentation
        printSectionHeader("DOCUMENTATION");
        printDocLink("README", "See README.md for getting started");
        printDocLink("Docs", "Check docs/ directory for comprehensive guides");
        printDocLink("Examples", "Explore examples/ directory for sample projects");
        terminal.writeln();
    }
    
    /// Print a section header with styling
    private static void printSectionHeader(string header)
    {
        terminal.writeColored(header ~ ":", Color.Cyan, Style.Bold);
        terminal.writeln();
    }
    
    /// Print a command with colored formatting
    private static void printCommand(string cmd, string args, string description)
    {
        terminal.write("  ");
        terminal.writeColored(cmd, Color.Green, Style.Bold);
        if (args.length > 0)
        {
            terminal.write(" ");
            terminal.writeColored(args, Color.Yellow);
        }
        
        import std.string : leftJustify;
        auto padding = 25 - (cmd.length + args.length);
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(description);
        terminal.writeln();
    }
    
    /// Print an option with colored formatting
    private static void printOption(string opt, string description)
    {
        terminal.write("  ");
        terminal.writeColored(opt, Color.Yellow, Style.Bold);
        
        import std.string : leftJustify;
        auto padding = 30 - opt.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(description);
        terminal.writeln();
    }
    
    /// Print a highlighted section with icon
    private static void printHighlight(string title, string content)
    {
        terminal.writeColored(title, Color.BrightYellow, Style.Bold);
        terminal.writeln();
        terminal.writeColored("  " ~ content, Color.Yellow);
        terminal.writeln();
    }
    
    /// Print an example command
    private static void printExample(string cmd, string description)
    {
        terminal.write("  ");
        terminal.writeColored(cmd, Color.BrightCyan, Style.Bold);
        
        import std.string : leftJustify;
        auto padding = 40 - cmd.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.writeColored("# " ~ description, Color.BrightBlack);
        terminal.writeln();
    }
    
    /// Print language category with languages
    private static void printLanguages(string category, string languages)
    {
        terminal.write("  ");
        terminal.writeColored(category ~ ":", Color.Magenta, Style.Bold);
        
        import std.string : leftJustify;
        auto padding = 15 - category.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(languages);
        terminal.writeln();
    }
    
    /// Print documentation link
    private static void printDocLink(string label, string description)
    {
        terminal.write("  ");
        terminal.writeColored(label ~ ":", Color.Blue, Style.Bold);
        
        import std.string : leftJustify;
        auto padding = 15 - label.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(description);
        terminal.writeln();
    }
    
    /// Show help for a specific command
    private static void showCommandHelp(string command)
    {
        switch (command)
        {
            case "build":
                showBuildHelp();
                break;
            case "test":
                showTestHelp();
                break;
            case "watch":
                WatchCommand.showHelp();
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
            case "wizard":
                showWizardHelp();
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
                terminal.write("Run ");
                terminal.writeColored("'builder help'", Color.Cyan, Style.Bold);
                terminal.write(" to see available commands.");
                terminal.writeln();
        }
    }
    
    private static void showTestHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Run test targets with comprehensive reporting and CI/CD integration.",
            "Supports test discovery, filtering, and JUnit XML output."
        ];
        terminal.writeln(formatter.formatBox("builder test [target]", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder test", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[options]", Color.Yellow);
        terminal.write(" ");
        terminal.writeColored("[target]", Color.Green);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("OPTIONS");
        printOption("-v, --verbose", "Show detailed test output");
        printOption("-q, --quiet", "Minimal output (errors only)");
        printOption("--show-passed", "Display passed tests");
        printOption("--fail-fast", "Stop on first test failure");
        printOption("--filter PATTERN", "Filter tests by pattern");
        printOption("--junit [PATH]", "Generate JUnit XML report");
        printOption("--coverage", "Generate coverage report (future)");
        printOption("-m, --mode <MODE>", "Set CLI rendering mode");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder test", "Run all tests");
        printExample("builder test --verbose", "Run with detailed output");
        printExample("builder test //path:target", "Run specific test target");
        printExample("builder test --filter unit", "Filter by pattern");
        printExample("builder test --junit report.xml", "Generate JUnit XML");
        printExample("builder test --fail-fast", "Stop on first failure");
        terminal.writeln();
        
        printSectionHeader("TEST DISCOVERY");
        printListItem("Automatically finds all targets with type: test");
        printListItem("Supports pattern matching and filtering");
        printListItem("Works with zero-config projects");
        printListItem("Caches test results for faster reruns");
        terminal.writeln();
        
        printSectionHeader("JUNIT XML INTEGRATION");
        printFeature("Compatible with Jenkins, GitHub Actions, GitLab CI");
        printFeature("Captures test case details and timing");
        printFeature("Includes failure messages and stack traces");
        printFeature("Supports nested test suites");
        terminal.writeln();
        
        printSectionHeader("FEATURES");
        printFeature("Test result caching for unchanged tests");
        printFeature("Parallel test execution");
        printFeature("Comprehensive test statistics");
        printFeature("Multi-language test framework support");
        printFeature("Test case and suite reporting");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder build", "Build targets");
        printSeeAlso("builder query", "Query test targets");
        printSeeAlso("builder watch", "Continuous testing");
        terminal.writeln();
    }
    
    private static void showBuildHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Build all targets in the workspace or a specific target. Builder",
            "automatically detects project structure and builds without configuration."
        ];
        terminal.writeln(formatter.formatBox("builder build [target]", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder build", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[options]", Color.Yellow);
        terminal.write(" ");
        terminal.writeColored("[target]", Color.Green);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("OPTIONS");
        printOption("-v, --verbose", "Show detailed build output");
        printOption("-g, --graph", "Display dependency graph before building");
        printOption("-m, --mode <MODE>", "Set CLI rendering mode");
        terminal.writeln();
        
        printSectionHeader("RENDER MODES");
        printRenderMode("auto", "Auto-detect best mode (default)");
        printRenderMode("interactive", "Rich, real-time progress display");
        printRenderMode("plain", "Simple text output for CI/CD");
        printRenderMode("verbose", "Detailed output with all commands");
        printRenderMode("quiet", "Minimal output (errors only)");
        terminal.writeln();
        
        printSectionHeader("TARGET SYNTAX");
        printTargetSyntax("//path/to:target", "Absolute target reference");
        printTargetSyntax(":target", "Target in current directory");
        printTargetSyntax("//path/to:*", "All targets in directory");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder build", "Build all targets");
        printExample("builder build -v", "Build with verbose output");
        printExample("builder build --graph", "Show graph, then build");
        printExample("builder build //src:myapp", "Build specific target");
        printExample("builder build -m plain", "Use plain mode for CI");
        printExample("builder build -m interactive", "Rich interactive mode");
        terminal.writeln();
        
        printSectionHeader("ZERO-CONFIG");
        terminal.write("  If no Builderfile exists, Builder will:");
        terminal.writeln();
        printListItem("Scan the project directory");
        printListItem("Detect languages and frameworks");
        printListItem("Infer build targets automatically");
        printListItem("Build without any configuration!");
        terminal.writeln();
        
        printSectionHeader("FEATURES");
        printFeature("Parallel builds with intelligent scheduling");
        printFeature("BLAKE3-based content hashing for fast caching");
        printFeature("Automatic checkpoint creation for recovery");
        printFeature("Build telemetry and performance tracking");
        printFeature("Multi-language and mixed-language projects");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder resume", "Resume from checkpoint");
        printSeeAlso("builder graph", "Visualize dependencies");
        printSeeAlso("builder telemetry", "View build analytics");
        terminal.writeln();
    }
    
    /// Print a render mode option
    private static void printRenderMode(string mode, string description)
    {
        terminal.write("  ");
        terminal.writeColored(mode, Color.Magenta, Style.Bold);
        
        auto padding = 20 - mode.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(description);
        terminal.writeln();
    }
    
    /// Print a target syntax example
    private static void printTargetSyntax(string syntax, string description)
    {
        terminal.write("  ");
        terminal.writeColored(syntax, Color.Green, Style.Bold);
        
        auto padding = 25 - syntax.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(description);
        terminal.writeln();
    }
    
    /// Print a numbered list item
    private static void printListItem(string text)
    {
        terminal.write("  ");
        terminal.writeColored("•", Color.Cyan);
        terminal.write(" ");
        terminal.write(text);
        terminal.writeln();
    }
    
    /// Print a feature with bullet point
    private static void printFeature(string text)
    {
        terminal.write("  ");
        terminal.writeColored("✓", Color.Green);
        terminal.write(" ");
        terminal.write(text);
        terminal.writeln();
    }
    
    /// Print a "see also" reference
    private static void printSeeAlso(string cmd, string description)
    {
        terminal.write("  ");
        terminal.writeColored(cmd, Color.BrightCyan, Style.Bold);
        
        auto padding = 25 - cmd.length;
        if (padding > 0)
        {
            foreach (_; 0 .. padding)
                terminal.write(" ");
        }
        else
        {
            terminal.write("  ");
        }
        
        terminal.write(description);
        terminal.writeln();
    }
    
    private static void showResumeHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Resume a failed build from the last checkpoint. Builder automatically",
            "saves checkpoints during builds, allowing you to continue from where",
            "a build failed without rebuilding already-completed targets."
        ];
        terminal.writeln(formatter.formatBox("builder resume", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder resume", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[options]", Color.Yellow);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("OPTIONS");
        printOption("-m, --mode <MODE>", "Set CLI rendering mode");
        terminal.writeln();
        
        printSectionHeader("HOW IT WORKS");
        terminal.write("  ");
        terminal.writeColored("1.", Color.BrightCyan);
        terminal.write(" Builder saves a checkpoint after each successful target build");
        terminal.writeln();
        terminal.write("  ");
        terminal.writeColored("2.", Color.BrightCyan);
        terminal.write(" If a build fails, the checkpoint is preserved");
        terminal.writeln();
        terminal.write("  ");
        terminal.writeColored("3.", Color.BrightCyan);
        terminal.write(" 'builder resume' loads the checkpoint and continues from there");
        terminal.writeln();
        terminal.write("  ");
        terminal.writeColored("4.", Color.BrightCyan);
        terminal.write(" Completed targets are skipped automatically");
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("CHECKPOINT VALIDATION");
        terminal.write("  Builder validates that:");
        terminal.writeln();
        printFeature("Project structure hasn't changed significantly");
        printFeature("Target dependencies remain the same");
        printFeature("Checkpoint is compatible with current configuration");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder resume", "Resume last failed build");
        printExample("builder resume -m verbose", "Resume with detailed output");
        terminal.writeln();
        
        printSectionHeader("NOTES");
        printListItem("Checkpoints are stored in .builder-cache/");
        printListItem("Use 'builder clean' to remove checkpoints");
        printListItem("Checkpoints are automatically invalidated when dependencies change");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder build", "Start a new build");
        printSeeAlso("builder clean", "Remove cache and checkpoints");
        terminal.writeln();
    }
    
    private static void showCleanHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Remove all build artifacts, cache files, and checkpoints. This forces",
            "a complete rebuild on the next build command."
        ];
        terminal.writeln(formatter.formatBox("builder clean", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder clean", Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("WHAT GETS REMOVED");
        terminal.write("  ");
        terminal.writeColored(".builder-cache/", Color.Yellow, Style.Bold);
        terminal.write("       Build cache and checkpoints");
        terminal.writeln();
        terminal.write("  ");
        terminal.writeColored("bin/", Color.Yellow, Style.Bold);
        terminal.write("                  Compiled binaries and artifacts");
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("WHEN TO USE");
        printFeature("After major project restructuring");
        printFeature("To free up disk space");
        printFeature("When cache appears corrupted");
        printFeature("To force complete rebuild");
        printFeature("When checkpoint validation fails");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder clean", "Clean everything");
        printExample("builder clean && builder build", "Clean then rebuild");
        terminal.writeln();
        
        printSectionHeader("NOTES");
        printListItem("Source files are never touched");
        printListItem("Telemetry data is preserved");
        printListItem("Operation cannot be undone");
        terminal.writeln();
    }
    
    private static void showGraphHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Visualize the dependency graph for all targets or a specific target.",
            "Shows build order, dependencies, and target relationships."
        ];
        terminal.writeln(formatter.formatBox("builder graph [target]", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder graph", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[target]", Color.Green);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder graph", "Show complete dependency graph");
        printExample("builder graph //src:myapp", "Show dependencies for specific target");
        printExample("builder graph :lib", "Show dependencies for local target");
        terminal.writeln();
        
        printSectionHeader("GRAPH OUTPUT INCLUDES");
        printFeature("Target names and types");
        printFeature("Dependency relationships");
        printFeature("Build order (topological sort)");
        printFeature("Parallel build opportunities");
        terminal.writeln();
        
        printSectionHeader("USE CASES");
        printFeature("Understanding project structure");
        printFeature("Debugging build issues");
        printFeature("Identifying circular dependencies");
        printFeature("Planning incremental builds");
        printFeature("Optimizing build parallelization");
        terminal.writeln();
        
        printSectionHeader("NOTES");
        printListItem("Graph generation is fast and doesn't build anything");
        printListItem("Works with both Builderfile and zero-config projects");
        printListItem("Can be combined with build: 'builder build --graph'");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder build --graph", "Show graph before building");
        printSeeAlso("builder infer", "Preview auto-detected targets");
        printSeeAlso("builder query", "Query targets and dependencies");
        terminal.writeln();
    }
    
    private static void showQueryHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Execute powerful bldrquery DSL to explore dependency graphs.",
            "Bazel-compatible with advanced extensions for path analysis,",
            "set operations, regex filtering, and multiple output formats."
        ];
        terminal.writeln(formatter.formatBox("builder query <expression> [--format=type]", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder query", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("'<expression>'", Color.Yellow);
        terminal.write(" ");
        terminal.writeColored("[--format=pretty|list|json|dot]", Color.BrightBlack);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("DEPENDENCY QUERIES");
        printTargetSyntax("deps(expr)", "All transitive dependencies");
        printTargetSyntax("deps(expr, depth)", "Dependencies up to depth");
        printTargetSyntax("rdeps(expr)", "Reverse dependencies");
        printTargetSyntax("rdeps(expr, depth)", "Reverse deps up to depth");
        terminal.writeln();
        
        printSectionHeader("PATH QUERIES");
        printTargetSyntax("allpaths(from, to)", "All paths between targets");
        printTargetSyntax("somepath(from, to)", "Any single path (faster)");
        printTargetSyntax("shortest(from, to)", "Shortest path using BFS");
        terminal.writeln();
        
        printSectionHeader("FILTERING");
        printTargetSyntax("kind(type, expr)", "Filter by type (executable, library, test)");
        printTargetSyntax("attr(name, value, expr)", "Filter by exact attribute match");
        printTargetSyntax("filter(attr, regex, expr)", "Filter using regex pattern");
        terminal.writeln();
        
        printSectionHeader("SET OPERATIONS");
        printTargetSyntax("expr1 + expr2", "Union (all targets in either)");
        printTargetSyntax("expr1 & expr2", "Intersection (targets in both)");
        printTargetSyntax("expr1 - expr2", "Difference (targets in A not B)");
        terminal.writeln();
        
        printSectionHeader("UTILITIES");
        printTargetSyntax("siblings(expr)", "Targets in same directory");
        printTargetSyntax("buildfiles(pattern)", "Find Builderfiles");
        printTargetSyntax("let(var, val, body)", "Variable binding");
        terminal.writeln();
        
        printSectionHeader("OUTPUT FORMATS");
        printTargetSyntax("--format=pretty", "Human-readable with colors (default)");
        printTargetSyntax("--format=list", "Newline-separated target names");
        printTargetSyntax("--format=json", "Machine-readable JSON");
        printTargetSyntax("--format=dot", "GraphViz DOT format");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder query '//...'", "List all targets");
        printExample("builder query 'deps(//src:app)'", "All dependencies");
        printExample("builder query 'rdeps(//lib:utils) & kind(test, //...)'", "Tests depending on utils");
        printExample("builder query 'shortest(//a:x, //b:y)'", "Shortest path");
        printExample("builder query '//src/... - //src/test/...'", "Source without tests");
        printExample("builder query 'deps(//...) --format=json'", "Export to JSON");
        terminal.writeln();
        
        printSectionHeader("USE CASES");
        printFeature("Explore dependency relationships");
        printFeature("Find critical paths in build graph");
        printFeature("Identify unused or orphaned targets");
        printFeature("Analyze test coverage (rdeps of src from tests)");
        printFeature("Debug circular dependencies");
        printFeature("Export data for external analysis tools");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder graph", "Visualize full dependency graph");
        printSeeAlso("builder infer", "Preview auto-detected targets");
        printSeeAlso("docs/features/bldrquery.md", "Complete query language reference");
        terminal.writeln();
    }
    
    private static void showWizardHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Interactive wizard for setting up a Builder project. Guides you through",
            "language selection, project structure, and configuration options."
        ];
        terminal.writeln(formatter.formatBox("builder wizard", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder wizard", Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("WHAT IT DOES");
        terminal.write("  The wizard will:");
        terminal.writeln();
        printFeature("Auto-detect existing project structure");
        printFeature("Ask about language and framework");
        printFeature("Configure project structure type");
        printFeature("Set up package manager preferences");
        printFeature("Enable/disable caching and remote execution");
        printFeature("Generate Builderfile, Builderspace, and .builderignore");
        terminal.writeln();
        
        printSectionHeader("INTERACTIVE FEATURES");
        printFeature("Arrow key navigation for selections");
        printFeature("Smart defaults based on detection");
        printFeature("Vim-style shortcuts (j/k for navigation)");
        printFeature("Confirmation before overwriting existing files");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder wizard", "Start interactive setup");
        printExample("cd my-project && builder wizard", "Set up specific project");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder init", "Non-interactive initialization");
        printSeeAlso("builder infer", "Preview auto-detection");
        terminal.writeln();
    }
    
    private static void showInitHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Initialize a new Builder project by creating a Builderfile, Builderspace,",
            "and .builderignore based on automatic project detection."
        ];
        terminal.writeln(formatter.formatBox("builder init", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder init", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[options]", Color.Yellow);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("GENERATED FILES");
        printDocLink("Builderfile", "Build configuration with detected targets");
        printDocLink("Builderspace", "Workspace-level configuration");
        printDocLink(".builderignore", "Patterns to exclude from scanning");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder init", "Initialize in current directory");
        printExample("cd my-project && builder init", "Initialize in specific directory");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder wizard", "Interactive setup with guided prompts");
        printSeeAlso("builder infer", "Preview detection without creating files");
        printSeeAlso("builder build", "Build after initialization");
        terminal.writeln();
    }
    
    private static void showInferHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Preview what targets would be automatically detected and inferred from",
            "your project structure without creating any files. Dry-run of zero-config."
        ];
        terminal.writeln(formatter.formatBox("builder infer", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder infer", Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("OUTPUT SHOWS");
        printFeature("Detected target names and types");
        printFeature("Programming languages");
        printFeature("Source files for each target");
        printFeature("Language-specific configuration");
        printFeature("Build commands that would be used");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder infer", "Show inferred targets");
        printExample("builder infer > targets.txt", "Save to file");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder wizard", "Interactive setup wizard");
        printSeeAlso("builder init", "Generate Builderfile from detection");
        printSeeAlso("builder build", "Build using zero-config");
        terminal.writeln();
    }
    
    private static void showTelemetryHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "View build analytics, performance insights, and telemetry data collected",
            "during builds. Helps identify bottlenecks and track build performance."
        ];
        terminal.writeln(formatter.formatBox("builder telemetry [cmd]", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder telemetry", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[subcommand]", Color.Yellow);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("SUBCOMMANDS");
        printCommand("summary", "", "Comprehensive analytics report (default)");
        printCommand("recent", "[n]", "Show last n builds (default: 10)");
        printCommand("export", "", "Export data as JSON");
        printCommand("clear", "", "Remove all telemetry data");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder telemetry", "Show summary");
        printExample("builder telemetry recent 20", "Show last 20 builds");
        printExample("builder telemetry export > data.json", "Export to file");
        printExample("builder telemetry clear", "Remove all data");
        terminal.writeln();
        
        printSectionHeader("PRIVACY");
        printListItem("All data stored locally in .builder-cache/telemetry/");
        printListItem("No data sent to external servers");
        printListItem("Can be disabled in workspace configuration");
        terminal.writeln();
        
        printSectionHeader("SEE ALSO");
        printSeeAlso("builder build", "Builds collect telemetry data");
        terminal.writeln();
    }
    
    private static void showInstallExtensionHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Install the Builder VS Code extension for syntax highlighting,",
            "autocompletion, and other IDE features for Builderfile editing."
        ];
        terminal.writeln(formatter.formatBox("builder install-extension", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder install-extension", Color.Cyan, Style.Bold);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("FEATURES");
        printFeature("Syntax highlighting for Builderfile and Builderspace");
        printFeature("Code completion for target types and commands");
        printFeature("Validation and error checking");
        printFeature("Snippets for common patterns");
        printFeature("Documentation on hover");
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder install-extension", "Install VS Code extension");
        terminal.writeln();
        
        printSectionHeader("NOTES");
        printListItem("Requires VS Code 1.60.0 or higher");
        printListItem("Extension updates must be installed manually");
        terminal.writeln();
    }
    
    private static void showHelpHelp()
    {
        terminal.writeln();
        
        string[] description = [
            "Display help information for Builder commands."
        ];
        terminal.writeln(formatter.formatBox("builder help [command]", description));
        terminal.writeln();
        
        printSectionHeader("USAGE");
        terminal.writeColored("  builder help", Color.Cyan, Style.Bold);
        terminal.write(" ");
        terminal.writeColored("[command]", Color.Yellow);
        terminal.writeln();
        terminal.writeln();
        
        printSectionHeader("EXAMPLES");
        printExample("builder help", "Show general help");
        printExample("builder help build", "Help for build command");
        printExample("builder help telemetry", "Help for telemetry command");
        terminal.writeln();
        
        printSectionHeader("AVAILABLE COMMANDS");
        terminal.write("  ");
        terminal.writeColored("build", Color.Green);
        terminal.write(", ");
        terminal.writeColored("resume", Color.Green);
        terminal.write(", ");
        terminal.writeColored("clean", Color.Green);
        terminal.write(", ");
        terminal.writeColored("graph", Color.Green);
        terminal.write(", ");
        terminal.writeColored("query", Color.Green);
        terminal.write(", ");
        terminal.writeColored("wizard", Color.Green);
        terminal.writeln();
        terminal.write("  ");
        terminal.writeColored("init", Color.Green);
        terminal.write(", ");
        terminal.writeColored("infer", Color.Green);
        terminal.write(", ");
        terminal.writeColored("telemetry", Color.Green);
        terminal.write(", ");
        terminal.writeColored("install-extension", Color.Green);
        terminal.write(", ");
        terminal.writeColored("help", Color.Green);
        terminal.writeln();
        terminal.writeln();
    }
}

