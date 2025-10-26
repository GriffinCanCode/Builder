module languages.dotnet.fsharp.tooling.builders.base;

import languages.dotnet.fsharp.core.config;
import analysis.targets.types;
import config.schema.schema;

/// Build result structure
struct FSharpBuildResult
{
    /// Build succeeded
    bool success = false;
    
    /// Error message if failed
    string error;
    
    /// Output files produced
    string[] outputs;
    
    /// Hash of output
    string outputHash;
    
    /// Build time in milliseconds
    long buildTime = 0;
    
    /// Warnings generated
    string[] warnings;
}

/// Base interface for F# builders
interface FSharpBuilder
{
    /// Build sources with given configuration
    FSharpBuildResult build(string[] sources, FSharpConfig config, Target target, WorkspaceConfig workspaceConfig);
    
    /// Get build mode this builder handles
    FSharpBuildMode getMode();
    
    /// Check if builder is available
    bool isAvailable();
}

/// Factory for creating appropriate builder
class FSharpBuilderFactory
{
    /// Create builder for specified mode
    static FSharpBuilder create(FSharpBuildMode mode, FSharpConfig config)
    {
        import languages.dotnet.fsharp.tooling.builders.library;
        import languages.dotnet.fsharp.tooling.builders.executable;
        import languages.dotnet.fsharp.tooling.builders.script;
        import languages.dotnet.fsharp.tooling.builders.fable;
        import languages.dotnet.fsharp.tooling.builders.native;
        
        final switch (mode)
        {
            case FSharpBuildMode.Library:
                return new LibraryBuilder();
            case FSharpBuildMode.Executable:
                return new ExecutableBuilder();
            case FSharpBuildMode.Script:
                return new ScriptBuilder();
            case FSharpBuildMode.Fable:
                return new FableBuilder();
            case FSharpBuildMode.Wasm:
                return new FableBuilder(); // Fable also handles WASM
            case FSharpBuildMode.Native:
                return new NativeBuilder();
            case FSharpBuildMode.Compile:
                return new LibraryBuilder(); // Use library builder for compile-only
        }
    }
}

