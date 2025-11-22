# Error Message Enrichment

## Overview

This document describes the comprehensive error enrichment system that provides rich, actionable error messages throughout Builder. The system automatically adds context, file locations, and specific suggestions to help users quickly diagnose and fix issues.

## Key Components

### 1. Enhanced Suggestion Generator

**Location**: `source/infrastructure/errors/formatting/suggestions.d`

The `SuggestionGenerator` now provides comprehensive suggestions for all error codes:

- **IO Errors** (5000-5999): File operation failures with permission and path suggestions
- **Parse Errors** (2000-2999): Syntax validation with format-specific guidance
- **Analysis Errors** (3000-3999): Dependency resolution with graph visualization commands
- **Build Errors** (1000-1999): Compilation failures with debugging commands
- **Cache Errors** (4000-4999): Cache operation issues with cleanup commands
- **System Errors** (8000-8999): Process and memory errors with resource management tips
- **Language Errors** (7000-7999): Compiler errors with toolchain guidance
- **Plugin/LSP/Watch Errors**: Specialized suggestions for each subsystem

### 2. Error Builder Helpers

**Location**: `source/infrastructure/errors/helpers/builders.d`

Smart error constructors that automatically add:

- **Source location tracking**: Captures file and line where error was created
- **Operation context**: What was being attempted when error occurred
- **File-type specific suggestions**: Different guidance based on file being processed
- **Common remediation steps**: Pre-configured fixes for each error type

#### Available Helpers

```d
// Parse errors with file-type specific suggestions
auto error = createParseError(filePath, message, code);

// File operations with existence checks
auto error = createFileReadError(filePath, context);

// Analysis errors with dependency-specific guidance
auto error = createAnalysisError(targetName, message, code);

// Build failures with compiler-specific help
auto error = createBuildError(targetId, message, code);

// Language errors with toolchain detection
auto error = createLanguageError(language, message, code);

// Cache errors with path and cleanup guidance
auto error = createCacheError(message, code, cachePath);

// System errors with resource management tips
auto error = createSystemError(message, code);
```

### 3. Manifest-Specific Error Helpers

**Location**: `source/infrastructure/errors/helpers/manifests.d`

Ecosystem integration errors with package-manager specific guidance:

```d
// Manifest not found (suggests initialization commands)
manifestNotFoundError(path, "npm|cargo|go|python|composer");

// Parse failures (format-specific validation)
manifestParseError(path, type, parseError);

// Missing fields (shows expected format)
manifestMissingFieldError(path, type, fieldName);

// Invalid values (explains correct format)
manifestInvalidFieldError(path, type, field, value, expected);

// Dependency resolution (package manager commands)
manifestDependencyError(path, type, depName, reason);

// Version mismatches (upgrade guidance)
manifestVersionError(path, type, current, supported);

// Tool missing (installation instructions)
ecosystemToolMissingError(tool, type);
```

## Error Context Chain

Errors now include a context chain showing the operation stack:

```
[Parse:ParseFailed] Failed to parse package.json: Invalid JSON
  → during: parsing configuration file (package.json) at npm.d:60
  → during: loading project manifests

Suggestions:
  • Run: Validate JSON syntax
    $ cat package.json | python3 -m json.tool
  • Check for trailing commas (not allowed in JSON)
  • Docs: See package.json examples
    → docs/features/ecosystem-integration.md
```

## File-Type Specific Suggestions

The system recognizes file types and provides targeted help:

### package.json (npm/yarn/pnpm)
- JSON validation commands
- Trailing comma detection
- npm-specific documentation links

### Cargo.toml (Rust)
- TOML syntax validation
- cargo check commands
- Cargo documentation links

### go.mod (Go)
- go mod tidy commands
- Module path verification

### pyproject.toml / setup.py (Python)
- pip install validation
- Python packaging guides

### composer.json (PHP)
- composer validate commands
- PHP packaging documentation

### Builderfile
- Builder syntax documentation
- Reinitialization commands
- Field validation guides

## Automatic Location Tracking

All error helpers automatically capture:
- Source file where error was created
- Line number in source
- Function/operation context

This enables precise error tracking for debugging and issue reporting.

## Usage Examples

### Before (Basic Error)

```d
// Old style - minimal context
auto error = new ParseError(filePath, "Parse error: " ~ e.msg, ErrorCode.ParseFailed);
return Result.err(error);
```

**Output**:
```
[Parse:ParseFailed] Parse error: unexpected token
  File: package.json
```

### After (Enriched Error)

```d
// New style - rich context and suggestions
return Result.err(manifestParseError(filePath, "npm", "Invalid JSON: " ~ e.msg));
```

**Output**:
```
[Parse:ParseFailed] Failed to parse npm manifest: Invalid JSON: unexpected token
  → during: parsing npm manifest at npm.d:60
  File: package.json

Suggestions:
  • Run: Validate JSON syntax
    $ cat package.json | python3 -m json.tool
  • Check for trailing commas (not allowed in JSON)
  • Docs: See package.json examples
    → docs/features/ecosystem-integration.md
```

## Integration Points

### Manifest Parsers
All ecosystem manifest parsers updated:
- ✅ `npm.d` - Node.js package.json
- ✅ `cargo.d` - Rust Cargo.toml
- ✅ `go.d` - Go go.mod
- ✅ `python.d` - Python pyproject.toml/setup.py
- ✅ `composer.d` - PHP composer.json

### Build Pipeline
- ✅ `parser.d` - Configuration parsing
- ✅ `analyzer.d` - Incremental analysis
- ✅ `cas.d` - Cache operations

### Language Handlers
- ✅ `base.d` - Base language handler (already had good errors)

## Benefits

### For Users
1. **Faster Problem Resolution**: Specific commands to run
2. **Better Understanding**: Context shows what was happening
3. **Self-Service**: Documentation links for learning
4. **Reduced Frustration**: Clear next steps instead of cryptic messages

### For Developers
1. **Easier Debugging**: Source location in errors
2. **Consistent Format**: All errors follow same pattern
3. **Easy to Extend**: Add new error types with helpers
4. **Better Bug Reports**: Users can provide detailed error context

### For Support
1. **Fewer Questions**: Errors include common solutions
2. **Faster Triage**: Context shows exact failure point
3. **Better Patterns**: Track common error categories
4. **Documentation Gaps**: See what docs users need

## Error Formatting Options

Errors support rich formatting:

```d
FormatOptions opts;
opts.colors = true;           // ANSI colors in terminal
opts.showCode = true;         // Show error code (e.g., ParseFailed)
opts.showCategory = true;     // Show category (e.g., Parse)
opts.showContexts = true;     // Show context chain
opts.showSuggestions = true;  // Show helpful suggestions
opts.showTimestamp = false;   // Show when error occurred
opts.maxWidth = 80;           // Wrap long lines

string formatted = format(error, opts);
```

## Suggestion Types

The system uses typed suggestions for semantic clarity:

- **Command**: Runnable CLI commands with syntax
- **Documentation**: Links to relevant docs/guides
- **FileCheck**: File/permission validation steps
- **Configuration**: Config file changes needed
- **General**: General advice/information

Each type is formatted differently for visual scanning.

## Future Enhancements

Potential improvements:

1. **Interactive Mode**: Let users choose from suggestions
2. **AI Integration**: Generate custom solutions based on context
3. **Error Analytics**: Track most common errors for UX improvements
4. **Solution Database**: Crowdsourced fixes from community
5. **IDE Integration**: Jump to file/line from error messages
6. **Localization**: Translate errors and suggestions
7. **Error Templates**: User-customizable error formats

## Migration Guide

To adopt enriched errors in new code:

1. Import helpers:
   ```d
   import infrastructure.errors.helpers;
   ```

2. Replace basic error construction:
   ```d
   // Before
   auto error = new ParseError(path, msg, code);
   
   // After
   auto error = createParseError(path, msg, code);
   ```

3. Add custom context if needed:
   ```d
   error.addContext(ErrorContext("operation", "details"));
   error.addSuggestion(ErrorSuggestion.command("desc", "cmd"));
   ```

4. For manifest errors, use specialized helpers:
   ```d
   manifestNotFoundError(path, "npm");
   manifestParseError(path, "cargo", msg);
   manifestDependencyError(path, "python", dep, reason);
   ```

## Testing

Error enrichment can be tested by:

1. Triggering error conditions
2. Verifying context chain is present
3. Checking suggestions are appropriate
4. Ensuring file types are recognized
5. Validating location tracking

Example test:
```d
// Trigger parse error with invalid JSON
auto result = parser.parse("invalid.json");
assert(result.isErr);

auto error = result.unwrapErr();
assert(error.suggestions().length > 0);
assert(error.contexts().length > 0);

// Verify JSON-specific suggestions
bool hasJSONValidation = false;
foreach (s; error.suggestions())
    if (s.message.canFind("JSON"))
        hasJSONValidation = true;
assert(hasJSONValidation);
```

## Conclusion

The error enrichment system transforms Builder's error messages from basic notifications into actionable guides that help users quickly understand and resolve issues. By providing context, specific commands, and relevant documentation, the system reduces friction and improves the overall developer experience.

