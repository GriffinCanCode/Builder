module languages.dotnet.csharp.config;

/// C# Configuration Modules
/// 
/// Grouped configuration pattern for maintainability.
/// Each module handles one aspect of C# configuration.

public import languages.dotnet.csharp.config.build;
public import languages.dotnet.csharp.config.dependency;
public import languages.dotnet.csharp.config.quality;
public import languages.dotnet.csharp.config.test;

/// Unified C# configuration
/// Composes specialized config groups
struct CSharpConfig
{
    CSharpBuildConfig build;
    CSharpDependencyConfig dependencies;
    CSharpQualityConfig quality;
    CSharpTestConfig testing;
    
    // Publishing options (specific to C#/.NET)
    bool singleFile = false;
    bool selfContained = false;
    bool readyToRun = false;
    bool trimmed = false;
    bool nativeAOT = false;
    
    // Convenience accessors for common patterns
    ref CSharpBuildMode mode() return { return build.mode; }
    ref CSharpBuildTool buildTool() return { return build.buildTool; }
    ref DotNetFramework framework() return { return build.framework; }
    ref CSharpProjectType projectType() return { return build.projectType; }
    ref NuGetConfig nuget() return { return dependencies.nuget; }
    ref MSBuildConfig msbuild() return { return build.msbuild; }
}

