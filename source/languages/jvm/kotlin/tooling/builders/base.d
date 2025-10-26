module languages.jvm.kotlin.tooling.builders.base;

import languages.jvm.kotlin.core.config;
import config.schema.schema;
import analysis.targets.types;

/// Build result for Kotlin builds
struct KotlinBuildResult
{
    bool success = false;
    string error;
    string[] outputs;
    string outputHash;
    string[] warnings;
}

/// Base interface for Kotlin builders
interface KotlinBuilder
{
    /// Build Kotlin sources
    KotlinBuildResult build(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Check if this builder supports the given build mode
    bool supportsMode(KotlinBuildMode mode);
}

/// Factory for creating Kotlin builders
class KotlinBuilderFactory
{
    /// Create builder based on build mode
    static KotlinBuilder create(KotlinBuildMode mode, KotlinConfig config)
    {
        import languages.jvm.kotlin.tooling.builders.jar;
        import languages.jvm.kotlin.tooling.builders.fatjar;
        import languages.jvm.kotlin.tooling.builders.native_;
        import languages.jvm.kotlin.tooling.builders.js;
        import languages.jvm.kotlin.tooling.builders.multiplatform;
        import languages.jvm.kotlin.tooling.builders.android;
        
        final switch (mode)
        {
            case KotlinBuildMode.JAR:
                return new JARBuilder();
            
            case KotlinBuildMode.FatJAR:
                return new FatJARBuilder();
            
            case KotlinBuildMode.Native:
                return new NativeBuilder();
            
            case KotlinBuildMode.JS:
                return new JSBuilder();
            
            case KotlinBuildMode.Multiplatform:
                return new MultiplatformBuilder();
            
            case KotlinBuildMode.Android:
                return new AndroidBuilder();
            
            case KotlinBuildMode.Compile:
                return new JARBuilder(); // Just compile, skip full packaging
        }
    }
    
    /// Auto-detect best builder based on configuration
    static KotlinBuilder createAuto(KotlinConfig config)
    {
        return create(config.mode, config);
    }
}

