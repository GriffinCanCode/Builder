# Quick Test Reference for ActionCache

## Run All ActionCache Tests

```bash
cd /Users/griffinstrier/projects/Builder

# Run all unit tests
dub test -- tests.unit.core.caching.action

# Run all integration tests
dub test -- tests.integration.action_cache_incremental
dub test -- tests.integration.action_cache_invalidation

# Run everything
dub test -- tests.unit.core.caching.action tests.integration.action_cache_incremental tests.integration.action_cache_invalidation
```

## Test Categories

### Unit Tests (Fast - ~1 second)
```bash
dub test -- tests.unit.core.caching.action
```

**Covers:**
- Basic operations (isCached, update, invalidate, clear)
- ActionId serialization
- Cache persistence
- Eviction policies (LRU, age, size)
- Statistics tracking
- Concurrent access
- Edge cases

### Integration Tests - Incremental Builds (~3 seconds)
```bash
dub test -- tests.integration.action_cache_incremental
```

**Scenarios:**
1. Multi-file C++ incremental build
2. Multi-target builds (library + app)
3. Header dependency invalidation
4. Compilation flag changes
5. Partial build failure recovery
6. Large-scale build (50+ files)

### Integration Tests - Invalidation (~2 seconds)
```bash
dub test -- tests.integration.action_cache_invalidation
```

**Scenarios:**
1. Input file modifications
2. Output file deletion
3. Metadata changes (flags, compiler, defines)
4. Multiple input changes
5. Cascading dependencies
6. Cross-target isolation
7. Failed action handling
8. Environment changes

## Verbose Output

```bash
dub test -v -- tests.unit.core.caching.action
```

## Run Specific Test

D doesn't support running individual unittest blocks, but you can:

```bash
# Run and grep for specific test
dub test -- tests.unit.core.caching.action 2>&1 | grep "Basic cache hit"
```

## Expected Output

### Successful Run
```
[TEST] ActionCache - Basic cache hit on unchanged action
  ✓ Basic cache hit works correctly
[TEST] ActionCache - Cache miss on input file change
  ✓ Cache miss on input change detected correctly
...
[INTEGRATION TEST] ActionCache - Incremental C++ build
  Phase 1: Initial build (all files compile)
    Compiled: main.cpp (cache miss)
    Compiled: utils.cpp (cache miss)
    Compiled: math.cpp (cache miss)
    Linked: my-app (cache miss)
  ...
  ✓ Incremental C++ build with action cache works correctly
```

### All Tests Passing
```
All unit tests have passed!
```

## Test Statistics

| Category | Count | Duration |
|----------|-------|----------|
| Unit Tests | 18 | ~1s |
| Integration - Incremental | 6 | ~3s |
| Integration - Invalidation | 7 | ~2s |
| **Total** | **31** | **~6s** |

## Troubleshooting

### Tests fail with "Permission denied"
```bash
# Clean temp directories
rm -rf /tmp/builder-test-*
rm -rf /tmp/action-cache-*
```

### Tests fail with timing issues
- Some tests use `Thread.sleep()` for file timestamp differences
- If filesystem has low timestamp precision, tests may fail
- Solution: Increase sleep duration in failing tests

### Concurrent tests fail
- Run tests sequentially: `dub test --single-threaded`
- Or fix synchronization in the test

## Coverage

Run with coverage:
```bash
dub test --coverage -- tests.unit.core.caching.action
# View coverage report
cat coverage.lst
```

## CI/CD Integration

For continuous integration:
```bash
#!/bin/bash
set -e

echo "Running ActionCache unit tests..."
dub test -- tests.unit.core.caching.action

echo "Running ActionCache integration tests..."
dub test -- tests.integration.action_cache_incremental
dub test -- tests.integration.action_cache_invalidation

echo "All ActionCache tests passed!"
```

## Test Development

### Add a new test
1. Edit `tests/unit/core/caching/action.d`
2. Add unittest block
3. Run tests to verify: `dub test -- tests.unit.core.caching.action`

### Debug a test
Add debug output:
```d
unittest {
    writeln("\x1b[36m[TEST]\x1b[0m My test");
    
    // Add debug info
    writeln("  DEBUG: Input path = ", sourcePath);
    writeln("  DEBUG: Cache dir = ", cacheDir);
    
    // Test logic
    Assert.isTrue(condition);
    
    writeln("\x1b[32m  ✓ Test passed\x1b[0m");
}
```

## Quick Verification After Changes

```bash
# Quick smoke test (unit tests only)
dub test -- tests.unit.core.caching.action

# Full test suite (all tests)
dub test -- tests.unit.core.caching.action \
            tests.integration.action_cache_incremental \
            tests.integration.action_cache_invalidation
```

## Files Created

- `tests/unit/core/caching/action.d` - 18 unit tests
- `tests/integration/action_cache_incremental.d` - 6 integration tests
- `tests/integration/action_cache_invalidation.d` - 7 integration tests
- `tests/unit/core/caching/README.md` - Test documentation
- `docs/development/ACTION_CACHE_TESTING.md` - Comprehensive documentation

