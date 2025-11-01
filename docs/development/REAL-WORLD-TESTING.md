# Real-World Build Testing

This document describes the real-world testing strategy for Builder, which validates that the build system works correctly with actual projects across multiple languages.

## Overview

Real-world tests run the actual `builder build` command against example projects to catch regressions in the full build pipeline. This is more comprehensive than unit tests because it:

- Tests the complete build workflow end-to-end
- Validates language detection and handler selection
- Verifies build artifact generation
- Catches integration issues between components
- Tests actual command-line behavior

## Test Structure

### Integration Tests (D)

Located in `tests/integration/real_world_builds.d`, these tests are written in D and integrated with the unittest framework:

```d
module tests.integration.real_world_builds;

// Tests that run builder build on example projects
unittest {
    auto result = runBuilder(projectPath, ["build"]);
    result.assertSuccess("Project name");
}
```

**Key Features:**
- Runs actual builder executable
- Validates exit codes and output
- Measures build times
- Verifies build artifacts
- Tests error handling

**Run with:**
```bash
make test
# or
dub test
```

### Shell Script Tests

Located in `tests/test-real-world.sh`, this is a standalone bash script for quick validation:

```bash
./tests/test-real-world.sh
```

**Key Features:**
- Fast execution for quick validation
- Useful for CI/CD pipelines
- Easy to run locally during development
- Provides summary of all test results
- Colorized output for easy reading

## What Gets Tested

### Languages Covered

1. **Compiled Languages:**
   - C++ (`cpp-project`)
   - Rust (`rust-project`)
   - Go (`go-project`)
   - D (`d-project`)
   - Nim (`nim-project`)
   - Zig (`zig-project`)

2. **JVM Languages:**
   - Java (`java-project`)

3. **Scripting Languages:**
   - Python (`simple`, `python-multi`)
   - Ruby (`ruby-project`)
   - Lua (`lua-project`)
   - PHP (`php-project`)
   - R (`r-project`)

4. **Web Technologies:**
   - TypeScript (`typescript-app`)
   - JavaScript (Node.js, Browser, React, Vue, Vite)

5. **.NET:**
   - C# (`csharp-project`)

6. **Multi-Language:**
   - Mixed Python/JavaScript (`mixed-lang`)

### Test Scenarios

1. **Basic Build:** Clean build from scratch
2. **Incremental Build:** Rebuild with cache (should be faster)
3. **Clean Command:** Verify artifacts are removed
4. **Verbose Output:** Test verbose logging
5. **Parallel Build:** Test concurrent builds (`-j` flag)
6. **Target Selection:** Build specific targets
7. **Error Handling:**
   - Missing dependencies
   - Syntax errors in Builderfile
   - Invalid project structures

## Running the Tests

### Quick Test (Shell Script)

```bash
# Build builder first
make

# Run real-world tests
./tests/test-real-world.sh
```

This will:
1. Check if builder executable exists
2. Test all example projects
3. Report pass/fail for each
4. Show summary with timing

### Full Test Suite (D unittest)

```bash
# Run all tests including real-world
make test

# Or with dub
dub test
```

### Test a Specific Project

```bash
cd examples/go-project
../../bin/builder build
```

### Clean All Example Builds

```bash
find examples -type d -name "bin" -exec rm -rf {} +
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Real-World Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install D compiler
        uses: dlang-community/setup-dlang@v1
        with:
          compiler: ldc-latest
      
      - name: Build builder
        run: make
      
      - name: Run real-world tests
        run: ./tests/test-real-world.sh
```

### GitLab CI Example

```yaml
test:real-world:
  script:
    - make
    - ./tests/test-real-world.sh
  artifacts:
    when: on_failure
    paths:
      - /tmp/builder-test-*.log
```

## Adding New Test Cases

### 1. Add Example Project

Create a new example in `examples/`:

```
examples/
  my-project/
    Builderfile
    main.ext
    README.md
```

### 2. Add to Integration Tests

Edit `tests/integration/real_world_builds.d`:

```d
unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m real_world_builds - My new project");
    
    auto projectPath = buildPath(getExamplesPath(), "my-project");
    if (!exists(projectPath))
    {
        writeln("\x1b[33m[SKIP]\x1b[0m Example project not found");
        return;
    }
    
    cleanProject(projectPath);
    
    auto result = runBuilder(projectPath, ["build"]);
    result.assertSuccess("My project");
    
    // Add custom assertions
    auto binPath = buildPath(projectPath, "bin", "my-app");
    Assert.isTrue(exists(binPath), "Expected output binary");
    
    writeln("\x1b[32m  ✓ My project built successfully\x1b[0m");
}
```

### 3. Add to Shell Script

Edit `tests/test-real-world.sh`:

```bash
test_project "my-project" "$EXAMPLES_DIR/my-project"
```

## Debugging Failed Tests

### View Detailed Output

```bash
cd examples/failing-project
../../bin/builder build --verbose
```

### Check Build Logs

```bash
# Shell script logs
cat /tmp/builder-test-$$.log

# Or run with verbose
cd examples/project
../../bin/builder build -v
```

### Common Issues

1. **Missing Dependencies:**
   - Ensure all language toolchains are installed
   - Check example README for requirements

2. **Path Issues:**
   - Verify builder executable path
   - Check BUILDER_PATH environment variable

3. **Cache Issues:**
   - Clean the project: `builder clean`
   - Remove `.builder-cache/`

4. **Permissions:**
   - Ensure test script is executable
   - Check write permissions in test directories

## Performance Tracking

The tests measure build times, which helps track:

- Performance regressions
- Cache effectiveness (incremental builds)
- Parallel build improvements

Example output:
```
✓ Go project built successfully in 847ms
✓ Rust project built successfully in 2341ms
✓ TypeScript project built successfully in 1523ms
```

## Best Practices

1. **Keep Examples Simple:** Example projects should be minimal but realistic
2. **Clean Before Testing:** Always clean before running tests
3. **Test Error Cases:** Include negative tests for error handling
4. **Document Requirements:** Note any special dependencies in example READMEs
5. **Maintain Examples:** Keep example projects up-to-date with best practices

## Troubleshooting

### Tests Won't Run

```bash
# Verify builder is built
ls -l bin/builder

# If not, build it
make clean && make

# Check permissions
chmod +x tests/test-real-world.sh
```

### All Tests Skip

```bash
# Verify examples exist
ls -la examples/

# Check paths in test script
echo $EXAMPLES_DIR
```

### Tests Fail on CI but Pass Locally

- Check language version differences
- Verify all dependencies are installed in CI
- Look for timing-sensitive tests
- Check file system differences (case sensitivity)

## Future Enhancements

Potential improvements to the test suite:

1. **Dependency Management Tests:**
   - Test projects with external dependencies
   - Verify dependency resolution

2. **Watch Mode Tests:**
   - Test file watching and auto-rebuild

3. **Cross-Platform Tests:**
   - Windows-specific tests
   - macOS vs Linux differences

4. **Performance Benchmarks:**
   - Track build time trends
   - Compare against baseline

5. **Stress Tests:**
   - Large projects (100+ files)
   - Deep dependency trees
   - Concurrent builds

## Related Documentation

- [Testing Guide](TESTING.md)
- [Example Projects](../../examples/README.md)
- [CLI Documentation](../user-guides/CLI.md)
- [Contributing Guide](../../CONTRIBUTING.md)



