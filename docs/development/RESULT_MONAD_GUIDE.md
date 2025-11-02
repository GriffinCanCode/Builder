# Result Monad: Complete Guide

## Overview

Builder's Result monad provides a powerful, type-safe approach to error handling inspired by Rust, Haskell, and modern functional programming. This guide covers the complete Result monad system including advanced functional operations.

## Core Concepts

### The Result Type

```d
import errors;

// Success case
Result!(int, BuildError) success = Ok!(int, BuildError)(42);

// Error case  
Result!(int, BuildError) failure = Err!(int, BuildError)(new IOError("path", "failed"));

// Void results (operations that don't return a value)
Result!BuildError voidSuccess = Ok!BuildError();
Result!BuildError voidFailure = Err!BuildError(new CacheError("failed"));
```

### Basic Operations

```d
// Check status
if (result.isOk) { /* ... */ }
if (result.isErr) { /* ... */ }

// Unwrap (throws if error)
int value = result.unwrap();

// Unwrap with context (recommended)
int value = result.expect("Failed to load configuration");

// Unwrap with default
int value = result.unwrapOr(0);

// Get error
if (result.isErr)
{
    BuildError err = result.unwrapErr();
}
```

## Functional Operations

### Map - Transform Success Values

Transform the success value without affecting errors:

```d
Result!(int, BuildError) count = Ok!(int, BuildError)(5);
Result!(string, BuildError) text = count.map((n) => "Count: " ~ n.to!string);
// Result is: Ok!("Count: 5")
```

### MapErr - Transform Error Values

Transform the error without affecting success:

```d
Result!(int, string) result = Err!(int, string)("file error");
Result!(int, BuildError) betterError = result.mapErr((msg) => new IOError("", msg));
```

### AndThen - Chain Operations (FlatMap)

Chain operations that return Results (monadic bind):

```d
Result!(string, BuildError) readAndParse(string path)
{
    return readFile(path)
        .andThen((content) => parseJSON(content))
        .andThen((json) => validateSchema(json));
}
```

### OrElse - Fallback on Error

Provide alternative operation if error occurs:

```d
auto config = readFile("config.json")
    .orElse((err) => readFile("config.default.json"));
```

### Match - Pattern Matching

Handle both cases explicitly:

```d
string message = result.match(
    (value) => "Success: " ~ value.to!string,
    (error) => "Error: " ~ error.message()
);
```

## Advanced Functional Extensions

### Traverse - Transform Collections

Apply a Result-returning function to each element, collecting all successes or stopping at first error:

```d
import errors.handling.extensions;

string[] filePaths = ["a.txt", "b.txt", "c.txt"];
Result!(string[], BuildError) contents = traverse(filePaths, (path) => readFile(path));

// If all succeed: Ok!(["content1", "content2", "content3"])
// If any fails: Err!(firstError)
```

### Sequence - Combine Results

Convert a collection of Results into a Result of collection:

```d
Result!(int, string)[] results = [
    Ok!(int, string)(1),
    Ok!(int, string)(2),
    Ok!(int, string)(3)
];

Result!(int[], string) combined = sequence(results);
// Result: Ok!([1, 2, 3])
```

### Partition - Separate Successes and Failures

Collect all results, never failing:

```d
Result!(int, string)[] mixed = [
    Ok!(int, string)(1),
    Err!(int, string)("error1"),
    Ok!(int, string)(2),
    Err!(int, string)("error2")
];

auto partitioned = partition(mixed);
// partitioned.successes = [1, 2]
// partitioned.errors = ["error1", "error2"]
```

### Zip - Combine Multiple Results

Combine 2 or 3 Results into a single Result with tuple:

```d
auto r1 = Ok!(int, string)(42);
auto r2 = Ok!(string, string)("hello");
auto zipped = zip(r1, r2);
// Result: Ok!(tuple(42, "hello"))

auto r3 = Ok!(bool, string)(true);
auto zipped3 = zip(r1, r2, r3);
// Result: Ok!(tuple(42, "hello", true))
```

### Flatten - Unwrap Nested Results

Remove one level of Result nesting:

```d
Result!(Result!(int, string), string) nested = Ok!(Result!(int, string), string)(
    Ok!(int, string)(42)
);

Result!(int, string) flat = flatten(nested);
// Result: Ok!(42)
```

### Tap/TapErr - Side Effects

Perform side effects without consuming the Result:

```d
auto result = readFile("config.json")
    .tap((content) { Logger.info("Read " ~ content.length.to!string ~ " bytes"); })
    .tapErr((error) { Logger.error("Failed: " ~ error.message()); })
    .map((content) => parseJSON(content));
```

### Recover - Convert Errors to Successes

Always succeeds by recovering from errors:

```d
string content = readFile("config.json")
    .recover((error) => "{}");  // Use empty JSON on error
```

### Bimap - Transform Both Types

Map both success and error simultaneously:

```d
Result!(int, BuildError) transformed = fileResult.bimap(
    (content) => content.length,        // Transform success
    (fileErr) => new IOError("", fileErr.msg)  // Transform error
);
```

### TryAll - First Success Wins

Try multiple operations until one succeeds:

```d
auto config = tryAll([
    () => readFile("config.json"),
    () => readFile("config.default.json"),
    () => Ok!(string, BuildError)("{}")  // Fallback
]);
```

### FoldResult - Accumulate with Result

Fold over a collection with Result-returning function:

```d
auto numbers = [1, 2, 3, 4, 5];
auto result = foldResult(numbers, 0, (acc, n) => 
    n > 0 ? Ok!(int, string)(acc + n) : Err!(int, string)("negative")
);
// Result: Ok!(15)
```

### Collect Strategies

Different ways to collect results:

```d
// FailFast - stop at first error (default)
auto result1 = collectWith!(CollectStrategy.FailFast)(files, (f) => readFile(f));

// CollectAll - collect all successes, ignore errors
auto successes = collectWith!(CollectStrategy.CollectAll)(files, (f) => readFile(f));

// Partition - collect both successes and errors
auto partitioned = collectWith!(CollectStrategy.Partition)(files, (f) => readFile(f));
```

### Parallel Traverse

Execute independent operations in parallel:

```d
string[] filePaths = ["a.txt", "b.txt", "c.txt"];
Result!(string[], BuildError) contents = traverseParallel(filePaths, (path) => 
    readFile(path)
);
// Reads all files in parallel, fails fast on first error
```

## Smart Error Constructors

Builder provides smart constructors that automatically add helpful suggestions:

### File Not Found

```d
auto error = fileNotFoundError("Builderfile");
// Automatically includes:
// - Command: "Create a Builderfile" (builder init)
// - Check: "Check if you're in the correct directory"
// - Docs: "See Builderfile documentation"
```

### File Read Error

```d
auto error = fileReadError("/path/to/file", "Permission denied", "reading config");
// Automatically includes:
// - Command: "Check file permissions" (ls -la /path/to/file)
// - Check: "Ensure file is readable"
// - Check: "Verify file is not locked by another process"
```

### Parse Error

```d
auto error = parseErrorWithContext("Builderfile", "Invalid JSON", 15);
// Automatically includes:
// - Docs: "Check Builderfile syntax"
// - Command: "Validate JSON syntax" (jsonlint Builderfile)
// - Check: "Ensure all braces and brackets are matched"
```

### Build Failure

```d
auto error = buildFailureError("myapp", "Compilation failed", ["dep1", "dep2"]);
// Automatically includes:
// - Check: "Review build output above for specific errors"
// - Command: "Run with verbose output" (builder build --verbose)
// - Check: "Check that all dependencies are installed"
```

### Target Not Found

```d
auto error = targetNotFoundError("myapp");
// Automatically includes:
// - Check: "Check that target name is spelled correctly"
// - Command: "View available targets" (builder graph)
// - Command: "List all targets" (builder list)
```

### Cache Error

```d
auto error = cacheLoadError(".builder-cache/action.db", "Corrupt database");
// Automatically includes:
// - Command: "Clear cache and rebuild" (builder clean)
// - Check: "Cache may be from incompatible version"
// - Command: "Check cache permissions" (ls -la .builder-cache/)
```

### Circular Dependency

```d
auto error = circularDependencyError(["A", "B", "C", "A"]);
// Automatically includes:
// - Check: "Break the circular dependency by removing one of the links"
// - Check: "Refactor code to eliminate the cycle"
// - Command: "View full dependency graph" (builder graph)
```

### Compilation Error

```d
auto error = compilationError("D", "app.d", "Syntax error", compilerOutput);
// Automatically includes:
// - Check: "Review compiler output above for specific errors"
// - Command: "Build with verbose output" (builder build --verbose)
// - Check: "Check syntax in app.d"
```

### Missing Dependency

```d
auto error = missingDependencyError("myapp", "libfoo");
// Automatically includes:
// - Check: "Add 'libfoo' to the deps list of target 'myapp'"
// - Check: "Check if 'libfoo' target exists in Builderfile"
// - Command: "List all available targets" (builder list)
```

### Process Execution Error

```d
auto error = processExecutionError("gcc main.c", 127, "Command not found");
// Automatically includes:
// - Command: "Check if command exists" (which gcc)
// - Check: "Verify command permissions and PATH"
// - Check: "Command not found - install required tool"
```

### Invalid Configuration

```d
auto error = invalidConfigError("Builderfile", "sources", "Must be array");
// Automatically includes:
// - Check: "Check the 'sources' field in Builderfile"
// - Docs: "See configuration syntax"
// - Check: "Verify field type and format"
```

### Handler Not Found

```d
auto error = handlerNotFoundError("Fortran");
// Automatically includes:
// - Check: "Check if language 'Fortran' is supported"
// - Check: "Verify 'language' field spelling in Builderfile"
// - Docs: "See supported languages"
```

## Error Builder Pattern

For custom errors with specific suggestions:

```d
auto error = ErrorBuilder!IOError
    .create(path, "File operation failed")
    .withContext("reading configuration", "system startup")
    .withCommand("Check permissions", "ls -la " ~ path)
    .withDocs("See file docs", "docs/files.md")
    .withFileCheck("Verify path exists", path)
    .withConfig("Set timeout", "timeout: 300")
    .build();
```

## Best Practices

### 1. Use `expect()` Instead of `unwrap()`

```d
// ❌ Bad - Generic error
auto sorted = graph.topologicalSort().unwrap();

// ✅ Good - Contextual error
auto sorted = graph.topologicalSort().expect("Build graph has cycles");
```

### 2. Chain Operations with `andThen`

```d
// ✅ Good - Monadic chaining
auto result = readFile("config.json")
    .andThen((content) => parseJSON(content))
    .andThen((json) => validateSchema(json))
    .andThen((config) => applyConfig(config));
```

### 3. Use Smart Constructors

```d
// ❌ Bad - Manual error construction
auto error = new IOError(path, "File not found");
error.addSuggestion("Run builder init");

// ✅ Good - Smart constructor with context-aware suggestions
auto error = fileNotFoundError(path);
```

### 4. Leverage Traverse for Collections

```d
// ❌ Bad - Manual loop with early return
Result!(Target[], BuildError) parseTargets(string[] files)
{
    Target[] targets;
    foreach (file; files)
    {
        auto result = parseTarget(file);
        if (result.isErr)
            return Err!(Target[], BuildError)(result.unwrapErr());
        targets ~= result.unwrap();
    }
    return Ok!(Target[], BuildError)(targets);
}

// ✅ Good - Elegant traverse
Result!(Target[], BuildError) parseTargets(string[] files)
{
    return traverse(files, (file) => parseTarget(file));
}
```

### 5. Use Partition for Partial Success

```d
// When you want to process all items regardless of errors
auto results = partition(targets.map!(t => buildTarget(t)).array);

Logger.info("Built " ~ results.successes.length.to!string ~ " targets");
if (results.anyFailed)
    Logger.warning("Failed " ~ results.errors.length.to!string ~ " targets");
```

### 6. Recover Gracefully

```d
// Provide sensible defaults for non-critical failures
auto config = readFile("custom.json")
    .recover((err) => readFile("default.json").unwrapOr("{}"));
```

## Migration from Exceptions

### Before (Exception-based)

```d
void addTarget(Target target)
{
    if (target.name in nodes)
        throw new Exception("Duplicate target: " ~ target.name);
    
    nodes[target.name] = new BuildNode(target);
}
```

### After (Result-based)

```d
Result!BuildError addTargetChecked(Target target)
{
    auto key = target.id.toString();
    if (key in nodes)
    {
        auto error = ErrorBuilder!GraphError
            .create("Duplicate target in build graph: " ~ key)
            .withSuggestion(ErrorSuggestion.fileCheck("Check for duplicate target definitions"))
            .withCommand("List all targets", "builder list")
            .build();
        return Err!BuildError(error);
    }
    
    nodes[key] = new BuildNode(target.id, target);
    return Ok!BuildError();
}

// Backward compatible wrapper
void addTarget(Target target)
{
    auto result = addTargetChecked(target);
    if (result.isErr)
        throw new Exception(format(result.unwrapErr()));
}
```

## Real-World Examples

### Example 1: Configuration Loading with Fallbacks

```d
Result!(Config, BuildError) loadConfig()
{
    return tryAll([
        () => readFile("config.json").andThen((s) => parseJSON(s)),
        () => readFile("config.yaml").andThen((s) => parseYAML(s)),
        () => Ok!(Config, BuildError)(Config.defaults())
    ]);
}
```

### Example 2: Parallel File Processing

```d
Result!(ProcessedFile[], BuildError) processFiles(string[] paths)
{
    return traverseParallel(paths, (path) =>
        readFile(path)
            .andThen((content) => validateContent(content))
            .andThen((valid) => transformContent(valid))
            .map((transformed) => ProcessedFile(path, transformed))
    );
}
```

### Example 3: Incremental Build with Partial Success

```d
BuildSummary incrementalBuild(Target[] targets)
{
    auto results = partition(targets.map!(t => buildTarget(t)).array);
    
    return BuildSummary(
        successCount: results.successes.length,
        failureCount: results.errors.length,
        successes: results.successes,
        failures: results.errors
    );
}
```

### Example 4: Dependency Resolution with Error Aggregation

```d
Result!(DependencyGraph, BuildError) resolveDependencies(Target[] targets)
{
    auto graph = new DependencyGraph();
    
    // Add all targets first
    auto addResults = traverse(targets, (t) => graph.addTargetChecked(t));
    if (addResults.isErr)
        return Err!(DependencyGraph, BuildError)(addResults.unwrapErr());
    
    // Resolve dependencies in parallel
    auto depResults = traverseParallel(targets, (t) =>
        analyzeDependencies(t)
            .andThen((deps) => addDependenciesToGraph(graph, t, deps))
    );
    
    if (depResults.isErr)
        return Err!(DependencyGraph, BuildError)(depResults.unwrapErr());
    
    // Validate no cycles
    return graph.validate().map(() => graph);
}
```

## Performance Considerations

1. **Result is Zero-Cost** - The Result type uses unions for memory efficiency
2. **Traverse is Short-Circuiting** - Stops at first error for performance
3. **Parallel Operations** - Use `traverseParallel` for I/O-bound operations
4. **Avoid Excessive Chaining** - Very long chains can impact compile times

## Testing with Result

```d
unittest
{
    // Test success case
    auto result = parseConfig("valid.json");
    assert(result.isOk);
    assert(result.unwrap().version == "1.0");
    
    // Test error case
    auto error = parseConfig("invalid.json");
    assert(error.isErr);
    auto err = error.unwrapErr();
    assert(err.code() == ErrorCode.ParseFailed);
    
    // Test traverse
    auto files = ["a.txt", "b.txt"];
    auto contents = traverse(files, (f) => readFile(f));
    assert(contents.isOk);
    assert(contents.unwrap().length == 2);
    
    // Test partition
    auto mixed = [Ok!(int, string)(1), Err!(int, string)("e"), Ok!(int, string)(2)];
    auto part = partition(mixed);
    assert(part.successes == [1, 2]);
    assert(part.errors == ["e"]);
}
```

## See Also

- [Error Handling Best Practices](ERROR_HANDLING.md)
- [Type-Safe Errors Guide](TYPE_SAFE_ERRORS.md)
- [Error Migration Status](TYPE_SAFE_ERRORS_MIGRATION.md)
- [API Documentation](../api/)


