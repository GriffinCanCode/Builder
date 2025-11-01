# Quick Start Guide: Builder Scale Benchmarking

Get up and running with large-scale benchmarks in 5 minutes.

## Prerequisites

- D compiler (`dmd` or `ldc`)
- DUB package manager
- 10+ GB free disk space
- 4+ GB RAM

## 1. Build Builder

```bash
cd /path/to/Builder
make
```

## 2. Run Your First Benchmark

### Option A: Quick Simulated Test (Fast - ~2 minutes)

```bash
cd tests/bench
dub run --single scale_benchmark.d
```

This runs simulated benchmarks without actually building anything.

### Option B: Full Integration Test (Slow - ~10-30 minutes)

```bash
cd tests/bench
dub run --single integration_bench.d
```

This generates real projects and runs the actual Builder system.

### Option C: Run All Benchmarks (Recommended)

```bash
cd tests/bench
./run-scale-benchmarks.sh
```

This runs both simulated and integration benchmarks automatically.

## 3. View Results

Check the generated reports:

```bash
cat benchmark-scale-report.md
cat benchmark-integration-report.md
```

## Common Commands

### Run Only Simulated Benchmarks

```bash
./run-scale-benchmarks.sh --simulated-only
```

Fast performance testing without real builds.

### Run Only Integration Benchmarks

```bash
./run-scale-benchmarks.sh --integration-only
```

Test real Builder system (requires built binary).

### Keep Generated Projects for Inspection

```bash
./run-scale-benchmarks.sh --keep-workspace
```

Workspaces will be preserved at:
- `bench-workspace/` - Simulated benchmark workspace
- `integration-bench-workspace/` - Integration test workspace

### Use Custom Builder Binary

```bash
./run-scale-benchmarks.sh --builder=/path/to/custom/builder
```

### Generate Test Project Without Running Benchmarks

```bash
cd tests/bench
cat > generate_project.d << 'EOF'
#!/usr/bin/env dub
/+ dub.sdl:
    name "generate-project"
    dependency "builder" path="../../"
+/

import std.stdio;
import tests.bench.target_generator;

void main()
{
    auto config = GeneratorConfig();
    config.targetCount = 50_000;
    config.projectType = ProjectType.Monorepo;
    config.outputDir = "my-test-project";
    
    auto generator = new TargetGenerator(config);
    generator.generate();
    
    writeln("Project generated at: my-test-project/");
}
EOF

dub run --single generate_project.d
```

## Understanding the Output

### Simulated Benchmark

```
[GENERATOR] Generating 50,000 targets...
  Generated 50,000 targets in 5,432 ms

[RESULTS]
  │ Targets:         50,000
  │ Total Time:      49,257 ms
  │ Throughput:      1,015 targets/sec
  │ Memory Used:     2,048 MB
  │ Cache Hit Rate:  0 %
```

**Key Metrics:**
- **Throughput**: Higher is better (targets processed per second)
- **Memory Used**: Lower is better
- **Cache Hit Rate**: Higher is better for incremental builds

### Integration Benchmark

```
[PHASE 3] Running Builder System
  Executing: ./bin/builder build
  ✓ Build succeeded
  Build time: 67,890 ms

[RESULT]
  │ Status:          PASSED
  │ Build Time:      67,890 ms
  │ Throughput:      736 targets/sec
```

**Status Indicators:**
- ✓ PASSED - Build succeeded
- ✗ FAILED - Build failed (check error message)

## Troubleshooting

### "Builder binary not found"

```bash
# Build Builder first
cd /path/to/Builder
make

# Or specify path explicitly
./run-scale-benchmarks.sh --builder=./bin/builder
```

### "Out of memory"

Reduce target count by editing the scripts:

```d
// In scale_benchmark.d or integration_bench.d
// Change:
config.targetCount = 100_000;
// To:
config.targetCount = 50_000;
```

Or add more swap space:

```bash
# Linux
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# macOS - edit /etc/sysctl.conf or use Disk Utility
```

### "Disk full"

```bash
# Check available space
df -h

# Clean up old workspaces
rm -rf bench-workspace integration-bench-workspace

# Or reduce source generation
# Edit config in scripts:
config.generateSources = false;
```

### "Build too slow"

Tips for faster benchmarks:

1. **Use SSD**: Significantly faster I/O
2. **Disable source generation**: For quick tests
3. **Run simulated only**: Skip integration tests
4. **Reduce target count**: Start with 25K-50K

```bash
# Quick test with 25K targets
./run-scale-benchmarks.sh --simulated-only
```

### Benchmark fails on specific scenario

Check the detailed output:

```bash
# Run with verbose output
dub run --single scale_benchmark.d 2>&1 | tee benchmark.log
```

## Next Steps

### 1. Customize Benchmarks

Edit `scale_benchmark.d` to add custom scenarios:

```d
scenarios ~= Scenario(
    ScenarioType.IncrementalSmall,
    75_000,
    "My custom scenario",
    false
);
```

### 2. Profile Performance

```bash
# Linux with perf
perf record -g dub run --single integration_bench.d
perf report

# macOS with Instruments
instruments -t "Time Profiler" dub run --single integration_bench.d
```

### 3. Track Performance Over Time

```bash
# Create historical record
mkdir -p benchmark-history
DATE=$(date +%Y-%m-%d)
./run-scale-benchmarks.sh
cp benchmark-*.md "benchmark-history/benchmark-$DATE.md"

# Compare with git
git log --all --graph --decorate --oneline benchmark-history/
```

### 4. CI/CD Integration

Add to `.github/workflows/benchmark.yml`:

```yaml
- name: Run Benchmarks
  run: |
    make
    cd tests/bench
    ./run-scale-benchmarks.sh --simulated-only
```

### 5. Custom Analysis

Export results to JSON for custom analysis:

```d
// In scale_benchmark.d
import std.json;

JSONValue toJson(ScaleBenchmarkResult result)
{
    JSONValue j;
    j["scenario"] = result.scenarioName;
    j["targets"] = result.targetCount;
    j["time_ms"] = result.totalTime.total!"msecs";
    j["throughput"] = result.targetsPerSecond;
    return j;
}

// Write JSON report
auto f = File("benchmark-results.json", "w");
f.write(results.map!toJson.array.toPrettyString);
```

## Performance Goals

### Targets for 50K Targets

| Scenario | Expected Time | Expected Throughput |
|----------|--------------|---------------------|
| Clean Build | 45-60s | 800-1200 t/s |
| Null Build | 5-10s | 5000-10000 t/s |
| Incremental (1%) | 8-12s | 4000-6000 t/s |
| Incremental (10%) | 15-20s | 2500-3500 t/s |

### Memory Usage

- **50K targets**: 1.5-2.5 GB peak
- **100K targets**: 3-5 GB peak

### Scaling

- **50K → 100K**: Should be ~2.0x (linear)
- **Alert if**: >2.5x (sub-linear scaling)

## Getting Help

- 📖 Full documentation: `tests/bench/README.md`
- 🐛 Report issues: Check project issue tracker
- 💬 Discussions: Project forums/chat

## Example Session

Complete example of a benchmark session:

```bash
$ cd /path/to/Builder
$ make
✓ Builder built successfully

$ cd tests/bench
$ ./run-scale-benchmarks.sh --simulated-only

╔════════════════════════════════════════════════════════════════╗
║           Builder Scale Benchmark Runner                      ║
╚════════════════════════════════════════════════════════════════╝

[INFO] Configuration:
  Simulated Tests: true
  Integration Tests: false

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running: Simulated Scale Benchmark
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[GENERATOR] Generating 50,000 targets...
  Phase 1/3: Generating target metadata...
  Phase 2/3: Generating dependency graph...
  Phase 3/3: Writing project files...
✓ Generated 50,000 targets

[SCENARIO 1/8] Clean build - 50K targets
... (benchmark runs) ...

✓ Simulated Scale Benchmark completed successfully

╔════════════════════════════════════════════════════════════════╗
║                    BENCHMARK SUMMARY                           ║
╚════════════════════════════════════════════════════════════════╝

Passed Tests (1):
  ✓ Simulated Benchmark

Generated Reports:
  - benchmark-scale-report.md (15K)

✓ All benchmarks completed successfully!

$ cat benchmark-scale-report.md
# Builder Large-Scale Benchmark Report

Generated: 2025-11-01T10:30:45

## Summary
...
```

---

**Ready to benchmark? Run:**

```bash
cd tests/bench
./run-scale-benchmarks.sh
```

Good luck! 🚀

