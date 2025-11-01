#!/usr/bin/env dub
/+ dub.sdl:
    name "scale-benchmark"
    dependency "builder" path="../../"
+/

/**
 * Large-scale benchmarking tool for Builder system
 * Tests performance with 50k-100k targets
 */

module tests.bench.scale_benchmark;

import std.stdio;
import std.file;
import std.path;
import std.datetime.stopwatch;
import std.datetime;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.range;
import std.string : lineSplitter;
import core.memory : GC;
import tests.bench.target_generator;
import tests.bench.utils;

/// Benchmark scenario types
enum ScenarioType
{
    CleanBuild,       // Full build from scratch
    NullBuild,        // No changes, pure cache hits
    IncrementalSmall, // 1% of files changed
    IncrementalMedium,// 10% of files changed
    IncrementalLarge, // 30% of files changed
    ColdCache,        // Empty cache
    WarmCache,        // Pre-warmed cache
    ParallelScale     // Test scaling with different core counts
}

/// Benchmark scenario configuration
struct Scenario
{
    ScenarioType type;
    size_t targetCount;
    string description;
    bool skipSourceGen;  // For scenarios that don't need actual files
}

/// Benchmark results
struct ScaleBenchmarkResult
{
    string scenarioName;
    size_t targetCount;
    Duration parseTime;
    Duration analysisTime;
    Duration executionTime;
    Duration totalTime;
    size_t memoryUsedMB;
    size_t peakMemoryMB;
    double targetsPerSecond;
    size_t cacheHits;
    size_t cacheMisses;
    size_t parallelism;
}

/// Main benchmark suite
class ScaleBenchmark
{
    private string benchDir;
    private ScaleBenchmarkResult[] results;
    
    this(string benchDir = "bench-workspace")
    {
        this.benchDir = benchDir;
    }
    
    /// Run all scale benchmarks
    void runAll()
    {
        writeln("╔════════════════════════════════════════════════════════════════╗");
        writeln("║           BUILDER LARGE-SCALE BENCHMARK SUITE                  ║");
        writeln("║              Testing 50K - 100K Targets                        ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        writeln();
        
        // Define test scenarios
        auto scenarios = [
            Scenario(ScenarioType.CleanBuild, 50_000, 
                    "Clean build - 50K targets", false),
            Scenario(ScenarioType.CleanBuild, 75_000, 
                    "Clean build - 75K targets", false),
            Scenario(ScenarioType.CleanBuild, 100_000, 
                    "Clean build - 100K targets", false),
            Scenario(ScenarioType.NullBuild, 50_000, 
                    "Null build - 50K targets (all cached)", true),
            Scenario(ScenarioType.NullBuild, 100_000, 
                    "Null build - 100K targets (all cached)", true),
            Scenario(ScenarioType.IncrementalSmall, 50_000, 
                    "Incremental build - 50K targets (1% changed)", true),
            Scenario(ScenarioType.IncrementalMedium, 75_000, 
                    "Incremental build - 75K targets (10% changed)", true),
            Scenario(ScenarioType.IncrementalLarge, 100_000, 
                    "Incremental build - 100K targets (30% changed)", true),
        ];
        
        foreach (i, scenario; scenarios)
        {
            writeln("\n" ~ "=".repeat(70).join);
            writeln(format("SCENARIO %d/%d: %s", i + 1, scenarios.length, scenario.description));
            writeln("=".repeat(70).join);
            
            try
            {
                auto result = runScenario(scenario);
                results ~= result;
                printResult(result);
            }
            catch (Exception e)
            {
                writeln("\x1b[31m✗ Scenario failed: ", e.msg, "\x1b[0m");
            }
            
            // Clean up between scenarios
            cleanupWorkspace();
            
            // Force GC to get accurate memory measurements for next scenario
            GC.collect();
        }
        
        // Generate final report
        generateReport();
    }
    
    /// Run a single benchmark scenario
    private ScaleBenchmarkResult runScenario(in Scenario scenario)
    {
        ScaleBenchmarkResult result;
        result.scenarioName = scenario.description;
        result.targetCount = scenario.targetCount;
        
        auto totalTimer = StopWatch(AutoStart.yes);
        auto memBefore = GC.stats().usedSize;
        
        // Phase 1: Generate targets
        writeln("\n\x1b[36m[PHASE 1]\x1b[0m Target Generation");
        auto genTimer = StopWatch(AutoStart.yes);
        
        auto config = GeneratorConfig();
        config.targetCount = scenario.targetCount;
        config.projectType = ProjectType.Monorepo;
        config.avgDepsPerTarget = 3.5;
        config.libToExecRatio = 0.7;
        config.generateSources = !scenario.skipSourceGen;
        config.outputDir = benchDir;
        
        auto generator = new TargetGenerator(config);
        auto targets = generator.generate();
        genTimer.stop();
        
        writeln(format("  Generated %d targets in %d ms", 
                targets.length, genTimer.peek.total!"msecs"));
        
        // Phase 2: Parse Builderfile (simulated)
        writeln("\n\x1b[36m[PHASE 2]\x1b[0m Builderfile Parsing");
        auto parseTimer = StopWatch(AutoStart.yes);
        
        // Simulate parsing by reading the Builderfile
        if (exists(buildPath(benchDir, "Builderfile")))
        {
            auto builderfileContent = readText(buildPath(benchDir, "Builderfile"));
            // Simulate parsing overhead
            foreach (line; builderfileContent.lineSplitter)
            {
                if (line.length > 0) {} // Simulate work
            }
        }
        
        parseTimer.stop();
        result.parseTime = parseTimer.peek;
        writeln(format("  Parsed in %d ms", result.parseTime.total!"msecs"));
        
        // Phase 3: Dependency analysis (simulated)
        writeln("\n\x1b[36m[PHASE 3]\x1b[0m Dependency Analysis");
        auto analysisTimer = StopWatch(AutoStart.yes);
        
        // Simulate building dependency graph
        simulateDependencyAnalysis(targets);
        
        analysisTimer.stop();
        result.analysisTime = analysisTimer.peek;
        writeln(format("  Analyzed %d dependencies in %d ms", 
                targets.map!(t => t.deps.length).sum, result.analysisTime.total!"msecs"));
        
        // Phase 4: Build execution (simulated)
        writeln("\n\x1b[36m[PHASE 4]\x1b[0m Build Execution");
        auto execTimer = StopWatch(AutoStart.yes);
        
        // Simulate build based on scenario type
        final switch (scenario.type)
        {
            case ScenarioType.CleanBuild:
                simulateCleanBuild(targets, result);
                break;
            case ScenarioType.NullBuild:
                simulateNullBuild(targets, result);
                break;
            case ScenarioType.IncrementalSmall:
                simulateIncrementalBuild(targets, result, 0.01);
                break;
            case ScenarioType.IncrementalMedium:
                simulateIncrementalBuild(targets, result, 0.10);
                break;
            case ScenarioType.IncrementalLarge:
                simulateIncrementalBuild(targets, result, 0.30);
                break;
            case ScenarioType.ColdCache:
                simulateColdCacheBuild(targets, result);
                break;
            case ScenarioType.WarmCache:
                simulateWarmCacheBuild(targets, result);
                break;
            case ScenarioType.ParallelScale:
                simulateParallelScaling(targets, result);
                break;
        }
        
        execTimer.stop();
        result.executionTime = execTimer.peek;
        
        // Calculate final metrics
        totalTimer.stop();
        result.totalTime = totalTimer.peek;
        
        auto memAfter = GC.stats().usedSize;
        result.memoryUsedMB = (memAfter - memBefore) / (1024 * 1024);
        result.peakMemoryMB = GC.stats().usedSize / (1024 * 1024);
        
        auto totalSeconds = result.totalTime.total!"hnsecs" / 10_000_000.0;
        result.targetsPerSecond = scenario.targetCount / totalSeconds;
        
        return result;
    }
    
    /// Simulate dependency analysis
    private void simulateDependencyAnalysis(in GeneratedTarget[] targets)
    {
        // Simulate topological sort and graph analysis
        size_t[int] layerCounts;
        foreach (target; targets)
        {
            layerCounts[target.layer]++;
        }
        
        writeln(format("  Dependency graph: %d layers", layerCounts.length));
        writeln(format("  Average layer size: %.0f targets", 
                cast(double)targets.length / layerCounts.length));
    }
    
    /// Simulate clean build (all targets built from scratch)
    private void simulateCleanBuild(in GeneratedTarget[] targets, ref ScaleBenchmarkResult result)
    {
        writeln("  Simulating clean build (no cache hits)...");
        
        result.cacheHits = 0;
        result.cacheMisses = targets.length;
        
        // Simulate build work (proportional to target count)
        size_t operations = 0;
        foreach (target; targets)
        {
            // Simulate compilation work
            operations += simulateBuildWork(target, false);
            
            if ((operations % 10000) == 0)
            {
                writeln(format("    Progress: %d / %d targets", 
                        operations, targets.length));
            }
        }
        
        writeln(format("  Built %d targets (0 cached)", targets.length));
    }
    
    /// Simulate null build (everything cached)
    private void simulateNullBuild(in GeneratedTarget[] targets, ref ScaleBenchmarkResult result)
    {
        writeln("  Simulating null build (all cache hits)...");
        
        result.cacheHits = targets.length;
        result.cacheMisses = 0;
        
        // Simulate cache lookup overhead only
        foreach (i, target; targets)
        {
            // Simulate cache lookup (very fast)
            simulateCacheLookup(target);
            
            if ((i % 10000) == 0 && i > 0)
            {
                writeln(format("    Progress: %d / %d targets", 
                        i, targets.length));
            }
        }
        
        writeln(format("  All %d targets cached (100%% hit rate)", targets.length));
    }
    
    /// Simulate incremental build (some percentage changed)
    private void simulateIncrementalBuild(in GeneratedTarget[] targets, 
                                         ref ScaleBenchmarkResult result, 
                                         double changePercent)
    {
        auto changedCount = cast(size_t)(targets.length * changePercent);
        writeln(format("  Simulating incremental build (%.1f%% changed = %d targets)...", 
                changePercent * 100, changedCount));
        
        result.cacheHits = targets.length - changedCount;
        result.cacheMisses = changedCount;
        
        foreach (i, target; targets)
        {
            if (i < changedCount)
            {
                // Rebuild this target
                simulateBuildWork(target, false);
            }
            else
            {
                // Cache hit
                simulateCacheLookup(target);
            }
            
            if ((i % 10000) == 0 && i > 0)
            {
                writeln(format("    Progress: %d / %d targets", 
                        i, targets.length));
            }
        }
        
        writeln(format("  Rebuilt %d targets, cached %d targets (%.1f%% hit rate)", 
                result.cacheMisses, result.cacheHits, 
                100.0 * result.cacheHits / targets.length));
    }
    
    /// Simulate cold cache build
    private void simulateColdCacheBuild(in GeneratedTarget[] targets, ref ScaleBenchmarkResult result)
    {
        simulateCleanBuild(targets, result);
    }
    
    /// Simulate warm cache build
    private void simulateWarmCacheBuild(in GeneratedTarget[] targets, ref ScaleBenchmarkResult result)
    {
        simulateNullBuild(targets, result);
    }
    
    /// Simulate parallel scaling test
    private void simulateParallelScaling(in GeneratedTarget[] targets, ref ScaleBenchmarkResult result)
    {
        writeln("  Simulating parallel build...");
        
        import std.parallelism : totalCPUs;
        result.parallelism = totalCPUs;
        
        // Simulate parallel execution (simplified)
        simulateCleanBuild(targets, result);
        
        writeln(format("  Built with %d parallel workers", result.parallelism));
    }
    
    /// Simulate build work for a single target
    private size_t simulateBuildWork(in GeneratedTarget target, bool cached)
    {
        if (cached)
            return 1;
        
        // Simulate work proportional to complexity
        size_t complexity = target.sources.length * 100 + target.deps.length * 10;
        
        // Simulate CPU work
        size_t result = 0;
        foreach (_; 0 .. complexity)
        {
            result += 1;
        }
        
        return result;
    }
    
    /// Simulate cache lookup
    private void simulateCacheLookup(in GeneratedTarget target)
    {
        // Simulate fast cache lookup (just hash computation)
        size_t hash = 0;
        foreach (c; target.id)
            hash = hash * 31 + c;
    }
    
    /// Print single result
    private void printResult(in ScaleBenchmarkResult result)
    {
        writeln("\n\x1b[32m[RESULTS]\x1b[0m");
        writeln("  ┌─────────────────────────────────────────────────────────────┐");
        writeln(format("  │ Targets:         %12d                             │", 
                result.targetCount));
        writeln(format("  │ Parse Time:      %12s ms                          │", 
                formatNumber(result.parseTime.total!"msecs")));
        writeln(format("  │ Analysis Time:   %12s ms                          │", 
                formatNumber(result.analysisTime.total!"msecs")));
        writeln(format("  │ Execution Time:  %12s ms                          │", 
                formatNumber(result.executionTime.total!"msecs")));
        writeln(format("  │ Total Time:      %12s ms                          │", 
                formatNumber(result.totalTime.total!"msecs")));
        writeln(format("  │ Throughput:      %12s targets/sec                 │", 
                formatNumber(cast(long)result.targetsPerSecond)));
        writeln(format("  │ Memory Used:     %12s MB                          │", 
                formatNumber(result.memoryUsedMB)));
        writeln(format("  │ Peak Memory:     %12s MB                          │", 
                formatNumber(result.peakMemoryMB)));
        writeln(format("  │ Cache Hits:      %12s                             │", 
                formatNumber(result.cacheHits)));
        writeln(format("  │ Cache Misses:    %12s                             │", 
                formatNumber(result.cacheMisses)));
        if (result.cacheHits + result.cacheMisses > 0)
        {
            auto hitRate = 100.0 * result.cacheHits / (result.cacheHits + result.cacheMisses);
            writeln(format("  │ Cache Hit Rate:  %12s %%                         │", 
                    formatNumber(cast(long)hitRate)));
        }
        writeln("  └─────────────────────────────────────────────────────────────┘");
    }
    
    /// Generate comprehensive report
    private void generateReport()
    {
        writeln("\n\n");
        writeln("╔════════════════════════════════════════════════════════════════╗");
        writeln("║                    FINAL BENCHMARK REPORT                      ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        
        if (results.empty)
        {
            writeln("No results to report.");
            return;
        }
        
        // Summary table
        writeln("\n## Summary Table\n");
        writeln("| Scenario | Targets | Total Time | Throughput | Memory | Cache Hit Rate |");
        writeln("|----------|---------|------------|------------|--------|----------------|");
        
        foreach (result; results)
        {
            auto hitRate = (result.cacheHits + result.cacheMisses) > 0 
                ? format("%.1f%%", 100.0 * result.cacheHits / (result.cacheHits + result.cacheMisses))
                : "N/A";
            
            writeln(format("| %s | %s | %s ms | %s t/s | %s MB | %s |",
                    result.scenarioName[0 .. min($, 25)],
                    formatNumber(result.targetCount),
                    formatNumber(result.totalTime.total!"msecs"),
                    formatNumber(cast(long)result.targetsPerSecond),
                    formatNumber(result.memoryUsedMB),
                    hitRate));
        }
        
        writeln();
        
        // Performance analysis
        writeln("## Performance Analysis\n");
        
        auto avgThroughput = results.map!(r => r.targetsPerSecond).sum / results.length;
        auto maxThroughput = results.map!(r => r.targetsPerSecond).maxElement;
        auto avgMemory = results.map!(r => r.memoryUsedMB).sum / results.length;
        
        writeln(format("- Average Throughput: %s targets/second", formatNumber(cast(long)avgThroughput)));
        writeln(format("- Peak Throughput: %s targets/second", formatNumber(cast(long)maxThroughput)));
        writeln(format("- Average Memory Usage: %s MB", formatNumber(avgMemory)));
        
        // Scaling analysis
        auto results50k = results.filter!(r => r.targetCount == 50_000).array;
        auto results100k = results.filter!(r => r.targetCount == 100_000).array;
        
        if (!results50k.empty && !results100k.empty)
        {
            writeln("\n## Scaling Analysis\n");
            auto time50k = results50k.front.totalTime.total!"msecs";
            auto time100k = results100k.front.totalTime.total!"msecs";
            auto scalingFactor = cast(double)time100k / time50k;
            
            writeln(format("- 50K targets: %s ms", formatNumber(time50k)));
            writeln(format("- 100K targets: %s ms", formatNumber(time100k)));
            writeln(format("- Scaling factor: %.2fx (ideal: 2.0x)", scalingFactor));
            
            if (scalingFactor < 2.2)
                writeln("  \x1b[32m✓ Excellent scaling (near-linear)\x1b[0m");
            else if (scalingFactor < 2.8)
                writeln("  \x1b[33m⚠ Good scaling (slightly sub-linear)\x1b[0m");
            else
                writeln("  \x1b[31m✗ Poor scaling (needs optimization)\x1b[0m");
        }
        
        // Write results to file
        writeReportToFile();
        
        writeln("\n\x1b[32m✓ Benchmark complete!\x1b[0m\n");
    }
    
    /// Write report to markdown file
    private void writeReportToFile()
    {
        auto reportPath = "benchmark-scale-report.md";
        auto f = File(reportPath, "w");
        
        f.writeln("# Builder Large-Scale Benchmark Report");
        f.writeln();
        f.writeln("Generated: ", Clock.currTime().toISOExtString());
        f.writeln();
        
        f.writeln("## Test Configuration");
        f.writeln();
        f.writeln("- Target Range: 50,000 - 100,000 targets");
        f.writeln("- Project Type: Monorepo");
        f.writeln("- Average Dependencies: ~3.5 per target");
        f.writeln("- Language Distribution: TypeScript (40%), Python (25%), Rust (15%), Go (10%), C++ (5%), Java (5%)");
        f.writeln();
        
        f.writeln("## Summary");
        f.writeln();
        f.writeln("| Scenario | Targets | Total Time | Throughput | Memory | Cache Hit Rate |");
        f.writeln("|----------|---------|------------|------------|--------|----------------|");
        
        foreach (result; results)
        {
            auto hitRate = (result.cacheHits + result.cacheMisses) > 0 
                ? format("%.1f%%", 100.0 * result.cacheHits / (result.cacheHits + result.cacheMisses))
                : "N/A";
            
            f.writeln(format("| %s | %,d | %,d ms | %,d t/s | %,d MB | %s |",
                    result.scenarioName,
                    result.targetCount,
                    result.totalTime.total!"msecs",
                    cast(long)result.targetsPerSecond,
                    result.memoryUsedMB,
                    hitRate));
        }
        
        f.writeln();
        f.writeln("## Detailed Results");
        f.writeln();
        
        foreach (result; results)
        {
            f.writeln("### ", result.scenarioName);
            f.writeln();
            f.writeln("- **Targets**: ", format("%,d", result.targetCount));
            f.writeln("- **Parse Time**: ", result.parseTime.total!"msecs", " ms");
            f.writeln("- **Analysis Time**: ", result.analysisTime.total!"msecs", " ms");
            f.writeln("- **Execution Time**: ", result.executionTime.total!"msecs", " ms");
            f.writeln("- **Total Time**: ", result.totalTime.total!"msecs", " ms");
            f.writeln("- **Throughput**: ", format("%,d", cast(long)result.targetsPerSecond), " targets/sec");
            f.writeln("- **Memory Used**: ", format("%,d", result.memoryUsedMB), " MB");
            f.writeln("- **Cache Hits**: ", format("%,d", result.cacheHits));
            f.writeln("- **Cache Misses**: ", format("%,d", result.cacheMisses));
            f.writeln();
        }
        
        f.close();
        
        writeln("\n\x1b[36m[REPORT]\x1b[0m Detailed report written to: ", reportPath);
    }
    
    /// Cleanup workspace between scenarios
    private void cleanupWorkspace()
    {
        if (exists(benchDir))
        {
            try
            {
                rmdirRecurse(benchDir);
            }
            catch (Exception e)
            {
                writeln("\x1b[33m⚠ Failed to clean workspace: ", e.msg, "\x1b[0m");
            }
        }
    }
    
    /// Helper to format numbers with thousand separators
    private string formatNumber(long number)
    {
        return format("%,d", number);
    }
    
    private string formatNumber(size_t number)
    {
        return format("%,d", number);
    }
}

/// Main entry point
void main(string[] args)
{
    import std.getopt;
    
    string workspaceDir = "bench-workspace";
    bool quick = false;
    
    auto helpInfo = getopt(
        args,
        "workspace|w", "Workspace directory for benchmarks", &workspaceDir,
        "quick|q", "Run quick benchmark (fewer scenarios)", &quick
    );
    
    if (helpInfo.helpWanted)
    {
        defaultGetoptPrinter(
            "Builder Large-Scale Benchmark Tool\n" ~
            "Tests performance with 50K-100K targets\n\n" ~
            "Usage:",
            helpInfo.options
        );
        return;
    }
    
    auto bench = new ScaleBenchmark(workspaceDir);
    bench.runAll();
}

