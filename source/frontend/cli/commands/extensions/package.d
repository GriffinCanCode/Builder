module frontend.cli.commands.extensions;

/// Extension and Observability Commands
/// 
/// This package contains commands for plugins, monitoring, and development tools:
/// 
/// - plugin: Manage Builder plugins (install, remove, list)
/// - telemetry: View and configure telemetry settings
/// - watch: Watch mode for automatic rebuilds on file changes

public import frontend.cli.commands.extensions.plugin;
public import frontend.cli.commands.extensions.telemetry;
public import frontend.cli.commands.extensions.watch;

