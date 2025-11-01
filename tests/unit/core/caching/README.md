# Action Cache Test Suite

This directory contains comprehensive unit tests for the ActionCache system, which provides fine-grained, action-level caching for incremental builds.

## Test Files

### `action.d` - Unit Tests

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

## Future Enhancements

Potential additional tests:
- Remote cache integration
- Cache compression
- Distributed builds
- Cache warming strategies
- Cross-platform cache portability

