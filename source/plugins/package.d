module plugins;

/// Builder Plugin System
/// 
/// Process-based plugin architecture for extending Builder functionality.
/// Plugins are standalone executables that communicate via JSON-RPC 2.0
/// protocol over stdin/stdout.
/// 
/// Architecture:
///   protocol/   - JSON-RPC 2.0 protocol implementation
///   discovery/  - Plugin discovery and validation
///   manager/    - Plugin registry, loader, and lifecycle
///   sdk/        - Plugin SDK and templates
/// 
/// Key Features:
///   - Language-agnostic (any language can write plugins)
///   - Process isolation (plugin crashes don't affect Builder)
///   - Zero ABI coupling (protocol-based communication)
///   - Homebrew distribution (plugins as separate formulas)
///   - Build lifecycle hooks (pre/post build)
///   - Custom target types
///   - Artifact processing
/// 
/// Example Plugin Discovery:
///   import plugins;
///   
///   auto scanner = new PluginScanner();
///   auto plugins = scanner.discover();
///   
///   foreach (plugin; plugins.unwrap()) {
///       writeln(plugin.name, " v", plugin.version_);
///   }
/// 
/// Example Plugin Execution:
///   auto loader = new PluginLoader();
///   auto request = RPCCodec.infoRequest(1);
///   auto result = loader.execute("docker", request);
///   
///   if (result.isOk) {
///       auto execution = result.unwrap();
///       auto info = PluginInfo.fromJSON(execution.response.result);
///   }
/// 
/// Example Lifecycle Hooks:
///   auto registry = new PluginRegistry("1.0.0");
///   auto loader = new PluginLoader();
///   auto lifecycle = new LifecycleManager(registry, loader);
///   
///   // Pre-build
///   lifecycle.executePreHooks(target, workspace);
///   
///   // Build...
///   
///   // Post-build
///   lifecycle.executePostHooks(target, workspace, outputs, true, 1000);

public import plugins.protocol;
public import plugins.discovery;
public import plugins.manager;
public import plugins.sdk;

