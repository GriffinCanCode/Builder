module cli.commands.test;

import std.stdio;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.algorithm : filter, map;
import std.array : array;
import std.range : empty;
import std.conv : to;
import std.string : strip, startsWith;
import config.parsing.parser;
import config.schema.schema;
import core.graph.graph;
import core.services.services;
import core.testing;
import core.shutdown.shutdown;
import utils.logging.logger;
import cli.control.terminal;
import cli.display.format;
import errors;

/// Test command - runs test targets with reporting
struct TestCommand
{
    private static Terminal terminal;
    private static Formatter formatter;
    private static bool initialized = false;
    
    /// Initialize terminal and formatter
    private static void init() @system
    {
        if (!initialized)
        {
            auto caps = Capabilities.detect();
            terminal = Terminal(caps);
            formatter = Formatter(caps);
            initialized = true;
        }
    }
    
    /// Execute test command
    static int execute(string[] args) @system
    {
        init();
        
        // Parse arguments
        TestConfig config;
        string targetSpec = "";
        string renderMode = "auto";
        
        size_t i = 1; // Skip "test" command itself
        while (i < args.length)
        {
            immutable arg = args[i];
            
            if (arg == "--verbose" || arg == "-v")
            {
                config.verbose = true;
                i++;
            }
            else if (arg == "--quiet" || arg == "-q")
            {
                config.quiet = true;
                i++;
            }
            else if (arg == "--show-passed")
            {
                config.showPassed = true;
                i++;
            }
            else if (arg == "--fail-fast")
            {
                config.failFast = true;
                i++;
            }
            else if (arg == "--filter" && i + 1 < args.length)
            {
                config.filter = args[i + 1];
                i += 2;
            }
            else if (arg == "--coverage")
            {
                // Coverage flag reserved for future implementation
                Logger.info("Coverage reporting will be available in a future release");
                i++;
            }
            else if (arg == "--junit")
            {
                config.generateJUnit = true;
                if (i + 1 < args.length && !args[i + 1].startsWith("--"))
                {
                    config.junitPath = args[i + 1];
                    i += 2;
                }
                else
                {
                    config.junitPath = "test-results.xml";
                    i++;
                }
            }
            else if (arg == "--mode" && i + 1 < args.length)
            {
                renderMode = args[i + 1];
                i += 2;
            }
            else if (arg == "--help" || arg == "-h")
            {
                showHelp();
                return 0;
            }
            else if (!arg.startsWith("--"))
            {
                // Target specification
                targetSpec = arg;
                i++;
            }
            else
            {
                Logger.error("Unknown option: " ~ arg);
                showHelp();
                return 1;
            }
        }
        
        // Run tests
        return runTests(targetSpec, config, renderMode);
    }
    
    /// Run tests with configuration
    private static int runTests(string targetSpec, TestConfig config, string renderMode) @system
    {
        auto sw = StopWatch(AutoStart.yes);
        
        Logger.info("Discovering tests...");
        
        // Parse workspace configuration
        auto configResult = ConfigParser.parseWorkspace(".");
        if (configResult.isErr)
        {
            Logger.error("Failed to parse workspace configuration");
            import errors.formatting.format : format;
            Logger.error(format(configResult.unwrapErr()));
            return 1;
        }
        
        auto wsConfig = configResult.unwrap();
        
        // Discover test targets
        auto discovery = new TestDiscovery(wsConfig);
        Target[] testTargets;
        
        if (!targetSpec.empty)
        {
            testTargets = discovery.findByTarget(targetSpec);
        }
        else if (!config.filter.empty)
        {
            testTargets = discovery.findByFilter(config.filter);
        }
        else
        {
            testTargets = discovery.findAll();
        }
        
        if (testTargets.empty)
        {
            Logger.warning("No test targets found");
            
            if (!targetSpec.empty)
            {
                Logger.info("Target specification: " ~ targetSpec);
            }
            if (!config.filter.empty)
            {
                Logger.info("Filter: " ~ config.filter);
            }
            
            Logger.info("Use 'builder query \"deps(//...)\"' to see all available targets");
            return 0;
        }
        
        // Create reporter
        auto reporter = new TestReporter(terminal, formatter, config.verbose);
        reporter.reportStart(testTargets.length);
        
        // Create services
        auto services = new BuildServices(wsConfig, wsConfig.options);
        
        // Register cache for cleanup
        auto coordinator = ShutdownCoordinator.instance();
        coordinator.registerCache(services.cache);
        
        // Set render mode
        import app : parseRenderMode;
        immutable rm = parseRenderMode(renderMode);
        services.setRenderMode(rm);
        
        // Execute tests
        TestResult[] results;
        bool hadFailure = false;
        
        foreach (target; testTargets)
        {
            auto result = executeTest(target, wsConfig, services, config);
            results ~= result;
            
            reporter.reportTest(result);
            
            if (!result.passed)
            {
                hadFailure = true;
                if (config.failFast)
                {
                    Logger.info("Stopping due to --fail-fast");
                    break;
                }
            }
        }
        
        // Compute statistics
        immutable stats = TestStats.compute(results);
        
        // Report summary
        reporter.reportSummary(stats);
        
        // Export JUnit XML if requested
        if (config.generateJUnit)
        {
            try
            {
                exportJUnit(results, config.junitPath);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to export JUnit XML: " ~ e.msg);
            }
        }
        
        // Cleanup
        services.shutdown();
        
        sw.stop();
        
        // Return exit code
        return stats.allPassed ? 0 : 1;
    }
    
    /// Execute a single test target
    private static TestResult executeTest(
        Target target,
        WorkspaceConfig config,
        BuildServices services,
        TestConfig testConfig
    ) @system
    {
        auto sw = StopWatch(AutoStart.yes);
        
        try
        {
            // Get language handler
            auto handler = services.registry.get(target.language);
            if (handler is null)
            {
                return TestResult.fail(
                    target.name,
                    sw.peek(),
                    "No language handler for: " ~ target.language.to!string
                );
            }
            
            // Build the test target (which will run tests)
            auto buildResult = handler.build(target, config);
            
            sw.stop();
            
            if (buildResult.isOk)
            {
                return TestResult.pass(target.name, sw.peek());
            }
            else
            {
                auto error = buildResult.unwrapErr();
                return TestResult.fail(
                    target.name,
                    sw.peek(),
                    error.message()
                );
            }
        }
        catch (Exception e)
        {
            sw.stop();
            return TestResult.fail(
                target.name,
                sw.peek(),
                "Exception: " ~ e.msg
            );
        }
    }
    
    /// Show help for test command
    private static void showHelp() @system
    {
        terminal.writeln();
        terminal.writeln("Usage: builder test [OPTIONS] [TARGET]");
        terminal.writeln();
        terminal.writeln("Run test targets with reporting and analysis.");
        terminal.writeln();
        terminal.writeln("Options:");
        terminal.writeln("  -v, --verbose         Show detailed output");
        terminal.writeln("  -q, --quiet           Minimal output");
        terminal.writeln("  --show-passed         Show passed tests");
        terminal.writeln("  --fail-fast           Stop on first failure");
        terminal.writeln("  --filter PATTERN      Filter tests by pattern");
        terminal.writeln("  --junit [PATH]        Generate JUnit XML report");
        terminal.writeln("  --coverage            Generate coverage report (future)");
        terminal.writeln("  --mode MODE           Render mode: auto, interactive, plain");
        terminal.writeln("  -h, --help            Show this help");
        terminal.writeln();
        terminal.writeln("Examples:");
        terminal.writeln("  builder test                    # Run all tests");
        terminal.writeln("  builder test //path:target      # Run specific test");
        terminal.writeln("  builder test --filter unit      # Filter tests");
        terminal.writeln("  builder test --junit report.xml # Generate JUnit XML");
        terminal.writeln("  builder test --fail-fast        # Stop on first failure");
        terminal.writeln();
        terminal.flush();
    }
}

