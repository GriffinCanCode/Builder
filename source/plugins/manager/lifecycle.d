module plugins.manager.lifecycle;

import std.algorithm : filter, map;
import std.array : array;
import std.datetime.stopwatch : StopWatch;
import plugins.protocol;
import plugins.manager.registry;
import plugins.manager.loader;
import utils.logging.logger;
import errors;

/// Build lifecycle hook manager
class LifecycleManager {
    private IPluginRegistry registry;
    private PluginLoader loader;
    
    this(IPluginRegistry registry, PluginLoader loader) @safe {
        this.registry = registry;
        this.loader = loader;
    }
    
    /// Execute pre-build hooks for all registered plugins
    Result!BuildError executePreHooks(
        PluginTarget target,
        PluginWorkspace workspace
    ) @system {
        // Get plugins with pre-hook capability
        auto plugins = registry.withCapability("build.pre_hook");
        
        if (plugins.length == 0) {
            return Ok!BuildError();
        }
        
        Logger.debug_("Executing pre-build hooks for " ~ plugins.length.to!string ~ " plugins");
        
        foreach (plugin; plugins) {
            auto sw = StopWatch();
            sw.start();
            
            Logger.info("Running pre-build hook: " ~ plugin.name);
            
            auto result = loader.callPreHook(plugin.name, target, workspace);
            
            sw.stop();
            
            if (result.isErr) {
                Logger.error("Pre-build hook failed: " ~ plugin.name ~ " - " ~ 
                    result.unwrapErr().message);
                return Err!BuildError(result.unwrapErr());
            }
            
            auto hookResult = result.unwrap();
            
            // Log plugin output
            foreach (log; hookResult.logs) {
                Logger.info("[" ~ plugin.name ~ "] " ~ log);
            }
            
            if (!hookResult.success) {
                auto err = new PluginError(
                    "Pre-build hook failed: " ~ plugin.name,
                    ErrorCode.BuildFailed
                );
                err.addContext(ErrorContext("plugin", plugin.name));
                return Err!BuildError(err);
            }
            
            Logger.debug_("Pre-build hook completed: " ~ plugin.name ~ " (" ~ 
                sw.peek().total!"msecs".to!string ~ "ms)");
        }
        
        return Ok!BuildError();
    }
    
    /// Execute post-build hooks for all registered plugins
    Result!BuildError executePostHooks(
        PluginTarget target,
        PluginWorkspace workspace,
        string[] outputs,
        bool buildSuccess,
        long durationMs
    ) @system {
        // Get plugins with post-hook capability
        auto plugins = registry.withCapability("build.post_hook");
        
        if (plugins.length == 0) {
            return Ok!BuildError();
        }
        
        Logger.debug_("Executing post-build hooks for " ~ plugins.length.to!string ~ " plugins");
        
        foreach (plugin; plugins) {
            auto sw = StopWatch();
            sw.start();
            
            Logger.info("Running post-build hook: " ~ plugin.name);
            
            auto result = loader.callPostHook(
                plugin.name,
                target,
                workspace,
                outputs,
                buildSuccess,
                durationMs
            );
            
            sw.stop();
            
            if (result.isErr) {
                // Post-hook failures are non-fatal (just log them)
                Logger.error("Post-build hook failed: " ~ plugin.name ~ " - " ~ 
                    result.unwrapErr().message);
                continue;
            }
            
            auto hookResult = result.unwrap();
            
            // Log plugin output
            foreach (log; hookResult.logs) {
                Logger.info("[" ~ plugin.name ~ "] " ~ log);
            }
            
            if (!hookResult.success) {
                Logger.warning("Post-build hook reported failure: " ~ plugin.name);
            }
            
            Logger.debug_("Post-build hook completed: " ~ plugin.name ~ " (" ~ 
                sw.peek().total!"msecs".to!string ~ "ms)");
        }
        
        return Ok!BuildError();
    }
    
    /// Check if any plugins handle custom target type
    bool hasCustomTypeHandler(string targetType) @system {
        auto plugins = registry.list();
        
        foreach (plugin; plugins) {
            if (plugin.capabilities.canFind("target.custom_type") ||
                plugin.capabilities.canFind("target.custom_type." ~ targetType)) {
                return true;
            }
        }
        
        return false;
    }
    
    /// Get plugins that can handle a custom target type
    PluginInfo[] getCustomTypeHandlers(string targetType) @system {
        return registry.list()
            .filter!(p => 
                p.capabilities.canFind("target.custom_type") ||
                p.capabilities.canFind("target.custom_type." ~ targetType)
            )
            .array;
    }
}

