module errors;

/// Modular error handling system for Builder
/// 
/// This package provides a sophisticated, type-safe error handling system with:
/// - Result<T, E> monad for explicit error handling
/// - Hierarchical error types with codes and categories
/// - Error context chains for debugging
/// - Rich formatting with colors and suggestions
/// - Recovery strategies for transient errors
/// 
/// Usage:
///   import errors;
///   
///   // Using Result type
///   Result!(string, BuildError) parse(string file) {
///       try {
///           auto content = readText(file);
///           return Ok!(string, BuildError)(content);
///       } catch (Exception e) {
///           return Err!(string, BuildError)(ioError(file, e.msg));
///       }
///   }
///   
///   // Chaining operations
///   auto result = parse("BUILD.json")
///       .map(content => parseJson(content))
///       .andThen(json => validate(json));
///   
///   if (result.isErr) {
///       writeln(format(result.unwrapErr()));
///   }

public import errors.result;
public import errors.codes;
public import errors.types;
public import errors.context;
public import errors.format;
public import errors.recovery;

