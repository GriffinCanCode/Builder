# Type Safety Improvements to Error System

## Summary

This document summarizes the type safety improvements made to Builder's error handling system, addressing the requirement to avoid "ANY" types and provide stronger typing throughout the codebase.

## Problem Statement

While Builder had a rule against using "ANY" types, the error handling system could benefit from stronger typing:

- Errors used loose string-based suggestions
- No structured data for different types of suggestions
- Difficult to format suggestions differently (commands vs docs vs file checks)
- No compile-time guarantees about suggestion structure

## Solution: Strongly-Typed Error Suggestions

### 1. New `ErrorSuggestion` Type

Added a strongly-typed suggestion system in `source/errors/types/context.d`:

```d
struct ErrorSuggestion
{
    enum Type
    {
        Command,           // CLI command to run
        Documentation,     // Link to documentation
        FileCheck,         // File/permission check
        Configuration,     // Config file change
        General            // General advice
    }
    
    Type type;
    string message;
    string detail;         // Command, URL, path, etc.
}
```

**Benefits:**
- ✅ **No ANY types** - Everything is strongly typed
- ✅ **Compile-time safety** - Can't pass wrong types
- ✅ **Structured data** - Can format based on type
- ✅ **Extensible** - Easy to add new suggestion types

### 2. Enhanced Error Builder

Extended the `ErrorBuilder` pattern with type-safe methods:

```d
auto error = ErrorBuilder!IOError.create(path, "File not found")
    .withCommand("Create file", "touch " ~ path)           // Typed as Command
    .withDocs("See docs", "docs/examples.md")              // Typed as Documentation
    .withFileCheck("Check permissions", path)               // Typed as FileCheck
    .withConfig("Set timeout", "timeout: 300")              // Typed as Configuration
    .build();
```

**Benefits:**
- ✅ Fluent API for error construction
- ✅ Each method creates appropriately typed suggestions
- ✅ Discoverable via IDE autocomplete
- ✅ Hard to misuse

### 3. Smart Error Constructors

Created specialized constructors that automatically provide context-aware suggestions:

#### `fileNotFoundError(path, context)`
Automatically detects file type (Builderfile, Builderspace, etc.) and provides appropriate suggestions.

#### `fileReadError(path, errorMsg, context)`
Provides file permission and access checking suggestions.

#### `parseErrorWithContext(filePath, message, line, context)`
Provides syntax checking and documentation suggestions based on file type.

#### `buildFailureError(targetId, message, failedDeps)`
Provides build debugging and dependency checking suggestions.

#### `targetNotFoundError(targetName)`
Provides target discovery and graph visualization suggestions.

#### `cacheLoadError(cachePath, message)`
Provides cache clearing and diagnostic suggestions.

**Benefits:**
- ✅ Consistent error messages across codebase
- ✅ Automatic context-aware suggestions
- ✅ Less code duplication
- ✅ Easier to maintain

### 4. Enhanced Formatting

Updated `errors/formatting/format.d` to format suggestions based on type:

**Command Suggestions:**
```
• Run: Clear cache
  $ builder clean
```

**Documentation Suggestions:**
```
• Docs: See Builderfile syntax
  → docs/user-guides/EXAMPLES.md
```

**File Check Suggestions:**
```
• Check: Verify file permissions
  /path/to/file
```

**Benefits:**
- ✅ Visual distinction between suggestion types
- ✅ Commands clearly marked as executable
- ✅ Documentation links clearly marked
- ✅ Better user experience

## Files Modified

### Core Error Types
- ✅ `source/errors/types/context.d` - Added `ErrorSuggestion` struct
- ✅ `source/errors/types/types.d` - Updated `BaseBuildError` to use typed suggestions
- ✅ `source/errors/types/types.d` - Enhanced `ErrorBuilder` with typed methods
- ✅ `source/errors/types/types.d` - Added smart error constructors

### Formatting
- ✅ `source/errors/formatting/format.d` - Added type-aware suggestion formatting

### Adapters
- ✅ `source/errors/adaptation/adapt.d` - Updated to use typed suggestions

### Usage Examples
- ✅ `source/config/parsing/parser.d` - Migrated to use smart constructors and builder pattern

### Documentation
- ✅ `docs/development/TYPE_SAFE_ERRORS.md` - Comprehensive usage guide
- ✅ `docs/examples/type_safe_errors_example.d` - Working code examples

## Migration Path

### Before (Old Style)

```d
auto error = new IOError(path, "File not found");
error.addSuggestion("Run: builder init");
error.addSuggestion("Check the file path");
error.addSuggestion("See docs/examples.md");
```

**Problems:**
- Suggestions are just strings
- No structure - can't tell commands from docs
- Hard to format consistently
- Easy to forget important suggestions

### After (New Style) - Option 1: Smart Constructor

```d
auto error = fileNotFoundError(path);
// Automatically includes:
// - Command: builder init
// - File check: directory location
// - Docs: Builderfile documentation
```

**Benefits:**
- Context-aware suggestions automatically included
- Consistent across codebase
- Less code to write

### After (New Style) - Option 2: Builder Pattern

```d
auto error = ErrorBuilder!IOError.create(path, "File not found")
    .withCommand("Initialize project", "builder init")
    .withFileCheck("Check directory")
    .withDocs("See examples", "docs/examples.md")
    .build();
```

**Benefits:**
- Strongly typed suggestions
- Fluent API
- IDE autocomplete support
- Compile-time type checking

## Type Safety Guarantees

### 1. No Generic/ANY Types

All error types are concrete:
- `ErrorCode` enum (not `auto`)
- `ErrorSuggestion.Type` enum (not `auto`)
- `BuildError` interface (not generic)
- Specific error classes (not `Exception`)

### 2. Compile-Time Checking

```d
// ✅ Compiles - correct types
error.addSuggestion(ErrorSuggestion.command("Run test", "make test"));

// ❌ Won't compile - type mismatch
error.addSuggestion(42);

// ❌ Won't compile - wrong enum
error.addSuggestion(ErrorSuggestion("msg", WrongEnum.Value));
```

### 3. Exhaustive Matching

All `final switch` statements on `ErrorSuggestion.Type` must handle all cases:

```d
final switch (suggestion.type)
{
    case ErrorSuggestion.Type.Command: /* ... */ break;
    case ErrorSuggestion.Type.Documentation: /* ... */ break;
    case ErrorSuggestion.Type.FileCheck: /* ... */ break;
    case ErrorSuggestion.Type.Configuration: /* ... */ break;
    case ErrorSuggestion.Type.General: /* ... */ break;
    // Compiler error if any case is missing
}
```

## Backward Compatibility

The new system maintains backward compatibility:

### String Suggestions Still Work

```d
error.addSuggestion("Check the file");  // Still works
```

Internally converted to `ErrorSuggestion(message, Type.General)`.

### Old Constructors Still Available

```d
auto error = new IOError(path, "File not found");  // Still works
```

But new code should prefer smart constructors:

```d
auto error = fileNotFoundError(path);  // Better!
```

## Testing

Run the example to see the new error formatting:

```bash
cd docs/examples
dub run --single type_safe_errors_example.d
```

## Performance Impact

**Minimal:**
- `ErrorSuggestion` is a small struct (stack allocated)
- No heap allocations for suggestion types
- Formatting only happens when errors are displayed
- Same number of string allocations as before

## Future Enhancements

Potential improvements building on this foundation:

1. **Internationalization**: Suggestion types enable translated messages
2. **Machine-Readable Errors**: Structured suggestions can be parsed by tools
3. **Interactive Mode**: Commands could be executed directly from error display
4. **Telemetry**: Track which suggestion types are most helpful
5. **Custom Suggestion Types**: Projects could define their own types

## Conclusion

These improvements provide:

✅ **Strong Type Safety** - No ANY types, all errors are concrete types
✅ **Better UX** - Structured suggestions with clear formatting
✅ **Maintainability** - Smart constructors reduce code duplication
✅ **Discoverability** - Builder pattern with IDE autocomplete
✅ **Consistency** - All errors follow same patterns
✅ **Backward Compatible** - Gradual migration path

The error system now fully adheres to the "NEVER USE ANY TYPES" rule while providing a much better developer and user experience.

