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

public import errors.handling.result;
public import errors.handling.codes;
public import errors.types.types;
public import errors.types.context;
public import errors.formatting.format;
public import errors.handling.recovery;
public import errors.handling.aggregate;
public import errors.adaptation.adapt;

