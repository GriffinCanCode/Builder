module languages.compiled.d.builders.base;

import languages.compiled.d.core.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import std.range : empty;
import engine.caching.actions.action : ActionCache;

/// Base interface for D builders
interface DBuilder
{
    /// Build D files
    DCompileResult build(
        in string[] sources,
        in DConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get builder version
    string getVersion();
}

/// Factory for creating D builders
class DBuilderFactory
{
    /// Create builder based on configuration with action cache support
    static DBuilder create(DConfig config, ActionCache actionCache = null)
    {
        import languages.compiled.d.builders.dub;
        import languages.compiled.d.builders.direct;
        
        // Check if we should use DUB
        bool useDub = false;
        
        if (config.mode == DBuildMode.Dub)
        {
            useDub = true;
        }
        else if (!config.dub.packagePath.empty)
        {
            useDub = true;
        }
        
        if (useDub)
        {
            return new DubBuilder(config, actionCache);
        }
        
        // Use direct compiler invocation
        return new DirectCompilerBuilder(config, actionCache);
    }
}


