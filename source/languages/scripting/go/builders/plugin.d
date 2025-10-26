module languages.scripting.go.builders.plugin;

import languages.scripting.go.builders.standard;
import languages.scripting.go.builders.base;
import languages.scripting.go.config;
import config.schema.schema;
import analysis.targets.types;
import utils.logging.logger;

/// Plugin builder - builds Go plugins (deprecated but still supported)
class PluginBuilder : StandardBuilder
{
    override GoBuildResult build(
        string[] sources,
        GoConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        Logger.info("Building Go plugin (Note: Go plugins are deprecated in Go 1.16+)");
        
        // Force plugin mode
        config.mode = GoBuildMode.Plugin;
        
        // Plugins don't work on all platforms
        version(Windows)
        {
            GoBuildResult result;
            result.error = "Go plugins are not supported on Windows";
            return result;
        }
        
        // Use standard builder with plugin mode
        return super.build(sources, config, target, workspace);
    }
    
    override string name() const
    {
        return "plugin";
    }
    
    override bool supportsMode(GoBuildMode mode)
    {
        return mode == GoBuildMode.Plugin;
    }
}
