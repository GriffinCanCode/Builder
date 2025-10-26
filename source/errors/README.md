# Errors Package

The errors package provides a sophisticated, type-safe error handling system with Result types, error codes, and rich formatting.

## Modules

- **result.d** - Result<T, E> monad for error handling
- **codes.d** - Error code definitions
- **types.d** - Error type hierarchy
- **context.d** - Error context chains
- **format.d** - Rich error formatting with colors
- **recovery.d** - Error recovery strategies
- **aggregate.d** - Multiple error aggregation

## Usage

```d
import errors;

Result!(string, BuildError) parse(string file) {
    try {
        auto content = readText(file);
        return Ok!(string, BuildError)(content);
    } catch (Exception e) {
        return Err!(string, BuildError)(ioError(file, e.msg));
    }
}

auto result = parse("BUILD.json")
    .map(content => parseJson(content))
    .andThen(json => validate(json));

if (result.isErr) {
    writeln(format(result.unwrapErr()));
}
```

## Key Features

- Type-safe Result monad (no exceptions)
- Hierarchical error types with codes
- Error context chains for debugging
- Rich formatting with colors and suggestions
- Recovery strategies for transient errors
- Multiple error aggregation

