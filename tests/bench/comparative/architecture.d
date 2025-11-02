/**
 * Comparative Benchmarking Framework - Core Architecture
 * 
 * Elegant, modular system for comparing build systems:
 * - Builder (our system)
 * - Buck2 (Meta)
 * - Bazel (Google)
 * - Pants (Twitter/Toolchain Labs)
 */

module tests.bench.comparative.architecture;

import std.datetime : Duration;
import std.typecons : Nullable;

/// Result monad for safe error handling
struct Result(T)
{
    import std.variant : Algebraic;
    
    Algebraic!(T, string) value;
    
    this(T val) { value = val; }
    this(string err) { value = err; }
    
    @property bool isOk() const { return value.peek!T !is null; }
    @property bool isErr() const { return value.peek!string !is null; }
    
    @property T unwrap()
    {
        if (auto p = value.peek!T)
            return *p;
        throw new Exception("Unwrapped error: " ~ *value.peek!string);
    }
    
    @property string error()
    {
        if (auto p = value.peek!string)
            return *p;
        return "";
    }
}

/// Build system identifier
enum BuildSystem
{
    Builder,
    Buck2,
    Bazel,
    Pants
}

/// Benchmark scenario type
enum ScenarioType
{
    CleanBuild,        // Full rebuild
    NullBuild,         // No changes (cache test)
    IncrementalSmall,  // 1-5% changed
    IncrementalMedium, // 10-20% changed
    IncrementalLarge,  // 30-50% changed
    Parallel,          // Parallelization test
    LargeScale,        // 10K+ targets
    MassiveScale,      // 100K+ targets
    ColdStart,         // First build after clean
    WarmCache          // Subsequent builds
}

/// Project complexity level
enum Complexity
{
    Trivial,    // < 10 targets
    Small,      // 10-100 targets
    Medium,     // 100-1000 targets
    Large,      // 1K-10K targets
    VeryLarge,  // 10K-100K targets
    Massive     // 100K+ targets
}

/// Language distribution for multi-language projects
struct LanguageDistribution
{
    double typescript = 0.40;
    double python = 0.25;
    double rust = 0.15;
    double go = 0.10;
    double cpp = 0.05;
    double java = 0.05;
    
    void normalize()
    {
        auto total = typescript + python + rust + go + cpp + java;
        if (total > 0)
        {
            typescript /= total;
            python /= total;
            rust /= total;
            go /= total;
            cpp /= total;
            java /= total;
        }
    }
}

/// Project configuration for benchmark
struct ProjectConfig
{
    string name;
    Complexity complexity;
    size_t targetCount;
    LanguageDistribution languages;
    double avgDependenciesPerTarget = 3.5;
    double libToExecRatio = 0.7;
    bool generateRealSources = true;
    bool complexDependencyGraph = true;
}

/// Build metrics collected from a single run
struct BuildMetrics
{
    Duration totalTime;
    Duration parseTime;
    Duration analysisTime;
    Duration executionTime;
    size_t memoryUsedMB;
    size_t peakMemoryMB;
    size_t diskUsedMB;
    size_t cacheHits;
    size_t cacheMisses;
    size_t targetsBuilt;
    size_t targetsCached;
    size_t parallelJobs;
    double cpuUsagePercent;
    bool success;
    string errorMessage;
    
    /// Derived metrics
    @property double cacheHitRate() const
    {
        auto total = cacheHits + cacheMisses;
        return total > 0 ? (cast(double)cacheHits / total) : 0.0;
    }
    
    @property double targetsPerSecond() const
    {
        auto seconds = totalTime.total!"msecs" / 1000.0;
        return seconds > 0 ? (targetsBuilt / seconds) : 0.0;
    }
    
    @property double efficiency() const
    {
        // Measure of work done per resource used
        auto resourceScore = memoryUsedMB + (diskUsedMB / 100.0);
        return resourceScore > 0 ? (targetsPerSecond / resourceScore) : 0.0;
    }
}

/// Benchmark result for a specific scenario
struct BenchmarkResult
{
    BuildSystem system;
    ScenarioType scenario;
    ProjectConfig project;
    BuildMetrics[] runs;  // Multiple runs for statistical significance
    
    /// Statistical metrics
    @property BuildMetrics average() const
    {
        import std.algorithm : sum, map;
        
        if (runs.length == 0)
            return BuildMetrics.init;
        
        BuildMetrics avg;
        avg.totalTime = runs.map!(r => r.totalTime).sum / runs.length;
        avg.parseTime = runs.map!(r => r.parseTime).sum / runs.length;
        avg.analysisTime = runs.map!(r => r.analysisTime).sum / runs.length;
        avg.executionTime = runs.map!(r => r.executionTime).sum / runs.length;
        avg.memoryUsedMB = cast(size_t)(runs.map!(r => r.memoryUsedMB).sum / runs.length);
        avg.peakMemoryMB = cast(size_t)(runs.map!(r => r.peakMemoryMB).sum / runs.length);
        avg.diskUsedMB = cast(size_t)(runs.map!(r => r.diskUsedMB).sum / runs.length);
        avg.cacheHits = cast(size_t)(runs.map!(r => r.cacheHits).sum / runs.length);
        avg.cacheMisses = cast(size_t)(runs.map!(r => r.cacheMisses).sum / runs.length);
        avg.targetsBuilt = cast(size_t)(runs.map!(r => r.targetsBuilt).sum / runs.length);
        avg.targetsCached = cast(size_t)(runs.map!(r => r.targetsCached).sum / runs.length);
        avg.parallelJobs = cast(size_t)(runs.map!(r => r.parallelJobs).sum / runs.length);
        avg.cpuUsagePercent = runs.map!(r => r.cpuUsagePercent).sum / runs.length;
        avg.success = runs.map!(r => r.success ? 1 : 0).sum == runs.length;
        
        return avg;
    }
    
    @property BuildMetrics best() const
    {
        import std.algorithm : minElement;
        return runs.minElement!(r => r.totalTime.total!"msecs");
    }
    
    @property BuildMetrics worst() const
    {
        import std.algorithm : maxElement;
        return runs.maxElement!(r => r.totalTime.total!"msecs");
    }
    
    @property double stdDev() const
    {
        import std.algorithm : map, sum;
        import std.math : sqrt;
        
        if (runs.length < 2)
            return 0.0;
        
        auto avg = average.totalTime.total!"msecs";
        auto variance = runs.map!(r => (r.totalTime.total!"msecs" - avg) ^^ 2).sum / runs.length;
        return sqrt(variance);
    }
}

/// Comparative analysis between build systems
struct Comparison
{
    BenchmarkResult baseline;  // Usually Builder
    BenchmarkResult competitor;
    
    @property double speedup() const
    {
        auto baselineTime = baseline.average.totalTime.total!"msecs";
        auto competitorTime = competitor.average.totalTime.total!"msecs";
        return competitorTime > 0 ? (cast(double)baselineTime / competitorTime) : 0.0;
    }
    
    @property double memoryRatio() const
    {
        auto baselineMem = baseline.average.memoryUsedMB;
        auto competitorMem = competitor.average.memoryUsedMB;
        return competitorMem > 0 ? (cast(double)baselineMem / competitorMem) : 0.0;
    }
    
    @property string verdict() const
    {
        auto sp = speedup;
        if (sp > 1.2) return "Winner";
        if (sp > 0.95) return "Competitive";
        if (sp > 0.8) return "Acceptable";
        return "Needs Improvement";
    }
}

/// Build system adapter interface
interface IBuildSystemAdapter
{
    /// Get the build system name
    @property BuildSystem system() const;
    
    /// Check if this build system is installed
    Result!bool isInstalled();
    
    /// Get version information
    Result!string getVersion();
    
    /// Generate project files for this build system
    Result!void generateProject(in ProjectConfig config, string outputDir);
    
    /// Clean build artifacts
    Result!void clean(string projectDir);
    
    /// Run a build and collect metrics
    Result!BuildMetrics build(string projectDir, bool incremental = false);
    
    /// Modify files for incremental build testing
    Result!void modifyFiles(string projectDir, double changePercent);
    
    /// Get optimal parallelism for this system
    size_t optimalParallelism() const;
}

/// Benchmark configuration
struct BenchmarkConfig
{
    ProjectConfig[] projects;
    ScenarioType[] scenarios;
    BuildSystem[] systems;
    size_t runsPerScenario = 5;  // Statistical significance
    bool cleanBetweenRuns = true;
    bool warmupRuns = true;
    string workspaceDir = "bench-comparative";
}

/// Benchmark runner interface
interface IBenchmarkRunner
{
    /// Run a single scenario
    Result!BenchmarkResult runScenario(
        IBuildSystemAdapter adapter,
        ScenarioType scenario,
        in ProjectConfig project
    );
    
    /// Run all configured benchmarks
    Result!(BenchmarkResult[]) runAll(in BenchmarkConfig config);
    
    /// Generate comparative report
    void generateReport(in BenchmarkResult[] results, string outputPath);
}

/// Statistical utilities
struct Statistics
{
    static double mean(T)(const T[] values)
    {
        import std.algorithm : sum;
        return values.length > 0 ? cast(double)values.sum / values.length : 0.0;
    }
    
    static double median(T)(T[] values)
    {
        import std.algorithm : sort;
        
        if (values.length == 0) return 0.0;
        values.sort();
        auto mid = values.length / 2;
        return values.length % 2 == 0
            ? (cast(double)values[mid-1] + values[mid]) / 2.0
            : cast(double)values[mid];
    }
    
    static double stdDev(T)(const T[] values)
    {
        import std.algorithm : map, sum;
        import std.math : sqrt;
        
        if (values.length < 2) return 0.0;
        
        auto avg = mean(values);
        auto variance = values.map!(v => (cast(double)v - avg) ^^ 2).sum / values.length;
        return sqrt(variance);
    }
    
    static double percentile(T)(T[] values, double p)
    {
        import std.algorithm : sort;
        import std.math : floor;
        
        if (values.length == 0) return 0.0;
        
        values.sort();
        auto index = cast(size_t)floor((values.length - 1) * p);
        return cast(double)values[index];
    }
}

