module infrastructure.migration.registry;

/// Migration Registry System
/// 
/// Provides centralized registration and discovery of build system migrators.
/// Follows the same pattern as LanguageRegistry for consistency.
/// 
/// Key Components:
///   - MigratorRegistry: Singleton registry for all migrators
///   - getMigratorRegistry(): Convenience function for registry access
/// 
/// Features:
///   - Automatic migrator registration on initialization
///   - Case-insensitive system name lookup
///   - Support status checking
///   - Enumeration of available migrators
/// 
/// Usage:
///   auto registry = getMigratorRegistry();
///   if (registry.isSupported("bazel")) {
///       auto migrator = registry.create("bazel");
///   }

public import infrastructure.migration.registry.registry;

