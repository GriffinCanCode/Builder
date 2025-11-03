module infrastructure.migration.core;

/// Core Migration Framework
/// 
/// Provides the fundamental types, interfaces, and base classes for the
/// migration system. This is the foundation that all migrators build upon.
/// 
/// Key Components:
///   - IMigrator: Interface that all build system migrators implement
///   - BaseMigrator: Abstract base class with common migration functionality
///   - MigratorFactory: Factory for creating and auto-detecting migrators
///   - MigrationTarget: Intermediate representation of build targets
///   - MigrationResult: Container for migration results, warnings, and errors
///   - MigrationWarning: Structured warnings with severity levels
/// 
/// Design Philosophy:
///   - Build system agnostic intermediate representation
///   - Result-based error handling (no exceptions in normal flow)
///   - Type-safe with schema integration
///   - Composable and extensible

public import infrastructure.migration.core.common;
public import infrastructure.migration.core.base;

