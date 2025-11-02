/**
 * Comparative Benchmark Runner
 * 
 * Orchestrates multi-system benchmarking with statistical rigor
 */

module tests.bench.comparative.runner;

import tests.bench.comparative.architecture;
import tests.bench.comparative.adapters;
import std.stdio;
import std.file;
import std.path;
import std.datetime.stopwatch;
import std.datetime : Duration, Clock;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.string;
import core.memory : GC;

/// Benchmark runner implementation
class BenchmarkRunner : IBenchmarkRunner
{
    private string workspaceDir;
    private bool verbose;
    
    this(string workspaceDir = "bench-comparative", bool verbose = true)
    {
        this.workspaceDir = workspaceDir;
        this.verbose = verbose;
    }
    
    override Result!BenchmarkResult runScenario(
        IBuildSystemAdapter adapter,
        ScenarioType scenario,
        in ProjectConfig project
    )
    {
        try
        {
            log(format("═══ %s: %s ═══", adapter.system, scenario));
            
            // Check if system is installed
            auto installedCheck = adapter.isInstalled();
            if (installedCheck.isErr)
            {
                log(format("⚠ %s", installedCheck.error), true);
                BenchmarkResult result;
                result.system = adapter.system;
                result.scenario = scenario;
                result.project = project;
                return Result!BenchmarkResult(result);
            }
            
            // Get version
            auto versionResult = adapter.getVersion();
            if (versionResult.isOk)
                log(format("Version: %s", versionResult.unwrap));
            
            // Create project directory
            auto systemName = to!string(adapter.system).toLower;
            auto scenarioName = to!string(scenario).toLower;
            auto projectDir = buildPath(workspaceDir, format("%s-%s-%s", 
                systemName, scenarioName, project.name));
            
            // Generate project
            log("Generating project...");
            auto genResult = adapter.generateProject(project, projectDir);
            if (genResult.isErr)
                return Result!BenchmarkResult(genResult.error);
            
            log(format("Project: %s (%d targets)", projectDir, project.targetCount));
            
            BenchmarkResult result;
            result.system = adapter.system;
            result.scenario = scenario;
            result.project = project;
            
            // Run scenario based on type
            final switch (scenario)
            {
                case ScenarioType.CleanBuild:
                    runCleanBuild(adapter, projectDir, result);
                    break;
                case ScenarioType.NullBuild:
                    runNullBuild(adapter, projectDir, result);
                    break;
                case ScenarioType.IncrementalSmall:
                    runIncrementalBuild(adapter, projectDir, result, 0.01);
                    break;
                case ScenarioType.IncrementalMedium:
                    runIncrementalBuild(adapter, projectDir, result, 0.10);
                    break;
                case ScenarioType.IncrementalLarge:
                    runIncrementalBuild(adapter, projectDir, result, 0.30);
                    break;
                case ScenarioType.Parallel:
                    runParallelBuild(adapter, projectDir, result);
                    break;
                case ScenarioType.LargeScale:
                case ScenarioType.MassiveScale:
                    runCleanBuild(adapter, projectDir, result);
                    break;
                case ScenarioType.ColdStart:
                    runColdStart(adapter, projectDir, result);
                    break;
                case ScenarioType.WarmCache:
                    runWarmCache(adapter, projectDir, result);
                    break;
            }
            
            // Cleanup
            if (exists(projectDir))
                rmdirRecurse(projectDir);
            
            logResults(result);
            
            return Result!BenchmarkResult(result);
        }
        catch (Exception e)
        {
            return Result!BenchmarkResult("Benchmark failed: " ~ e.msg);
        }
    }
    
    override Result!(BenchmarkResult[]) runAll(in BenchmarkConfig config)
    {
        log("╔════════════════════════════════════════════════════════════════╗");
        log("║        COMPARATIVE BUILD SYSTEM BENCHMARK SUITE                ║");
        log("╚════════════════════════════════════════════════════════════════╝");
        log("");
        
        BenchmarkResult[] results;
        
        // Prepare workspace
        if (exists(workspaceDir))
            rmdirRecurse(workspaceDir);
        mkdirRecurse(workspaceDir);
        
        size_t totalScenarios = config.systems.length * config.scenarios.length * config.projects.length;
        size_t current = 0;
        
        // Run all combinations
        foreach (system; config.systems)
        {
            log(format("\n━━━ Testing %s ━━━", system));
            
            auto adapter = AdapterFactory.create(system);
            
            foreach (scenario; config.scenarios)
            {
                foreach (project; config.projects)
                {
                    current++;
                    log(format("\n[%d/%d] %s - %s - %s", 
                        current, totalScenarios, system, scenario, project.name));
                    
                    auto result = runScenario(adapter, scenario, project);
                    if (result.isOk)
                    {
                        results ~= result.unwrap;
                    }
                    else
                    {
                        log(format("✗ Failed: %s", result.error), true);
                    }
                    
                    // Force GC between runs
                    if (config.cleanBetweenRuns)
                        GC.collect();
                }
            }
        }
        
        log("\n╔════════════════════════════════════════════════════════════════╗");
        log(format("║ Completed %d / %d scenarios", results.length, totalScenarios));
        log("╚════════════════════════════════════════════════════════════════╝");
        
        return Result!(BenchmarkResult[])(results);
    }
    
    override void generateReport(in BenchmarkResult[] results, string outputPath)
    {
        import tests.bench.comparative.report;
        auto generator = new ReportGenerator();
        generator.generate(results, outputPath);
    }
    
    private void runCleanBuild(IBuildSystemAdapter adapter, string projectDir, 
                               ref BenchmarkResult result)
    {
        log("Running clean builds...");
        
        foreach (run; 0 .. 5)  // 5 runs for statistical significance
        {
            log(format("  Run %d/5", run + 1));
            
            auto metrics = adapter.build(projectDir, false);
            if (metrics.isOk)
            {
                result.runs ~= metrics.unwrap;
                log(format("    Time: %d ms", metrics.unwrap.totalTime.total!"msecs"));
            }
            else
            {
                log(format("    Failed: %s", metrics.error), true);
            }
        }
    }
    
    private void runNullBuild(IBuildSystemAdapter adapter, string projectDir,
                              ref BenchmarkResult result)
    {
        log("Running null builds (cached)...");
        
        // First, do a clean build to populate cache
        log("  Initial build (populating cache)...");
        auto initialBuild = adapter.build(projectDir, false);
        if (initialBuild.isErr)
        {
            log(format("  Initial build failed: %s", initialBuild.error), true);
            return;
        }
        
        // Now run cached builds
        foreach (run; 0 .. 5)
        {
            log(format("  Cached run %d/5", run + 1));
            
            auto metrics = adapter.build(projectDir, true);
            if (metrics.isOk)
            {
                result.runs ~= metrics.unwrap;
                log(format("    Time: %d ms", metrics.unwrap.totalTime.total!"msecs"));
            }
            else
            {
                log(format("    Failed: %s", metrics.error), true);
            }
        }
    }
    
    private void runIncrementalBuild(IBuildSystemAdapter adapter, string projectDir,
                                     ref BenchmarkResult result, double changePercent)
    {
        log(format("Running incremental builds (%.1f%% changed)...", changePercent * 100));
        
        // Initial build
        log("  Initial build...");
        auto initialBuild = adapter.build(projectDir, false);
        if (initialBuild.isErr)
        {
            log(format("  Initial build failed: %s", initialBuild.error), true);
            return;
        }
        
        // Modify files and rebuild
        foreach (run; 0 .. 5)
        {
            log(format("  Incremental run %d/5", run + 1));
            
            // Modify files
            auto modifyResult = adapter.modifyFiles(projectDir, changePercent);
            if (modifyResult.isErr)
            {
                log(format("    Modify failed: %s", modifyResult.error), true);
                continue;
            }
            
            // Rebuild
            auto metrics = adapter.build(projectDir, true);
            if (metrics.isOk)
            {
                result.runs ~= metrics.unwrap;
                log(format("    Time: %d ms", metrics.unwrap.totalTime.total!"msecs"));
            }
            else
            {
                log(format("    Failed: %s", metrics.error), true);
            }
        }
    }
    
    private void runParallelBuild(IBuildSystemAdapter adapter, string projectDir,
                                  ref BenchmarkResult result)
    {
        // Same as clean build but emphasizes parallel performance
        runCleanBuild(adapter, projectDir, result);
    }
    
    private void runColdStart(IBuildSystemAdapter adapter, string projectDir,
                              ref BenchmarkResult result)
    {
        // Same as clean build
        runCleanBuild(adapter, projectDir, result);
    }
    
    private void runWarmCache(IBuildSystemAdapter adapter, string projectDir,
                              ref BenchmarkResult result)
    {
        // Same as null build
        runNullBuild(adapter, projectDir, result);
    }
    
    private void log(string message, bool isError = false)
    {
        if (verbose || isError)
        {
            if (isError)
                writeln("\x1b[31m", message, "\x1b[0m");
            else
                writeln(message);
        }
    }
    
    private void logResults(in BenchmarkResult result)
    {
        if (result.runs.length == 0)
        {
            log("  ⚠ No successful runs", true);
            return;
        }
        
        auto avg = result.average;
        log(format("\n  Results (%d runs):", result.runs.length));
        log(format("    Average time:  %d ms", avg.totalTime.total!"msecs"));
        log(format("    Throughput:    %.0f targets/sec", avg.targetsPerSecond));
        log(format("    Memory:        %d MB", avg.memoryUsedMB));
        log(format("    Cache hit rate: %.1f%%", avg.cacheHitRate * 100));
    }
}

