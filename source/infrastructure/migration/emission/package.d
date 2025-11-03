module infrastructure.migration.emission;

/// Builderfile Code Generation
/// 
/// Generates clean, idiomatic Builderfile DSL from migration intermediate
/// representation. Handles formatting, indentation, and comment generation.
/// 
/// Key Components:
///   - BuilderfileEmitter: Main code generator
/// 
/// Features:
///   - Clean DSL generation with proper indentation
///   - Automatic comment generation for metadata
///   - Warning and error summary in generated output
///   - Type-safe enum to string conversion
///   - Structured array and map formatting
/// 
/// Output Format:
///   - Header comments with migration information
///   - Target declarations with all properties
///   - Metadata preserved as comments
///   - Migration summary with warnings/errors
/// 
/// Usage:
///   auto emitter = BuilderfileEmitter();
///   string builderfile = emitter.emit(migrationResult);

public import infrastructure.migration.emission.emitter;

