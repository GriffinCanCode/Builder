module languages.jvm.scala.tooling.builders.base;

import languages.jvm.scala.core.config;
import config.schema.schema;
import analysis.targets.types;
import core.caching.actions.action : ActionCache;

/// Build result for Scala builds
struct ScalaBuildResult
{
    bool success = false;
    string error;
    string[] outputs;
    string outputHash;
    string[] warnings;
    string[] compilerMessages;
}

/// Base interface for Scala builders
interface ScalaBuilder
{
    /// Build Scala sources
    ScalaBuildResult build(
        const string[] sources,
        ScalaConfig config,
        const Target target,
        const WorkspaceConfig workspace
    );
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Check if this builder supports the given build mode
    bool supportsMode(ScalaBuildMode mode);
}

/// Factory for creating Scala builders
class ScalaBuilderFactory
{
    /// Create builder based on build mode with action cache
    static ScalaBuilder create(ScalaBuildMode mode, ScalaConfig config, ActionCache cache = null)
    {
        import languages.jvm.scala.tooling.builders.jar;
        import languages.jvm.scala.tooling.builders.assembly;
        import languages.jvm.scala.tooling.builders.native_;
        import languages.jvm.scala.tooling.builders.scalajs;
        import languages.jvm.scala.tooling.builders.scalanative;
        
        final switch (mode)
        {
            case ScalaBuildMode.JAR:
                return new JARBuilder(cache);
            
            case ScalaBuildMode.Assembly:
                return new AssemblyBuilder(cache);
            
            case ScalaBuildMode.NativeImage:
                return new NativeImageBuilder(cache);
            
            case ScalaBuildMode.ScalaJS:
                return new ScalaJSBuilder(cache);
            
            case ScalaBuildMode.ScalaNative:
                return new ScalaNativeBuilder(cache);
            
            case ScalaBuildMode.Compile:
                return new JARBuilder(cache); // Just compile, skip packaging
        }
    }
    
    /// Auto-detect best builder based on configuration and project
    static ScalaBuilder createAuto(ScalaConfig config, string projectDir, ActionCache cache = null)
    {
        import languages.jvm.scala.tooling.detection;
        
        // Check for special build modes first
        if (ScalaToolDetection.usesScalaJS(projectDir))
            return create(ScalaBuildMode.ScalaJS, config, cache);
        
        if (ScalaToolDetection.usesScalaNative(projectDir))
            return create(ScalaBuildMode.ScalaNative, config, cache);
        
        if (ScalaToolDetection.usesGraalNative(projectDir))
            return create(ScalaBuildMode.NativeImage, config, cache);
        
        if (ScalaToolDetection.usesSbtAssembly(projectDir))
            return create(ScalaBuildMode.Assembly, config, cache);
        
        // Default to JAR
        return create(config.mode, config, cache);
    }
}

