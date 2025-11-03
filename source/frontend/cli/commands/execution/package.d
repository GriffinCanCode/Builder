module frontend.cli.commands.execution;

/// Build Execution and Analysis Commands
/// 
/// This package contains commands for building, testing, querying,
/// and analyzing the build graph:
/// 
/// - discover: Preview dynamic dependency discovery without building
/// - query: Query the build graph and configuration
/// - test: Execute tests with advanced filtering and reporting
/// - infer: Infer build configuration from source code

public import frontend.cli.commands.execution.discover;
public import frontend.cli.commands.execution.query;
public import frontend.cli.commands.execution.test;
public import frontend.cli.commands.execution.infer;
