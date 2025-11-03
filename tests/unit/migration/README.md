# Migration System Unit Tests

Comprehensive test suite for the build system migration feature.

## Test Coverage

### Core Modules

- **common.d** - Tests for MigrationTarget, MigrationResult, MigrationWarning
- **emitter.d** - Tests for BuilderfileEmitter DSL generation
- **registry.d** - Tests for MigratorRegistry and MigratorFactory

### System Migrators

- **bazel.d** - Tests for Bazel BUILD file migration
- **cmake.d** - Tests for CMake CMakeLists.txt migration
- **npm.d** - Tests for npm package.json migration

### Integration

- **integration.d** - End-to-end workflow tests

## Running Tests

### Run All Migration Tests

```bash
dub test --build=unittest-cov -- tests.unit.migration
```

### Run Specific Test Module

```bash
# Test common types
dub test --build=unittest -- tests.unit.migration.common

# Test emitter
dub test --build=unittest -- tests.unit.migration.emitter

# Test registry
dub test --build=unittest -- tests.unit.migration.registry

# Test Bazel migrator
dub test --build=unittest -- tests.unit.migration.bazel

# Test integration
dub test --build=unittest -- tests.unit.migration.integration
```

### Run Individual Tests

```bash
cd tests/unit/migration
rdmd --main -unittest common.d
rdmd --main -unittest emitter.d
rdmd --main -unittest registry.d
```

## Test Structure

Each test module follows this pattern:

1. **Unit Tests** - Test individual functions and methods
2. **Edge Cases** - Test boundary conditions and error paths
3. **Integration** - Test component interactions

## Adding New Tests

When adding a new migrator:

1. Create `tests/unit/migration/<system>.d`
2. Test all IMigrator interface methods
3. Test parsing of typical input files
4. Test edge cases (empty, invalid, complex)
5. Add to integration tests

Example template:

```d
module tests.unit.migration.newsystem;

import std.stdio;
import migration.systems.newsystem;

/// Test system name
unittest
{
    auto migrator = new NewSystemMigrator();
    assert(migrator.systemName() == "newsystem");
}

/// Test migration
unittest
{
    // Test logic here
}

void main()
{
    writeln("Running migration.newsystem tests...");
    writeln("All tests passed!");
}
```

## Coverage Goals

- **Core modules:** 95%+ coverage
- **Migrators:** 80%+ coverage
- **Integration:** All critical paths tested

## Continuous Integration

These tests run automatically on:
- Every commit
- Pull requests
- Release builds

## Test Data

Test files are created in `tempDir()` and cleaned up automatically using `scope(exit)`.

## Performance

All tests should complete in <1 second. Integration tests may take slightly longer due to file I/O.

