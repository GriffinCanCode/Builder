module frontend.cli.commands;

/// CLI Command Implementations
/// 
/// This package provides all command handlers for the Builder CLI,
/// organized into logical categories for maintainability and clarity.
/// 
/// ## Command Categories
/// 
/// ### Execution Commands (`execution/`)
/// Build, test, query, and analyze commands for working with the build graph.
/// 
/// ### Project Commands (`project/`)
/// Project initialization, configuration, and migration commands.
/// 
/// ### Infrastructure Commands (`infrastructure/`)
/// Distributed build infrastructure management (cache server, coordinator, worker).
/// 
/// ### Extensions Commands (`extensions/`)
/// Plugin management, telemetry, and development tools (watch mode).
/// 
/// ### Help Commands (`help/`)
/// Documentation and help information display.
/// 
/// Each command module follows a consistent interface pattern for easy
/// integration and testing.

// Execution commands
public import frontend.cli.commands.execution;

// Project management commands
public import frontend.cli.commands.project;

// Infrastructure commands
public import frontend.cli.commands.infrastructure;

// Extensions and observability commands
public import frontend.cli.commands.extensions;

// Help commands
public import frontend.cli.commands.help;
