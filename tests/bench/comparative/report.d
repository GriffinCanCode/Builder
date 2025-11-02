/**
 * Comparative Report Generator
 * 
 * Generates comprehensive markdown reports comparing build systems
 */

module tests.bench.comparative.report;

import tests.bench.comparative.architecture;
import std.stdio;
import std.file;
import std.datetime : Clock;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.string;

/// Report generator
class ReportGenerator
{
    /// Generate comprehensive comparative report
    void generate(in BenchmarkResult[] results, string outputPath)
    {
        auto f = File(outputPath, "w");
        
        writeHeader(f, results);
        writeExecutiveSummary(f, results);
        writeSystemComparison(f, results);
        writeScenarioAnalysis(f, results);
        writeDetailedResults(f, results);
        writeStatisticalAnalysis(f, results);
        writeRecommendations(f, results);
        writeFooter(f);
        
        f.close();
        
        writeln(format("\n\x1b[32m✓ Report generated: %s\x1b[0m", outputPath));
    }
    
    private void writeHeader(File f, in BenchmarkResult[] results)
    {
        f.writeln("# Comparative Build System Benchmark Report");
        f.writeln();
        f.writeln("**Generated:** ", Clock.currTime().toISOExtString());
        f.writeln("**Systems Tested:** ", getSystemsList(results));
        f.writeln("**Total Scenarios:** ", results.length);
        f.writeln();
        f.writeln("---");
        f.writeln();
    }
    
    private void writeExecutiveSummary(File f, in BenchmarkResult[] results)
    {
        f.writeln("## Executive Summary");
        f.writeln();
        
        // Group results by system
        auto bySystem = groupBySystem(results);
        
        f.writeln("### Overall Performance Rankings");
        f.writeln();
        f.writeln("| Rank | System | Avg Time | Throughput | Cache Hit Rate | Memory |");
        f.writeln("|------|--------|----------|------------|----------------|--------|");
        
        // Calculate rankings
        struct SystemStats
        {
            BuildSystem system;
            double avgTime;
            double avgThroughput;
            double avgCacheHit;
            size_t avgMemory;
            double score;
        }
        
        SystemStats[] stats;
        
        foreach (system, systemResults; bySystem)
        {
            auto stat = SystemStats(system);
            
            foreach (result; systemResults)
            {
                if (result.runs.length > 0)
                {
                    auto avg = result.average;
                    stat.avgTime += avg.totalTime.total!"msecs";
                    stat.avgThroughput += avg.targetsPerSecond;
                    stat.avgCacheHit += avg.cacheHitRate;
                    stat.avgMemory += avg.memoryUsedMB;
                }
            }
            
            auto count = systemResults.length;
            if (count > 0)
            {
                stat.avgTime /= count;
                stat.avgThroughput /= count;
                stat.avgCacheHit /= count;
                stat.avgMemory /= count;
                
                // Calculate composite score (lower time, higher throughput = better)
                stat.score = (stat.avgThroughput / stat.avgTime) * 1000;
            }
            
            stats ~= stat;
        }
        
        // Sort by score
        stats.sort!((a, b) => a.score > b.score);
        
        foreach (rank, stat; stats)
        {
            f.writeln(format("| %d | %s | %d ms | %.0f t/s | %.1f%% | %d MB |",
                rank + 1,
                stat.system,
                cast(long)stat.avgTime,
                stat.avgThroughput,
                stat.avgCacheHit * 100,
                stat.avgMemory));
        }
        
        f.writeln();
        
        // Key findings
        f.writeln("### Key Findings");
        f.writeln();
        
        if (stats.length >= 2)
        {
            auto best = stats[0];
            auto baseline = stats.find!(s => s.system == BuildSystem.Builder);
            
            f.writeln(format("- **Fastest System:** %s (%.0f targets/sec average)", 
                best.system, best.avgThroughput));
            
            if (!baseline.empty)
            {
                auto builderStats = baseline.front;
                auto speedup = best.avgThroughput / builderStats.avgThroughput;
                f.writeln(format("- **Builder Performance:** %.2fx relative to fastest", speedup));
            }
        }
        
        f.writeln();
        f.writeln("---");
        f.writeln();
    }
    
    private void writeSystemComparison(File f, in BenchmarkResult[] results)
    {
        f.writeln("## System-by-System Comparison");
        f.writeln();
        
        auto bySystem = groupBySystem(results);
        
        foreach (system, systemResults; bySystem)
        {
            f.writeln(format("### %s", system));
            f.writeln();
            
            if (systemResults.empty || systemResults[0].runs.empty)
            {
                f.writeln("*No successful benchmark runs*");
                f.writeln();
                continue;
            }
            
            // Aggregate statistics
            double totalTime = 0;
            double totalThroughput = 0;
            double totalCacheHit = 0;
            size_t totalMemory = 0;
            size_t successCount = 0;
            
            foreach (result; systemResults)
            {
                if (result.runs.length > 0)
                {
                    auto avg = result.average;
                    totalTime += avg.totalTime.total!"msecs";
                    totalThroughput += avg.targetsPerSecond;
                    totalCacheHit += avg.cacheHitRate;
                    totalMemory += avg.memoryUsedMB;
                    successCount++;
                }
            }
            
            if (successCount > 0)
            {
                f.writeln("**Performance Metrics:**");
                f.writeln();
                f.writeln(format("- Average Build Time: %.0f ms", totalTime / successCount));
                f.writeln(format("- Average Throughput: %.0f targets/sec", totalThroughput / successCount));
                f.writeln(format("- Average Cache Hit Rate: %.1f%%", (totalCacheHit / successCount) * 100));
                f.writeln(format("- Average Memory Usage: %d MB", totalMemory / successCount));
                f.writeln();
                
                // Strengths and weaknesses
                f.writeln("**Analysis:**");
                f.writeln();
                analyzeSystem(f, system, systemResults);
            }
            
            f.writeln();
        }
        
        f.writeln("---");
        f.writeln();
    }
    
    private void writeScenarioAnalysis(File f, in BenchmarkResult[] results)
    {
        f.writeln("## Scenario Analysis");
        f.writeln();
        
        auto byScenario = groupByScenario(results);
        
        foreach (scenario, scenarioResults; byScenario)
        {
            f.writeln(format("### %s", scenario));
            f.writeln();
            
            f.writeln("| System | Avg Time | Best Time | Worst Time | Throughput | Std Dev |");
            f.writeln("|--------|----------|-----------|------------|------------|---------|");
            
            foreach (result; scenarioResults)
            {
                if (result.runs.empty)
                    continue;
                
                auto avg = result.average;
                auto best = result.best;
                auto worst = result.worst;
                
                f.writeln(format("| %s | %d ms | %d ms | %d ms | %.0f t/s | %.1f ms |",
                    result.system,
                    avg.totalTime.total!"msecs",
                    best.totalTime.total!"msecs",
                    worst.totalTime.total!"msecs",
                    avg.targetsPerSecond,
                    result.stdDev));
            }
            
            f.writeln();
            
            // Winner for this scenario
            if (!scenarioResults.empty)
            {
                auto winner = scenarioResults.minElement!(r => 
                    r.runs.empty ? long.max : r.average.totalTime.total!"msecs");
                
                if (!winner.runs.empty)
                {
                    f.writeln(format("**Winner:** %s (%.0f targets/sec)", 
                        winner.system, winner.average.targetsPerSecond));
                    f.writeln();
                }
            }
        }
        
        f.writeln("---");
        f.writeln();
    }
    
    private void writeDetailedResults(File f, in BenchmarkResult[] results)
    {
        f.writeln("## Detailed Results");
        f.writeln();
        
        foreach (result; results)
        {
            if (result.runs.empty)
                continue;
            
            f.writeln(format("### %s - %s (%s)", 
                result.system, result.scenario, result.project.name));
            f.writeln();
            
            auto avg = result.average;
            
            f.writeln("**Configuration:**");
            f.writeln(format("- Target Count: %,d", result.project.targetCount));
            f.writeln(format("- Complexity: %s", result.project.complexity));
            f.writeln(format("- Runs: %d", result.runs.length));
            f.writeln();
            
            f.writeln("**Metrics:**");
            f.writeln(format("- Total Time: %d ms", avg.totalTime.total!"msecs"));
            f.writeln(format("- Parse Time: %d ms", avg.parseTime.total!"msecs"));
            f.writeln(format("- Analysis Time: %d ms", avg.analysisTime.total!"msecs"));
            f.writeln(format("- Execution Time: %d ms", avg.executionTime.total!"msecs"));
            f.writeln(format("- Throughput: %.0f targets/sec", avg.targetsPerSecond));
            f.writeln(format("- Memory Used: %d MB", avg.memoryUsedMB));
            f.writeln(format("- Peak Memory: %d MB", avg.peakMemoryMB));
            f.writeln(format("- Cache Hit Rate: %.1f%%", avg.cacheHitRate * 100));
            f.writeln(format("- Standard Deviation: %.1f ms", result.stdDev));
            f.writeln();
        }
        
        f.writeln("---");
        f.writeln();
    }
    
    private void writeStatisticalAnalysis(File f, in BenchmarkResult[] results)
    {
        f.writeln("## Statistical Analysis");
        f.writeln();
        
        f.writeln("### Confidence Intervals (95%)");
        f.writeln();
        f.writeln("| System | Scenario | Mean | CI Lower | CI Upper |");
        f.writeln("|--------|----------|------|----------|----------|");
        
        foreach (result; results)
        {
            if (result.runs.length < 2)
                continue;
            
            auto mean = result.average.totalTime.total!"msecs";
            auto stdDev = result.stdDev;
            auto margin = 1.96 * (stdDev / sqrt(cast(double)result.runs.length));
            
            f.writeln(format("| %s | %s | %d ms | %d ms | %d ms |",
                result.system,
                result.scenario,
                cast(long)mean,
                cast(long)(mean - margin),
                cast(long)(mean + margin)));
        }
        
        f.writeln();
        f.writeln("---");
        f.writeln();
    }
    
    private void writeRecommendations(File f, in BenchmarkResult[] results)
    {
        f.writeln("## Recommendations");
        f.writeln();
        
        auto bySystem = groupBySystem(results);
        
        if (auto builderResults = BuildSystem.Builder in bySystem)
        {
            f.writeln("### For Builder");
            f.writeln();
            
            // Analyze Builder's performance
            auto avgThroughput = 0.0;
            auto avgCacheHit = 0.0;
            auto count = 0;
            
            foreach (result; *builderResults)
            {
                if (result.runs.length > 0)
                {
                    avgThroughput += result.average.targetsPerSecond;
                    avgCacheHit += result.average.cacheHitRate;
                    count++;
                }
            }
            
            if (count > 0)
            {
                avgThroughput /= count;
                avgCacheHit /= count;
                
                if (avgThroughput < 1000)
                    f.writeln("- **Priority 1:** Improve build throughput (current: %.0f t/s, target: >1000 t/s)", avgThroughput);
                
                if (avgCacheHit < 0.95)
                    f.writeln("- **Priority 2:** Optimize cache system (current hit rate: %.1f%%, target: >95%%)", avgCacheHit * 100);
                
                f.writeln("- **Priority 3:** Reduce base overhead for small projects");
                f.writeln("- **Priority 4:** Implement distributed caching for large-scale builds");
            }
            
            f.writeln();
        }
        
        f.writeln("### General Recommendations");
        f.writeln();
        f.writeln("1. Focus on incremental build performance for developer productivity");
        f.writeln("2. Optimize cache hit rates to minimize redundant work");
        f.writeln("3. Improve parallelization for multi-core systems");
        f.writeln("4. Reduce memory footprint for large-scale builds");
        f.writeln();
        
        f.writeln("---");
        f.writeln();
    }
    
    private void writeFooter(File f)
    {
        f.writeln("## Methodology");
        f.writeln();
        f.writeln("- Each scenario was run 5 times for statistical significance");
        f.writeln("- Results represent average performance across all runs");
        f.writeln("- Standard deviation indicates consistency of performance");
        f.writeln("- All tests conducted on the same hardware for fair comparison");
        f.writeln();
        f.writeln("---");
        f.writeln();
        f.writeln("*Report generated by Builder Comparative Benchmark Suite*");
    }
    
    private string getSystemsList(in BenchmarkResult[] results)
    {
        return results.map!(r => to!string(r.system)).array.sort.uniq.join(", ");
    }
    
    private BenchmarkResult[][BuildSystem] groupBySystem(in BenchmarkResult[] results)
    {
        BenchmarkResult[][BuildSystem] groups;
        
        foreach (result; results)
        {
            groups[result.system] ~= cast(BenchmarkResult)result;
        }
        
        return groups;
    }
    
    private BenchmarkResult[][ScenarioType] groupByScenario(in BenchmarkResult[] results)
    {
        BenchmarkResult[][ScenarioType] groups;
        
        foreach (result; results)
        {
            groups[result.scenario] ~= cast(BenchmarkResult)result;
        }
        
        return groups;
    }
    
    private void analyzeSystem(File f, BuildSystem system, in BenchmarkResult[] results)
    {
        // Calculate various metrics
        auto throughputs = results
            .filter!(r => r.runs.length > 0)
            .map!(r => r.average.targetsPerSecond)
            .array;
        
        auto cacheHits = results
            .filter!(r => r.runs.length > 0)
            .map!(r => r.average.cacheHitRate)
            .array;
        
        if (throughputs.empty)
        {
            f.writeln("Insufficient data for analysis");
            return;
        }
        
        auto avgThroughput = throughputs.sum / throughputs.length;
        auto avgCacheHit = cacheHits.sum / cacheHits.length;
        
        // System-specific analysis
        final switch (system)
        {
            case BuildSystem.Builder:
                if (avgThroughput > 1000)
                    f.writeln("- ✓ Excellent throughput for medium-scale projects");
                else if (avgThroughput > 500)
                    f.writeln("- ⚠ Good throughput, but room for improvement");
                else
                    f.writeln("- ✗ Throughput needs optimization");
                
                if (avgCacheHit > 0.9)
                    f.writeln("- ✓ Highly effective caching system");
                else
                    f.writeln("- ⚠ Cache effectiveness could be improved");
                break;
            
            case BuildSystem.Buck2:
                f.writeln("- Meta's production-grade build system");
                f.writeln("- Optimized for monorepo workflows");
                break;
            
            case BuildSystem.Bazel:
                f.writeln("- Google's proven large-scale build system");
                f.writeln("- Strong remote caching capabilities");
                break;
            
            case BuildSystem.Pants:
                f.writeln("- Python-focused build system");
                f.writeln("- Good for polyglot monorepos");
                break;
        }
    }
    
    private double sqrt(double x)
    {
        import std.math : sqrt;
        return sqrt(x);
    }
}

