#!/usr/bin/env dub
/+ dub.sdl:
    name "comparative-benchmark"
    dependency "builder" path="../../../"
+/

/**
 * Comparative Benchmark Tool - Main Entry Point
 * 
 * Comprehensive benchmarking suite comparing Builder against
 * Buck2, Bazel, and Pants across multiple scenarios
 */

module tests.bench.comparative.main;

import tests.bench.comparative.architecture;
import tests.bench.comparative.adapters;
import tests.bench.comparative.runner;
import tests.bench.comparative.report;
import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.conv;

void main(string[] args)
{
    // Configuration
    string workspaceDir = "bench-comparative-workspace";
    string outputReport = "benchmark-comparative-report.md";
    bool quick = false;
    bool builderOnly = false;
    string[] systemsFilter;
    string[] scenariosFilter;
    
    auto helpInfo = getopt(
        args,
        "workspace|w", "Workspace directory for benchmarks", &workspaceDir,
        "output|o", "Output report path", &outputReport,
        "quick|q", "Quick benchmark (fewer runs)", &quick,
        "builder-only", "Only benchmark Builder (skip competitors)", &builderOnly,
        "systems|s", "Systems to test (comma-separated: builder,buck2,bazel,pants)", &systemsFilter,
        "scenarios", "Scenarios to test (comma-separated)", &scenariosFilter
    );
    
    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(
            "Builder Comparative Benchmark Tool\n" ~
            "Compare Builder against Buck2, Bazel, and Pants\n\n" ~
            "Usage:",
            helpInfo.options
        );
        return;
    }
    
    printBanner();
    
    // Create benchmark configuration
    auto config = createConfig(quick, builderOnly, systemsFilter, scenariosFilter);
    config.workspaceDir = workspaceDir;
    
    writeln("Configuration:");
    writeln(format("  Workspace: %s", workspaceDir));
    writeln(format("  Output: %s", outputReport));
    writeln(format("  Systems: %s", config.systems));
    writeln(format("  Scenarios: %d", config.scenarios.length));
    writeln(format("  Projects: %d", config.projects.length));
    writeln(format("  Runs per scenario: %d", config.runsPerScenario));
    writeln();
    
    // Check prerequisites
    writeln("Checking prerequisites...");
    checkPrerequisites(config.systems);
    writeln();
    
    // Run benchmarks
    auto runner = new BenchmarkRunner(workspaceDir, true);
    auto resultsResult = runner.runAll(config);
    
    if (resultsResult.isErr)
    {
        writeln("\x1b[31m✗ Benchmark failed: ", resultsResult.error, "\x1b[0m");
        return;
    }
    
    auto results = resultsResult.unwrap;
    
    // Generate report
    writeln("\nGenerating report...");
    runner.generateReport(results, outputReport);
    
    // Print summary
    printSummary(results);
    
    writeln("\n\x1b[32m✓ Benchmark complete!\x1b[0m");
    writeln(format("  Report: %s", outputReport));
}

void printBanner()
{
    writeln("╔════════════════════════════════════════════════════════════════╗");
    writeln("║     BUILDER COMPARATIVE BENCHMARK SUITE                        ║");
    writeln("║                                                                ║");
    writeln("║     Testing Builder vs Buck2, Bazel, and Pants                ║");
    writeln("╚════════════════════════════════════════════════════════════════╝");
    writeln();
}

BenchmarkConfig createConfig(bool quick, bool builderOnly, string[] systemsFilter, string[] scenariosFilter)
{
    BenchmarkConfig config;
    
    // Systems to test
    if (builderOnly)
    {
        config.systems = [BuildSystem.Builder];
    }
    else if (systemsFilter.length > 0)
    {
        foreach (sys; systemsFilter)
        {
            import std.string : toLower;
            auto sysLower = sys.toLower;
            
            if (sysLower == "builder")
                config.systems ~= BuildSystem.Builder;
            else if (sysLower == "buck2")
                config.systems ~= BuildSystem.Buck2;
            else if (sysLower == "bazel")
                config.systems ~= BuildSystem.Bazel;
            else if (sysLower == "pants")
                config.systems ~= BuildSystem.Pants;
        }
    }
    else
    {
        config.systems = [
            BuildSystem.Builder,
            BuildSystem.Buck2,
            BuildSystem.Bazel,
            BuildSystem.Pants
        ];
    }
    
    // Scenarios
    if (quick)
    {
        config.scenarios = [
            ScenarioType.CleanBuild,
            ScenarioType.NullBuild
        ];
        config.runsPerScenario = 3;
    }
    else
    {
        config.scenarios = [
            ScenarioType.CleanBuild,
            ScenarioType.NullBuild,
            ScenarioType.IncrementalSmall,
            ScenarioType.IncrementalMedium,
            ScenarioType.IncrementalLarge
        ];
        config.runsPerScenario = 5;
    }
    
    // Projects with varying complexity
    config.projects = [
        createProject("small", Complexity.Small, 50),
        createProject("medium", Complexity.Medium, 500),
        createProject("large", Complexity.Large, 2000)
    ];
    
    if (!quick)
    {
        config.projects ~= createProject("very-large", Complexity.VeryLarge, 10_000);
    }
    
    return config;
}

ProjectConfig createProject(string name, Complexity complexity, size_t targetCount)
{
    ProjectConfig project;
    project.name = name;
    project.complexity = complexity;
    project.targetCount = targetCount;
    project.languages = LanguageDistribution();
    project.avgDependenciesPerTarget = 3.5;
    project.libToExecRatio = 0.7;
    project.generateRealSources = true;
    project.complexDependencyGraph = true;
    
    return project;
}

void checkPrerequisites(BuildSystem[] systems)
{
    foreach (system; systems)
    {
        auto adapter = AdapterFactory.create(system);
        auto installed = adapter.isInstalled();
        
        if (installed.isOk && installed.unwrap)
        {
            auto version_ = adapter.getVersion();
            if (version_.isOk)
                writeln(format("  ✓ %s: %s", system, version_.unwrap));
            else
                writeln(format("  ✓ %s: installed", system));
        }
        else
        {
            writeln(format("  ⚠ %s: not installed", system));
            
            // Provide installation instructions
            final switch (system)
            {
                case BuildSystem.Builder:
                    writeln("     Build with: make");
                    break;
                case BuildSystem.Buck2:
                    writeln("     Install with: brew install buck2");
                    break;
                case BuildSystem.Bazel:
                    writeln("     Install with: brew install bazel");
                    break;
                case BuildSystem.Pants:
                    writeln("     Install with: pip install pantsbuild.pants");
                    break;
            }
        }
    }
}

void printSummary(in BenchmarkResult[] results)
{
    writeln("\n╔════════════════════════════════════════════════════════════════╗");
    writeln("║                    BENCHMARK SUMMARY                           ║");
    writeln("╚════════════════════════════════════════════════════════════════╝");
    writeln();
    
    // Group by system
    size_t[BuildSystem] successCounts;
    size_t[BuildSystem] totalCounts;
    
    foreach (result; results)
    {
        totalCounts[result.system]++;
        if (result.runs.length > 0)
            successCounts[result.system]++;
    }
    
    writeln("Results by System:");
    foreach (system; [BuildSystem.Builder, BuildSystem.Buck2, BuildSystem.Bazel, BuildSystem.Pants])
    {
        if (system in totalCounts)
        {
            auto success = successCounts.get(system, 0);
            auto total = totalCounts[system];
            auto rate = total > 0 ? (cast(double)success / total * 100) : 0.0;
            
            writeln(format("  %s: %d/%d scenarios (%.0f%%)", 
                system, success, total, rate));
        }
    }
    
    writeln();
    
    // Calculate averages for successful runs
    writeln("Average Performance:");
    foreach (system; [BuildSystem.Builder, BuildSystem.Buck2, BuildSystem.Bazel, BuildSystem.Pants])
    {
        auto systemResults = results.filter!(r => r.system == system && r.runs.length > 0).array;
        
        if (systemResults.empty)
            continue;
        
        double totalThroughput = 0;
        double totalCacheHit = 0;
        
        foreach (result; systemResults)
        {
            auto avg = result.average;
            totalThroughput += avg.targetsPerSecond;
            totalCacheHit += avg.cacheHitRate;
        }
        
        auto avgThroughput = totalThroughput / systemResults.length;
        auto avgCacheHit = totalCacheHit / systemResults.length;
        
        writeln(format("  %s: %.0f t/s, %.1f%% cache hit", 
            system, avgThroughput, avgCacheHit * 100));
    }
}

