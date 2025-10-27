#!/usr/bin/env dub
/+ dub.sdl:
    name "benchmark-performance"
    dependency "builder" path="../"
+/

/**
 * Performance benchmarking tool for Builder
 * Measures and reports detailed performance metrics
 */

module tools.benchmark_performance;

import std.stdio;
import std.datetime.stopwatch;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.range;
import core.memory : GC;

struct BenchmarkResult
{
    string name;
    size_t iterations;
    Duration totalTime;
    Duration minTime;
    Duration maxTime;
    Duration avgTime;
    size_t memoryBefore;
    size_t memoryAfter;
    size_t memoryDelta;
    
    double throughput() const
    {
        auto seconds = totalTime.total!"hnsecs" / 10_000_000.0;
        return iterations / seconds;
    }
}

class PerformanceBenchmark
{
    private BenchmarkResult[] results;
    private string outputFile;
    
    this(string outputFile = "benchmark-results.md")
    {
        this.outputFile = outputFile;
    }
    
    /// Run a benchmark
    BenchmarkResult benchmark(string name, size_t iterations, void delegate() setup, void delegate() fn, void delegate() teardown = null)
    {
        writeln("\n╔════════════════════════════════════════════════════════════════╗");
        writefln("║ BENCHMARK: %-52s ║", name);
        writeln("╚════════════════════════════════════════════════════════════════╝");
        writefln("  Iterations: %,d", iterations);
        
        // Setup
        if (setup)
        {
            writeln("  Running setup...");
            setup();
        }
        
        // Force GC before benchmark
        GC.collect();
        auto memBefore = GC.stats().usedSize;
        
        Duration[] times;
        times.reserve(iterations);
        
        // Warmup (10% of iterations)
        writeln("  Warming up...");
        auto warmupIterations = max(iterations / 10, 1);
        foreach (_; 0 .. warmupIterations)
        {
            fn();
        }
        
        // Actual benchmark
        writeln("  Running benchmark...");
        StopWatch sw;
        foreach (i; 0 .. iterations)
        {
            sw.reset();
            sw.start();
            fn();
            sw.stop();
            times ~= sw.peek();
            
            // Progress indicator for long benchmarks
            if (iterations >= 100 && (i + 1) % (iterations / 10) == 0)
            {
                writefln("    Progress: %d%%", ((i + 1) * 100) / iterations);
            }
        }
        
        // Memory measurement
        GC.collect();
        auto memAfter = GC.stats().usedSize;
        
        // Teardown
        if (teardown)
        {
            writeln("  Running teardown...");
            teardown();
        }
        
        // Calculate statistics
        auto totalTime = times.sum;
        auto avgTime = totalTime / iterations;
        auto minTime = times.minElement;
        auto maxTime = times.maxElement;
        auto memDelta = memAfter > memBefore ? memAfter - memBefore : 0;
        
        auto result = BenchmarkResult(
            name, iterations, totalTime, minTime, maxTime, avgTime,
            memBefore, memAfter, memDelta
        );
        
        results ~= result;
        printResult(result);
        
        return result;
    }
    
    /// Print a single result
    private void printResult(BenchmarkResult result)
    {
        writeln("\n  ┌─ Results ─────────────────────────────────────────────────────┐");
        writefln("  │ Total time:      %12s ms                              │", 
                 format("%,d", result.totalTime.total!"msecs"));
        writefln("  │ Average time:    %12s μs                              │", 
                 format("%,d", result.avgTime.total!"usecs"));
        writefln("  │ Min time:        %12s μs                              │", 
                 format("%,d", result.minTime.total!"usecs"));
        writefln("  │ Max time:        %12s μs                              │", 
                 format("%,d", result.maxTime.total!"usecs"));
        writefln("  │ Throughput:      %12s ops/sec                         │", 
                 format("%,.0f", result.throughput()));
        writefln("  │ Memory before:   %12s MB                              │", 
                 format("%.2f", result.memoryBefore / 1024.0 / 1024.0));
        writefln("  │ Memory after:    %12s MB                              │", 
                 format("%.2f", result.memoryAfter / 1024.0 / 1024.0));
        writefln("  │ Memory delta:    %12s KB                              │", 
                 format("%,d", result.memoryDelta / 1024));
        writeln("  └───────────────────────────────────────────────────────────────┘");
    }
    
    /// Generate markdown report
    void generateReport()
    {
        auto f = File(outputFile, "w");
        
        f.writeln("# Builder Performance Benchmark Report");
        f.writeln();
        f.writeln("Generated: ", Clock.currTime().toISOExtString());
        f.writeln();
        
        f.writeln("## Summary");
        f.writeln();
        f.writeln("| Benchmark | Iterations | Avg Time | Throughput | Memory |");
        f.writeln("|-----------|------------|----------|------------|--------|");
        
        foreach (result; results)
        {
            f.writefln("| %s | %,d | %,d μs | %,.0f ops/s | %,d KB |",
                      result.name,
                      result.iterations,
                      result.avgTime.total!"usecs",
                      result.throughput(),
                      result.memoryDelta / 1024);
        }
        
        f.writeln();
        f.writeln("## Detailed Results");
        f.writeln();
        
        foreach (result; results)
        {
            f.writeln("### ", result.name);
            f.writeln();
            f.writeln("- **Iterations**: ", format("%,d", result.iterations));
            f.writeln("- **Total Time**: ", result.totalTime.total!"msecs", " ms");
            f.writeln("- **Average Time**: ", result.avgTime.total!"usecs", " μs");
            f.writeln("- **Min Time**: ", result.minTime.total!"usecs", " μs");
            f.writeln("- **Max Time**: ", result.maxTime.total!"usecs", " μs");
            f.writeln("- **Throughput**: ", format("%,.0f", result.throughput()), " ops/sec");
            f.writeln("- **Memory Before**: ", format("%.2f", result.memoryBefore / 1024.0 / 1024.0), " MB");
            f.writeln("- **Memory After**: ", format("%.2f", result.memoryAfter / 1024.0 / 1024.0), " MB");
            f.writeln("- **Memory Delta**: ", format("%,d", result.memoryDelta / 1024), " KB");
            f.writeln();
        }
        
        f.writeln("## Performance Analysis");
        f.writeln();
        
        if (results.length >= 2)
        {
            // Compare first two results (typically serial vs parallel)
            auto r1 = results[0];
            auto r2 = results[1];
            auto speedup = cast(double)r1.totalTime.total!"hnsecs" / r2.totalTime.total!"hnsecs";
            
            f.writeln("### Speedup Analysis");
            f.writeln();
            f.writefln("- **Speedup**: %.2fx", speedup);
            f.writefln("- **%s**: %,d ms", r1.name, r1.totalTime.total!"msecs");
            f.writefln("- **%s**: %,d ms", r2.name, r2.totalTime.total!"msecs");
            f.writeln();
        }
        
        f.writeln("## System Information");
        f.writeln();
        f.writeln("- **OS**: ", environment.get("OS", "Unknown"));
        f.writeln("- **CPU Cores**: ", totalCPUs);
        f.writeln();
        
        f.close();
        
        writeln("\n╔════════════════════════════════════════════════════════════════╗");
        writeln("║ Report generated: ", outputFile, "                            ");
        writeln("╚════════════════════════════════════════════════════════════════╝");
    }
}

void main()
{
    writeln("╔════════════════════════════════════════════════════════════════╗");
    writeln("║         Builder Performance Benchmark Tool                     ║");
    writeln("╚════════════════════════════════════════════════════════════════╝");
    
    auto bench = new PerformanceBenchmark("benchmark-results.md");
    
    // Example benchmarks - users can customize these
    
    writeln("\nStarting benchmarks...");
    
    // Benchmark 1: String operations
    bench.benchmark(
        "String Concatenation (10K ops)",
        10_000,
        () {},  // setup
        {       // benchmark
            string s;
            foreach (i; 0 .. 100)
                s ~= "test";
        },
        null    // teardown
    );
    
    // Benchmark 2: Array operations
    bench.benchmark(
        "Array Append (10K ops)",
        10_000,
        () {},
        {
            int[] arr;
            foreach (i; 0 .. 100)
                arr ~= i;
        },
        null
    );
    
    // Benchmark 3: File operations
    string testFile = "benchmark-temp-file.txt";
    bench.benchmark(
        "File Write (1K ops)",
        1_000,
        () {},
        {
            std.file.write(testFile, "test data");
        },
        () { if (exists(testFile)) remove(testFile); }
    );
    
    // Generate report
    bench.generateReport();
    
    writeln("\n✓ All benchmarks completed successfully!");
}

