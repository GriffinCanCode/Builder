#!/usr/bin/env dub
/+ dub.sdl:
    name "realworld-benchmark"
    dependency "builder" path="../../"
+/

/**
 * Enhanced Real-World Benchmarking Tool
 * 
 * Tests Builder against actual example projects with comprehensive metrics
 */

module tests.bench.realworld;

import std.stdio;
import std.file;
import std.path;
import std.process;
import std.datetime.stopwatch;
import std.datetime : Clock, Duration;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.string;
import std.range;
import core.sys.posix.sys.resource;

struct ProjectMetrics
{
    string name;
    size_t targetCount;
    Duration cleanBuildTime;
    Duration cachedBuildTime;
    Duration parseTime;
    size_t cacheSize;
    double cpuUsage;
    size_t peakMemoryMB;
    bool success;
    string errorMessage;
}

class RealWorldBenchmark
{
    private string builderBin;
    private string examplesDir;
    private ProjectMetrics[] results;
    
    this(string builderBin = null, string examplesDir = null)
    {
        // Find builder binary relative to script location
        if (builderBin is null)
        {
            import std.file : thisExePath;
            auto scriptDir = thisExePath().dirName;
            auto projectRoot = buildPath(scriptDir, "..", "..");
            this.builderBin = buildPath(projectRoot, "bin", "builder");
        }
        else
        {
            this.builderBin = builderBin;
        }
        
        if (examplesDir is null)
        {
            import std.file : thisExePath;
            auto scriptDir = thisExePath().dirName;
            auto projectRoot = buildPath(scriptDir, "..", "..");
            this.examplesDir = buildPath(projectRoot, "examples");
        }
        else
        {
            this.examplesDir = examplesDir;
        }
    }
    
    void runAll()
    {
        writeln("╔════════════════════════════════════════════════════════════════╗");
        writeln("║     BUILDER REAL-WORLD PERFORMANCE BENCHMARK                   ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        writeln();
        
        // Check builder exists
        if (!exists(builderBin))
        {
            writeln("\x1b[31m✗ Builder binary not found: ", builderBin, "\x1b[0m");
            writeln("  Build it first with: make");
            return;
        }
        
        writeln("Builder: ", builderBin);
        writeln("Examples: ", examplesDir);
        writeln();
        
        // Test projects in order of complexity
        string[] projects = [
            "simple",
            "python-multi",
            "javascript/javascript-basic",
            "javascript/javascript-node",
            "mixed-lang",
            "go-project",
            "rust-project",
            "cpp-project",
            "typescript-app",
            "java-project",
            "ocaml-project",
            "haskell-project"
        ];
        
        foreach (i, project; projects)
        {
            writeln(format("\n[%d/%d] Testing: %s", i + 1, projects.length, project));
            writeln("═".repeat(70).join);
            
            auto projectPath = buildPath(examplesDir, project);
            if (!exists(projectPath))
            {
                writeln("  \x1b[33m⊘ SKIP\x1b[0m Project not found");
                continue;
            }
            
            auto metrics = benchmarkProject(projectPath, project);
            results ~= metrics;
            
            printMetrics(metrics);
        }
        
        // Generate report
        generateReport();
    }
    
    private ProjectMetrics benchmarkProject(string projectPath, string projectName)
    {
        ProjectMetrics metrics;
        metrics.name = projectName;
        
        // Check if project has Builderfile
        if (!exists(buildPath(projectPath, "Builderfile")) && 
            !exists(buildPath(projectPath, "Builderspace")))
        {
            metrics.success = false;
            metrics.errorMessage = "No Builderfile found";
            return metrics;
        }
        
        // Count targets
        metrics.targetCount = countTargets(projectPath);
        writeln(format("  Targets: %d", metrics.targetCount));
        
        // Clean build
        writeln("  Running clean build...");
        auto cleanMetrics = runBuild(projectPath, true);
        metrics.cleanBuildTime = cleanMetrics.time;
        metrics.parseTime = cleanMetrics.parseTime;
        metrics.success = cleanMetrics.success;
        metrics.errorMessage = cleanMetrics.errorMessage;
        metrics.cpuUsage = cleanMetrics.cpuUsage;
        metrics.peakMemoryMB = cleanMetrics.peakMemory;
        
        if (!metrics.success)
        {
            writeln(format("    \x1b[31m✗ Failed: %s\x1b[0m", metrics.errorMessage));
            return metrics;
        }
        
        writeln(format("    ✓ Time: %d ms", metrics.cleanBuildTime.total!"msecs"));
        
        // Cached build
        writeln("  Running cached build...");
        auto cachedMetrics = runBuild(projectPath, false);
        metrics.cachedBuildTime = cachedMetrics.time;
        
        writeln(format("    ✓ Time: %d ms", metrics.cachedBuildTime.total!"msecs"));
        
        // Get cache size
        auto cacheDir = buildPath(projectPath, ".builder-cache");
        if (exists(cacheDir))
        {
            metrics.cacheSize = getCacheSize(cacheDir);
            writeln(format("    Cache: %d bytes", metrics.cacheSize));
        }
        
        return metrics;
    }
    
    private struct BuildResult
    {
        Duration time;
        Duration parseTime;
        bool success;
        string errorMessage;
        double cpuUsage;
        size_t peakMemory;
    }
    
    private BuildResult runBuild(string projectPath, bool clean)
    {
        BuildResult result;
        
        // Clean if requested
        if (clean)
        {
            auto cacheDir = buildPath(projectPath, ".builder-cache");
            if (exists(cacheDir))
                rmdirRecurse(cacheDir);
            
            auto binDir = buildPath(projectPath, "bin");
            if (exists(binDir))
                rmdirRecurse(binDir);
        }
        
        // Run build with time measurement
        auto sw = StopWatch(AutoStart.yes);
        
        auto buildResult = execute([builderBin, "build"], null, Config.none, size_t.max, projectPath);
        
        sw.stop();
        result.time = sw.peek();
        result.success = buildResult.status == 0;
        
        if (!result.success)
            result.errorMessage = buildResult.output;
        
        // Parse output for additional metrics
        parseOutput(buildResult.output, result);
        
        return result;
    }
    
    private void parseOutput(string output, ref BuildResult result)
    {
        // Parse Builder output for metrics
        foreach (line; output.lineSplitter)
        {
            if (line.canFind("Parse") && line.canFind("ms"))
            {
                // Try to extract parse time
                auto parts = line.split();
                foreach (i, part; parts)
                {
                    if (part.canFind("ms") && i > 0)
                    {
                        try
                        {
                            auto timeStr = parts[i-1].replace(",", "");
                            auto msecs = to!long(timeStr);
                            result.parseTime = msecs.msecs;
                        }
                        catch (Exception e)
                        {
                            // Ignore parse errors
                        }
                    }
                }
            }
        }
    }
    
    private size_t countTargets(string projectPath)
    {
        size_t count = 0;
        
        auto builderfile = buildPath(projectPath, "Builderfile");
        if (exists(builderfile))
        {
            auto content = readText(builderfile);
            
            // Count target definitions (simple heuristic)
            foreach (line; content.lineSplitter)
            {
                auto trimmed = line.strip;
                if (trimmed.startsWith("target ") || 
                    trimmed.startsWith("py_") ||
                    trimmed.startsWith("js_") ||
                    trimmed.startsWith("rust_") ||
                    trimmed.startsWith("go_") ||
                    trimmed.startsWith("cpp_"))
                {
                    count++;
                }
            }
        }
        
        return count > 0 ? count : 1;  // At least 1
    }
    
    private size_t getCacheSize(string cacheDir)
    {
        size_t total = 0;
        
        try
        {
            foreach (entry; dirEntries(cacheDir, SpanMode.depth))
            {
                if (entry.isFile)
                    total += entry.size;
            }
        }
        catch (Exception e)
        {
            // Ignore errors
        }
        
        return total;
    }
    
    private void printMetrics(in ProjectMetrics metrics)
    {
        if (!metrics.success)
            return;
        
        writeln("\n  Performance Summary:");
        writeln(format("    Clean build:   %5d ms", metrics.cleanBuildTime.total!"msecs"));
        writeln(format("    Cached build:  %5d ms", metrics.cachedBuildTime.total!"msecs"));
        
        if (metrics.cachedBuildTime.total!"msecs" > 0 && metrics.cleanBuildTime.total!"msecs" > 0)
        {
            auto speedup = cast(double)metrics.cleanBuildTime.total!"msecs" / metrics.cachedBuildTime.total!"msecs";
            writeln(format("    Speedup:       %.2fx", speedup));
        }
        
        if (metrics.targetCount > 0)
        {
            auto throughput = metrics.targetCount / (metrics.cleanBuildTime.total!"msecs" / 1000.0);
            writeln(format("    Throughput:    %.1f targets/sec", throughput));
        }
        
        if (metrics.parseTime.total!"msecs" > 0)
            writeln(format("    Parse time:    %d ms", metrics.parseTime.total!"msecs"));
    }
    
    private void generateReport()
    {
        writeln("\n\n╔════════════════════════════════════════════════════════════════╗");
        writeln("║                    FINAL REPORT                                ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        writeln();
        
        auto successful = results.filter!(r => r.success).array;
        
        writeln(format("Tested: %d projects", results.length));
        writeln(format("Successful: %d projects", successful.length));
        writeln();
        
        if (successful.empty)
        {
            writeln("No successful builds to report.");
            return;
        }
        
        // Summary table
        writeln("| Project | Targets | Clean | Cached | Speedup | Throughput |");
        writeln("|---------|---------|-------|--------|---------|------------|");
        
        foreach (metrics; successful)
        {
            auto cleanMs = metrics.cleanBuildTime.total!"msecs";
            auto cachedMs = metrics.cachedBuildTime.total!"msecs";
            auto speedup = cachedMs > 0 ? (cast(double)cleanMs / cachedMs) : 0.0;
            auto throughput = metrics.targetCount / (cleanMs / 1000.0);
            
            writeln(format("| %s | %d | %d ms | %d ms | %.2fx | %.0f t/s |",
                metrics.name,
                metrics.targetCount,
                cleanMs,
                cachedMs,
                speedup,
                throughput));
        }
        
        writeln();
        
        // Averages
        auto avgClean = successful.map!(r => r.cleanBuildTime.total!"msecs").sum / successful.length;
        auto avgCached = successful.map!(r => r.cachedBuildTime.total!"msecs").sum / successful.length;
        auto avgThroughput = successful.map!(r => r.targetCount / (r.cleanBuildTime.total!"msecs" / 1000.0)).sum / successful.length;
        
        writeln("Averages:");
        writeln(format("  Clean build:   %d ms", avgClean));
        writeln(format("  Cached build:  %d ms", avgCached));
        writeln(format("  Throughput:    %.0f targets/sec", avgThroughput));
        writeln();
        
        // Write to file
        writeMarkdownReport(successful);
    }
    
    private void writeMarkdownReport(ProjectMetrics[] successful)
    {
        auto reportPath = "benchmark-realworld-enhanced.md";
        auto f = File(reportPath, "w");
        
        f.writeln("# Builder Real-World Performance Benchmark");
        f.writeln();
        f.writeln("**Generated:** ", Clock.currTime().toISOExtString());
        f.writeln("**Projects Tested:** ", results.length);
        f.writeln("**Successful Builds:** ", successful.length);
        f.writeln();
        f.writeln("---");
        f.writeln();
        
        f.writeln("## Summary");
        f.writeln();
        f.writeln("| Project | Targets | Clean Build | Cached Build | Speedup | Throughput |");
        f.writeln("|---------|---------|-------------|--------------|---------|------------|");
        
        foreach (metrics; successful)
        {
            auto cleanMs = metrics.cleanBuildTime.total!"msecs";
            auto cachedMs = metrics.cachedBuildTime.total!"msecs";
            auto speedup = cachedMs > 0 ? (cast(double)cleanMs / cachedMs) : 0.0;
            auto throughput = metrics.targetCount / (cleanMs / 1000.0);
            
            f.writeln(format("| %s | %d | %d ms | %d ms | %.2fx | %.0f t/s |",
                metrics.name,
                metrics.targetCount,
                cleanMs,
                cachedMs,
                speedup,
                throughput));
        }
        
        f.writeln();
        f.writeln("---");
        f.writeln();
        
        // Detailed results
        f.writeln("## Detailed Results");
        f.writeln();
        
        foreach (metrics; successful)
        {
            f.writeln("### ", metrics.name);
            f.writeln();
            f.writeln("- **Targets:** ", metrics.targetCount);
            f.writeln("- **Clean Build Time:** ", metrics.cleanBuildTime.total!"msecs", " ms");
            f.writeln("- **Cached Build Time:** ", metrics.cachedBuildTime.total!"msecs", " ms");
            f.writeln("- **Parse Time:** ", metrics.parseTime.total!"msecs", " ms");
            f.writeln("- **Cache Size:** ", metrics.cacheSize, " bytes");
            
            auto cleanMs = metrics.cleanBuildTime.total!"msecs";
            auto cachedMs = metrics.cachedBuildTime.total!"msecs";
            if (cachedMs > 0)
            {
                auto speedup = cast(double)cleanMs / cachedMs;
                f.writeln("- **Speedup:** ", format("%.2fx", speedup));
            }
            
            f.writeln();
        }
        
        f.close();
        
        writeln("\x1b[32m✓ Detailed report written to: ", reportPath, "\x1b[0m");
    }
}

void main()
{
    auto bench = new RealWorldBenchmark();
    bench.runAll();
}

