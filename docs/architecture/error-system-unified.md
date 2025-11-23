# Unified Error System

## Overview

The Builder error system has been unified to eliminate error type proliferation and provide a consistent, hierarchical approach to error handling across the codebase.

## Architecture

### Error Hierarchy

All errors in Builder implement the `BuildError` interface and extend `BaseBuildError`:

```d
BuildError (interface)
  └── BaseBuildError (abstract base class)
        ├── BuildFailureError
        ├── ParseError
        ├── AnalysisError
        ├── CacheError
        ├── IOError
        ├── GraphError
        ├── LanguageError
        ├── SystemError
        ├── InternalError
        ├── PluginError
        ├── LSPError
        ├── WatchError
        ├── ConfigError
        ├── NetworkError
        ├── RepositoryError
        ├── DistributedError
        │     ├── ExecutionError
        │     ├── WorkerError
        │     └── ResourceLimitError
        ├── EconomicsError
        └── GenericError
```

### Error Categories

Errors are organized into 13 categories for systematic classification:

1. **Build** - Build execution errors
2. **Parse** - Configuration parsing errors
3. **Analysis** - Dependency analysis errors
4. **Cache** - Cache operation errors
5. **IO** - File system errors
6. **Graph** - Dependency graph errors
7. **Language** - Language handler errors
8. **System** - System-level errors
9. **Internal** - Internal/unexpected errors
10. **Plugin** - Plugin system errors
11. **LSP** - LSP server errors
12. **Watch** - Watch mode errors
13. **Config** - Configuration/Validation errors

### Recoverability Classification

Errors are classified by recoverability to guide error handling strategies:

#### Fatal
Cannot be recovered, must fail the build:
- Build failures
- Syntax errors
- Graph cycles
- Missing dependencies
- Internal errors

#### Transient
Temporary failures that can be retried:
- Build timeout
- Cache timeout
- Network errors
- Process timeout
- Worker timeout
- Repository fetch failures

#### User
Incorrect configuration or usage:
- Parse errors
- Invalid configuration
- Target not found
- File not found
- Permission denied
- Unsupported language
- Invalid target configuration

### Error Codes

All errors have numeric codes organized in ranges of 1000:

- **0-999**: General errors
- **1000-1999**: Build errors
- **2000-2999**: Parse errors
- **3000-3999**: Analysis errors
- **4000-4499**: Cache errors
- **4500-4599**: Repository errors
- **5000-5999**: IO errors
- **6000-6999**: Graph errors
- **7000-7999**: Language errors
- **8000-8999**: System errors
- **9000-9999**: Internal errors
- **10000-10999**: Telemetry errors
- **11000-11999**: Tracing errors
- **12000-12999**: Distributed build errors
- **13000-13999**: Plugin errors
- **14000-14999**: LSP errors
- **15000-15999**: Watch mode errors
- **16000-16999**: Configuration errors
- **17000-17999**: Migration errors

### Central Error Registry

The error registry (`errorRegistry` in `codes.d`) provides a single source of truth for error metadata:

```d
struct ErrorRegistryEntry
{
    ErrorCode code;
    ErrorCategory category;
    Recoverability recoverability;
    string message;
    string[] defaultSuggestions;
    string docsUrl;
}
```

## Key Design Principles

### 1. Single Base Implementation

All error types extend `BaseBuildError`, which provides:
- Automatic error code to category mapping
- Automatic recoverability determination
- Error context chains
- Suggestion management
- Consistent formatting

### 2. No Redundant Overrides

Error types **do not** override `category()` or `recoverable()` methods. These are automatically derived from the error code using optimized lookup tables in `codes.d`.

### 3. Type Safety

The system uses strong typing with specific error classes for different domains (BuildFailureError, ParseError, etc.) while maintaining a consistent interface.

### 4. Builder Pattern

Error construction uses a fluent builder pattern for adding context and suggestions:

```d
auto error = ErrorBuilder!ParseError.create(filePath, message)
    .withContext("parsing", "Builderfile")
    .withSuggestion("Check JSON syntax")
    .withDocs("See examples", "docs/user-guides/examples.md")
    .build();
```

### 5. Smart Constructors

Helper functions provide smart error construction with built-in suggestions:

```d
// Automatically includes relevant suggestions
auto error = fileNotFoundError("Builderfile", "build");
auto error = targetNotFoundError("myTarget");
auto error = circularDependencyError(["A", "B", "C", "A"]);
```

## Migration Guide

### Removed Patterns

#### ❌ Before: Redundant Overrides
```d
class MyError : BaseBuildError
{
    override ErrorCategory category() const pure nothrow
    {
        return ErrorCategory.Build;
    }
    
    override bool recoverable() const pure nothrow
    {
        return false;
    }
}
```

#### ✅ After: Clean Implementation
```d
class MyError : BaseBuildError
{
    this(string message, ErrorCode code = ErrorCode.BuildFailed)
    {
        super(code, message);
    }
}
```

### Exception-Based Errors

#### ❌ Before: Raw Exceptions
```d
throw new Exception("File not found: " ~ path);
```

#### ✅ After: Typed Errors
```d
throw fileNotFoundError(path, "dependency analysis");
```

### Duplicate Error Types

Removed duplicate `NetworkError` definition from `engine/distributed/protocol/protocol.d`. Now re-exports from `infrastructure.errors.types.network`.

## Usage Examples

### Creating Errors

```d
// Simple error
auto error = new BuildFailureError("myTarget", "Compilation failed");

// Error with context
auto error = new ParseError("Builderfile", "Invalid JSON")
    .withContext(ErrorContext("parsing", "target 'build'"))
    .withSuggestion(ErrorSuggestion.command("Validate JSON", "jsonlint Builderfile"));

// Using builder pattern
auto error = ErrorBuilder!AnalysisError.create("myTarget", "Circular dependency")
    .withContext("dependency analysis", "resolving imports")
    .withSuggestion("Break the cycle by removing a dependency")
    .withDocs("See architecture guide", "docs/architecture/overview.md")
    .build();

// Smart constructors
auto error = fileNotFoundError("Builderfile");  // Auto-includes suggestions
auto error = targetNotFoundError("myTarget");   // Auto-includes suggestions
```

### Error Handling

```d
// Using Result type
Result!(string, BuildError) parse(string file)
{
    if (!exists(file))
        return Err!(string, BuildError)(fileNotFoundError(file, "parsing"));
    
    try {
        auto content = readText(file);
        return Ok!(string, BuildError)(content);
    } catch (Exception e) {
        return Err!(string, BuildError)(
            fileReadError(file, e.msg, "parsing")
        );
    }
}

// Checking error properties
if (error.recoverable()) {
    // Retry transient errors
    retry(operation);
} else if (error.recoverability() == Recoverability.User) {
    // Show helpful suggestions for user errors
    showSuggestions(error.suggestions());
} else {
    // Fatal error, fail fast
    abort(error);
}
```

### Query Error Metadata

```d
// Look up error in registry
auto entry = lookupError(ErrorCode.BuildFailed);
writeln("Category: ", entry.category);
writeln("Recoverable: ", entry.recoverability);
writeln("Message: ", entry.message);
writeln("Docs: ", entry.docsUrl);
foreach (suggestion; entry.defaultSuggestions) {
    writeln("  - ", suggestion);
}

// Check if error is recoverable
if (isRecoverable(code)) {
    // Retry logic
}

// Get category from code
auto category = categoryOf(ErrorCode.CacheTimeout);
```

## Benefits

1. **Consistency**: All errors follow the same pattern and structure
2. **Maintainability**: Error metadata is centralized in the registry
3. **Type Safety**: Strong typing prevents error misuse
4. **Discoverability**: Error codes and categories make errors easy to find
5. **Debugging**: Rich context chains provide detailed error information
6. **User Experience**: Built-in suggestions help users resolve errors
7. **Performance**: Optimized lookup tables for O(1) category/recoverability checks

## Implementation Files

- `source/infrastructure/errors/handling/codes.d` - Error codes, categories, recoverability, registry
- `source/infrastructure/errors/types/types.d` - Error type hierarchy and builders
- `source/infrastructure/errors/types/context.d` - Error context and suggestions
- `source/infrastructure/errors/types/network.d` - Network error specialization
- `source/infrastructure/repository/core/types.d` - Repository errors
- `engine/distributed/protocol/protocol.d` - Distributed system errors
- `engine/economics/optimizer.d` - Economics errors

## Statistics

- **Error Categories**: 13
- **Error Codes**: 100+
- **Error Types**: 20+
- **Recoverability Classes**: 3 (Fatal, Transient, User)
- **Redundant Overrides Removed**: All (100% consistency)
- **Exception-Based Errors Replaced**: 13 critical paths

