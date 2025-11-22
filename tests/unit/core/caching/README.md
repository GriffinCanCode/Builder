# Caching System Test Suite

This directory contains comprehensive unit tests for Builder's multi-tier caching system, including target-level caching, action-level caching, content-addressable storage, eviction policies, events, and the unified cache coordinator.

## Test Files Overview

### Core Test Files

#### `action.d` - Action Cache Unit Tests
Comprehensive unit tests covering all ActionCache functionality:

#### Basic Functionality Tests
- **Basic cache hit on unchanged action** - Verifies cache hit when nothing changes
- **Cache miss on input file change** - Detects when source files are modified
- **Cache miss on metadata change** - Detects compilation flag changes
- **Cache miss on missing output file** - Invalidates when output files are deleted
- **Failed action not cached** - Ensures failed compilations don't produce cache hits
- **ActionId parsing and serialization** - Tests ActionId string format
- **Multiple actions per target** - Verifies per-file action caching

#### Cache Invalidation Tests
- **Manual invalidation** - Tests explicit cache invalidation
- **Clear all entries** - Tests cache clear operation

#### Persistence Tests
- **Persistence across instances** - Verifies cache survives process restart
- **Automatic flush on close** - Tests auto-save on cache closure

#### Eviction Policy Tests
- **LRU eviction** - Tests least-recently-used eviction
- **Age-based eviction** - Tests time-based expiration

#### Statistics Tests
- **Statistics tracking** - Verifies hit/miss tracking

#### Different Action Types Tests
- **Different action types** - Tests Compile, Link, Codegen, Test actions

#### Concurrent Access Tests
- **Concurrent action updates** - Tests thread-safe concurrent updates

#### Edge Cases
- **Empty metadata handling** - Tests actions without metadata
- **Multiple inputs per action** - Tests link actions with many inputs
- **ActionId with no subId** - Tests optional sub-identifier field

## Integration Tests

Located in `tests/integration/`:

### `action_cache_incremental.d` - Incremental Build Tests

Real-world scenarios demonstrating incremental build performance:

1. **Incremental C++ build** - Multi-file project with selective recompilation
2. **Multi-target incremental build** - Library + application with dependency tracking
3. **Header file dependency invalidation** - Validates header change detection
4. **Compilation flag change invalidation** - Detects optimization level changes
5. **Partial build failure recovery** - Caches successful actions when some fail
6. **Large-scale incremental build** - 50+ file project demonstrating cache efficiency

### `action_cache_invalidation.d` - Cache Invalidation Tests

Focused tests on invalidation correctness:

1. **Input file modification** - Content vs timestamp changes
2. **Output file deletion** - Missing output detection
3. **Metadata changes** - Compiler flags, defines, and environment
4. **Multiple input files** - Link actions with many dependencies
5. **Cascading dependency invalidation** - Transitive dependency handling
6. **Cross-target isolation** - Independent target caching
7. **Failed action handling** - Failure-aware caching
8. **Environment variable changes** - Environment-sensitive compilation

## Running the Tests

### Run Unit Tests Only
```bash
dub test --filter="tests.unit.core.caching.action"
```

### Run Integration Tests
```bash
dub test --filter="tests.integration.action_cache_incremental"
dub test --filter="tests.integration.action_cache_invalidation"
```

### Run All Action Cache Tests
```bash
dub test --filter="action_cache"
```

## Test Coverage

The test suite provides comprehensive coverage of:

- ✅ **Basic Operations** - isCached, update, invalidate, clear
- ✅ **Input Tracking** - File hash validation, multi-input actions
- ✅ **Output Tracking** - Output file existence validation
- ✅ **Metadata Tracking** - Compiler flags, environment, custom metadata
- ✅ **Action Types** - Compile, Link, Codegen, Test, Package, Transform, Custom
- ✅ **Cache Persistence** - Binary serialization, signature verification, expiration
- ✅ **Eviction Policies** - LRU, age-based, size-based
- ✅ **Concurrent Access** - Thread-safe operations
- ✅ **Statistics** - Hit/miss rates, cache size tracking
- ✅ **Incremental Builds** - Real-world build scenarios
- ✅ **Invalidation** - Comprehensive invalidation testing
- ✅ **Error Handling** - Failed action handling, partial build recovery

## Test Statistics

- **Total Unit Tests**: 18
- **Total Integration Tests**: 13
- **Total Test Assertions**: 150+
- **Lines of Test Code**: 1,500+

## Key Scenarios Covered

### Incremental Build Workflow
1. Initial build - all files compile (cache misses)
2. Rebuild without changes - all cached (cache hits)
3. Modify one file - only that file recompiles
4. Verify other files remain cached

### Cache Invalidation Scenarios
- Source file content changes
- Output file deletion
- Compilation flags change
- Compiler change
- Header file changes (affects dependents)
- Multiple input changes
- Dependency library changes

### Failure Recovery
- Some files compile successfully
- Some files fail
- Successful compilations are cached
- Failed files must be rebuilt
- After fixing, only failed files rebuild

## Implementation Notes

### Test Fixtures
Uses `TempDir` fixture for isolated filesystem operations:
```d
auto tempDir = scoped(new TempDir("test-name"));
// Creates isolated temporary directory
// Automatically cleaned up on scope exit
```

### Action IDs
Tests use proper ActionId construction:
```d
ActionId actionId;
actionId.targetId = "my-target";
actionId.type = ActionType.Compile;
actionId.inputHash = "content-hash";
actionId.subId = "source-file.cpp";  // Optional
```

### Metadata
Metadata represents execution context:
```d
string[string] metadata;
metadata["compiler"] = "g++";
metadata["flags"] = "-O2 -std=c++17";
metadata["defines"] = "-DDEBUG";
```

#### `coordinator.d` - Cache Coordinator Tests
Tests for the unified cache coordinator that orchestrates all caching tiers.

#### `storage.d` - Content-Addressable Storage Tests
Tests for CAS (content-addressable storage) with deduplication and garbage collection.

### New Comprehensive Test Suites (80/20 Edge Case Coverage)

#### `edge_cases.d` - Critical Edge Cases
Comprehensive edge case testing following the 80/20 rule for maximum impact:

**Concurrent Race Conditions:**
- Concurrent cache file access race
- File modified during hash computation

**Corrupted Cache Files:**
- Corrupted cache file recovery
- Partial write/interrupted flush

**File System Errors:**
- Read-only cache directory
- Cache directory deleted during operation

**Empty and Null Inputs:**
- Empty source file list
- Empty/null metadata in ActionCache
- Zero-byte file handling

**Special File Names:**
- Unicode and special characters in filenames
- Very long file paths

**Symlinks and Links:**
- Symlink handling and modification detection

**Hash Collision Simulation:**
- Hash collision handling in CAS

**Cache Size Boundary Conditions:**
- Cache at exactly max entries limit
- Single entry beyond size limit

**Eviction Edge Cases:**
- Eviction with simultaneous access

**Integrity Validation:**
- Tampered cache data detection

**Transitive Dependency Invalidation:**
- Nested dependency chain invalidation

**Coordinator Edge Cases:**
- Coordinator with mixed cache states

**Memory and Resource Pressure:**
- Large number of cache entries (1000+)
- Very large blob storage (1MB+ blobs)

#### `events_test.d` - Cache Events Testing
Comprehensive tests for cache event system and telemetry:

**Event Creation and Properties:**
- CacheHitEvent, CacheMissEvent, CacheUpdateEvent
- CacheEvictionEvent, RemoteCacheEvent
- CacheGCEvent, ActionCacheEvent

**Event Timing and Timestamps:**
- Timestamp generation
- Multiple events ordering

**Edge Cases:**
- Zero-duration operations
- Very large artifact sizes
- Empty target IDs
- Failed remote operations
- GC with zero collections

**Event Polymorphism:**
- Event inheritance and type handling

**Realistic Event Sequences:**
- Typical build event sequences

#### `eviction_test.d` - Eviction Policy Tests
Focused tests on cache eviction policies and strategies:

**Basic Eviction Tests:**
- No eviction when under limits
- Evict oldest entries when over max entries
- Age-based eviction
- LRU eviction preserves recently accessed

**Size-Based Eviction:**
- Size-based eviction triggers
- Calculate total size accuracy

**Hybrid Eviction Strategies:**
- Combined age + count limits
- Combined size + LRU strategies

**Edge Cases:**
- Empty cache
- Single entry eviction
- All entries same timestamp
- Zero age limit disables age eviction
- Very large entry count (1000+ entries)

**Eviction Statistics:**
- Accurate statistics reporting

**Integration with Real Caches:**
- BuildCache eviction integration
- ActionCache eviction integration

#### `integration_test.d` - Full System Integration
End-to-end integration tests combining all caching components:

**Multi-Tier Caching Integration:**
- Full build with target and action caching
- Incremental rebuild with action cache

**Content-Addressable Storage Integration:**
- CAS with coordinator
- Garbage collection with CAS

**Metrics and Events Integration:**
- Metrics collection across build

**Persistence and Recovery:**
- Persistence across coordinator restart
- Recovery from partial cache corruption

**Stress Tests:**
- Rapid cache updates (100+ entries)
- Concurrent coordinator access (20 threads)
- Large action cache with many entries (500+)
- Many small blobs in CAS (200+ blobs)

**Complex Dependency Scenarios:**
- Complex dependency graph handling
- Transitive dependency invalidation

**Edge Case Combinations:**
- Simultaneous eviction and access

## Running the Tests

### Run All Caching Tests
```bash
dub test --filter="tests.unit.core.caching"
```

### Run Specific Test Files
```bash
# Action cache tests
dub test --filter="tests.unit.core.caching.action"

# Edge case tests
dub test --filter="tests.unit.core.caching.edge_cases"

# Event tests
dub test --filter="tests.unit.core.caching.events_test"

# Eviction tests
dub test --filter="tests.unit.core.caching.eviction_test"

# Integration tests
dub test --filter="tests.unit.core.caching.integration_test"

# Coordinator tests
dub test --filter="tests.unit.core.caching.coordinator"

# Storage tests
dub test --filter="tests.unit.core.caching.storage"
```

## Test Coverage Summary

### Coverage by Component

- ✅ **Target Cache** - Basic operations, persistence, eviction, statistics
- ✅ **Action Cache** - Multi-action caching, incremental builds, invalidation
- ✅ **Content-Addressable Storage** - Blob storage, deduplication, reference counting
- ✅ **Cache Coordinator** - Multi-tier orchestration, event emission, GC coordination
- ✅ **Eviction Policies** - LRU, age-based, size-based, hybrid strategies
- ✅ **Cache Events** - All event types, polymorphism, timing, sequences
- ✅ **Garbage Collection** - Orphaned blob collection, safe deletion
- ✅ **Metrics** - Hit rates, latencies, storage statistics
- ✅ **Edge Cases** - Concurrent access, corruption, filesystem errors, boundaries
- ✅ **Integration** - Full multi-tier builds, stress tests, complex dependencies

### Test Statistics (Updated)

- **Total Unit Tests**: 100+
- **Test Files**: 7 (4 new comprehensive suites)
- **Test Assertions**: 400+
- **Lines of Test Code**: 4,500+
- **Edge Cases Covered**: 50+
- **Stress Test Scenarios**: 10+
- **Integration Scenarios**: 15+

## Key Test Scenarios

### 80/20 Rule Edge Cases (High Priority)

The new test suites focus on the 20% of edge cases that cause 80% of real-world issues:

1. **Concurrent Access** - Multiple threads/processes accessing cache
2. **Corruption Recovery** - Handling corrupted or partial cache files
3. **File System Errors** - Permission denied, disk full, missing directories
4. **Resource Limits** - Very large caches, memory pressure, many entries
5. **Special Characters** - Unicode, spaces, very long paths
6. **Race Conditions** - Files modified during operations
7. **Transitive Dependencies** - Complex dependency graphs
8. **Eviction Under Load** - Eviction during active cache operations
9. **Event Timing** - Proper event ordering and timestamp handling
10. **Multi-Tier Coordination** - All cache tiers working together

### Integration Test Patterns

**Full Build Flow:**
1. Clean build - all cache misses
2. Record actions and targets
3. Rebuild - all cache hits
4. Modify one file - selective invalidation
5. Incremental rebuild - partial cache hits

**Stress Test Pattern:**
1. Create hundreds of cache entries
2. Concurrent access from multiple threads
3. Trigger eviction under load
4. Verify correctness and consistency

**Recovery Test Pattern:**
1. Create valid cache
2. Introduce corruption/errors
3. Restart cache system
4. Verify graceful recovery or fresh start

## Best Practices Demonstrated

### Test Isolation
- Each test uses separate temporary directory
- Automatic cleanup via `scoped()` pattern
- No cross-test contamination

### Realistic Scenarios
- Real file system operations
- Actual hash computations
- Proper concurrent access patterns

### Edge Case Coverage
- Boundary conditions (0, 1, max values)
- Error conditions (missing files, corruption)
- Concurrent scenarios (race conditions)
- Resource pressure (large data, many entries)

## Future Enhancements

Additional test coverage to consider:
- Remote cache integration
- Cache compression
- Distributed builds coordination
- Cache warming strategies
- Cross-platform cache portability
- Network failure scenarios
- Backup and restore procedures

