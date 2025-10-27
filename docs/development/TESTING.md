# Testing Guide

## Overview

Builder uses a sophisticated test infrastructure designed for extensibility, modularity, and performance. The testing system leverages D's built-in `unittest` blocks with a custom test harness for enhanced capabilities.

## Architecture

### Structure

```
tests/
├── runner.d          # Main test runner with CLI
├── harness.d         # Test framework and assertions
├── fixtures.d        # Test fixtures and helpers
├── mocks.d           # Mock objects and spies
├── unit/             # Unit tests (mirrors source/)
│   ├── core/
│   │   ├── graph.d
│   │   ├── cache.d
│   │   ├── executor.d
│   │   └── storage.d
│   ├── analysis/
│   │   ├── types.d
│   │   └── ...
│   ├── config/
│   │   └── parser.d
│   ├── languages/
│   │   └── python.d
│   └── utils/
│       ├── glob.d
│       └── hash.d
├── integration/      # Integration tests
│   └── build.d
└── bench/            # Benchmarks
    └── suite.d
```

## Running Tests

### Run All Tests

```bash
dub test
```

### Run with Verbose Output

```bash
dub test -- --verbose
```

### Run Specific Tests (Filter)

```bash
dub test -- --filter="glob"
```

### Parallel Execution

```bash
dub test -- --parallel --workers=8
```

## Writing Tests

### Basic Unit Test

```d
module tests.unit.mymodule;

import std.stdio;
import tests.harness;
import mymodule;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m mymodule - Test description");
    
    // Arrange
    auto obj = new MyClass();
    
    // Act
    auto result = obj.doSomething();
    
    // Assert
    Assert.equal(result, expectedValue);
    
    writeln("\x1b[32m  ✓ Test passed\x1b[0m");
}
```

### Using Fixtures

```d
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m mymodule - Test with temp directory");
    
    auto tempDir = scoped(new TempDir("my-test"));
    
    tempDir.createFile("test.txt", "content");
    Assert.isTrue(tempDir.hasFile("test.txt"));
    
    // Automatic cleanup on scope exit
    writeln("\x1b[32m  ✓ Test passed\x1b[0m");
}
```

### Using Mock Workspace

```d
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m mymodule - Test with workspace");
    
    auto workspace = scoped(new MockWorkspace());
    
    workspace.createTarget("lib", TargetType.Library, 
                          ["lib.py"], []);
    workspace.createTarget("app", TargetType.Executable, 
                          ["main.py"], ["//lib"]);
    
    // Test workspace operations
    
    writeln("\x1b[32m  ✓ Test passed\x1b[0m");
}
```

### Using Mocks

```d
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m mymodule - Test with mock handler");
    
    auto mockHandler = new MockLanguageHandler(true);
    
    // Use mock in test
    auto result = mockHandler.build(target, config);
    
    Assert.isTrue(mockHandler.buildCalled);
    Assert.isTrue(result.success);
    
    writeln("\x1b[32m  ✓ Test passed\x1b[0m");
}
```

## Assertions

The `Assert` struct provides type-safe assertions:

### Equality

```d
Assert.equal(actual, expected);
Assert.notEqual(actual, unexpected);
```

### Boolean

```d
Assert.isTrue(condition);
Assert.isFalse(condition);
Assert.isTrue(condition, "Custom message");
```

### Null Checks

```d
Assert.isNull(ptr);
Assert.notNull(ptr);
```

### Collections

```d
Assert.contains(array, element);
Assert.isEmpty(array);
Assert.notEmpty(array);
```

### Exceptions

```d
Assert.throws!MyException({
    throwingFunction();
});

Assert.notThrows({
    safeFunction();
});
```

## Benchmarks

### Writing Benchmarks

```d
module tests.bench.mybench;

import tests.bench.suite;

unittest
{
    auto suite = new BenchmarkSuite();
    
    suite.bench("operation name", 10000, {
        // Code to benchmark
        expensiveOperation();
    });
    
    suite.printSummary();
}
```

## Best Practices

### 1. One Test Per Behavior

Each `unittest` block should test one specific behavior.

```d
// Good
unittest { /* Test addition */ }
unittest { /* Test subtraction */ }

// Bad
unittest { /* Test addition and subtraction */ }
```

### 2. Descriptive Names

Use the first `writeln` to clearly describe what's being tested.

```d
writeln("\x1b[36m[TEST]\x1b[0m module.function - Specific behavior");
```

### 3. Arrange-Act-Assert Pattern

```d
unittest
{
    // Arrange - Set up test data
    auto input = prepareInput();
    
    // Act - Execute the code under test
    auto result = functionUnderTest(input);
    
    // Assert - Verify the result
    Assert.equal(result, expected);
}
```

### 4. Use Fixtures for Complex Setup

Don't duplicate setup code. Create fixtures in `tests/fixtures.d`.

### 5. Test Edge Cases

```d
unittest { /* Test empty input */ }
unittest { /* Test null input */ }
unittest { /* Test maximum value */ }
unittest { /* Test error conditions */ }
```

### 6. Fast Tests

Keep unit tests fast (< 100ms each). Move slow tests to integration tests.

### 7. Isolated Tests

Tests should not depend on each other or share state.

## Integration Tests

Integration tests live in `tests/integration/` and test multiple components together.

```d
module tests.integration.build;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m integration - Full build pipeline");
    
    auto workspace = scoped(new MockWorkspace());
    // Create realistic workspace structure
    // Run actual build
    // Verify outputs
}
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: dlang-community/setup-dlang@v1
      - run: dub test
      - run: dub test -- --parallel
```

## Performance Testing

Use the benchmark suite for performance-critical code:

```d
suite.bench("hash computation", 1000, {
    computeHash(testFile);
});

suite.bench("glob matching", 1000, {
    glob("**/*.py", testDir);
});
```

## Test Organization

### Unit Tests

- Mirror `source/` structure exactly
- One test file per source file
- Test public APIs thoroughly
- Test edge cases and error conditions

### Integration Tests

- Test component interactions
- Test realistic workflows
- Test error propagation
- Test end-to-end scenarios

### Benchmarks

- Test performance-critical paths
- Compare algorithm variants
- Regression testing
- Optimization validation

## Code Coverage

Generate coverage reports:

```bash
dub test --coverage
```

Coverage files are generated in the project root.

## Debugging Tests

Run specific test module directly:

```bash
dub test --filter="graph"
```

Add debug output:

```d
unittest
{
    debug writeln("Debug info: ", variable);
    // Test code
}
```

## Contributing Tests

When contributing:

1. Add tests for all new features
2. Add tests for bug fixes (regression tests)
3. Maintain test coverage > 80%
4. Follow existing test patterns
5. Update this documentation for new patterns

## Test Quality Checklist

- [ ] Tests are fast (< 100ms for unit tests)
- [ ] Tests are isolated (no shared state)
- [ ] Tests are deterministic (no flaky tests)
- [ ] Tests have clear descriptions
- [ ] Edge cases are covered
- [ ] Error conditions are tested
- [ ] Tests use appropriate assertions
- [ ] Tests clean up resources
- [ ] Integration tests are in `integration/`
- [ ] Benchmarks are in `bench/`

## Future Enhancements

- [ ] Property-based testing with QuickCheck-style library
- [ ] Mutation testing for test quality
- [ ] Visual test reports (HTML/JSON)
- [ ] Test parallelization at module level
- [ ] Automatic test generation from type signatures
- [ ] Coverage-guided fuzzing

