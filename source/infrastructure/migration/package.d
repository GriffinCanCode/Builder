module infrastructure.migration;

/// Build System Migration Package
/// 
/// Provides comprehensive migration tools from various build systems to Builder.
/// Supports: Bazel, CMake, Maven, Gradle, Make, Cargo, npm, Go modules, DUB, SBT, Meson
/// 
/// Architecture:
///   core/       - Fundamental interfaces, types, and base classes
///     - common.d    - Common types and intermediate representation
///     - base.d      - Base interface, factory, and abstract migrator
///   registry/   - Migrator registration and discovery system
///     - registry.d  - Singleton registry (follows LanguageRegistry pattern)
///   emission/   - Code generation and output formatting
///     - emitter.d   - Builderfile DSL code generation
///   systems/    - Individual migrator implementations for each build system
/// 
/// Design Principles:
///   - Modular organization with clear separation of concerns
///   - Composable parsers with unified intermediate representation
///   - Result-based error handling throughout (no exceptions)
///   - Strong typing with TargetId and schema types
///   - Single responsibility per module
///   - Registry pattern for extensibility
///   - Barrel exports for clean API surface
/// 
/// Usage:
///   import infrastructure.migration;
///   
///   // Factory-based creation
///   auto migrator = MigratorFactory.create("bazel");
///   auto result = migrator.migrate("BUILD");
///   
///   // Auto-detection
///   auto detected = MigratorFactory.autoDetect("BUILD");
///   
///   // Code generation
///   if (result.isOk) {
///       auto emitter = BuilderfileEmitter();
///       string builderfile = emitter.emit(result.unwrap());
///       writeln(builderfile);
///   }

public import infrastructure.migration.core;
public import infrastructure.migration.registry;
public import infrastructure.migration.emission;
public import infrastructure.migration.systems;

