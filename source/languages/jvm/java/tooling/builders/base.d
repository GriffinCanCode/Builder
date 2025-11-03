module languages.jvm.java.tooling.builders.base;

import languages.jvm.java.core.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import engine.caching.actions.action : ActionCache;

/// Build result for Java builds
struct JavaBuildResult
{
    bool success = false;
    string error;
    string[] outputs;
    string outputHash;
    string[] warnings;
}

/// Base interface for Java builders
interface JavaBuilder
{
    /// Build Java sources
    JavaBuildResult build(
        const string[] sources,
        JavaConfig config,
        const Target target,
        const WorkspaceConfig workspace
    );
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Check if this builder supports the given build mode
    bool supportsMode(JavaBuildMode mode);
}

/// Factory for creating Java builders
class JavaBuilderFactory
{
    /// Create builder based on build mode with action-level caching support
    static JavaBuilder create(JavaBuildMode mode, JavaConfig config, ActionCache actionCache = null)
    {
        import languages.jvm.java.tooling.builders.jar;
        import languages.jvm.java.tooling.builders.fatjar;
        import languages.jvm.java.tooling.builders.war;
        import languages.jvm.java.tooling.builders.modular;
        import languages.jvm.java.tooling.builders.native_;
        
        final switch (mode)
        {
            case JavaBuildMode.JAR:
                return new JARBuilder(actionCache);
            
            case JavaBuildMode.FatJAR:
                return new FatJARBuilder(actionCache);
            
            case JavaBuildMode.WAR:
            case JavaBuildMode.EAR:
            case JavaBuildMode.RAR:
                return new WARBuilder(actionCache);
            
            case JavaBuildMode.ModularJAR:
                return new ModularJARBuilder(actionCache);
            
            case JavaBuildMode.NativeImage:
                return new NativeImageBuilder(actionCache);
            
            case JavaBuildMode.Compile:
                return new JARBuilder(actionCache); // Just compile, skip packaging
        }
    }
    
    /// Auto-detect best builder based on configuration
    static JavaBuilder createAuto(JavaConfig config, ActionCache actionCache = null)
    {
        return create(config.mode, config, actionCache);
    }
}

