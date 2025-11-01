#!/usr/bin/env dub
/+ dub.sdl:
    name "integration-bench"
    dependency "builder" path="../../"
+/

/**
 * Integration benchmark - tests actual Builder system with generated targets
 * This benchmarks the REAL Builder system, not simulations
 */

module tests.bench.integration_bench;

import std.stdio;
import std.file;
import std.path;
import std.process;
import std.datetime.stopwatch;
import std.datetime;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.string;
import std.range;
import core.memory : GC;
import tests.bench.target_generator;
import tests.bench.utils;

/// Integration test scenario
struct IntegrationScenario
{
    string name;
    size_t targetCount;
    bool cleanFirst;
    double changePercent;  // For incremental tests
}

/// Integration benchmark result
struct IntegrationResult
{
    string scenarioName;
    size_t targetCount;
    Duration generationTime;
    Duration buildTime;
    Duration totalTime;
    bool success;
    string errorMessage;
    long exitCode;
    size_t stdoutLines;
    size_t stderrLines;
}

/// Integration benchmark runner
class IntegrationBenchmark
{
    private string workspaceDir;
    private string builderBinary;
    private IntegrationResult[] results;
    
    this(string workspaceDir = "integration-bench-workspace", string builderBinary = "./bin/builder")
    {
        this.workspaceDir = workspaceDir;
        this.builderBinary = builderBinary;
    }
    
    /// Run all integration benchmarks
    void runAll()
    {
        writeln("╔════════════════════════════════════════════════════════════════╗");
        writeln("║      BUILDER INTEGRATION BENCHMARK - REAL SYSTEM TESTS        ║");
        writeln("║         Testing actual Builder with 50K-100K targets          ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        writeln();
        
        // Verify Builder binary exists
        if (!exists(builderBinary))
        {
            writeln("\x1b[31m✗ Builder binary not found: ", builderBinary, "\x1b[0m");
            writeln("  Please build Builder first: make");
            return;
        }
        
        writeln("\x1b[32m✓\x1b[0m Using Builder binary: ", builderBinary);
        writeln();
        
        // Define integration test scenarios
        auto scenarios = [
            IntegrationScenario("Real build - 50K targets (clean)", 50_000, true, 0.0),
            IntegrationScenario("Real build - 50K targets (cached)", 50_000, false, 0.0),
            IntegrationScenario("Real build - 75K targets (clean)", 75_000, true, 0.0),
            IntegrationScenario("Real build - 100K targets (clean)", 100_000, true, 0.0),
        ];
        
        foreach (i, scenario; scenarios)
        {
            writeln("\n" ~ "=".repeat(70).join);
            writeln(format("SCENARIO %d/%d: %s", i + 1, scenarios.length, scenario.name));
            writeln("=".repeat(70).join);
            
            try
            {
                auto result = runIntegrationScenario(scenario);
                results ~= result;
                printResult(result);
            }
            catch (Exception e)
            {
                writeln("\x1b[31m✗ Scenario failed: ", e.msg, "\x1b[0m");
            }
            
            // Cleanup between scenarios (optional - can keep for cache testing)
            if (scenario.cleanFirst)
            {
                cleanupWorkspace();
            }
            
            GC.collect();
        }
        
        // Generate report
        generateReport();
    }
    
    /// Run single integration scenario
    private IntegrationResult runIntegrationScenario(in IntegrationScenario scenario)
    {
        IntegrationResult result;
        result.scenarioName = scenario.name;
        result.targetCount = scenario.targetCount;
        
        auto totalTimer = StopWatch(AutoStart.yes);
        
        // Phase 1: Generate project
        writeln("\n\x1b[36m[PHASE 1]\x1b[0m Generating Test Project");
        auto genTimer = StopWatch(AutoStart.yes);
        
        auto config = GeneratorConfig();
        config.targetCount = scenario.targetCount;
        config.projectType = ProjectType.Monorepo;
        config.avgDepsPerTarget = 3.5;
        config.libToExecRatio = 0.7;
        config.generateSources = true;  // Always generate actual sources for integration tests
        config.outputDir = workspaceDir;
        
        auto generator = new TargetGenerator(config);
        auto targets = generator.generate();
        
        genTimer.stop();
        result.generationTime = genTimer.peek;
        writeln(format("  Generated %,d targets in %,d ms", 
                targets.length, result.generationTime.total!"msecs"));
        
        // Phase 2: Clean if requested
        if (scenario.cleanFirst)
        {
            writeln("\n\x1b[36m[PHASE 2]\x1b[0m Cleaning (forcing fresh build)");
            cleanBuildArtifacts();
        }
        
        // Phase 3: Run actual Builder
        writeln("\n\x1b[36m[PHASE 3]\x1b[0m Running Builder System");
        auto buildTimer = StopWatch(AutoStart.yes);
        
        try
        {
            auto buildResult = runBuilder();
            buildTimer.stop();
            
            result.buildTime = buildTimer.peek;
            result.success = (buildResult.status == 0);
            result.exitCode = buildResult.status;
            result.stdoutLines = buildResult.output.lineSplitter.count;
            
            if (!result.success)
            {
                result.errorMessage = "Builder exited with code " ~ buildResult.status.to!string;
                writeln("\x1b[31m✗ Build failed with exit code: ", buildResult.status, "\x1b[0m");
            }
            else
            {
                writeln("\x1b[32m✓ Build succeeded\x1b[0m");
            }
            
            writeln(format("  Build time: %,d ms", result.buildTime.total!"msecs"));
        }
        catch (Exception e)
        {
            buildTimer.stop();
            result.buildTime = buildTimer.peek;
            result.success = false;
            result.errorMessage = e.msg;
            writeln("\x1b[31m✗ Build failed: ", e.msg, "\x1b[0m");
        }
        
        totalTimer.stop();
        result.totalTime = totalTimer.peek;
        
        return result;
    }
    
    /// Run Builder binary
    private auto runBuilder()
    {
        writeln("  Executing: ", builderBinary, " build");
        writeln("  Working directory: ", workspaceDir);
        
        auto cmd = [builderBinary, "build"];
        auto result = execute(cmd, null, Config.none, size_t.max, workspaceDir);
        
        if (result.status != 0)
        {
            writeln("\n  STDOUT:");
            writeln("  ", result.output.lineSplitter.join("\n  "));
        }
        
        return result;
    }
    
    /// Clean build artifacts
    private void cleanBuildArtifacts()
    {
        auto cacheDir = buildPath(workspaceDir, ".builder-cache");
        if (exists(cacheDir))
        {
            try
            {
                rmdirRecurse(cacheDir);
                writeln("  Cleaned cache directory");
            }
            catch (Exception e)
            {
                writeln("  \x1b[33m⚠ Failed to clean cache: ", e.msg, "\x1b[0m");
            }
        }
        
        // Also clean bin/ directory
        auto binDir = buildPath(workspaceDir, "bin");
        if (exists(binDir))
        {
            try
            {
                rmdirRecurse(binDir);
                writeln("  Cleaned bin directory");
            }
            catch (Exception e)
            {
                writeln("  \x1b[33m⚠ Failed to clean bin: ", e.msg, "\x1b[0m");
            }
        }
    }
    
    /// Cleanup entire workspace
    private void cleanupWorkspace()
    {
        if (exists(workspaceDir))
        {
            try
            {
                rmdirRecurse(workspaceDir);
                writeln("  \x1b[32m✓\x1b[0m Cleaned workspace");
            }
            catch (Exception e)
            {
                writeln("  \x1b[33m⚠ Failed to clean workspace: ", e.msg, "\x1b[0m");
            }
        }
    }
    
    /// Print single result
    private void printResult(in IntegrationResult result)
    {
        writeln("\n\x1b[36m[RESULT]\x1b[0m");
        writeln("  ┌─────────────────────────────────────────────────────────────┐");
        writeln(format("  │ Status:          %s                                        │", 
                result.success ? "\x1b[32mPASSED\x1b[0m" : "\x1b[31mFAILED\x1b[0m"));
        writeln(format("  │ Targets:         %12,d                             │", 
                result.targetCount));
        writeln(format("  │ Generation Time: %12,d ms                          │", 
                result.generationTime.total!"msecs"));
        writeln(format("  │ Build Time:      %12,d ms                          │", 
                result.buildTime.total!"msecs"));
        writeln(format("  │ Total Time:      %12,d ms                          │", 
                result.totalTime.total!"msecs"));
        
        if (result.buildTime.total!"msecs" > 0)
        {
            auto throughput = (result.targetCount * 1000.0) / result.buildTime.total!"msecs";
            writeln(format("  │ Throughput:      %12,d targets/sec                 │", 
                    cast(long)throughput));
        }
        
        if (!result.success)
        {
            writeln(format("  │ Error:           %-44s │", 
                    result.errorMessage[0 .. min($, 44)]));
        }
        
        writeln("  └─────────────────────────────────────────────────────────────┘");
    }
    
    /// Generate comprehensive report
    private void generateReport()
    {
        writeln("\n\n");
        writeln("╔════════════════════════════════════════════════════════════════╗");
        writeln("║              INTEGRATION BENCHMARK REPORT                      ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        
        if (results.empty)
        {
            writeln("No results to report.");
            return;
        }
        
        writeln("\n## Summary\n");
        writeln("| Scenario | Targets | Gen Time | Build Time | Total | Success |");
        writeln("|----------|---------|----------|------------|-------|---------|");
        
        foreach (result; results)
        {
            writeln(format("| %s | %,d | %,d ms | %,d ms | %,d ms | %s |",
                    result.scenarioName[0 .. min($, 30)],
                    result.targetCount,
                    result.generationTime.total!"msecs",
                    result.buildTime.total!"msecs",
                    result.totalTime.total!"msecs",
                    result.success ? "✓" : "✗"));
        }
        
        writeln();
        
        // Success rate
        auto successCount = results.count!(r => r.success);
        auto successRate = 100.0 * successCount / results.length;
        writeln(format("Success Rate: %d/%d (%.1f%%)", 
                successCount, results.length, successRate));
        
        // Performance analysis
        auto successResults = results.filter!(r => r.success).array;
        if (!successResults.empty)
        {
            writeln("\n## Performance Metrics (Successful Builds Only)\n");
            
            auto avgBuildTime = successResults.map!(r => r.buildTime.total!"msecs").sum / successResults.length;
            auto avgThroughput = successResults.map!(r => 
                (r.targetCount * 1000.0) / r.buildTime.total!"msecs").sum / successResults.length;
            
            writeln(format("- Average Build Time: %,d ms", avgBuildTime));
            writeln(format("- Average Throughput: %,d targets/second", cast(long)avgThroughput));
            
            // Find best and worst
            auto fastest = successResults.minElement!(r => r.buildTime);
            auto slowest = successResults.maxElement!(r => r.buildTime);
            
            writeln(format("\n- Fastest: %s (%,d ms)", 
                    fastest.scenarioName, fastest.buildTime.total!"msecs"));
            writeln(format("- Slowest: %s (%,d ms)", 
                    slowest.scenarioName, slowest.buildTime.total!"msecs"));
        }
        
        // Write to file
        writeReportToFile();
        
        writeln("\n\x1b[32m✓ Integration benchmark complete!\x1b[0m\n");
    }
    
    /// Write report to file
    private void writeReportToFile()
    {
        auto reportPath = "benchmark-integration-report.md";
        auto f = File(reportPath, "w");
        
        f.writeln("# Builder Integration Benchmark Report");
        f.writeln();
        f.writeln("Generated: ", Clock.currTime().toISOExtString());
        f.writeln();
        f.writeln("This report contains results from running the actual Builder system");
        f.writeln("with large-scale generated projects (50K-100K targets).");
        f.writeln();
        
        f.writeln("## Configuration");
        f.writeln();
        f.writeln("- Builder Binary: `", builderBinary, "`");
        f.writeln("- Workspace: `", workspaceDir, "`");
        f.writeln("- Project Type: Monorepo");
        f.writeln("- Average Dependencies: ~3.5 per target");
        f.writeln();
        
        f.writeln("## Results");
        f.writeln();
        f.writeln("| Scenario | Targets | Gen Time | Build Time | Total | Success |");
        f.writeln("|----------|---------|----------|------------|-------|---------|");
        
        foreach (result; results)
        {
            f.writeln(format("| %s | %,d | %,d ms | %,d ms | %,d ms | %s |",
                    result.scenarioName,
                    result.targetCount,
                    result.generationTime.total!"msecs",
                    result.buildTime.total!"msecs",
                    result.totalTime.total!"msecs",
                    result.success ? "✓" : "✗"));
        }
        
        f.writeln();
        f.writeln("## Detailed Results");
        f.writeln();
        
        foreach (result; results)
        {
            f.writeln("### ", result.scenarioName);
            f.writeln();
            f.writeln("- **Status**: ", result.success ? "✓ Success" : "✗ Failed");
            f.writeln("- **Targets**: ", format("%,d", result.targetCount));
            f.writeln("- **Generation Time**: ", format("%,d", result.generationTime.total!"msecs"), " ms");
            f.writeln("- **Build Time**: ", format("%,d", result.buildTime.total!"msecs"), " ms");
            f.writeln("- **Total Time**: ", format("%,d", result.totalTime.total!"msecs"), " ms");
            
            if (result.buildTime.total!"msecs" > 0)
            {
                auto throughput = (result.targetCount * 1000.0) / result.buildTime.total!"msecs";
                f.writeln("- **Throughput**: ", format("%,d", cast(long)throughput), " targets/second");
            }
            
            if (!result.success)
            {
                f.writeln("- **Error**: ", result.errorMessage);
            }
            
            f.writeln();
        }
        
        f.close();
        
        writeln("\n\x1b[36m[REPORT]\x1b[0m Detailed report written to: ", reportPath);
    }
}

/// Main entry point
void main(string[] args)
{
    import std.getopt;
    
    string workspaceDir = "integration-bench-workspace";
    string builderBinary = "./bin/builder";
    
    auto helpInfo = getopt(
        args,
        "workspace|w", "Workspace directory for benchmarks", &workspaceDir,
        "builder|b", "Path to Builder binary", &builderBinary
    );
    
    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(
            "Builder Integration Benchmark Tool\n" ~
            "Tests actual Builder system with large-scale projects\n\n" ~
            "Usage:",
            helpInfo.options
        );
        return;
    }
    
    auto bench = new IntegrationBenchmark(workspaceDir, builderBinary);
    bench.runAll();
}

