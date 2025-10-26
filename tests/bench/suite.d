module tests.bench.suite;

import std.stdio;
import std.datetime.stopwatch;
import std.algorithm;
import std.array;
import std.conv;
import std.format;

/// Benchmark result
struct BenchResult
{
    string name;
    size_t iterations;
    Duration totalTime;
    Duration avgTime;
    Duration minTime;
    Duration maxTime;
    
    double opsPerSecond() const
    {
        auto seconds = totalTime.total!"hnsecs" / 10_000_000.0;
        return iterations / seconds;
    }
}

/// Benchmark harness
class BenchmarkSuite
{
    private BenchResult[] results;
    
    /// Run a benchmark
    void bench(string name, size_t iterations, void delegate() fn)
    {
        writeln("\x1b[36m[BENCH]\x1b[0m ", name, " (", iterations, " iterations)");
        
        Duration[] times;
        times.reserve(iterations);
        
        // Warmup
        foreach (_; 0 .. iterations / 10)
            fn();
        
        // Actual benchmark
        StopWatch sw;
        foreach (_; 0 .. iterations)
        {
            sw.reset();
            sw.start();
            fn();
            sw.stop();
            times ~= sw.peek();
        }
        
        auto totalTime = times.sum;
        auto avgTime = totalTime / iterations;
        auto minTime = times.minElement;
        auto maxTime = times.maxElement;
        
        auto result = BenchResult(name, iterations, totalTime, avgTime, minTime, maxTime);
        results ~= result;
        
        printResult(result);
    }
    
    /// Print benchmark result
    private void printResult(BenchResult result)
    {
        writeln("  Total:   ", result.totalTime.total!"msecs", " ms");
        writeln("  Average: ", result.avgTime.total!"usecs", " μs");
        writeln("  Min:     ", result.minTime.total!"usecs", " μs");
        writeln("  Max:     ", result.maxTime.total!"usecs", " μs");
        writeln("  Ops/sec: ", format("%.0f", result.opsPerSecond()));
        writeln();
    }
    
    /// Print summary of all benchmarks
    void printSummary()
    {
        if (results.empty)
            return;
        
        writeln("\n" ~ "=".repeat(70).join);
        writeln("BENCHMARK SUMMARY");
        writeln("=".repeat(70).join);
        
        foreach (result; results)
        {
            writeln(result.name);
            writeln("  ", format("%.0f", result.opsPerSecond()), " ops/sec");
        }
        
        writeln("=".repeat(70).join ~ "\n");
    }
    
    /// Get all results
    BenchResult[] getResults() const
    {
        return results.dup;
    }
}

/// Benchmark example
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m bench.suite - Benchmark infrastructure");
    
    auto suite = new BenchmarkSuite();
    
    // Example benchmark
    suite.bench("string concatenation", 10000, {
        string s;
        foreach (i; 0 .. 100)
            s ~= "x";
    });
    
    auto results = suite.getResults();
    assert(results.length == 1);
    assert(results[0].iterations == 10000);
    
    writeln("\x1b[32m  ✓ Benchmark infrastructure works\x1b[0m");
}

