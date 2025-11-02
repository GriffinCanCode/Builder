module plugins.discovery;

/// Plugin Discovery Module
/// 
/// Discovers and validates plugins installed on the system.
/// Plugins are discovered by scanning directories in PATH for
/// executables matching the pattern: builder-plugin-*
/// 
/// Key Components:
///   - PluginScanner: Scans filesystem for plugins
///   - PluginValidator: Validates plugin compatibility
///   - SemanticVersion: Version parsing and comparison
/// 
/// Example:
///   auto scanner = new PluginScanner();
///   auto plugins = scanner.discover();
///   
///   foreach (plugin; plugins.unwrap()) {
///       writeln(plugin.name, " ", plugin.version_);
///   }

public import plugins.discovery.scanner;
public import plugins.discovery.validator;

