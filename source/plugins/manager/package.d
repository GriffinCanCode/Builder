module plugins.manager;

/// Plugin Manager Module
/// 
/// Manages plugin lifecycle, registration, and execution.
/// 
/// Key Components:
///   - PluginRegistry: Registry of discovered plugins
///   - PluginLoader: Executes plugins with RPC protocol
///   - LifecycleManager: Manages build lifecycle hooks
/// 
/// Example:
///   auto registry = new PluginRegistry("1.0.0");
///   auto loader = new PluginLoader();
///   auto lifecycle = new LifecycleManager(registry, loader);
///   
///   // Execute pre-build hooks
///   lifecycle.executePreHooks(target, workspace);
///   
///   // Build...
///   
///   // Execute post-build hooks
///   lifecycle.executePostHooks(target, workspace, outputs, true, 1000);

public import plugins.manager.registry;
public import plugins.manager.loader;
public import plugins.manager.lifecycle;

