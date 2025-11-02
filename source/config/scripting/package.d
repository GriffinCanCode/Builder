module config.scripting;

/// Builder Programmability System - Tier 1: Functional DSL Extensions
/// 
/// Provides variables, functions, conditionals, loops, and macros for Builderfiles.
/// Enables code reuse, dynamic target generation, and complex build logic
/// while maintaining type safety and compile-time evaluation.
/// 
/// Architecture:
///   types      - Value types and type system
///   scope      - Symbol table and lexical scoping
///   builtins   - Standard library functions
///   evaluator  - Expression evaluation engine
///   expander   - Macro expansion
/// 
/// Features:
///   - Variables: let/const bindings with scoping
///   - Functions: Pure functions for code reuse
///   - Conditionals: if/else for platform-specific builds
///   - Loops: for/range for generating multiple targets
///   - Macros: Code generation at parse time
///   - Built-ins: String, array, file, environment operations
///   - Type safety: Static type checking at parse time
///   - Performance: Compile-time evaluation when possible
/// 
/// Example:
///   let packages = ["core", "api", "cli"];
///   
///   for pkg in packages {
///       target(pkg) {
///           type: library;
///           language: python;
///           sources: ["lib/" + pkg + "/**/*.py"];
///       }
///   }

public import config.scripting.types;
public import config.scripting.scopemanager;
public import config.scripting.builtins;
public import config.scripting.evaluator;
public import config.scripting.expander;

