# Integration Tests

Comprehensive integration tests for Builder's core functionality and distributed build system.

## Test Suites

### Build System Integration

#### `build.d` - Core Build Integration
Tests for complete build workflows:
- Full project builds (Python, JavaScript, Go, Rust)
- Multi-target builds with dependencies
- Build graph construction and execution
- Incremental builds
- Cache integration

#### `language_handlers.d` - Language Handler Integration
Tests for language-specific build handlers:
- Python (pytest, setuptools)
- JavaScript/TypeScript (npm, webpack)
- Go (go build, go test)
- Rust (cargo)
- D (dmd, dub)
- Multi-language projects

#### `multilang_stress.d` - Multi-Language Stress Testing
Stress tests for mixed-language projects:
- Large codebases with multiple languages
- Complex dependency graphs
- Concurrent language handler execution
- Resource utilization under load

### Caching Integration

#### `action_cache_incremental.d` - Incremental Caching
Tests for action cache with incremental builds:
- Cache hit/miss scenarios
- Dependency-based invalidation
- Content-addressable caching
- Incremental update performance

#### `action_cache_invalidation.d` - Cache Invalidation
Tests for cache invalidation strategies:
- Time-based expiration
- Content change detection
- Dependency chain invalidation
- Manual cache clearing

#### `cache_pressure.d` - Cache Under Load
Stress tests for cache system:
- High-frequency cache operations
- Large artifact storage
- Concurrent cache access
- Eviction policy validation

#### `checkpoint_resume.d` - Build Checkpointing
Tests for build interruption and resume:
- Checkpoint creation during build
- Resume from checkpoint
- State consistency validation
- Partial build recovery

### Parser & Language Analysis

#### `parser_fuzzing.d` - Parser Fuzzing
Fuzz testing for DSL parsers:
- Random input generation
- Error handling validation
- Edge case discovery
- Parser robustness testing

### Distributed System Integration

#### `distributed_e2e.d` - End-to-End Distributed Builds
**Comprehensive end-to-end testing for distributed build system**

**Test Coverage:**
- Simple distributed builds across workers
- Multiple actions distributed and load balanced
- Build graph with dependencies
- Priority-based scheduling (Critical/High/Normal/Low)
- Load balancing validation across worker pool
- Worker capability matching
- Large-scale builds (100+ actions, stress testing)
- Dynamic worker join/leave
- Coordinator recovery after worker loss

**Key Features:**
- Mock workers with functional execution
- Full coordinator-worker communication
- Action scheduling and distribution
- Work-stealing simulation
- Priority queue validation
- Throughput measurement
- Recovery testing

**Test Count:** 10 integration tests

#### `distributed_chaos.d` - Chaos Engineering Tests
**Industry-standard chaos testing with fault injection**

**Fault Injection Types:**
- `NetworkDelay` - Slow network conditions
- `NetworkDrop` - Packet loss
- `NetworkPartition` - Complete network partition
- `WorkerCrash` - Simulated worker crashes
- `WorkerHang` - Worker becomes unresponsive
- `Timeout` - Operation timeouts

**Test Coverage:**
- Network partition during build
- Worker crash and recovery
- Multiple simultaneous worker failures
- Network delays and timeouts
- Worker hanging (unresponsive)
- Cascading failures
- Network partition and healing
- Repeated worker crashes (flapping)
- Load spike during failures
- Timeout handling

**Chaos Scenarios:**
- Single worker failure → Work reassignment
- Mass failure (3/5 workers) → System continues with remaining
- Cascading failures → Progressive degradation handling
- Network partition → Split-brain prevention
- Flapping workers → Stability under instability
- Load spike + failures → Resource redistribution

**Test Count:** 10 chaos tests

**Fault Configuration:**
```d
FaultConfig delayConfig;
delayConfig.type = FaultType.NetworkDelay;
delayConfig.probability = 1.0;  // 100% injection
delayConfig.delay = 3.seconds;
delayConfig.maxFaults = 5;
worker.addFault(delayConfig);
```

### Real-World Integration

#### `real_world_builds.d` - Real-World Projects
Integration tests with actual open-source projects:
- Clone and build real repositories
- Validate build outputs
- Performance benchmarking
- Compatibility testing

#### `stress_parallel.d` - Parallel Build Stress
Stress tests for parallel build execution:
- Maximum parallelism testing
- Thread pool saturation
- Resource contention handling
- Deadlock prevention

## Running Integration Tests

### Run All Integration Tests
```bash
cd /Users/griffinstrier/projects/Builder
dub test -- tests.integration
```

### Run Specific Test Suite
```bash
# Core builds
dub test -- tests.integration.build

# Distributed end-to-end
dub test -- tests.integration.distributed_e2e

# Chaos engineering
dub test -- tests.integration.distributed_chaos

# Caching
dub test -- tests.integration.action_cache_incremental

# Language handlers
dub test -- tests.integration.language_handlers
```

### Run Individual Test
```bash
# Run with verbose output
dub test -v -- tests.integration.distributed_chaos
```

## Test Infrastructure

### Fixtures
- `TempDir` - Temporary directory management
- `MockWorkspace` - Mock workspace creation
- `E2EWorker` - Functional mock worker
- `MockWorker` - Chaos-capable mock worker
- `DistributedTestFixture` - Distributed system setup

### Utilities
- `Assert.*` - Assertion helpers
- `Logger.*` - Test logging
- `MonoTime` - Performance measurement

## Test Categories

| Category | Test Count | Purpose |
|----------|------------|---------|
| Build System | 3 | Core build workflows |
| Caching | 4 | Cache behavior and performance |
| Distributed E2E | 10 | End-to-end distributed builds |
| Distributed Chaos | 10 | Fault injection and recovery |
| Language Support | 2 | Multi-language integration |
| Parser | 1 | Parser robustness |
| Real-World | 2 | Compatibility validation |
| **Total** | **32** | **Comprehensive coverage** |

## Industry Standards Compliance

### Distributed System Testing ✅
Following Google SRE / Netflix Chaos Engineering practices:

1. **End-to-End Testing**
   - Full coordinator-worker integration
   - Real network communication
   - Complete build workflows

2. **Fault Injection**
   - Network failures (delay, drop, partition)
   - Worker crashes and hangs
   - Timeout scenarios
   - Resource exhaustion

3. **Chaos Engineering**
   - Cascading failures
   - Split-brain scenarios
   - Load spike handling
   - Recovery validation

4. **Production Readiness**
   - Load balancing verification
   - Priority scheduling
   - Worker pool management
   - Graceful degradation

## CI/CD Integration

These tests run as part of the Builder CI pipeline:
- Executed on every PR
- Required for merge approval
- Performance benchmarks tracked
- Failure notifications sent

## Contributing

When adding new integration tests:

1. **Follow naming conventions**
   - `test_name.d` for test files
   - Descriptive test names in comments

2. **Use existing fixtures**
   - Prefer `TempDir` for file operations
   - Use `Assert.*` for validation
   - Leverage test harness utilities

3. **Document thoroughly**
   - Add test description in file header
   - Explain what scenario is tested
   - Document expected outcomes

4. **Update this README**
   - Add test to appropriate category
   - Update test count
   - Document new features

5. **Ensure isolation**
   - Tests must not interfere with each other
   - Clean up resources in `scope(exit)`
   - Use unique ports/directories

## Performance Targets

| Test Type | Target Duration | Max Duration |
|-----------|----------------|--------------|
| Unit Test | < 100ms | 1s |
| Integration | < 5s | 30s |
| Stress Test | < 30s | 2m |
| Chaos Test | < 15s | 1m |
| E2E Test | < 10s | 1m |

## Notes

- Integration tests require more setup than unit tests
- Some tests may require network access (disabled in sandbox)
- Distributed tests use local ports (18000-18200 range)
- Tests are deterministic and reproducible
- Failure logs are captured for debugging

## Chaos Engineering Tests (NEW)

### Graph Discovery Chaos
**File:** `graph_discovery_chaos.d`
- Cycle detection with chaos injection
- Race conditions in concurrent discovery
- Explosive graph growth handling
- Invalid target data validation
- 8 chaos test scenarios

### Economics Chaos
**File:** `economics_chaos.d`
- Real cloud pricing volatility (AWS/GCP/Azure)
- Price spikes and budget violations
- Spot instance terminations
- Invalid cost handling (NaN, Infinity)
- 9 chaos test scenarios

### Hermetic Cross-Platform
**File:** `hermetic_crossplatform.d`
- Linux/macOS/Windows hermetic builds
- Platform-specific compiler flags
- Cross-platform reproducibility
- File system behavior differences
- 11 cross-platform test scenarios

### Plugin Recovery Chaos
**File:** `plugin_recovery_chaos.d`
- Plugin crashes and recovery
- Timeout and hang detection
- Invalid JSON/RPC responses
- Retry logic validation
- 9 chaos test scenarios

### Distributed Network Chaos
**File:** `distributed_network_chaos.d`
- Packet loss and corruption
- Network partitions (split-brain)
- Asymmetric failures
- Bandwidth limitations
- 10 chaos test scenarios

### Corruption & Worker Killing
**File:** `corruption_chaos.d`
- File corruption (content, truncation, deletion)
- Cache corruption during builds
- Worker killing (SIGTERM, SIGKILL, OOM)
- Disk full simulation
- 7 chaos test scenarios

**Total Chaos Tests:** 58 tests covering 54 distinct fault types

See `CHAOS_TESTING_IMPLEMENTATION.md` for comprehensive documentation.

## Future Additions

Planned integration tests:
- [ ] Remote cache integration tests
- [ ] LSP integration tests
- [ ] Watch mode integration
- [ ] Performance regression detection

## Support

For test failures or questions:
- Check test logs for detailed output
- Review fixture setup/teardown
- Verify resource availability (ports, disk space)
- Run with verbose flag: `dub test -v`
- Contact: Griffin (griffincancode@gmail.com)

