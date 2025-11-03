module infrastructure.migration;

/// Build System Migration Package
/// 
/// Provides comprehensive migration tools from various build systems to Builder.
/// Supports: Bazel, CMake, Maven, Gradle, Make, Cargo, npm, Go modules, DUB, SBT, Meson
/// 
/// Architecture:
///   common.d    - Common types and intermediate representation
///   base.d      - Base interface and factory for migrators
///   registry.d  - Migrator registry (follows LanguageRegistry pattern)
///   emitter.d   - Builderfile DSL code generation
///   systems/    - Individual migrator implementations
/// 
/// Design Principles:
///   - Composable parsers with unified IR
///   - Result-based error handling throughout
///   - Strong typing with TargetId and schema types
///   - Single responsibility services
///   - Registry pattern for extensibility
/// 
/// Usage:
///   import migration;
///   
///   auto migrator = MigratorFactory.create("bazel");
///   auto result = migrator.migrate("BUILD");
///   
///   if (result.isOk) {
///       auto emitter = BuilderfileEmitter();
///       auto builderfile = emitter.emit(result.unwrap());
///       writeln(builderfile);
///   }

public import infrastructure.migration.common;
public import infrastructure.migration.base;
public import infrastructure.migration.registry;
public import infrastructure.migration.emitter;
public import infrastructure.migration.systems;

