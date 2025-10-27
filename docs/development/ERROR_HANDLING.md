# Error Handling Best Practices

Builder uses a sophisticated `Result<T, E>` monad for type-safe error handling, inspired by Rust. This guide shows the best practices for error handling in the codebase.

## Core Principles

1. **Prefer Result types over exceptions** for expected error cases
2. **Provide context** when unwrapping results
3. **Propagate errors upward** rather than panic
4. **Log errors with full context** for debugging

## The Result Type

```d
import errors.handling.result;

// Success
auto result = Ok!(string, BuildError)("success");

// Error
auto result = Err!(string, BuildError)(new ParseError("Invalid syntax"));
```

## Methods Overview

| Method | Use Case | Throws? |
|--------|----------|---------|
| `unwrap()` | When you're certain it's Ok | Yes |
| `expect(msg)` | **Preferred**: Adds context to errors | Yes |
| `unwrapOr(default)` | Provide fallback value | No |
| `isErr` check + `unwrap()` | Explicit error handling | Yes (if not checked) |
| `match()` | Pattern matching style | No |
| `andThen()` | Monadic chaining | No |

## ✅ Best Practices

### 1. Use `expect()` Instead of `unwrap()`

**Bad** - Generic error message:
```d
auto sorted = graph.topologicalSort().unwrap();
// Throws: "Called unwrap on an error: Cycle detected..."
```

**Good** - Contextual error message:
```d
auto sorted = graph.topologicalSort().expect("Build graph has cycles");
// Throws: "Build graph has cycles: Cycle detected between A -> B -> C"
```

### 2. Check `isErr` Before Critical Operations

**Good** - Explicit error handling with logging:
```d
auto sortResult = graph.topologicalSort();
if (sortResult.isErr)
{
    auto error = sortResult.unwrapErr();
    Logger.error("Cannot build: " ~ format(error));
    
    // Publish event for monitoring
    if (eventPublisher !is null)
        eventPublisher.publish(new BuildFailedEvent(error.message()));
    
    return; // Graceful exit
}

auto sorted = sortResult.unwrap(); // Safe here
```

### 3. Use `unwrapOr()` for Defaults

**Good** - Graceful degradation:
```d
// If cache load fails, use empty cache
auto cache = loadCache().unwrapOr(BuildCache.empty());

// If config missing, use default
auto parallelism = config.get("parallelism").unwrapOr(4);
```

### 4. Chain Operations with `andThen()`

**Good** - Monadic error propagation:
```d
auto result = parseConfig(file)
    .andThen((config) => validate(config))
    .andThen((validated) => build(validated));

if (result.isErr)
{
    Logger.error("Build failed: " ~ format(result.unwrapErr()));
    return;
}

auto output = result.unwrap();
```

### 5. Use `match()` for Pattern Matching

**Good** - Functional style:
```d
auto message = parseFile(path).match(
    (content) => "Loaded " ~ content.length.to!string ~ " bytes",
    (error) => "Error: " ~ error.message()
);

writeln(message);
```

### 6. Propagate Errors in Library Code

**Good** - Return Result types:
```d
Result!(BuildGraph, BuildError) buildGraph(BuildConfig config)
{
    auto parseResult = parseTargets(config.file);
    if (parseResult.isErr)
        return Err!(BuildGraph, BuildError)(parseResult.unwrapErr());
    
    auto graph = new BuildGraph();
    foreach (target; parseResult.unwrap())
    {
        auto addResult = graph.addTarget(target);
        if (addResult.isErr)
            return Err!(BuildGraph, BuildError)(addResult.unwrapErr());
    }
    
    return Ok!(BuildGraph, BuildError)(graph);
}
```

## ❌ Anti-Patterns

### 1. Bare `unwrap()` Without Context

```d
// BAD - No context if it fails
auto config = loadConfig().unwrap();

// GOOD - Provides context
auto config = loadConfig().expect("Failed to load build configuration");
```

### 2. Silent Failure

```d
// BAD - Swallows errors
auto result = operation();
if (result.isErr)
    return; // What went wrong?

// GOOD - Logs before returning
auto result = operation();
if (result.isErr)
{
    Logger.error("Operation failed: " ~ format(result.unwrapErr()));
    return;
}
```

### 3. Re-wrapping Unnecessarily

```d
// BAD - Loses error information
try {
    result.unwrap();
} catch (Exception e) {
    throw new Exception("Failed");
}

// GOOD - Use expect() with context
result.expect("Operation X failed during phase Y");
```

## Testing Patterns

In tests, `unwrap()` is acceptable since test failures are expected to throw:

```d
unittest
{
    auto result = parseExpression("x + y");
    assert(result.isOk);
    
    auto expr = result.unwrap(); // OK in tests
    assert(expr.type == ExprType.BinaryOp);
}
```

For better test error messages, use `expect()`:

```d
unittest
{
    auto result = complexOperation();
    auto value = result.expect("Test setup: complex operation should succeed");
    
    assert(value == expectedValue);
}
```

## Error Context Chain

Builder supports error context chains for debugging:

```d
import errors.types.types;

auto error = new ParseError("Invalid token", ErrorCode.ParseFailed);
error.addContext(ErrorContext("parseExpression", "line 42"));
error.addContext(ErrorContext("parseFile", "/path/to/file.d"));

// Formats as:
// [Parse:ParseFailed] Invalid token
//   parseExpression: line 42
//   parseFile: /path/to/file.d
```

## Recovery Strategies

For transient errors, use retry logic:

```d
import errors.handling.recovery;

auto result = retryWithBackoff(
    () => networkOperation(),
    RetryConfig.withExponentialBackoff(3, 100.msecs)
);

if (result.isErr)
    Logger.warning("Operation failed after retries: " ~ format(result.unwrapErr()));
```

## Summary

| Scenario | Recommended Approach |
|----------|---------------------|
| Known to succeed | `expect("context")` |
| May fail, have default | `unwrapOr(default)` |
| Need to log/handle | Check `isErr` first |
| Chain operations | `andThen()` |
| Tests | `unwrap()` is fine |
| Pattern matching | `match()` |

## Migration Guide

When you see bare `unwrap()` calls:

1. **Add context**: Replace with `expect("what this does")`
2. **Add logging**: Check `isErr` before unwrap
3. **Add defaults**: Use `unwrapOr()` where appropriate
4. **Propagate**: Return `Result` types instead of unwrapping

Example refactoring:

```d
// Before
auto config = loadConfig().unwrap();
processConfig(config);

// After (Option 1: expect with context)
auto config = loadConfig().expect("Loading build configuration from .builder/config.json");
processConfig(config);

// After (Option 2: explicit error handling)
auto configResult = loadConfig();
if (configResult.isErr)
{
    Logger.error("Failed to load config: " ~ format(configResult.unwrapErr()));
    return Err!(...)(configResult.unwrapErr());
}
auto config = configResult.unwrap();
processConfig(config);
```

---

**Key Takeaway**: Always provide context for errors. The `expect()` method is your friend!

