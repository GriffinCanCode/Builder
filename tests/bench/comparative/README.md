# Comparative Benchmarking Framework

Comprehensive, extensible benchmarking system for comparing Builder against industry-leading build systems: **Buck2** (Meta), **Bazel** (Google), and **Pants** (Twitter/Toolchain Labs).

## Architecture

The framework follows elegant, modular design principles:

```
comparative/
├── architecture.d  # Core types, interfaces, result monads
├── adapters.d      # Build system implementations
├── runner.d        # Benchmark orchestration
├── report.d        # Report generation
├── main.d          # CLI entry point
└── README.md       # This file
```

### Design Principles

1. **Strong Typing**: Result monads for safe error handling
2. **Extensibility**: Interface-based adapters for easy system addition
3. **Statistical Rigor**: Multiple runs, confidence intervals, std dev
4. **Modularity**: Each component is compact, focused, testable

## Quick Start

### Prerequisites

```bash
# Build Builder first
make

# Install competitor systems (optional)
brew install buck2     # Meta's Buck2
brew install bazel     # Google's Bazel  
pip install pantsbuild.pants  # Pants
```

### Run Benchmarks

```bash
# Full comparative benchmark
cd tests/bench/comparative
dub run --single main.d

# Quick benchmark (fewer runs, smaller projects)
dub run --single main.d -- --quick

# Builder only (no competitors)
dub run --single main.d -- --builder-only

# Specific systems
dub run --single main.d -- --systems=builder,buck2

# Custom workspace
dub run --single main.d -- --workspace=/tmp/bench --output=my-report.md
```

## Usage

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `--workspace` | Workspace directory | `--workspace=/tmp/bench` |
| `--output` | Report output path | `--output=report.md` |
| `--quick` | Quick mode (3 runs, small projects) | `--quick` |
| `--builder-only` | Skip competitor testing | `--builder-only` |
| `--systems` | Systems to test | `--systems=builder,buck2` |
| `--help` | Show help | `--help` |

### Benchmark Scenarios

1. **Clean Build**: Full rebuild from scratch (cold cache)
2. **Null Build**: No changes, 100% cache hit
3. **Incremental Small**: 1-5% of files changed
4. **Incremental Medium**: 10-20% of files changed
5. **Incremental Large**: 30-50% of files changed

### Project Complexities

- **Small**: 50 targets
- **Medium**: 500 targets
- **Large**: 2,000 targets
- **Very Large**: 10,000 targets

## Architecture Details

### Result Monad

Safe error handling without exceptions:

```d
Result!BuildMetrics metrics = adapter.build(projectDir);

if (metrics.isOk)
{
    auto m = metrics.unwrap;
    writeln("Success: ", m.totalTime);
}
else
{
    writeln("Error: ", metrics.error);
}
```

### Adapter Interface

All build systems implement `IBuildSystemAdapter`:

```d
interface IBuildSystemAdapter
{
    Result!bool isInstalled();
    Result!string getVersion();
    Result!void generateProject(ProjectConfig, string dir);
    Result!void clean(string projectDir);
    Result!BuildMetrics build(string projectDir, bool incremental);
    Result!void modifyFiles(string projectDir, double changePercent);
    size_t optimalParallelism() const;
}
```

### Metrics Collection

Comprehensive metrics for each build:

```d
struct BuildMetrics
{
    Duration totalTime;
    Duration parseTime;
    Duration analysisTime;
    Duration executionTime;
    size_t memoryUsedMB;
    size_t peakMemoryMB;
    size_t cacheHits;
    size_t cacheMisses;
    size_t targetsBuilt;
    double cpuUsagePercent;
    // ... derived metrics
}
```

## Reports

Generated reports include:

1. **Executive Summary**: Rankings, key findings
2. **System Comparison**: Head-to-head analysis
3. **Scenario Analysis**: Performance by scenario type
4. **Detailed Results**: All metrics for all runs
5. **Statistical Analysis**: Confidence intervals, std dev
6. **Recommendations**: Actionable improvements

### Sample Output

```
═══════════════════════════════════════════════════════════════
| Rank | System  | Avg Time | Throughput | Cache Hit Rate |
|------|---------|----------|------------|----------------|
| 1    | Buck2   | 234 ms   | 2137 t/s   | 98.5%         |
| 2    | Bazel   | 289 ms   | 1730 t/s   | 97.2%         |
| 3    | Builder | 356 ms   | 1404 t/s   | 95.8%         |
| 4    | Pants   | 421 ms   | 1188 t/s   | 94.3%         |
═══════════════════════════════════════════════════════════════
```

## Extending the Framework

### Adding a New Build System

1. Create adapter class:

```d
class MySystemAdapter : IBuildSystemAdapter
{
    override BuildSystem system() const { return BuildSystem.MySystem; }
    
    override Result!void generateProject(ProjectConfig config, string dir)
    {
        // Generate build files
        return Result!void();
    }
    
    override Result!BuildMetrics build(string projectDir, bool incremental)
    {
        // Run build, collect metrics
        BuildMetrics metrics;
        // ... populate metrics
        return Result!BuildMetrics(metrics);
    }
    
    // ... implement other methods
}
```

2. Add to `BuildSystem` enum in `architecture.d`
3. Update `AdapterFactory` in `adapters.d`

### Adding a New Scenario

1. Add to `ScenarioType` enum:

```d
enum ScenarioType
{
    // ... existing scenarios
    MyNewScenario
}
```

2. Implement in `BenchmarkRunner.runScenario()`:

```d
case ScenarioType.MyNewScenario:
    runMyNewScenario(adapter, projectDir, result);
    break;
```

### Custom Metrics

Extend `BuildMetrics`:

```d
struct BuildMetrics
{
    // ... existing fields
    size_t myCustomMetric;
}
```

## Performance Expectations

### Benchmark Runtime

- **Quick mode**: 2-5 minutes
- **Full mode**: 15-30 minutes
- **With competitors**: +10-20 minutes per system

### Disk Usage

- Small projects: ~10 MB per system
- Medium projects: ~100 MB per system
- Large projects: ~500 MB per system
- Very large: ~2 GB per system

### Memory Usage

- Framework overhead: ~50 MB
- Per project: ~100-500 MB
- Large scale (10K+ targets): 1-2 GB

## Best Practices

1. **Consistent Environment**: Run on same hardware for fair comparison
2. **Multiple Runs**: Framework does 5 runs per scenario for statistical significance
3. **Clean Between Runs**: Enabled by default to ensure reproducibility
4. **Warmup**: First run may be slower due to OS caching
5. **Resource Monitoring**: Watch CPU, memory, disk I/O during benchmarks

## Troubleshooting

### System Not Installed

```
⚠ Buck2: not installed
   Install with: brew install buck2
```

**Solution**: Install the missing system or use `--builder-only`

### Build Failures

If a competitor fails:
- Check installation: `buck2 --version`, `bazel version`, etc.
- Review generated project files in workspace
- Check system-specific logs

### Performance Variance

High std dev indicates:
- Background processes competing for resources
- Thermal throttling
- Disk I/O contention

**Solution**: Close other applications, run benchmarks when system is idle

## Contributing

### Code Style

- One word, memorable file names
- Functions < 50 lines
- Strong typing, no `any` types
- Result monads for error handling
- Comprehensive documentation

### Testing

```bash
# Test adapters
dub test --single adapters.d

# Test runner
dub test --single runner.d

# Test report generation
dub test --single report.d
```

## Related Tools

- `../scale_benchmark.d`: Large-scale simulated benchmarks (50K-100K targets)
- `../integration_bench.d`: Integration tests with real Builder binary
- `../realworld.d`: Enhanced real-world project benchmarks
- `../../test-real-world.sh`: Quick real-world test suite

## Future Enhancements

- [ ] Remote execution benchmarking
- [ ] Distributed caching tests
- [ ] Network I/O simulation
- [ ] More languages (Kotlin, Swift, Scala)
- [ ] Docker containerized benchmarks
- [ ] CI/CD integration (GitHub Actions)
- [ ] Historical trend analysis
- [ ] Interactive web dashboard
- [ ] Automated regression detection

## License

Same as Builder project (see root LICENSE file).

## References

- [Buck2 Documentation](https://buck2.build/)
- [Bazel Documentation](https://bazel.build/)
- [Pants Documentation](https://www.pantsbuild.org/)
- [Build System Performance Best Practices](https://buildbuddy.io/blog/)

---

*Built with elegance, tested with rigor.*

