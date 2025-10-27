module languages.scripting.go.builders.base;

import languages.scripting.go.core.config;
import config.schema.schema;
import analysis.targets.types;

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
    /// Create builder based on build mode
    static GoBuilder create(GoBuildMode mode, GoConfig config)
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
                    return new CrossBuilder();
                if (config.cgo.enabled)
                    return new CGoBuilder();
                return new StandardBuilder();
                
            case GoBuildMode.Plugin:
                return new PluginBuilder();
                
            case GoBuildMode.CArchive:
            case GoBuildMode.CShared:
                return new CGoBuilder();
                
            case GoBuildMode.PIE:
            case GoBuildMode.Shared:
                return new StandardBuilder();
        }
    }
    
    /// Auto-detect best builder based on configuration
    static GoBuilder createAuto(GoConfig config)
    {
        return create(config.mode, config);
    }
}

