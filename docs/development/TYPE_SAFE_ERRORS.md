# Type-Safe Error Handling

This document demonstrates Builder's strongly-typed error handling system, which provides better type safety and more helpful error messages.

## Overview

Builder's error system uses structured types instead of loose strings, ensuring:
- **No "ANY" types** - All errors are strongly typed
- **Rich suggestions** - Errors include structured, actionable suggestions
- **Type-specific formatting** - Commands, docs links, and file checks are formatted appropriately
- **Discoverable API** - Builder pattern makes it easy to construct helpful errors

## Basic Error Construction

### Simple Error (Old Style - Still Supported)

```d
// Basic error with string message
auto error = new IOError(path, "File not found");
error.addSuggestion("Check the file path");
```

### Improved: Strongly-Typed Suggestions

```d
import errors.types.context : ErrorSuggestion;

auto error = new IOError(path, "File not found");

// Typed suggestions with structured data
error.addSuggestion(ErrorSuggestion.command("Create file", "touch " ~ path));
error.addSuggestion(ErrorSuggestion.docs("See file docs", "docs/files.md"));
error.addSuggestion(ErrorSuggestion.fileCheck("Verify path exists", path));
```

## Using the Error Builder Pattern

The builder pattern provides a fluent API for constructing errors:

```d
auto error = ErrorBuilder!IOError.create(path, "File not found: " ~ path)
    .withContext("reading Builderfile")
    .withCommand("Create a Builderfile", "builder init")
    .withFileCheck("Check if you're in the correct directory")
    .withDocs("See documentation", "docs/user-guides/EXAMPLES.md")
    .build();
```

### Builder Methods

- `withContext(operation, details)` - Add context about what was happening
- `withSuggestion(ErrorSuggestion)` - Add a typed suggestion
- `withCommand(description, command)` - Add a command suggestion
- `withDocs(description, url)` - Add a documentation link
- `withFileCheck(description, path)` - Add a file/permission check
- `withConfig(description, setting)` - Add a configuration suggestion

## Smart Error Constructors

Builder provides smart constructors that automatically include appropriate suggestions:

### File Not Found Error

```d
// Automatically adds context-aware suggestions
auto error = fileNotFoundError("Builderfile");
// Includes:
// - Run: Create a Builderfile ($ builder init)
// - Check: Check if you're in the correct directory
// - Docs: See Builderfile documentation (docs/user-guides/EXAMPLES.md)
```

### File Read Error

```d
auto error = fileReadError("/path/to/file", "Permission denied", "reading config");
// Includes:
// - Run: Check file permissions ($ ls -la /path/to/file)
// - Check: Ensure file is readable
// - Check: Verify file is not locked by another process
```

### Parse Error

```d
auto error = parseErrorWithContext("Builderfile", "Invalid JSON", 15);
// Includes:
// - Docs: Check Builderfile syntax (docs/user-guides/EXAMPLES.md)
// - Run: Validate JSON syntax ($ jsonlint Builderfile)
// - Check: Ensure all braces and brackets are matched
```

### Build Failure Error

```d
auto error = buildFailureError("myapp", "Compilation failed", ["dep1", "dep2"]);
// Includes:
// - Run: Review build output above for specific errors
// - Run: Run with verbose output ($ builder build --verbose)
// - Check: Check that all dependencies are installed
// - Run: View dependency graph ($ builder graph)
```

### Target Not Found Error

```d
auto error = targetNotFoundError("myapp");
// Includes:
// - Check: Check that target name is spelled correctly
// - Run: View available targets ($ builder graph)
// - Run: List all targets ($ builder list)
// - Docs: See target documentation (docs/user-guides/EXAMPLES.md)
```

### Cache Error

```d
auto error = cacheLoadError(".builder-cache/action.db", "Corrupt database");
// Includes:
// - Run: Clear cache and rebuild ($ builder clean)
// - Check: Cache may be from incompatible version
// - Run: Check cache permissions ($ ls -la .builder-cache/)
```

## Suggestion Types

### Command Suggestions

Used when the user should run a specific command:

```d
error.addSuggestion(ErrorSuggestion.command("Clear cache", "builder clean"));
```

**Formatted Output:**
```
• Run: Clear cache
  $ builder clean
```

### Documentation Suggestions

Used to point users to relevant documentation:

```d
error.addSuggestion(ErrorSuggestion.docs(
    "See Builderfile syntax", 
    "docs/user-guides/EXAMPLES.md"
));
```

**Formatted Output:**
```
• Docs: See Builderfile syntax
  → docs/user-guides/EXAMPLES.md
```

### File Check Suggestions

Used when the user should verify file state:

```d
error.addSuggestion(ErrorSuggestion.fileCheck(
    "Check file permissions",
    "/path/to/file"
));
```

**Formatted Output:**
```
• Check: Check file permissions
  /path/to/file
```

### Configuration Suggestions

Used when configuration changes are needed:

```d
error.addSuggestion(ErrorSuggestion.config(
    "Increase timeout",
    "timeout: 300"
));
```

**Formatted Output:**
```
• Config: Increase timeout
  timeout: 300
```

### General Suggestions

For general advice without specific structure:

```d
error.addSuggestion(ErrorSuggestion("Try running the build again"));
```

**Formatted Output:**
```
• Try running the build again
```

## Complete Example

Here's a complete example showing how to use the type-safe error system:

```d
import errors;
import errors.types.context : ErrorSuggestion;

Result!(Target[], BuildError) parseBuilderfile(string path)
{
    import std.file : exists, readText;
    import std.json : parseJSON, JSONException;
    
    // Check if file exists
    if (!exists(path))
    {
        auto error = fileNotFoundError(path, "parsing Builderfile");
        return Err!(Target[], BuildError)(error);
    }
    
    // Try to read file
    try
    {
        string content = readText(path);
        auto json = parseJSON(content);
        
        // ... parse targets ...
        
        return Ok!(Target[], BuildError)(targets);
    }
    catch (FileException e)
    {
        auto error = fileReadError(path, e.msg, "parsing Builderfile");
        return Err!(Target[], BuildError)(error);
    }
    catch (JSONException e)
    {
        auto error = parseErrorWithContext(path, "Invalid JSON: " ~ e.msg, 0, "parsing Builderfile");
        return Err!(Target[], BuildError)(error);
    }
}

// Usage
auto result = parseBuilderfile("Builderfile");
if (result.isErr)
{
    import errors.formatting.format : format;
    writeln(format(result.unwrapErr()));
    // Outputs a beautifully formatted error with suggestions
}
```

## Error Output Example

When a file is not found, the output looks like:

```
[IO:FileNotFound] File not found: Builderfile
  → during: parsing Builderfile

Suggestions:
  • Run: Create a Builderfile
    $ builder init
  • Check: Check if you're in the correct directory
  • Docs: See Builderfile documentation
    → docs/user-guides/EXAMPLES.md
```

## Benefits of Type Safety

### 1. No "ANY" Types

All errors use concrete types (`ErrorCode`, `ErrorSuggestion.Type`, etc.) instead of loose `auto` or generic types.

### 2. Compile-Time Checking

The compiler ensures you use the right types:

```d
// ✅ Correct - strongly typed
error.addSuggestion(ErrorSuggestion.command("Run test", "make test"));

// ❌ Would not compile if types were wrong
error.addSuggestion(42); // Type error!
```

### 3. Discoverability

IDE autocomplete shows all available builder methods and suggestion types.

### 4. Structured Data

Suggestions contain structured data (type, message, detail) that can be:
- Formatted differently based on type
- Parsed programmatically
- Extended in the future without breaking changes

### 5. Consistency

Smart constructors ensure consistent, helpful error messages across the codebase.

## Migration Guide

### From Old Style

```d
// Old style
auto error = new IOError(path, "File not found");
error.addSuggestion("Run: builder init");
error.addSuggestion("Check the file path");
```

### To New Style

```d
// New style - strongly typed
auto error = fileNotFoundError(path);
// Suggestions are automatically added based on context
```

Or with builder:

```d
auto error = ErrorBuilder!IOError.create(path, "File not found")
    .withCommand("Initialize project", "builder init")
    .withFileCheck("Verify the file path", path)
    .build();
```

## Best Practices

1. **Use smart constructors** (`fileNotFoundError`, etc.) for common scenarios
2. **Use the builder pattern** for custom errors with specific suggestions
3. **Always provide context** - helps users understand what operation failed
4. **Be specific in suggestions** - include actual commands and paths when possible
5. **Link to docs** - use `ErrorSuggestion.docs()` to point to relevant documentation
6. **Order suggestions by usefulness** - most likely fixes first

## Anti-Patterns

### ❌ Don't Use Vague Messages

```d
// Bad
auto error = new IOError("", "Something went wrong");
```

### ❌ Don't Skip Context

```d
// Bad - no context about what was happening
auto error = new IOError(path, "Failed");
```

### ❌ Don't Use Generic Strings for Commands

```d
// Bad - not structured
error.addSuggestion("Try running: builder clean");

// Good - structured
error.addSuggestion(ErrorSuggestion.command("Clear cache", "builder clean"));
```

### ❌ Don't Use "ANY" Types

```d
// Bad - too generic
auto result = someOperation(); // What type is this?

// Good - explicit types
Result!(Target[], BuildError) result = parseTargets();
```

## See Also

- [Error Handling Overview](ERROR_HANDLING.md)
- [Result Type Documentation](../../source/errors/handling/result.d)
- [Error Codes](../../source/errors/handling/codes.d)
- [Error Formatting](../../source/errors/formatting/format.d)

