# Type-Safe Errors: Quick Reference

Quick reference for creating strongly-typed errors in Builder. No "ANY" types allowed!

## Quick Start

### Import What You Need

```d
import errors;
import errors.types.context : ErrorSuggestion;
```

## Common Patterns

### File Not Found

**Before (String-based):**
```d
auto error = new IOError(path, "File not found");
error.addSuggestion("Run builder init");
error.addSuggestion("Check the directory");
```

**After (Type-safe):**
```d
auto error = fileNotFoundError(path);
// Automatic context-aware suggestions included!
```

### File Read Errors

**Before:**
```d
auto error = new IOError(path, "Failed to read: " ~ e.msg);
error.addSuggestion("Check permissions: ls -la " ~ path);
```

**After:**
```d
auto error = fileReadError(path, e.msg, "reading config");
// Automatic permission check suggestions included!
```

### Parse Errors

**Before:**
```d
auto error = new ParseError(path, "Invalid syntax");
error.addSuggestion("Check the syntax");
```

**After:**
```d
auto error = parseErrorWithContext(path, "Invalid syntax", lineNum);
// Automatic syntax help and docs links included!
```

### Build Failures

**Before:**
```d
auto error = new BuildFailureError(target, "Build failed");
error.addSuggestion("Check build output");
```

**After:**
```d
auto error = buildFailureError(target, "Build failed", failedDeps);
// Automatic build debugging suggestions included!
```

## Builder Pattern

For custom errors with specific suggestions:

```d
auto error = ErrorBuilder!IOError.create(path, "Custom error message")
    .withCommand("Try this command", "builder init")
    .withDocs("Read documentation", "docs/guide.md")
    .withFileCheck("Check this file", path)
    .withConfig("Change setting", "timeout: 300")
    .withContext("what was happening", "details")
    .build();
```

## Suggestion Types

| Type | Method | Example | Use When |
|------|--------|---------|----------|
| Command | `.withCommand(desc, cmd)` | `"Clear cache", "builder clean"` | User should run a command |
| Documentation | `.withDocs(desc, url)` | `"See docs", "docs/guide.md"` | Point to docs/help |
| File Check | `.withFileCheck(desc, path)` | `"Check permissions", path` | File/permission issue |
| Configuration | `.withConfig(desc, setting)` | `"Set timeout", "timeout: 300"` | Config change needed |
| General | `.withSuggestion(desc)` | `"Try again later"` | General advice |

## Formatted Output Examples

### Command Suggestion
```
• Run: Clear cache
  $ builder clean
```

### Documentation Suggestion
```
• Docs: See Builderfile syntax
  → docs/user-guides/EXAMPLES.md
```

### File Check Suggestion
```
• Check: Verify file permissions
  /path/to/file
```

## Smart Constructors

| Function | Best For | Auto-Suggestions |
|----------|----------|------------------|
| `fileNotFoundError(path, context)` | Missing files | Create commands, directory checks, docs |
| `fileReadError(path, msg, context)` | Permission issues | Permission checks, file locks |
| `parseErrorWithContext(path, msg, line, context)` | Syntax errors | Syntax help, validation commands |
| `buildFailureError(target, msg, deps)` | Build failures | Verbose mode, dependency checks |
| `targetNotFoundError(name)` | Missing targets | Graph view, list command |
| `cacheLoadError(path, msg)` | Cache issues | Clean command, permission checks |

## Error Handling with Result Type

```d
Result!(string, BuildError) processFile(string path)
{
    if (!exists(path))
        return Err!(string, BuildError)(fileNotFoundError(path));
    
    try {
        return Ok!(string, BuildError)(readText(path));
    }
    catch (FileException e) {
        return Err!(string, BuildError)(fileReadError(path, e.msg));
    }
}

// Usage
auto result = processFile("config.json");
if (result.isErr) {
    writeln(format(result.unwrapErr()));  // Beautiful formatted error!
}
```

## Type Safety Rules

✅ **DO:**
- Use smart constructors for common errors
- Use ErrorBuilder for custom errors
- Specify suggestion types explicitly
- Include context with errors
- Link to documentation

❌ **DON'T:**
- Use `auto` where types are ambiguous
- Use plain string suggestions (use `ErrorSuggestion`)
- Create errors without suggestions
- Forget to add context
- Use vague error messages

## Migration Checklist

When updating old error code:

1. [ ] Replace `new IOError(...)` with `fileNotFoundError(...)` or builder
2. [ ] Replace `error.addSuggestion("string")` with typed suggestions
3. [ ] Add `.withCommand()`, `.withDocs()`, etc. as appropriate
4. [ ] Test that formatted output looks good
5. [ ] Ensure all suggestion types make sense

## Common Combinations

### File Operation Failed
```d
ErrorBuilder!IOError.create(path, message)
    .withFileCheck("Check file exists")
    .withCommand("Check permissions", "ls -la " ~ path)
    .withDocs("File operation docs", "docs/files.md")
    .build()
```

### Parse/Syntax Error
```d
parseErrorWithContext(path, message, line)
    // Automatic suggestions + custom ones:
    .withCommand("Validate syntax", "validator " ~ path)
```

### Configuration Error
```d
ErrorBuilder!ParseError.create(path, message)
    .withConfig("Set required field", "field: value")
    .withDocs("Configuration guide", "docs/config.md")
    .withFileCheck("Check config syntax")
    .build()
```

### Dependency Error
```d
buildFailureError(target, message, ["dep1", "dep2"])
    // Automatic suggestions + custom ones:
    .withCommand("Install dependencies", "builder deps")
```

## See Also

- [Full Documentation](TYPE_SAFE_ERRORS.md)
- [Implementation Details](TYPE_SAFETY_IMPROVEMENTS.md)
- [Examples](../examples/type_safe_errors_example.d)

