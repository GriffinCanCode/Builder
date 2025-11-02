module utils.benchmarking.bench;

import std.stdio;
import std.datetime.stopwatch;
import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import std.format;
import utils.files.hash;
import utils.files.metadata;
import utils.files.chunking;
import utils.files.glob;

/// Performance benchmarking utilities
struct Benchmark
{
    private string name;
    private StopWatch timer;
    private size_t iterations;
    private Duration[] samples;
    
    this(string name, size_t iterations = 1)
    {
        this.name = name;
        this.iterations = iterations;
        this.timer = StopWatch(AutoStart.no);
    }
    
    /// Run benchmark
    @system // Stopwatch and delegate execution
    void run(void delegate() func)
    {
        samples.length = 0;
        
        foreach (_; 0 .. iterations)
        {
            timer.reset();
            timer.start();
            func();
            timer.stop();
            samples ~= timer.peek();
        }
    }
    
    /// Get results
    BenchmarkResult result()
    {
        BenchmarkResult res;
        res.name = name;
        res.iterations = iterations;
        
        if (samples.empty)
            return res;
        
        auto totalNsecs = samples.map!(d => d.total!"nsecs").sum;
        res.totalTime = dur!"nsecs"(totalNsecs);
        res.avgTime = dur!"nsecs"(totalNsecs / samples.length);
        res.minTime = samples.minElement;
        res.maxTime = samples.maxElement;
        
        // Calculate median
        auto sorted = samples.dup.sort;
        if (samples.length % 2 == 0)
        {
            auto mid = samples.length / 2;
            auto median = (sorted[mid - 1].total!"nsecs" + sorted[mid].total!"nsecs") / 2;
            res.medianTime = dur!"nsecs"(median);
        }
        else
        {
            res.medianTime = sorted[samples.length / 2];
        }
        
        // Calculate standard deviation
        auto avgNsecs = res.avgTime.total!"nsecs";
        auto variance = samples
            .map!(d => d.total!"nsecs" - avgNsecs)
            .map!(diff => diff * diff)
            .sum / samples.length;
        res.stdDev = dur!"nsecs"(cast(long)sqrt(cast(double)variance));
        
        return res;
    }
    
    /// Calculate square root (for std dev)
    private static double sqrt(double x)
    {
        import std.math : sqrt;
        return sqrt(x);
    }
}

/// Benchmark result
struct BenchmarkResult
{
    string name;
    size_t iterations;
    Duration totalTime;
    Duration avgTime;
    Duration minTime;
    Duration maxTime;
    Duration medianTime;
    Duration stdDev;
    
    /// Print results
    @system // I/O operations
    void print()
    {
        writeln("\n=== ", name, " ===");
        writeln("Iterations: ", iterations);
        writeln("Total:      ", formatDuration(totalTime));
        writeln("Average:    ", formatDuration(avgTime));
        writeln("Median:     ", formatDuration(medianTime));
        writeln("Min:        ", formatDuration(minTime));
        writeln("Max:        ", formatDuration(maxTime));
        writeln("Std Dev:    ", formatDuration(stdDev));
        
        if (iterations > 1)
        {
            auto opsPerSec = 1_000_000_000.0 / avgTime.total!"nsecs";
            writeln("Throughput: ", format!"%.2f"(opsPerSec), " ops/sec");
        }
    }
    
    /// Format duration nicely
    static string formatDuration(Duration d)
    {
        auto nsecs = d.total!"nsecs";
        
        if (nsecs < 1_000)
            return format!"%d ns"(nsecs);
        if (nsecs < 1_000_000)
            return format!"%.2f μs"(nsecs / 1_000.0);
        if (nsecs < 1_000_000_000)
            return format!"%.2f ms"(nsecs / 1_000_000.0);
        return format!"%.2f s"(nsecs / 1_000_000_000.0);
    }
}

/// Benchmark suite for file operations
struct FileOpBenchmark
{
    /// Benchmark different hashing strategies
    @system // File operations and benchmarking
    static void benchmarkHashing(string[] testFiles)
    {
        writeln("\n╔══════════════════════════════════════════════════════════════╗");
        writeln("║           HASHING STRATEGY PERFORMANCE COMPARISON            ║");
        writeln("╚══════════════════════════════════════════════════════════════╝");
        
        foreach (file; testFiles)
        {
            if (!exists(file))
                continue;
            
            auto size = getSize(file);
            writeln("\nFile: ", baseName(file), " (", formatSize(size), ")");
            
            // Benchmark full hash
            auto fullBench = Benchmark("Full Hash", 10);
            fullBench.run(() {
                auto hash = FastHash.hashFile(file);
            });
            fullBench.result().print();
            
            // Benchmark metadata hash
            auto metaBench = Benchmark("Metadata Hash", 10);
            metaBench.run(() {
                auto hash = FastHash.hashMetadata(file);
            });
            metaBench.result().print();
            
            // Calculate speedup
            auto speedup = fullBench.result().avgTime.total!"nsecs" / 
                          cast(double)metaBench.result().avgTime.total!"nsecs";
            writeln("\n>>> Speedup: ", format!"%.1f"(speedup), "x");
        }
    }
    
    /// Benchmark metadata checking
    @system // File operations and benchmarking
    static void benchmarkMetadata(string[] testFiles)
    {
        writeln("\n╔══════════════════════════════════════════════════════════════╗");
        writeln("║              METADATA CHECKING PERFORMANCE                   ║");
        writeln("╚══════════════════════════════════════════════════════════════╝");
        
        FileMetadata[] metadata;
        foreach (file; testFiles)
        {
            if (exists(file))
                metadata ~= FileMetadata.from(file);
        }
        
        // Benchmark quick check (size only)
        auto quickBench = Benchmark("Quick Check (size)", 100_000);
        quickBench.run(() {
            foreach (i, file; testFiles)
            {
                if (i < metadata.length && exists(file))
                {
                    auto newMeta = FileMetadata.from(file);
                    auto same = metadata[i].quickEquals(newMeta);
                }
            }
        });
        quickBench.result().print();
        
        // Benchmark fast check (size + mtime)
        auto fastBench = Benchmark("Fast Check (size + mtime)", 100_000);
        fastBench.run(() {
            foreach (i, file; testFiles)
            {
                if (i < metadata.length && exists(file))
                {
                    auto newMeta = FileMetadata.from(file);
                    auto same = metadata[i].fastEquals(newMeta);
                }
            }
        });
        fastBench.result().print();
        
        // Benchmark full check
        auto fullBench = Benchmark("Full Check (all fields)", 100_000);
        fullBench.run(() {
            foreach (i, file; testFiles)
            {
                if (i < metadata.length && exists(file))
                {
                    auto newMeta = FileMetadata.from(file);
                    auto same = metadata[i].equals(newMeta);
                }
            }
        });
        fullBench.result().print();
    }
    
    /// Benchmark glob matching
    @system // File operations and benchmarking
    static void benchmarkGlob(string baseDir, string[] patterns)
    {
        writeln("\n╔══════════════════════════════════════════════════════════════╗");
        writeln("║                GLOB MATCHING PERFORMANCE                     ║");
        writeln("╚══════════════════════════════════════════════════════════════╝");
        
        foreach (pattern; patterns)
        {
            writeln("\nPattern: ", pattern);
            
            auto bench = Benchmark("Glob Match", 10);
            string[] results;
            bench.run(() {
                results = glob(pattern, baseDir);
            });
            
            auto res = bench.result();
            res.print();
            writeln("Files matched: ", results.length);
        }
    }
    
    /// Benchmark content-defined chunking
    @system // File operations and benchmarking
    static void benchmarkChunking(string[] testFiles)
    {
        writeln("\n╔══════════════════════════════════════════════════════════════╗");
        writeln("║          CONTENT-DEFINED CHUNKING PERFORMANCE                ║");
        writeln("╚══════════════════════════════════════════════════════════════╝");
        
        foreach (file; testFiles)
        {
            if (!exists(file))
                continue;
            
            auto size = getSize(file);
            writeln("\nFile: ", baseName(file), " (", formatSize(size), ")");
            
            auto bench = Benchmark("Chunking", 5);
            ContentChunker.ChunkResult result;
            bench.run(() {
                result = ContentChunker.chunkFile(file);
            });
            
            bench.result().print();
            writeln("Chunks: ", result.chunks.length);
            
            if (result.chunks.length > 0)
            {
                auto avgChunkSize = size / result.chunks.length;
                writeln("Avg chunk size: ", formatSize(avgChunkSize));
            }
        }
    }
    
    /// Format size nicely
    private static string formatSize(size_t bytes)
    {
        if (bytes < 1024)
            return format!"%d B"(bytes);
        if (bytes < 1024 * 1024)
            return format!"%.2f KB"(bytes / 1024.0);
        if (bytes < 1024 * 1024 * 1024)
            return format!"%.2f MB"(bytes / (1024.0 * 1024));
        return format!"%.2f GB"(bytes / (1024.0 * 1024 * 1024));
    }
    
    /// Run comprehensive benchmark suite
    @system // File operations and benchmarking
    static void runAll(string testDir = ".")
    {
        writeln("\n");
        writeln("╔════════════════════════════════════════════════════════════════╗");
        writeln("║                    BUILDER PERFORMANCE SUITE                   ║");
        writeln("╚════════════════════════════════════════════════════════════════╝");
        
        // Find test files
        string[] testFiles = glob("**/*.d", testDir);
        if (testFiles.empty)
            testFiles = glob("**/*.*", testDir);
        
        if (testFiles.empty)
        {
            writeln("No test files found in: ", testDir);
            return;
        }
        
        // Limit to reasonable number
        if (testFiles.length > 20)
            testFiles = testFiles[0 .. 20];
        
        writeln("\nTest files: ", testFiles.length);
        
        // Run benchmarks
        benchmarkMetadata(testFiles);
        benchmarkHashing(testFiles);
        benchmarkChunking(testFiles);
        benchmarkGlob(testDir, ["**/*.d", "**/*.py", "**/*.js"]);
        
        writeln("\n╔════════════════════════════════════════════════════════════════╗");
        writeln("║                    BENCHMARK COMPLETE                          ║");
        writeln("╚════════════════════════════════════════════════════════════════╝\n");
    }
}

/// Compare two benchmark results
struct BenchmarkComparison
{
    BenchmarkResult baseline;
    BenchmarkResult optimized;
    
    @system // I/O operations
    void print()
    {
        writeln("\n=== Comparison: ", baseline.name, " vs ", optimized.name, " ===");
        
        auto speedup = baseline.avgTime.total!"nsecs" / 
                      cast(double)optimized.avgTime.total!"nsecs";
        
        writeln("Baseline:  ", BenchmarkResult.formatDuration(baseline.avgTime));
        writeln("Optimized: ", BenchmarkResult.formatDuration(optimized.avgTime));
        writeln("Speedup:   ", format!"%.2f"(speedup), "x");
        
        auto improvement = (1.0 - 1.0 / speedup) * 100;
        writeln("Improvement: ", format!"%.1f"(improvement), "%");
    }
}

