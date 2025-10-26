module tests.bench.utils;

import std.stdio;
import std.datetime.stopwatch;
import std.algorithm;
import std.array;
import std.conv;
import std.math;
import std.range;
import std.format;

/// Benchmark result for a single run
struct BenchResult
{
    string name;
    Duration duration;
    size_t iterations;
    
    /// Average time per iteration
    Duration avgTime() const
    {
        return duration / iterations;
    }
    
    /// Iterations per second
    double throughput() const
    {
        if (duration.total!"msecs" == 0) return double.infinity;
        return (iterations * 1000.0) / duration.total!"msecs";
    }
}

/// Benchmark statistics across multiple runs
struct BenchStats
{
    string name;
    Duration[] times;
    size_t iterations;
    
    Duration min() const { return times.minElement; }
    Duration max() const { return times.maxElement; }
    Duration median() const 
    {
        auto sorted = times.dup.sort;
        return sorted[$ / 2];
    }
    
    double mean() const
    {
        return times.map!(t => t.total!"usecs").sum / cast(double)times.length;
    }
    
    double stdDev() const
    {
        auto avg = mean();
        auto variance = times
            .map!(t => t.total!"usecs")
            .map!(t => pow(t - avg, 2))
            .sum / times.length;
        return sqrt(variance);
    }
}

/// Simple benchmarking harness
struct Benchmark
{
    /// Run a benchmark function multiple times
    static BenchResult run(string name, void delegate() func, size_t iterations = 100)
    {
        // Warmup
        foreach (_; 0 .. min(10, iterations))
            func();
        
        // Measure
        StopWatch sw;
        sw.start();
        
        foreach (_; 0 .. iterations)
            func();
        
        sw.stop();
        
        return BenchResult(name, sw.peek(), iterations);
    }
    
    /// Run benchmark with statistical analysis (multiple samples)
    static BenchStats runStats(string name, void delegate() func, 
                               size_t iterations = 100, size_t samples = 10)
    {
        Duration[] times;
        
        foreach (_; 0 .. samples)
        {
            auto result = run(name, func, iterations);
            times ~= result.duration;
        }
        
        return BenchStats(name, times, iterations);
    }
    
    /// Compare two implementations
    static void compare(string baseline, void delegate() baseFunc,
                       string candidate, void delegate() candFunc,
                       size_t iterations = 100)
    {
        auto baseResult = run(baseline, baseFunc, iterations);
        auto candResult = run(candidate, candFunc, iterations);
        
        writeln("\n" ~ "=".repeat(60).join);
        writeln("BENCHMARK COMPARISON");
        writeln("=".repeat(60).join);
        
        writeln("\nBaseline (", baseline, "):");
        writeln("  Time:       ", baseResult.duration.total!"msecs", "ms");
        writeln("  Throughput: ", format("%.2f", baseResult.throughput()), " ops/sec");
        
        writeln("\nCandidate (", candidate, "):");
        writeln("  Time:       ", candResult.duration.total!"msecs", "ms");
        writeln("  Throughput: ", format("%.2f", candResult.throughput()), " ops/sec");
        
        auto speedup = cast(double)baseResult.duration.total!"usecs" / 
                      candResult.duration.total!"usecs";
        
        writeln("\nSpeedup: ", format("%.2fx", speedup));
        
        if (speedup > 1.0)
            writeln("\x1b[32m✓ Candidate is faster\x1b[0m");
        else if (speedup < 1.0)
            writeln("\x1b[33m⚠ Candidate is slower\x1b[0m");
        else
            writeln("≈ Performance is similar");
        
        writeln("=".repeat(60).join ~ "\n");
    }
    
    /// Print detailed statistics
    static void printStats(BenchStats stats)
    {
        writeln("\nBenchmark: ", stats.name);
        writeln("  Iterations: ", stats.iterations);
        writeln("  Samples:    ", stats.times.length);
        writeln("  Min:        ", stats.min().total!"msecs", "ms");
        writeln("  Max:        ", stats.max().total!"msecs", "ms");
        writeln("  Median:     ", stats.median().total!"msecs", "ms");
        writeln("  Mean:       ", format("%.2f", stats.mean() / 1000), "ms");
        writeln("  Std Dev:    ", format("%.2f", stats.stdDev() / 1000), "ms");
    }
}

/// Property-based testing utilities
struct Property
{
    /// Generate random integers in range
    static int[] randomInts(size_t count, int min = 0, int max = 100)
    {
        import std.random;
        int[] result;
        foreach (_; 0 .. count)
            result ~= uniform(min, max);
        return result;
    }
    
    /// Generate random strings
    static string[] randomStrings(size_t count, size_t maxLength = 20)
    {
        import std.random;
        import std.range;
        
        string[] result;
        foreach (_; 0 .. count)
        {
            auto len = uniform(1, maxLength);
            auto str = iota(len)
                .map!(_ => cast(char)uniform('a', 'z' + 1))
                .array;
            result ~= str.idup;
        }
        return result;
    }
    
    /// Test a property holds for random inputs
    static bool forAll(T)(bool delegate(T) predicate, T[] samples)
    {
        return samples.all!predicate;
    }
    
    /// Test property with generated inputs
    static bool check(bool delegate(int[]) predicate, 
                     size_t sampleSize = 100, size_t arraySize = 10)
    {
        foreach (_; 0 .. sampleSize)
        {
            auto sample = randomInts(arraySize);
            if (!predicate(sample))
                return false;
        }
        return true;
    }
}

/// Performance assertion utilities
struct PerfAssert
{
    /// Assert that an operation completes within a time limit
    static void completesWithin(void delegate() func, Duration limit, 
                               string message = "Operation too slow")
    {
        StopWatch sw;
        sw.start();
        func();
        sw.stop();
        
        if (sw.peek() > limit)
        {
            throw new Exception(
                format("%s: %dms > %dms", message, 
                      sw.peek().total!"msecs", limit.total!"msecs")
            );
        }
    }
    
    /// Assert that candidate is faster than baseline
    static void fasterThan(void delegate() baseline, void delegate() candidate,
                          size_t iterations = 100)
    {
        auto baseTime = Benchmark.run("baseline", baseline, iterations);
        auto candTime = Benchmark.run("candidate", candidate, iterations);
        
        if (candTime.duration >= baseTime.duration)
        {
            throw new Exception(
                format("Candidate not faster: %dms vs %dms",
                      candTime.duration.total!"msecs",
                      baseTime.duration.total!"msecs")
            );
        }
    }
    
    /// Assert memory usage is below limit
    static void memoryUnder(void delegate() func, size_t limitMB)
    {
        import core.memory;
        
        auto before = GC.stats().usedSize;
        func();
        auto after = GC.stats().usedSize;
        
        auto usedMB = (after - before) / (1024 * 1024);
        
        if (usedMB > limitMB)
        {
            throw new Exception(
                format("Memory usage too high: %d MB > %d MB", usedMB, limitMB)
            );
        }
    }
}


