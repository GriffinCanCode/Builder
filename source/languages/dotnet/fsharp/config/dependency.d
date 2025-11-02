module languages.dotnet.fsharp.config.dependency;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Package manager selection
enum FSharpPackageManager
{
    /// Auto-detect from project
    Auto,
    /// NuGet (standard)
    NuGet,
    /// Paket (deterministic)
    Paket,
    /// None
    None
}

/// Paket configuration
struct PaketConfig
{
    /// Enable Paket
    bool enabled = false;
    
    /// Paket dependencies file
    string dependenciesFile = "paket.dependencies";
    
    /// Paket lock file
    string lockFile = "paket.lock";
    
    /// Auto-restore packages
    bool autoRestore = true;
    
    /// Generate load scripts
    bool generateLoadScripts = true;
    
    /// Storage mode (symlink, copy, none)
    string storageMode = "symlink";
}

/// NuGet configuration
struct NuGetConfig
{
    /// NuGet config file
    string configFile;
    
    /// Package sources
    string[] sources;
    
    /// Fallback sources
    string[] fallbackSources;
    
    /// Enable package restore
    bool enableRestore = true;
    
    /// Use lock file
    bool useLockFile = false;
    
    /// Locked mode
    bool lockedMode = false;
}

/// F# Dependency Configuration
struct FSharpDependencyConfig
{
    /// Package manager
    FSharpPackageManager packageManager = FSharpPackageManager.Auto;
    
    /// Paket configuration
    PaketConfig paket;
    
    /// NuGet configuration
    NuGetConfig nuget;
}

/// Parse PaketConfig from JSON
PaketConfig parsePaketConfig(JSONValue json)
{
    PaketConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("dependenciesFile" in json)
        config.dependenciesFile = json["dependenciesFile"].str;
    if ("lockFile" in json)
        config.lockFile = json["lockFile"].str;
    if ("autoRestore" in json)
        config.autoRestore = json["autoRestore"].type == JSONType.true_;
    if ("generateLoadScripts" in json)
        config.generateLoadScripts = json["generateLoadScripts"].type == JSONType.true_;
    if ("storageMode" in json)
        config.storageMode = json["storageMode"].str;
    
    return config;
}

/// Parse NuGetConfig from JSON
NuGetConfig parseNuGetConfig(JSONValue json)
{
    NuGetConfig config;
    
    if ("configFile" in json)
        config.configFile = json["configFile"].str;
    if ("sources" in json)
        config.sources = json["sources"].array.map!(e => e.str).array;
    if ("fallbackSources" in json)
        config.fallbackSources = json["fallbackSources"].array.map!(e => e.str).array;
    if ("enableRestore" in json)
        config.enableRestore = json["enableRestore"].type == JSONType.true_;
    if ("useLockFile" in json)
        config.useLockFile = json["useLockFile"].type == JSONType.true_;
    if ("lockedMode" in json)
        config.lockedMode = json["lockedMode"].type == JSONType.true_;
    
    return config;
}

/// String to enum converter
FSharpPackageManager toFSharpPackageManager(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpPackageManager.Auto;
        case "nuget": return FSharpPackageManager.NuGet;
        case "paket": return FSharpPackageManager.Paket;
        case "none": return FSharpPackageManager.None;
        default: return FSharpPackageManager.Auto;
    }
}

