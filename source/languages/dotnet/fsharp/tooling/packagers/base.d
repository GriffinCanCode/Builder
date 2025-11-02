module languages.dotnet.fsharp.tooling.packagers.base;

import languages.dotnet.fsharp.config;

/// Package result structure
struct PackageResult
{
    /// Package succeeded
    bool success = false;
    
    /// Error message if failed
    string error;
    
    /// Package file produced
    string packageFile;
    
    /// Package hash
    string packageHash;
}

/// Base interface for F# packagers
interface FSharpPackager
{
    /// Create package
    PackageResult pack(string projectFile, FSharpPackagingConfig config);
    
    /// Get packager name
    string getName();
    
    /// Check if packager is available
    bool isAvailable();
}

