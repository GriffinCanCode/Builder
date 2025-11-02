module languages.jvm.kotlin.config;

/// Kotlin Configuration Modules
/// 
/// Grouped configuration pattern for maintainability.
/// Each module handles one aspect of Kotlin configuration.

public import languages.jvm.kotlin.config.build;
public import languages.jvm.kotlin.config.dependency;
public import languages.jvm.kotlin.config.quality;
public import languages.jvm.kotlin.config.test;

/// Unified Kotlin configuration
/// Composes specialized config groups
struct KotlinConfig
{
    KotlinBuildConfig build;
    KotlinDependencyConfig dependencies;
    KotlinQualityConfig quality;
    KotlinTestConfig testing;
    
    // Convenience accessors for common patterns
    ref KotlinBuildMode mode() return { return build.mode; }
    ref KotlinBuildTool buildTool() return { return build.buildTool; }
    ref KotlinPlatform platform() return { return build.platform; }
    ref GradleConfig gradle() return { return dependencies.gradle; }
    ref MavenConfig maven() return { return dependencies.maven; }
}

