module languages.scripting.go.builders.base;

import languages.scripting.go.core.config;
import config.schema.schema;
import analysis.targets.types;
import core.caching.actions.action : ActionCache;

/// Base interface for Go builders
interface GoBuilder
{
    /// Build Go sources with specific mode
    GoBuildResult build(
        in string[] sources,
        in GoConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get Go compiler version
    string getVersion();
    
    /// Check if this builder supports the given build mode
    bool supportsMode(GoBuildMode mode);
}

/// Factory for creating Go builders
class GoBuilderFactory
{
    /// Create builder based on build mode with action-level caching support
    static GoBuilder create(GoBuildMode mode, GoConfig config, ActionCache actionCache = null)
    {
        import languages.scripting.go.builders.standard;
        import languages.scripting.go.builders.plugin;
        import languages.scripting.go.builders.cgo;
        import languages.scripting.go.builders.cross;
        
        final switch (mode)
        {
            case GoBuildMode.Executable:
            case GoBuildMode.Library:
                // Standard builder handles both
                if (config.cross.isCross())
                    return new CrossBuilder(actionCache);
                if (config.cgo.enabled)
                    return new CGoBuilder(actionCache);
                return new StandardBuilder(actionCache);
                
            case GoBuildMode.Plugin:
                return new PluginBuilder(actionCache);
                
            case GoBuildMode.CArchive:
            case GoBuildMode.CShared:
                return new CGoBuilder(actionCache);
                
            case GoBuildMode.PIE:
            case GoBuildMode.Shared:
                return new StandardBuilder(actionCache);
        }
    }
    
    /// Auto-detect best builder based on configuration
    static GoBuilder createAuto(GoConfig config, ActionCache actionCache = null)
    {
        return create(config.mode, config, actionCache);
    }
}

