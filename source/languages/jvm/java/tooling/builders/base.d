module languages.jvm.java.tooling.builders.base;

import languages.jvm.java.core.config;
import config.schema.schema;
import analysis.targets.types;

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
    /// Create builder based on build mode
    static JavaBuilder create(JavaBuildMode mode, JavaConfig config)
    {
        import languages.jvm.java.tooling.builders.jar;
        import languages.jvm.java.tooling.builders.fatjar;
        import languages.jvm.java.tooling.builders.war;
        import languages.jvm.java.tooling.builders.modular;
        import languages.jvm.java.tooling.builders.native_;
        
        final switch (mode)
        {
            case JavaBuildMode.JAR:
                return new JARBuilder();
            
            case JavaBuildMode.FatJAR:
                return new FatJARBuilder();
            
            case JavaBuildMode.WAR:
            case JavaBuildMode.EAR:
            case JavaBuildMode.RAR:
                return new WARBuilder();
            
            case JavaBuildMode.ModularJAR:
                return new ModularJARBuilder();
            
            case JavaBuildMode.NativeImage:
                return new NativeImageBuilder();
            
            case JavaBuildMode.Compile:
                return new JARBuilder(); // Just compile, skip packaging
        }
    }
    
    /// Auto-detect best builder based on configuration
    static JavaBuilder createAuto(JavaConfig config)
    {
        return create(config.mode, config);
    }
}

