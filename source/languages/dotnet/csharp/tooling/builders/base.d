module languages.dotnet.csharp.tooling.builders.base;

import std.string;
import languages.dotnet.csharp.core.config;
import analysis.targets.spec;
import config.schema.schema;

/// Build result structure
struct BuildResult
{
    /// Build succeeded
    bool success;
    
    /// Output files generated
    string[] outputs;
    
    /// Output hash for caching
    string outputHash;
    
    /// Error message if failed
    string error;
}

/// Base interface for C# builders
interface CSharpBuilder
{
    /// Build the project
    BuildResult build(
        string[] sources,
        CSharpConfig config,
        Target target,
        WorkspaceConfig workspaceConfig
    );
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name();
}

/// Builder factory
struct CSharpBuilderFactory
{
    /// Create appropriate builder for build mode
    static CSharpBuilder create(CSharpBuildMode mode, CSharpConfig config)
    {
        import languages.dotnet.csharp.tooling.builders.standard;
        import languages.dotnet.csharp.tooling.builders.publish;
        import languages.dotnet.csharp.tooling.builders.aot;
        
        final switch (mode)
        {
            case CSharpBuildMode.Standard:
            case CSharpBuildMode.Compile:
                return new StandardBuilder();
            
            case CSharpBuildMode.SingleFile:
            case CSharpBuildMode.ReadyToRun:
            case CSharpBuildMode.Trimmed:
                return new PublishBuilder();
            
            case CSharpBuildMode.NativeAOT:
                return new AOTBuilder();
            
            case CSharpBuildMode.NuGet:
                return new StandardBuilder(); // NuGet packing is handled separately
        }
    }
}

