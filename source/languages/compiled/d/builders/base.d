module languages.compiled.d.builders.base;

import languages.compiled.d.core.config;
import config.schema.schema;
import analysis.targets.types;

/// Base interface for D builders
interface DBuilder
{
    /// Build D files
    DCompileResult build(
        string[] sources,
        DConfig config,
        Target target,
        WorkspaceConfig workspace
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
    /// Create builder based on configuration
    static DBuilder create(DConfig config)
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
            return new DubBuilder(config);
        }
        
        // Use direct compiler invocation
        return new DirectCompilerBuilder(config);
    }
}


