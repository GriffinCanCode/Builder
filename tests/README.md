# Builder Test Suite

This directory contains the comprehensive test infrastructure for Builder.

## Quick Start

```bash
# Run all tests
dub test

# Run with verbose output
dub test -- --verbose

# Run specific tests
dub test -- --filter="glob"

# Run in parallel
dub test -- --parallel
```

## Structure

```
tests/
├── runner.d          # Test runner CLI
├── harness.d         # Assertions and test framework
├── fixtures.d        # Test fixtures (TempDir, MockWorkspace, etc.)
├── mocks.d           # Mock objects and spies
├── unit/             # Unit tests mirroring source/
├── integration/      # End-to-end integration tests
└── bench/            # Performance benchmarks
```

## Key Features

- **Modular Design**: Tests organized by domain
- **Strong Typing**: Type-safe assertions
- **Fixtures**: RAII-based test fixtures with automatic cleanup
- **Mocks**: Comprehensive mocking framework
- **Benchmarks**: Built-in performance testing
- **Parallel**: Parallel test execution support

## Writing Tests

See [docs/TESTING.md](/docs/TESTING.md) for comprehensive guide.

### Example

```d
module tests.unit.mymodule;

import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m mymodule - description");
    
    Assert.equal(2 + 2, 4);
    
    writeln("\x1b[32m  ✓ Test passed\x1b[0m");
}
```

## Components

### harness.d

Test framework providing:
- `Assert` - Type-safe assertions
- `TestHarness` - Test execution and reporting
- `TestResult` / `TestStats` - Test results tracking

### fixtures.d

Test fixtures:
- `TempDir` - Temporary directories with auto-cleanup
- `MockWorkspace` - Mock build workspaces
- `TargetBuilder` - Fluent API for building test targets
- `ScopedFixture` - RAII wrapper for fixtures

### mocks.d

Mock objects:
- `MockBuildNode` - Mock build graph nodes
- `MockLanguageHandler` - Mock language handlers
- `CallTracker` - Track method calls
- `Stub<T>` - Control return values

### runner.d

Test runner with CLI:
- Automatic unittest discovery
- Parallel execution
- Filtering by name
- Configurable verbosity
- Statistics reporting

## Best Practices

1. **One test per behavior** - Each unittest tests one thing
2. **Fast tests** - Unit tests should be < 100ms
3. **Isolated** - No shared state between tests
4. **Descriptive** - Clear test descriptions
5. **Use fixtures** - Don't duplicate setup code

## Examples

### Unit Test

```d
unittest
{
    auto tempDir = scoped(new TempDir());
    tempDir.createFile("test.txt", "content");
    Assert.isTrue(tempDir.hasFile("test.txt"));
}
```

### Integration Test

```d
unittest
{
    auto workspace = scoped(new MockWorkspace());
    workspace.createTarget("app", TargetType.Executable, 
                          ["main.py"], []);
    // Test full build pipeline
}
```

### Benchmark

```d
unittest
{
    auto suite = new BenchmarkSuite();
    suite.bench("operation", 1000, {
        expensiveOperation();
    });
}
```

## Contributing

When adding tests:
1. Place unit tests in `unit/` mirroring `source/` structure
2. Place integration tests in `integration/`
3. Place benchmarks in `bench/`
4. Follow existing patterns
5. Maintain > 80% coverage

