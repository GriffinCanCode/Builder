module cli.commands;

/// CLI command implementations
/// 
/// This package provides command handlers for the Builder CLI.
/// Each command is implemented as a standalone module with a
/// consistent interface pattern.

public import cli.commands.init;
public import cli.commands.infer;
public import cli.commands.telemetry;
public import cli.commands.help;
public import cli.commands.query;
public import cli.commands.wizard;
public import cli.commands.watch;
public import cli.commands.cacheserver;
public import cli.commands.plugin;
public import cli.commands.coordinator;
public import cli.commands.worker;
public import cli.commands.test;
public import cli.commands.migrate;

