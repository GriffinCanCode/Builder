module languages.dotnet.fsharp.config.build;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// F# build modes
enum FSharpBuildMode
{
    /// Standard DLL library
    Library,
    /// Executable
    Executable,
    /// F# script (.fsx) execution
    Script,
    /// Fable compilation to JavaScript
    Fable,
    /// WebAssembly via Fable
    Wasm,
    /// Native executable via .NET Native AOT
    Native,
    /// Compilation only without packaging
    Compile
}

/// Build tool selection
enum FSharpBuildTool
{
    /// Auto-detect from project structure
    Auto,
    /// dotnet CLI (recommended)
    Dotnet,
    /// FAKE build system
    FAKE,
    /// Direct fsc compiler
    Direct,
    /// None - manual control
    None
}

/// F# compiler selection
enum FSharpCompiler
{
    /// Auto-detect best available
    Auto,
    /// F# compiler (fsc)
    FSC,
    /// F# Interactive (fsi)
    FSI,
    /// Fable compiler (F# to JS)
    Fable
}

/// F# platform target
enum FSharpPlatform
{
    /// .NET CLR
    DotNet,
    /// JavaScript via Fable
    JavaScript,
    /// TypeScript via Fable
    TypeScript,
    /// WebAssembly
    Wasm,
    /// Native AOT
    Native
}

/// F# language version
struct FSharpVersion
{
    /// Major version (4, 5, 6, 7, 8, etc.)
    int major = 8;
    
    /// Minor version
    int minor = 0;
    
    /// Patch version
    int patch = 0;
    
    /// Parse from string like "8.0", "7.0.0"
    static FSharpVersion parse(string ver)
    {
        FSharpVersion v;
        
        if (ver.empty)
            return v;
        
        auto parts = ver.split(".");
        if (parts.length >= 1)
            v.major = parts[0].to!int;
        if (parts.length >= 2)
            v.minor = parts[1].to!int;
        if (parts.length >= 3)
            v.patch = parts[2].to!int;
        
        return v;
    }
    
    /// Convert to string
    string toString() const
    {
        import std.format : format;
        
        if (patch == 0 && minor == 0)
            return format("%d.0", major);
        if (patch == 0)
            return format("%d.%d", major, minor);
        return format("%d.%d.%d", major, minor, patch);
    }
    
    /// Check if version supports anonymous records (4.6+)
    bool supportsAnonymousRecords() const
    {
        return major >= 5 || (major == 4 && minor >= 6);
    }
    
    /// Check if version supports computation expressions (all)
    bool supportsComputationExpressions() const
    {
        return true;
    }
    
    /// Check if version supports applicative CEs (5.0+)
    bool supportsApplicativeComputationExpressions() const
    {
        return major >= 5;
    }
    
    /// Check if version supports nameof (5.0+)
    bool supportsNameof() const
    {
        return major >= 5;
    }
    
    /// Check if version supports open type declarations (5.0+)
    bool supportsOpenTypeDeclarations() const
    {
        return major >= 5;
    }
    
    /// Check if version supports task expressions (6.0+)
    bool supportsTaskExpressions() const
    {
        return major >= 6;
    }
    
    /// Check if version supports string interpolation (5.0+)
    bool supportsStringInterpolation() const
    {
        return major >= 5;
    }
    
    /// Check if version supports as patterns (7.0+)
    bool supportsAsPatterns() const
    {
        return major >= 7;
    }
    
    /// Check if version supports FromTheEnd slicing (8.0+)
    bool supportsFromTheEndSlicing() const
    {
        return major >= 8;
    }
}

/// .NET target framework
struct DotNetFramework
{
    /// Framework identifier (net8.0, net7.0, net6.0, netstandard2.1, etc.)
    string identifier = "net8.0";
    
    /// Parse from string
    static DotNetFramework parse(string fw)
    {
        DotNetFramework framework;
        framework.identifier = fw;
        return framework;
    }
    
    /// Convert to string
    string toString() const
    {
        return identifier;
    }
    
    /// Check if .NET Core/5+
    bool isDotNetCore() const
    {
        return identifier.startsWith("net") && !identifier.startsWith("netstandard") && !identifier.startsWith("netframework");
    }
    
    /// Check if .NET Standard
    bool isDotNetStandard() const
    {
        return identifier.startsWith("netstandard");
    }
    
    /// Check if .NET Framework
    bool isDotNetFramework() const
    {
        return identifier.startsWith("netframework") || identifier.startsWith("net4");
    }
}

/// Dotnet configuration
struct DotnetConfig
{
    /// Target framework
    DotNetFramework framework;
    
    /// Configuration (Debug, Release)
    string configuration = "Release";
    
    /// Runtime identifier (linux-x64, win-x64, osx-arm64)
    string runtime;
    
    /// Self-contained deployment
    bool selfContained = false;
    
    /// Single file publish
    bool singleFile = false;
    
    /// Enable ReadyToRun
    bool readyToRun = false;
    
    /// Trim unused assemblies
    bool trimmed = false;
    
    /// Output directory
    string outputDir;
    
    /// Verbosity level
    string verbosity = "minimal";
    
    /// No restore during build
    bool noRestore = false;
    
    /// No dependencies
    bool noDependencies = false;
    
    /// Force rebuild
    bool force = false;
    
    /// Enable NuGet restore
    bool restore = true;
}

/// FAKE build system configuration
struct FAKEConfig
{
    /// FAKE script file
    string scriptFile = "build.fsx";
    
    /// Target to execute
    string target = "Build";
    
    /// Environment variables
    string[string] environment;
    
    /// Script arguments
    string[] arguments;
    
    /// Enable verbose output
    bool verbose = false;
    
    /// Single target mode
    bool singleTarget = false;
    
    /// Parallel execution
    bool parallel = true;
}

/// Interactive (FSI) configuration
struct FSIConfig
{
    /// Enable F# Interactive
    bool enabled = false;
    
    /// FSI arguments
    string[] arguments;
    
    /// Load scripts before execution
    string[] loadScripts;
    
    /// References to load
    string[] references;
    
    /// Enable readline support
    bool readline = true;
    
    /// Enable GUI support
    bool gui = false;
    
    /// Define symbols
    string[] defines;
    
    /// Optimization level
    bool optimize = false;
    
    /// Tail calls
    bool tailcalls = true;
}

/// Fable configuration
struct FableConfig
{
    /// Enable Fable
    bool enabled = false;
    
    /// Output directory
    string outDir = "js";
    
    /// Module system (commonjs, es6, amd)
    string moduleSystem = "es6";
    
    /// Source maps
    bool sourceMaps = true;
    
    /// TypeScript output
    bool typescript = false;
    
    /// Language (JavaScript or TypeScript)
    string language = "javascript";
    
    /// Fable library mode
    bool libraryMode = false;
    
    /// Watch mode
    bool watch = false;
    
    /// Run after compilation
    string runAfter;
    
    /// Optimization
    bool optimize = true;
    
    /// Define constants
    string[] defines;
}

/// Native AOT configuration
struct NativeAOTConfig
{
    /// Enable native compilation
    bool enabled = false;
    
    /// Optimization level
    string optimization = "speed";
    
    /// Include PDB
    bool includeSymbols = false;
    
    /// Invariant globalization
    bool invariantGlobalization = false;
    
    /// IL strip
    bool ilStrip = true;
    
    /// Stack trace support
    string stackTraceSupport = "true";
}

/// Packaging configuration
struct FSharpPackagingConfig
{
    /// Package ID
    string packageId;
    
    /// Package version
    string version_;
    
    /// Authors
    string[] authors;
    
    /// Description
    string description;
    
    /// License
    string license;
    
    /// Project URL
    string projectUrl;
    
    /// Icon
    string icon;
    
    /// Tags
    string[] tags;
    
    /// Repository URL
    string repositoryUrl;
    
    /// Repository type
    string repositoryType = "git";
    
    /// Release notes
    string releaseNotes;
    
    /// Include symbols
    bool includeSymbols = false;
    
    /// Include source
    bool includeSource = false;
}

/// F# Build Configuration - all build-related settings
struct FSharpBuildConfig
{
    /// Build mode
    FSharpBuildMode mode = FSharpBuildMode.Library;
    
    /// Build tool
    FSharpBuildTool buildTool = FSharpBuildTool.Auto;
    
    /// Compiler selection
    FSharpCompiler compiler = FSharpCompiler.Auto;
    
    /// Target platform
    FSharpPlatform platform = FSharpPlatform.DotNet;
    
    /// F# language version
    FSharpVersion languageVersion;
    
    /// Dotnet configuration
    DotnetConfig dotnet;
    
    /// FAKE configuration
    FAKEConfig fake;
    
    /// F# Interactive
    FSIConfig fsi;
    
    /// Fable (JS/TS compilation)
    FableConfig fable;
    
    /// Native AOT
    NativeAOTConfig native;
    
    /// Packaging
    FSharpPackagingConfig packaging;
    
    /// Compiler flags
    string[] compilerFlags;
    
    /// Define constants
    string[] defines;
    
    /// Checked arithmetic
    bool checked = false;
    
    /// Debug symbols
    bool debug_ = false;
    
    /// Optimize code
    bool optimize = true;
    
    /// Tail calls
    bool tailcalls = true;
    
    /// Cross-optimize
    bool crossoptimize = true;
    
    /// Deterministic builds
    bool deterministic = true;
    
    /// Enable documentation generation
    bool generateDocs = false;
    
    /// XML documentation output
    string xmlDoc;
    
    /// Enable verbose output
    bool verbose = false;
}

/// Parse DotnetConfig from JSON
DotnetConfig parseDotnetConfig(JSONValue json)
{
    DotnetConfig config;
    
    if ("framework" in json)
        config.framework = DotNetFramework.parse(json["framework"].str);
    if ("configuration" in json)
        config.configuration = json["configuration"].str;
    if ("runtime" in json)
        config.runtime = json["runtime"].str;
    if ("selfContained" in json)
        config.selfContained = json["selfContained"].type == JSONType.true_;
    if ("singleFile" in json)
        config.singleFile = json["singleFile"].type == JSONType.true_;
    if ("readyToRun" in json)
        config.readyToRun = json["readyToRun"].type == JSONType.true_;
    if ("trimmed" in json)
        config.trimmed = json["trimmed"].type == JSONType.true_;
    if ("outputDir" in json)
        config.outputDir = json["outputDir"].str;
    if ("verbosity" in json)
        config.verbosity = json["verbosity"].str;
    if ("noRestore" in json)
        config.noRestore = json["noRestore"].type == JSONType.true_;
    if ("noDependencies" in json)
        config.noDependencies = json["noDependencies"].type == JSONType.true_;
    if ("force" in json)
        config.force = json["force"].type == JSONType.true_;
    if ("restore" in json)
        config.restore = json["restore"].type == JSONType.true_;
    
    return config;
}

/// Parse FAKEConfig from JSON
FAKEConfig parseFAKEConfig(JSONValue json)
{
    FAKEConfig config;
    
    if ("scriptFile" in json)
        config.scriptFile = json["scriptFile"].str;
    if ("target" in json)
        config.target = json["target"].str;
    if ("arguments" in json)
        config.arguments = json["arguments"].array.map!(e => e.str).array;
    if ("verbose" in json)
        config.verbose = json["verbose"].type == JSONType.true_;
    if ("singleTarget" in json)
        config.singleTarget = json["singleTarget"].type == JSONType.true_;
    if ("parallel" in json)
        config.parallel = json["parallel"].type == JSONType.true_;
    
    return config;
}

/// Parse FSIConfig from JSON
FSIConfig parseFSIConfig(JSONValue json)
{
    FSIConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("arguments" in json)
        config.arguments = json["arguments"].array.map!(e => e.str).array;
    if ("loadScripts" in json)
        config.loadScripts = json["loadScripts"].array.map!(e => e.str).array;
    if ("references" in json)
        config.references = json["references"].array.map!(e => e.str).array;
    if ("readline" in json)
        config.readline = json["readline"].type == JSONType.true_;
    if ("gui" in json)
        config.gui = json["gui"].type == JSONType.true_;
    if ("defines" in json)
        config.defines = json["defines"].array.map!(e => e.str).array;
    if ("optimize" in json)
        config.optimize = json["optimize"].type == JSONType.true_;
    if ("tailcalls" in json)
        config.tailcalls = json["tailcalls"].type == JSONType.true_;
    
    return config;
}

/// Parse FableConfig from JSON
FableConfig parseFableConfig(JSONValue json)
{
    FableConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("outDir" in json)
        config.outDir = json["outDir"].str;
    if ("moduleSystem" in json)
        config.moduleSystem = json["moduleSystem"].str;
    if ("sourceMaps" in json)
        config.sourceMaps = json["sourceMaps"].type == JSONType.true_;
    if ("typescript" in json)
        config.typescript = json["typescript"].type == JSONType.true_;
    if ("language" in json)
        config.language = json["language"].str;
    if ("libraryMode" in json)
        config.libraryMode = json["libraryMode"].type == JSONType.true_;
    if ("watch" in json)
        config.watch = json["watch"].type == JSONType.true_;
    if ("runAfter" in json)
        config.runAfter = json["runAfter"].str;
    if ("optimize" in json)
        config.optimize = json["optimize"].type == JSONType.true_;
    if ("defines" in json)
        config.defines = json["defines"].array.map!(e => e.str).array;
    
    return config;
}

/// Parse NativeAOTConfig from JSON
NativeAOTConfig parseNativeAOTConfig(JSONValue json)
{
    NativeAOTConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("optimization" in json)
        config.optimization = json["optimization"].str;
    if ("includeSymbols" in json)
        config.includeSymbols = json["includeSymbols"].type == JSONType.true_;
    if ("invariantGlobalization" in json)
        config.invariantGlobalization = json["invariantGlobalization"].type == JSONType.true_;
    if ("ilStrip" in json)
        config.ilStrip = json["ilStrip"].type == JSONType.true_;
    if ("stackTraceSupport" in json)
        config.stackTraceSupport = json["stackTraceSupport"].str;
    
    return config;
}

/// Parse FSharpPackagingConfig from JSON
FSharpPackagingConfig parseFSharpPackagingConfig(JSONValue json)
{
    FSharpPackagingConfig config;
    
    if ("packageId" in json)
        config.packageId = json["packageId"].str;
    if ("version" in json)
        config.version_ = json["version"].str;
    if ("authors" in json)
        config.authors = json["authors"].array.map!(e => e.str).array;
    if ("description" in json)
        config.description = json["description"].str;
    if ("license" in json)
        config.license = json["license"].str;
    if ("projectUrl" in json)
        config.projectUrl = json["projectUrl"].str;
    if ("icon" in json)
        config.icon = json["icon"].str;
    if ("tags" in json)
        config.tags = json["tags"].array.map!(e => e.str).array;
    if ("repositoryUrl" in json)
        config.repositoryUrl = json["repositoryUrl"].str;
    if ("repositoryType" in json)
        config.repositoryType = json["repositoryType"].str;
    if ("releaseNotes" in json)
        config.releaseNotes = json["releaseNotes"].str;
    if ("includeSymbols" in json)
        config.includeSymbols = json["includeSymbols"].type == JSONType.true_;
    if ("includeSource" in json)
        config.includeSource = json["includeSource"].type == JSONType.true_;
    
    return config;
}

/// String to enum converters
FSharpBuildMode toFSharpBuildMode(string s)
{
    switch (s.toLower)
    {
        case "library": case "lib": case "dll": return FSharpBuildMode.Library;
        case "executable": case "exe": return FSharpBuildMode.Executable;
        case "script": case "fsx": return FSharpBuildMode.Script;
        case "fable": case "js": return FSharpBuildMode.Fable;
        case "wasm": case "webassembly": return FSharpBuildMode.Wasm;
        case "native": case "aot": return FSharpBuildMode.Native;
        case "compile": return FSharpBuildMode.Compile;
        default: return FSharpBuildMode.Library;
    }
}

FSharpBuildTool toFSharpBuildTool(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpBuildTool.Auto;
        case "dotnet": return FSharpBuildTool.Dotnet;
        case "fake": return FSharpBuildTool.FAKE;
        case "direct": case "fsc": return FSharpBuildTool.Direct;
        case "none": return FSharpBuildTool.None;
        default: return FSharpBuildTool.Auto;
    }
}

FSharpCompiler toFSharpCompiler(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpCompiler.Auto;
        case "fsc": return FSharpCompiler.FSC;
        case "fsi": return FSharpCompiler.FSI;
        case "fable": return FSharpCompiler.Fable;
        default: return FSharpCompiler.Auto;
    }
}

FSharpPlatform toFSharpPlatform(string s)
{
    switch (s.toLower)
    {
        case "dotnet": case "clr": case "net": return FSharpPlatform.DotNet;
        case "javascript": case "js": return FSharpPlatform.JavaScript;
        case "typescript": case "ts": return FSharpPlatform.TypeScript;
        case "wasm": case "webassembly": return FSharpPlatform.Wasm;
        case "native": case "aot": return FSharpPlatform.Native;
        default: return FSharpPlatform.DotNet;
    }
}

