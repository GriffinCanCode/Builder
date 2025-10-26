module languages.dotnet.fsharp.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import analysis.targets.types;
import config.schema.schema;

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

/// Testing framework selection
enum FSharpTestFramework
{
    /// Auto-detect from dependencies
    Auto,
    /// Expecto (functional)
    Expecto,
    /// xUnit
    XUnit,
    /// NUnit
    NUnit,
    /// FsUnit
    FsUnit,
    /// Unquote
    Unquote,
    /// None - skip testing
    None
}

/// Code analyzer selection
enum FSharpAnalyzer
{
    /// Auto-detect best available
    Auto,
    /// FSharpLint
    FSharpLint,
    /// Compiler warnings only
    Compiler,
    /// Ionide (LSP-based)
    Ionide,
    /// None - skip analysis
    None
}

/// Code formatter selection
enum FSharpFormatter
{
    /// Auto-detect best available
    Auto,
    /// Fantomas (official)
    Fantomas,
    /// None - skip formatting
    None
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

/// Testing configuration
struct FSharpTestConfig
{
    /// Testing framework
    FSharpTestFramework framework = FSharpTestFramework.Auto;
    
    /// Run tests in parallel
    bool parallel = true;
    
    /// Fail fast on first error
    bool failFast = false;
    
    /// Test filter expression
    string filter;
    
    /// Test name patterns
    string[] testPatterns;
    
    /// Additional test flags
    string[] testFlags;
    
    /// Code coverage
    bool coverage = false;
    
    /// Coverage tool (coverlet, altcover)
    string coverageTool = "coverlet";
    
    /// Minimum coverage threshold
    int coverageThreshold = 0;
    
    /// Timeout per test (seconds)
    int timeout = 300;
}

/// Static analysis configuration
struct FSharpAnalysisConfig
{
    /// Enable static analysis
    bool enabled = false;
    
    /// Analyzer to use
    FSharpAnalyzer analyzer = FSharpAnalyzer.Auto;
    
    /// Fail build on warnings
    bool failOnWarnings = false;
    
    /// Fail build on errors
    bool failOnErrors = true;
    
    /// FSharpLint: Config file path
    string lintConfig = "fsharplint.json";
    
    /// FSharpLint: Ignore files pattern
    string[] ignoreFiles;
    
    /// Compiler warning level
    int warningLevel = 4;
    
    /// Warnings as errors
    bool warningsAsErrors = false;
    
    /// Specific warnings to treat as errors
    int[] warningsAsErrorsList;
    
    /// Disable specific warnings
    int[] disableWarnings;
}

/// Formatter configuration
struct FSharpFormatterConfig
{
    /// Enable formatting
    bool enabled = false;
    
    /// Formatter to use
    FSharpFormatter formatter = FSharpFormatter.Auto;
    
    /// Auto-format before build
    bool autoFormat = false;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// Configuration file path
    string configFile = ".editorconfig";
    
    /// Max line length
    int maxLineLength = 120;
    
    /// Indent size
    int indentSize = 4;
    
    /// Fantomas: Insert final newline
    bool insertFinalNewline = true;
    
    /// Fantomas: Fsharp style
    bool fsharpStyle = true;
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

/// Complete F# configuration
struct FSharpConfig
{
    /// Build mode
    FSharpBuildMode mode = FSharpBuildMode.Library;
    
    /// Build tool
    FSharpBuildTool buildTool = FSharpBuildTool.Auto;
    
    /// Package manager
    FSharpPackageManager packageManager = FSharpPackageManager.Auto;
    
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
    
    /// Paket configuration
    PaketConfig paket;
    
    /// NuGet configuration
    NuGetConfig nuget;
    
    /// Testing configuration
    FSharpTestConfig test;
    
    /// Static analysis
    FSharpAnalysisConfig analysis;
    
    /// Code formatting
    FSharpFormatterConfig formatter;
    
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

/// Parse F# configuration from target
FSharpConfig parseFSharpConfig(Target target)
{
    FSharpConfig config;
    
    // Parse from langConfig JSON
    if ("fsharp" in target.langConfig)
    {
        try
        {
            JSONValue json = parseJSON(target.langConfig["fsharp"]);
            config = parseFSharpConfigFromJSON(json);
        }
        catch (Exception e)
        {
            // Use defaults
        }
    }
    
    return config;
}

/// Parse F# configuration from JSON
FSharpConfig parseFSharpConfigFromJSON(JSONValue json)
{
    FSharpConfig config;
    
    // Build mode
    if ("mode" in json)
        config.mode = json["mode"].str.toFSharpBuildMode();
    
    // Build tool
    if ("buildTool" in json)
        config.buildTool = json["buildTool"].str.toFSharpBuildTool();
    
    // Package manager
    if ("packageManager" in json)
        config.packageManager = json["packageManager"].str.toFSharpPackageManager();
    
    // Compiler
    if ("compiler" in json)
        config.compiler = json["compiler"].str.toFSharpCompiler();
    
    // Platform
    if ("platform" in json)
        config.platform = json["platform"].str.toFSharpPlatform();
    
    // Versions
    if ("languageVersion" in json)
        config.languageVersion = FSharpVersion.parse(json["languageVersion"].str);
    
    // Dotnet
    if ("dotnet" in json)
        config.dotnet = parseDotnetConfig(json["dotnet"]);
    
    // FAKE
    if ("fake" in json)
        config.fake = parseFAKEConfig(json["fake"]);
    
    // Paket
    if ("paket" in json)
        config.paket = parsePaketConfig(json["paket"]);
    
    // NuGet
    if ("nuget" in json)
        config.nuget = parseNuGetConfig(json["nuget"]);
    
    // Testing
    if ("test" in json)
        config.test = parseFSharpTestConfig(json["test"]);
    
    // Analysis
    if ("analysis" in json)
        config.analysis = parseFSharpAnalysisConfig(json["analysis"]);
    
    // Formatter
    if ("formatter" in json)
        config.formatter = parseFSharpFormatterConfig(json["formatter"]);
    
    // FSI
    if ("fsi" in json)
        config.fsi = parseFSIConfig(json["fsi"]);
    
    // Fable
    if ("fable" in json)
        config.fable = parseFableConfig(json["fable"]);
    
    // Native
    if ("native" in json)
        config.native = parseNativeAOTConfig(json["native"]);
    
    // Packaging
    if ("packaging" in json)
        config.packaging = parseFSharpPackagingConfig(json["packaging"]);
    
    // Simple fields
    if ("compilerFlags" in json)
        config.compilerFlags = json["compilerFlags"].array.map!(e => e.str).array;
    if ("defines" in json)
        config.defines = json["defines"].array.map!(e => e.str).array;
    if ("checked" in json)
        config.checked = json["checked"].type == JSONType.true_;
    if ("debug" in json)
        config.debug_ = json["debug"].type == JSONType.true_;
    if ("optimize" in json)
        config.optimize = json["optimize"].type == JSONType.true_;
    if ("tailcalls" in json)
        config.tailcalls = json["tailcalls"].type == JSONType.true_;
    if ("crossoptimize" in json)
        config.crossoptimize = json["crossoptimize"].type == JSONType.true_;
    if ("deterministic" in json)
        config.deterministic = json["deterministic"].type == JSONType.true_;
    if ("generateDocs" in json)
        config.generateDocs = json["generateDocs"].type == JSONType.true_;
    if ("xmlDoc" in json)
        config.xmlDoc = json["xmlDoc"].str;
    if ("verbose" in json)
        config.verbose = json["verbose"].type == JSONType.true_;
    
    return config;
}

// Helper parsing functions
private DotnetConfig parseDotnetConfig(JSONValue json)
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

private FAKEConfig parseFAKEConfig(JSONValue json)
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

private PaketConfig parsePaketConfig(JSONValue json)
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

private NuGetConfig parseNuGetConfig(JSONValue json)
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

private FSharpTestConfig parseFSharpTestConfig(JSONValue json)
{
    FSharpTestConfig config;
    
    if ("framework" in json)
        config.framework = json["framework"].str.toFSharpTestFramework();
    if ("parallel" in json)
        config.parallel = json["parallel"].type == JSONType.true_;
    if ("failFast" in json)
        config.failFast = json["failFast"].type == JSONType.true_;
    if ("filter" in json)
        config.filter = json["filter"].str;
    if ("testPatterns" in json)
        config.testPatterns = json["testPatterns"].array.map!(e => e.str).array;
    if ("testFlags" in json)
        config.testFlags = json["testFlags"].array.map!(e => e.str).array;
    if ("coverage" in json)
        config.coverage = json["coverage"].type == JSONType.true_;
    if ("coverageTool" in json)
        config.coverageTool = json["coverageTool"].str;
    if ("coverageThreshold" in json)
        config.coverageThreshold = cast(int)json["coverageThreshold"].integer;
    if ("timeout" in json)
        config.timeout = cast(int)json["timeout"].integer;
    
    return config;
}

private FSharpAnalysisConfig parseFSharpAnalysisConfig(JSONValue json)
{
    FSharpAnalysisConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("analyzer" in json)
        config.analyzer = json["analyzer"].str.toFSharpAnalyzer();
    if ("failOnWarnings" in json)
        config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    if ("failOnErrors" in json)
        config.failOnErrors = json["failOnErrors"].type == JSONType.true_;
    if ("lintConfig" in json)
        config.lintConfig = json["lintConfig"].str;
    if ("ignoreFiles" in json)
        config.ignoreFiles = json["ignoreFiles"].array.map!(e => e.str).array;
    if ("warningLevel" in json)
        config.warningLevel = cast(int)json["warningLevel"].integer;
    if ("warningsAsErrors" in json)
        config.warningsAsErrors = json["warningsAsErrors"].type == JSONType.true_;
    if ("warningsAsErrorsList" in json)
        config.warningsAsErrorsList = json["warningsAsErrorsList"].array.map!(e => cast(int)e.integer).array;
    if ("disableWarnings" in json)
        config.disableWarnings = json["disableWarnings"].array.map!(e => cast(int)e.integer).array;
    
    return config;
}

private FSharpFormatterConfig parseFSharpFormatterConfig(JSONValue json)
{
    FSharpFormatterConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("formatter" in json)
        config.formatter = json["formatter"].str.toFSharpFormatter();
    if ("autoFormat" in json)
        config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("checkOnly" in json)
        config.checkOnly = json["checkOnly"].str == "true";
    if ("configFile" in json)
        config.configFile = json["configFile"].str;
    if ("maxLineLength" in json)
        config.maxLineLength = cast(int)json["maxLineLength"].integer;
    if ("indentSize" in json)
        config.indentSize = cast(int)json["indentSize"].integer;
    if ("insertFinalNewline" in json)
        config.insertFinalNewline = json["insertFinalNewline"].type == JSONType.true_;
    if ("fsharpStyle" in json)
        config.fsharpStyle = json["fsharpStyle"].type == JSONType.true_;
    
    return config;
}

private FSIConfig parseFSIConfig(JSONValue json)
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

private FableConfig parseFableConfig(JSONValue json)
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

private NativeAOTConfig parseNativeAOTConfig(JSONValue json)
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

private FSharpPackagingConfig parseFSharpPackagingConfig(JSONValue json)
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

// String to enum converters
private FSharpBuildMode toFSharpBuildMode(string s)
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

private FSharpBuildTool toFSharpBuildTool(string s)
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

private FSharpPackageManager toFSharpPackageManager(string s)
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

private FSharpCompiler toFSharpCompiler(string s)
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

private FSharpPlatform toFSharpPlatform(string s)
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

private FSharpTestFramework toFSharpTestFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpTestFramework.Auto;
        case "expecto": return FSharpTestFramework.Expecto;
        case "xunit": return FSharpTestFramework.XUnit;
        case "nunit": return FSharpTestFramework.NUnit;
        case "fsunit": return FSharpTestFramework.FsUnit;
        case "unquote": return FSharpTestFramework.Unquote;
        case "none": return FSharpTestFramework.None;
        default: return FSharpTestFramework.Auto;
    }
}

private FSharpAnalyzer toFSharpAnalyzer(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpAnalyzer.Auto;
        case "fsharplint": case "lint": return FSharpAnalyzer.FSharpLint;
        case "compiler": return FSharpAnalyzer.Compiler;
        case "ionide": return FSharpAnalyzer.Ionide;
        case "none": return FSharpAnalyzer.None;
        default: return FSharpAnalyzer.Auto;
    }
}

private FSharpFormatter toFSharpFormatter(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpFormatter.Auto;
        case "fantomas": return FSharpFormatter.Fantomas;
        case "none": return FSharpFormatter.None;
        default: return FSharpFormatter.Auto;
    }
}

