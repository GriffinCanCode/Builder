# Performance Benchmarks

This document describes the comprehensive performance benchmark suite for Builder's core components.

## Overview

Three new benchmark files have been added to measure and validate performance against established baselines:

1. **`serialization_bench.d`** - SIMD-accelerated serialization performance
2. **`work_stealing_bench.d`** - Lock-free work-stealing queue efficiency
3. **`chunking_bench.d`** - Content-defined chunking for network transfers

## Benchmark Files

### 1. Serialization Benchmark (`serialization_bench.d`)

**Purpose:** Validates that Builder's SIMD-accelerated serialization meets performance targets.

**Baseline Comparisons:**
- JSON serialization (target: 10x faster)
- Standard D binary format (target: 2.5x faster)

**Test Scenarios:**

| Scenario | Description | Target |
|----------|-------------|--------|
| Small Structs | 10,000 cache entries | 10x faster than JSON |
| Large Graphs | 50,000 build graph nodes | < 500ms serialize |
| SIMD Arrays | 1M integers | 5x faster than baseline |
| Nested Structures | 1,000 complex AST nodes | 8x faster than JSON |

**Key Metrics:**
- Serialize/deserialize speed
- Data size compression (target: 40% smaller)
- Throughput (operations/sec)
- Statistical analysis (mean, median, stddev)

**Expected Results:**
```
✓ Small structs: 10-20x faster than JSON
✓ Large graphs: < 500ms for 50K nodes
✓ SIMD arrays: 5-8x speedup
✓ Size reduction: 40-60% vs JSON
```

### 2. Work-Stealing Benchmark (`work_stealing_bench.d`)

**Purpose:** Validates lock-free work-stealing deque for parallel task execution.

**Baseline Comparisons:**
- Mutex-protected queue (target: 10x faster under contention)

**Test Scenarios:**

| Scenario | Description | Target |
|----------|-------------|--------|
| Single-Threaded | 100K push/pop ops | Near-zero overhead |
| Multi-Threaded | 4 threads, 100K tasks | 10x faster under contention |
| Steal Operations | 10K steal attempts | < 100ns per steal |
| Load Balancing | 8 workers, varied load | < 10% imbalance |

**Key Metrics:**
- Push/pop throughput
- Steal operation latency
- Load imbalance percentage
- Per-worker task distribution

**Expected Results:**
```
✓ Single-thread: 2-5x faster than mutex
✓ Contention: 5-15x faster under load
✓ Steal latency: < 100ns per operation
✓ Load balance: < 10% imbalance
```

### 3. Chunking Benchmark (`chunking_bench.d`)

**Purpose:** Validates Rabin fingerprinting content-defined chunking efficiency.

**Baseline Comparisons:**
- Fixed-size chunking

**Test Scenarios:**

| Scenario | Description | Target |
|----------|-------------|--------|
| Chunking Speed | 100MB binary file | < 50ms |
| Deduplication | 50MB with 30% duplicates | 90%+ detection |
| Incremental Update | 10MB file, 1% change | < 5% chunks changed |
| Network Transfer | 50MB file, 10% modified | 80%+ bandwidth savings |

**Key Metrics:**
- Chunking throughput (MB/sec)
- Deduplication ratio
- Changed chunk percentage
- Network transfer savings

**Expected Results:**
```
✓ Chunking speed: < 50ms for 100MB
✓ Dedup efficiency: 25-40% savings
✓ Incremental: < 5% re-transfer
✓ Network savings: 80-90% bandwidth
```

## Running Benchmarks

### Prerequisites

```bash
# Build Builder first
make
```

### Run Individual Benchmarks

```bash
cd tests/bench

# Serialization benchmark (~30 seconds)
dub run --single serialization_bench.d

# Work-stealing benchmark (~60 seconds, multi-threaded)
dub run --single work_stealing_bench.d

# Chunking benchmark (~45 seconds)
dub run --single chunking_bench.d
```

### Run All Performance Benchmarks

```bash
cd tests/bench
for bench in serialization_bench.d work_stealing_bench.d chunking_bench.d; do
    echo "Running $bench..."
    dub run --single $bench
    echo ""
done
```

## Output Format

Each benchmark produces:

1. **Console Output** - Detailed results with color-coded pass/fail indicators
2. **Performance Summary** - Key findings and recommendations
3. **Baseline Comparisons** - Speedup factors vs established baselines

### Example Output

```
╔════════════════════════════════════════════════════════════════╗
║         BUILDER SERIALIZATION PERFORMANCE BENCHMARKS          ║
║  Comparing SIMD-accelerated vs JSON baseline (10x target)    ║
╚════════════════════════════════════════════════════════════════╝

======================================================================
BENCHMARK 1: Small Cache Entries (10,000 items)
======================================================================
Target: 10x faster than JSON, 40% smaller size

Results:
  Builder Serialize:      45 ms
  JSON Serialize:        523 ms
  Speedup:             11.62x ✓ Target met!

  Builder Deserialize:    28 ms
  JSON Deserialize:      412 ms
  Speedup:             14.71x ✓ Target met!

  Builder Size:        245678 bytes
  JSON Size:           682341 bytes
  Compression:          2.78x ✓ Excellent
```

## Performance Targets

### Serialization
- **vs JSON**: 10-23x faster, 3-4x smaller
- **vs Binary**: 2.5-4x faster
- **Large graphs**: < 500ms for 50K nodes
- **SIMD arrays**: 5-8x speedup

### Work-Stealing
- **Single-thread**: 2-5x faster than mutex
- **Contention**: 5-15x faster under load
- **Steal latency**: < 100ns per operation
- **Load balance**: < 10% imbalance across workers

### Chunking
- **Throughput**: > 2 GB/sec chunking speed
- **Deduplication**: 25-40% space savings
- **Incremental**: < 5% re-transfer for 1% change
- **Network**: 40-90% bandwidth reduction

## Integration with CI/CD

These benchmarks can be integrated into continuous integration pipelines to detect performance regressions:

```yaml
# Example GitHub Actions workflow
- name: Run Performance Benchmarks
  run: |
    cd tests/bench
    dub run --single serialization_bench.d > serialization_results.txt
    dub run --single work_stealing_bench.d > work_stealing_results.txt
    dub run --single chunking_bench.d > chunking_results.txt
    
- name: Check Performance Targets
  run: |
    # Parse results and fail if targets not met
    grep "Target met" tests/bench/*_results.txt
```

## Troubleshooting

### Benchmark Runs Too Slow

- Reduce iteration counts in the benchmark code
- Run with release optimizations: `dub run --single --build=release`
- Close other applications to reduce noise

### Inconsistent Results

- Run multiple times and average results
- Check for background processes consuming CPU
- Ensure machine is not under thermal throttling

### Out of Memory

- Reduce test data sizes (e.g., 50K nodes → 10K nodes)
- Run benchmarks individually rather than all at once
- Monitor with `top` or Activity Monitor

## Development

### Adding New Benchmarks

1. Create new `*_bench.d` file in `tests/bench/`
2. Use `tests.bench.utils` for benchmark harness
3. Compare against established baselines
4. Document expected performance targets
5. Update this README

### Modifying Existing Benchmarks

- Maintain backwards compatibility with baselines
- Document any target changes
- Re-run all benchmarks to verify
- Update expected results in this document

## References

- [Serialization README](../../source/infrastructure/utils/serialization/README.md)
- [Work-Stealing Architecture](../../docs/architecture/workstealing.md)
- [Chunking Feature Doc](../../docs/features/chunk-transfer.md)
- [Benchmark Utils](./utils.d)

## License

Same as Builder project.

