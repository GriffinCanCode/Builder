module languages.dotnet.csharp.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import infrastructure.analysis.targets.types;
import infrastructure.config.schema.schema;
import languages.dotnet.csharp.config.test : CSharpTestFramework;

/// C# build modes
enum CSharpBuildMode
{
    /// Standard DLL or EXE
    Standard,
    /// Single-file publish
    SingleFile,
    /// Ready-to-run (R2R) with ahead-of-time compilation
    ReadyToRun,
    /// Native AOT compilation (.NET 7+)
    NativeAOT,
    /// Trimmed publish (IL trimming)
    Trimmed,
    /// NuGet package (.nupkg)
    NuGet,
    /// Compilation only, no publishing
    Compile
}

/// Build tool selection
enum CSharpBuildTool
{
    /// Auto-detect from project structure
    Auto,
    /// dotnet CLI (recommended)
    DotNet,
    /// MSBuild directly
    MSBuild,
    /// Direct csc compiler (legacy)
    Direct,
    /// No build tool (legacy)
    CSC,
    /// None - manual control
    None
}

/// .NET target framework
enum DotNetFramework
{
    /// Auto-detect from project
    Auto,
    /// .NET Framework 4.8 (Windows only)
    Net48,
    /// .NET Framework 4.7.2 (Windows only)
    Net472,
    /// .NET Framework 4.6.1 (Windows only)
    Net461,
    /// .NET 6 (LTS)
    Net6,
    /// .NET 7
    Net7,
    /// .NET 8 (LTS)
    Net8,
    /// .NET 9
    Net9,
    /// .NET Standard 2.1
    NetStandard21,
    /// .NET Standard 2.0
    NetStandard20,
    /// Mono
    Mono,
    /// Custom/Other
    Custom
}

/// Project types
enum CSharpProjectType
{
    /// Console application
    Console,
    /// Class library
    Library,
    /// ASP.NET Core Web API
    WebAPI,
    /// ASP.NET Core MVC
    WebMVC,
    /// Blazor WebAssembly
    BlazorWasm,
    /// Blazor Server
    BlazorServer,
    /// .NET MAUI application
    MAUI,
    /// Windows Forms
    WinForms,
    /// WPF application
    WPF,
    /// Azure Functions
    AzureFunctions,
    /// gRPC service
    GRPC,
    /// Worker service
    Worker,
    /// Razor Class Library
    RazorClassLib,
    /// Test project
    Test,
    /// Custom
    Custom
}

/// Runtime identifier for cross-platform publishing
enum RuntimeIdentifier
{
    /// Auto-detect current platform
    Auto,
    /// Windows x64
    WinX64,
    /// Windows x86
    WinX86,
    /// Windows ARM64
    WinArm64,
    /// Linux x64
    LinuxX64,
    /// Linux ARM64
    LinuxArm64,
    /// Linux ARM32
    LinuxArm,
    /// macOS x64 (Intel)
    OsxX64,
    /// macOS ARM64 (Apple Silicon)
    OsxArm64,
    /// Portable (no runtime included)
    Portable,
    /// Custom RID
    Custom
}


/// Static analyzer selection
enum CSharpAnalyzer
{
    /// Auto-detect best available
    Auto,
    /// Roslyn analyzers (built-in)
    Roslyn,
    /// StyleCop analyzers
    StyleCop,
    /// SonarAnalyzer for C#
    SonarAnalyzer,
    /// Roslynator
    Roslynator,
    /// FxCop analyzers
    FxCop,
    /// None - skip analysis
    None
}

/// Code formatter selection
enum CSharpFormatter
{
    /// Auto-detect best available
    Auto,
    /// dotnet-format (official)
    DotNetFormat,
    /// CSharpier (opinionated)
    CSharpier,
    /// None - skip formatting
    None
}

/// Language version specification
struct CSharpVersion
{
    /// Major version (7, 8, 9, 10, 11, 12, etc.)
    int major = 12;
    
    /// Minor version (optional)
    int minor = 0;
    
    /// Parse from string like "11", "10.0", "latest", "preview"
    static CSharpVersion parse(string ver)
    {
        CSharpVersion v;
        
        if (ver.empty || ver == "default")
            return v;
        
        // Handle special versions
        if (ver == "latest")
        {
            v.major = 12;
            return v;
        }
        if (ver == "preview")
        {
            v.major = 13;
            return v;
        }
        if (ver == "latestmajor" || ver == "latest-major")
        {
            v.major = 12;
            return v;
        }
        
        auto parts = ver.split(".");
        if (parts.length >= 1)
            v.major = parts[0].to!int;
        if (parts.length >= 2)
            v.minor = parts[1].to!int;
        
        return v;
    }
    
    /// Convert to string
    string toString() const
    {
        if (minor == 0)
            return major.to!string;
        return format("%d.%d", major, minor);
    }
    
    /// Check if version supports nullable reference types (C# 8+)
    bool supportsNullable() const
    {
        return major >= 8;
    }
    
    /// Check if version supports records (C# 9+)
    bool supportsRecords() const
    {
        return major >= 9;
    }
    
    /// Check if version supports top-level statements (C# 9+)
    bool supportsTopLevelStatements() const
    {
        return major >= 9;
    }
    
    /// Check if version supports global usings (C# 10+)
    bool supportsGlobalUsings() const
    {
        return major >= 10;
    }
    
    /// Check if version supports file-scoped namespaces (C# 10+)
    bool supportsFileScopedNamespaces() const
    {
        return major >= 10;
    }
    
    /// Check if version supports required members (C# 11+)
    bool supportsRequiredMembers() const
    {
        return major >= 11;
    }
    
    /// Check if version supports primary constructors (C# 12+)
    bool supportsPrimaryConstructors() const
    {
        return major >= 12;
    }
    
    /// Check if version supports collection expressions (C# 12+)
    bool supportsCollectionExpressions() const
    {
        return major >= 12;
    }
}

/// NuGet configuration
struct NuGetConfig
{
    /// Auto-restore packages before build
    bool autoRestore = true;
    
    /// Lock file mode (restore only if lock file exists)
    bool lockedMode = false;
    
    /// Force package evaluation
    bool forceEvaluate = false;
    
    /// No cache
    bool noCache = false;
    
    /// Package sources
    string[] sources;
    
    /// Config file path
    string configFile;
    
    /// Output directory for packages
    string packagesDirectory;
    
    /// Create symbol packages
    bool symbols = false;
    
    /// NuGet package ID (for pack)
    string packageId;
    
    /// NuGet package version
    string packageVersion;
    
    /// Package license (SPDX or file path)
    string packageLicense;
    
    /// Package authors
    string[] packageAuthors;
}

/// MSBuild configuration
struct MSBuildConfig
{
    /// MSBuild verbosity (quiet, minimal, normal, detailed, diagnostic)
    string verbosity = "minimal";
    
    /// Max CPU count for parallel builds
    int maxCpuCount = 0; // 0 = auto
    
    /// MSBuild properties
    string[string] properties;
    
    /// Node reuse
    bool nodeReuse = true;
    
    /// Detailed summary
    bool detailedSummary = false;
    
    /// Binary logger
    bool binaryLogger = false;
    
    /// Binary log file path
    string binaryLogPath;
}

/// Publish configuration
struct PublishConfig
{
    /// Self-contained deployment
    bool selfContained = false;
    
    /// Single-file publish
    bool singleFile = false;
    
    /// Ready-to-run compilation
    bool readyToRun = false;
    
    /// Native AOT
    bool nativeAot = false;
    
    /// IL trimming
    bool trimmed = false;
    
    /// Trim mode (link, copyused, full)
    string trimMode = "link";
    
    /// Include native libraries for debugging
    bool includeNativeLibrariesForSelfExtract = false;
    
    /// Include all content
    bool includeAllContentForSelfExtract = false;
    
    /// Enable compression (single-file only)
    bool enableCompressionInSingleFile = true;
    
    /// Produce single file (even on Linux/macOS)
    bool produceSingleFile = false;
    
    /// Publish profiles
    string publishProfile;
}

/// AOT configuration (Native AOT)
struct AOTConfig
{
    /// Enable Native AOT
    bool enabled = false;
    
    /// Optimize for size
    bool optimizeForSize = false;
    
    /// Invariant globalization
    bool invariantGlobalization = false;
    
    /// IL compiler options
    string[] ilcOptimizationPreference;
    
    /// IL compiler flags
    string[] ilcFlags;
    
    /// Stack trace support
    bool stackTraceSupport = true;
    
    /// Use system ICU on Linux
    bool useSystemResourceKeys = false;
}

/// Testing configuration
struct TestConfig
{
    /// Testing framework
    CSharpTestFramework framework = CSharpTestFramework.Auto;
    
    /// Enable test execution
    bool enabled = true;
    
    /// Test filter expression
    string filter;
    
    /// Test logger
    string logger = "console";
    
    /// Enable code coverage
    bool coverage = false;
    
    /// Coverage tool (coverlet, dotcover)
    string coverageTool = "coverlet";
    
    /// Coverage output format
    string[] coverageFormats = ["cobertura", "opencover"];
    
    /// Minimum coverage percentage
    double minCoverage = 0.0;
    
    /// Parallel test execution
    bool parallel = true;
    
    /// Fail fast on first error
    bool failFast = false;
    
    /// Verbose output
    bool verbose = false;
    
    /// Results directory
    string resultsDirectory;
    
    /// Blame mode (collect crash dumps)
    bool blame = false;
}

/// Static analysis configuration
struct AnalysisConfig
{
    /// Enable static analysis
    bool enabled = false;
    
    /// Analyzer to use
    CSharpAnalyzer analyzer = CSharpAnalyzer.Auto;
    
    /// Fail build on warnings
    bool failOnWarnings = false;
    
    /// Fail build on errors
    bool failOnErrors = true;
    
    /// Treat warnings as errors
    bool treatWarningsAsErrors = false;
    
    /// Warning level (0-4)
    int warningLevel = 4;
    
    /// Specific warnings to treat as errors
    string[] warningsAsErrors;
    
    /// Warnings to suppress
    string[] noWarn;
    
    /// Ruleset file path
    string rulesetFile;
    
    /// .editorconfig file path
    string editorConfigFile;
    
    /// Enable nullable reference type warnings
    bool nullable = false;
}

/// Formatter configuration
struct FormatterConfig
{
    /// Enable formatting
    bool enabled = false;
    
    /// Formatter to use
    CSharpFormatter formatter = CSharpFormatter.Auto;
    
    /// Auto-format before build
    bool autoFormat = false;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// .editorconfig file path
    string editorConfigFile;
    
    /// Include generated code
    bool includeGenerated = false;
    
    /// Verify no changes (for CI)
    bool verifyNoChanges = false;
}

/// Complete C# configuration
struct CSharpConfig
{
    /// Build mode
    CSharpBuildMode mode = CSharpBuildMode.Standard;
    
    /// Parse from JSON (required by ConfigParsingMixin)
    static CSharpConfig fromJSON(JSONValue json)
    {
        return parseCSharpConfigFromJSON(json);
    }
    
    /// Build tool
    CSharpBuildTool buildTool = CSharpBuildTool.Auto;
    
    /// Project type
    CSharpProjectType projectType = CSharpProjectType.Console;
    
    /// Target framework
    DotNetFramework framework = DotNetFramework.Auto;
    
    /// Custom target framework moniker (e.g., "net8.0")
    string customFramework;
    
    /// Runtime identifier
    RuntimeIdentifier runtime = RuntimeIdentifier.Auto;
    
    /// Custom runtime identifier
    string customRuntime;
    
    /// C# language version
    CSharpVersion languageVersion;
    
    /// Build configuration (Debug, Release)
    string configuration = "Release";
    
    /// NuGet configuration
    NuGetConfig nuget;
    
    /// MSBuild configuration
    MSBuildConfig msbuild;
    
    /// Publish configuration
    PublishConfig publish;
    
    /// AOT configuration
    AOTConfig aot;
    
    /// Testing configuration
    TestConfig test;
    
    /// Static analysis
    AnalysisConfig analysis;
    
    /// Code formatting
    FormatterConfig formatter;
    
    /// Output directory
    string outputPath;
    
    /// Intermediate output directory
    string intermediateOutputPath;
    
    /// Document file path (XML documentation)
    string documentationFile;
    
    /// Generate XML documentation
    bool generateDocumentation = false;
    
    /// Platform target (AnyCPU, x86, x64, ARM64)
    string platformTarget = "AnyCPU";
    
    /// Optimize code
    bool optimize = true;
    
    /// Debug symbols type (portable, embedded, full, pdbonly)
    string debugType = "portable";
    
    /// Deterministic build
    bool deterministic = true;
    
    /// Disable implicit usings
    bool disableImplicitUsings = false;
    
    /// Disable implicit framework references
    bool disableImplicitFrameworkReferences = false;
    
    /// Additional MSBuild properties
    string[string] properties;
    
    /// Additional compiler flags
    string[] compilerFlags;
    
    /// Preprocessor defines
    string[] defines;
    
    /// Suppress specific warnings
    string[] noWarn;
    
    /// Warnings as errors
    string[] warningsAsErrors;
    
    /// Enable unsafe code
    bool allowUnsafeBlocks = false;
    
    /// Check for overflow/underflow
    bool checkForOverflowUnderflow = false;
    
    /// Application manifest (for Windows apps)
    string applicationManifest;
    
    /// Icon file (for Windows apps)
    string applicationIcon;
    
    /// Win32 resource file
    string win32Resource;
}

/// Parse C# configuration from target
CSharpConfig parseCSharpConfig(in Target target)
{
    CSharpConfig config;
    
    // Parse from langConfig JSON
    if ("csharp" in target.langConfig)
    {
        try
        {
            JSONValue json = parseJSON(target.langConfig["csharp"]);
            config = parseCSharpConfigFromJSON(json);
        }
        catch (Exception e)
        {
            // Use defaults
        }
    }
    
    return config;
}

/// Parse C# configuration from JSON
CSharpConfig parseCSharpConfigFromJSON(JSONValue json)
{
    CSharpConfig config;
    
    // Build mode
    if ("mode" in json)
        config.mode = json["mode"].str.toCSharpBuildMode();
    
    // Build tool
    if ("buildTool" in json)
        config.buildTool = json["buildTool"].str.toCSharpBuildTool();
    
    // Project type
    if ("projectType" in json)
        config.projectType = json["projectType"].str.toCSharpProjectType();
    
    // Framework
    if ("framework" in json)
        config.framework = json["framework"].str.toDotNetFramework();
    if ("customFramework" in json)
        config.customFramework = json["customFramework"].str;
    
    // Runtime
    if ("runtime" in json)
        config.runtime = json["runtime"].str.toRuntimeIdentifier();
    if ("customRuntime" in json)
        config.customRuntime = json["customRuntime"].str;
    
    // Language version
    if ("languageVersion" in json)
        config.languageVersion = CSharpVersion.parse(json["languageVersion"].str);
    
    // Configuration
    if ("configuration" in json)
        config.configuration = json["configuration"].str;
    
    // NuGet
    if ("nuget" in json)
        config.nuget = parseNuGetConfig(json["nuget"]);
    
    // MSBuild
    if ("msbuild" in json)
        config.msbuild = parseMSBuildConfig(json["msbuild"]);
    
    // Publish
    if ("publish" in json)
        config.publish = parsePublishConfig(json["publish"]);
    
    // AOT
    if ("aot" in json)
        config.aot = parseAOTConfig(json["aot"]);
    
    // Testing
    if ("test" in json)
        config.test = parseTestConfig(json["test"]);
    
    // Analysis
    if ("analysis" in json)
        config.analysis = parseAnalysisConfig(json["analysis"]);
    
    // Formatter
    if ("formatter" in json)
        config.formatter = parseFormatterConfig(json["formatter"]);
    
    // Simple string fields
    if ("outputPath" in json) config.outputPath = json["outputPath"].str;
    if ("intermediateOutputPath" in json) config.intermediateOutputPath = json["intermediateOutputPath"].str;
    if ("documentationFile" in json) config.documentationFile = json["documentationFile"].str;
    if ("platformTarget" in json) config.platformTarget = json["platformTarget"].str;
    if ("debugType" in json) config.debugType = json["debugType"].str;
    if ("applicationManifest" in json) config.applicationManifest = json["applicationManifest"].str;
    if ("applicationIcon" in json) config.applicationIcon = json["applicationIcon"].str;
    if ("win32Resource" in json) config.win32Resource = json["win32Resource"].str;
    
    // Boolean fields
    if ("generateDocumentation" in json) config.generateDocumentation = json["generateDocumentation"].type == JSONType.true_;
    if ("optimize" in json) config.optimize = json["optimize"].type == JSONType.true_;
    if ("deterministic" in json) config.deterministic = json["deterministic"].type == JSONType.true_;
    if ("disableImplicitUsings" in json) config.disableImplicitUsings = json["disableImplicitUsings"].type == JSONType.true_;
    if ("disableImplicitFrameworkReferences" in json) config.disableImplicitFrameworkReferences = json["disableImplicitFrameworkReferences"].type == JSONType.true_;
    if ("allowUnsafeBlocks" in json) config.allowUnsafeBlocks = json["allowUnsafeBlocks"].type == JSONType.true_;
    if ("checkForOverflowUnderflow" in json) config.checkForOverflowUnderflow = json["checkForOverflowUnderflow"].type == JSONType.true_;
    
    // Array fields
    if ("compilerFlags" in json) config.compilerFlags = json["compilerFlags"].array.map!(e => e.str).array;
    if ("defines" in json) config.defines = json["defines"].array.map!(e => e.str).array;
    if ("noWarn" in json) config.noWarn = json["noWarn"].array.map!(e => e.str).array;
    if ("warningsAsErrors" in json) config.warningsAsErrors = json["warningsAsErrors"].array.map!(e => e.str).array;
    
    return config;
}

// Helper parsing functions
private NuGetConfig parseNuGetConfig(JSONValue json)
{
    NuGetConfig config;
    if ("autoRestore" in json) config.autoRestore = json["autoRestore"].type == JSONType.true_;
    if ("lockedMode" in json) config.lockedMode = json["lockedMode"].type == JSONType.true_;
    if ("forceEvaluate" in json) config.forceEvaluate = json["forceEvaluate"].type == JSONType.true_;
    if ("noCache" in json) config.noCache = json["noCache"].type == JSONType.true_;
    if ("sources" in json) config.sources = json["sources"].array.map!(e => e.str).array;
    if ("configFile" in json) config.configFile = json["configFile"].str;
    if ("packagesDirectory" in json) config.packagesDirectory = json["packagesDirectory"].str;
    if ("symbols" in json) config.symbols = json["symbols"].type == JSONType.true_;
    if ("packageId" in json) config.packageId = json["packageId"].str;
    if ("packageVersion" in json) config.packageVersion = json["packageVersion"].str;
    if ("packageLicense" in json) config.packageLicense = json["packageLicense"].str;
    if ("packageAuthors" in json) config.packageAuthors = json["packageAuthors"].array.map!(e => e.str).array;
    return config;
}

private MSBuildConfig parseMSBuildConfig(JSONValue json)
{
    MSBuildConfig config;
    if ("verbosity" in json) config.verbosity = json["verbosity"].str;
    if ("maxCpuCount" in json) config.maxCpuCount = json["maxCpuCount"].integer.to!int;
    if ("nodeReuse" in json) config.nodeReuse = json["nodeReuse"].type == JSONType.true_;
    if ("detailedSummary" in json) config.detailedSummary = json["detailedSummary"].type == JSONType.true_;
    if ("binaryLogger" in json) config.binaryLogger = json["binaryLogger"].type == JSONType.true_;
    if ("binaryLogPath" in json) config.binaryLogPath = json["binaryLogPath"].str;
    return config;
}

private PublishConfig parsePublishConfig(JSONValue json)
{
    PublishConfig config;
    if ("selfContained" in json) config.selfContained = json["selfContained"].type == JSONType.true_;
    if ("singleFile" in json) config.singleFile = json["singleFile"].type == JSONType.true_;
    if ("readyToRun" in json) config.readyToRun = json["readyToRun"].type == JSONType.true_;
    if ("nativeAot" in json) config.nativeAot = json["nativeAot"].type == JSONType.true_;
    if ("trimmed" in json) config.trimmed = json["trimmed"].type == JSONType.true_;
    if ("trimMode" in json) config.trimMode = json["trimMode"].str;
    if ("includeNativeLibrariesForSelfExtract" in json) config.includeNativeLibrariesForSelfExtract = json["includeNativeLibrariesForSelfExtract"].type == JSONType.true_;
    if ("includeAllContentForSelfExtract" in json) config.includeAllContentForSelfExtract = json["includeAllContentForSelfExtract"].type == JSONType.true_;
    if ("enableCompressionInSingleFile" in json) config.enableCompressionInSingleFile = json["enableCompressionInSingleFile"].type == JSONType.true_;
    if ("produceSingleFile" in json) config.produceSingleFile = json["produceSingleFile"].type == JSONType.true_;
    if ("publishProfile" in json) config.publishProfile = json["publishProfile"].str;
    return config;
}

private AOTConfig parseAOTConfig(JSONValue json)
{
    AOTConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("optimizeForSize" in json) config.optimizeForSize = json["optimizeForSize"].type == JSONType.true_;
    if ("invariantGlobalization" in json) config.invariantGlobalization = json["invariantGlobalization"].type == JSONType.true_;
    if ("ilcOptimizationPreference" in json) config.ilcOptimizationPreference = json["ilcOptimizationPreference"].array.map!(e => e.str).array;
    if ("ilcFlags" in json) config.ilcFlags = json["ilcFlags"].array.map!(e => e.str).array;
    if ("stackTraceSupport" in json) config.stackTraceSupport = json["stackTraceSupport"].type == JSONType.true_;
    if ("useSystemResourceKeys" in json) config.useSystemResourceKeys = json["useSystemResourceKeys"].type == JSONType.true_;
    return config;
}

private TestConfig parseTestConfig(JSONValue json)
{
    TestConfig config;
    if ("framework" in json) config.framework = json["framework"].str.toCSharpTestFramework();
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("filter" in json) config.filter = json["filter"].str;
    if ("logger" in json) config.logger = json["logger"].str;
    if ("coverage" in json) config.coverage = json["coverage"].type == JSONType.true_;
    if ("coverageTool" in json) config.coverageTool = json["coverageTool"].str;
    if ("coverageFormats" in json) config.coverageFormats = json["coverageFormats"].array.map!(e => e.str).array;
    if ("minCoverage" in json) config.minCoverage = json["minCoverage"].floating;
    if ("parallel" in json) config.parallel = json["parallel"].type == JSONType.true_;
    if ("failFast" in json) config.failFast = json["failFast"].type == JSONType.true_;
    if ("verbose" in json) config.verbose = json["verbose"].type == JSONType.true_;
    if ("resultsDirectory" in json) config.resultsDirectory = json["resultsDirectory"].str;
    if ("blame" in json) config.blame = json["blame"].type == JSONType.true_;
    return config;
}

private AnalysisConfig parseAnalysisConfig(JSONValue json)
{
    AnalysisConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("analyzer" in json) config.analyzer = json["analyzer"].str.toCSharpAnalyzer();
    if ("failOnWarnings" in json) config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    if ("failOnErrors" in json) config.failOnErrors = json["failOnErrors"].type == JSONType.true_;
    if ("treatWarningsAsErrors" in json) config.treatWarningsAsErrors = json["treatWarningsAsErrors"].type == JSONType.true_;
    if ("warningLevel" in json) config.warningLevel = json["warningLevel"].integer.to!int;
    if ("warningsAsErrors" in json) config.warningsAsErrors = json["warningsAsErrors"].array.map!(e => e.str).array;
    if ("noWarn" in json) config.noWarn = json["noWarn"].array.map!(e => e.str).array;
    if ("rulesetFile" in json) config.rulesetFile = json["rulesetFile"].str;
    if ("editorConfigFile" in json) config.editorConfigFile = json["editorConfigFile"].str;
    if ("nullable" in json) config.nullable = json["nullable"].type == JSONType.true_;
    return config;
}

private FormatterConfig parseFormatterConfig(JSONValue json)
{
    FormatterConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("formatter" in json) config.formatter = json["formatter"].str.toCSharpFormatter();
    if ("autoFormat" in json) config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("checkOnly" in json) config.checkOnly = json["checkOnly"].type == JSONType.true_;
    if ("editorConfigFile" in json) config.editorConfigFile = json["editorConfigFile"].str;
    if ("includeGenerated" in json) config.includeGenerated = json["includeGenerated"].type == JSONType.true_;
    if ("verifyNoChanges" in json) config.verifyNoChanges = json["verifyNoChanges"].type == JSONType.true_;
    return config;
}

// Enum conversion helpers
private CSharpBuildMode toCSharpBuildMode(string s)
{
    switch (s.toLower)
    {
        case "standard": return CSharpBuildMode.Standard;
        case "singlefile": case "single-file": return CSharpBuildMode.SingleFile;
        case "readytorun": case "ready-to-run": case "r2r": return CSharpBuildMode.ReadyToRun;
        case "nativeaot": case "native-aot": case "aot": return CSharpBuildMode.NativeAOT;
        case "trimmed": case "trim": return CSharpBuildMode.Trimmed;
        case "nuget": case "nupkg": return CSharpBuildMode.NuGet;
        case "compile": return CSharpBuildMode.Compile;
        default: return CSharpBuildMode.Standard;
    }
}

private CSharpBuildTool toCSharpBuildTool(string s)
{
    switch (s.toLower)
    {
        case "auto": return CSharpBuildTool.Auto;
        case "dotnet": return CSharpBuildTool.DotNet;
        case "msbuild": return CSharpBuildTool.MSBuild;
        case "csc": return CSharpBuildTool.CSC;
        case "none": return CSharpBuildTool.None;
        default: return CSharpBuildTool.Auto;
    }
}

private CSharpProjectType toCSharpProjectType(string s)
{
    switch (s.toLower)
    {
        case "console": return CSharpProjectType.Console;
        case "library": return CSharpProjectType.Library;
        case "webapi": case "web-api": return CSharpProjectType.WebAPI;
        case "webmvc": case "web-mvc": case "mvc": return CSharpProjectType.WebMVC;
        case "blazorwasm": case "blazor-wasm": return CSharpProjectType.BlazorWasm;
        case "blazorserver": case "blazor-server": return CSharpProjectType.BlazorServer;
        case "maui": return CSharpProjectType.MAUI;
        case "winforms": return CSharpProjectType.WinForms;
        case "wpf": return CSharpProjectType.WPF;
        case "azurefunctions": case "azure-functions": return CSharpProjectType.AzureFunctions;
        case "grpc": return CSharpProjectType.GRPC;
        case "worker": return CSharpProjectType.Worker;
        case "razorclasslib": case "razor-class-lib": return CSharpProjectType.RazorClassLib;
        case "test": return CSharpProjectType.Test;
        case "custom": return CSharpProjectType.Custom;
        default: return CSharpProjectType.Console;
    }
}

private DotNetFramework toDotNetFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return DotNetFramework.Auto;
        case "net48": case "net4.8": return DotNetFramework.Net48;
        case "net472": case "net4.7.2": return DotNetFramework.Net472;
        case "net461": case "net4.6.1": return DotNetFramework.Net461;
        case "net6": case "net6.0": return DotNetFramework.Net6;
        case "net7": case "net7.0": return DotNetFramework.Net7;
        case "net8": case "net8.0": return DotNetFramework.Net8;
        case "net9": case "net9.0": return DotNetFramework.Net9;
        case "netstandard2.1": return DotNetFramework.NetStandard21;
        case "netstandard2.0": return DotNetFramework.NetStandard20;
        case "mono": return DotNetFramework.Mono;
        case "custom": return DotNetFramework.Custom;
        default: return DotNetFramework.Auto;
    }
}

private RuntimeIdentifier toRuntimeIdentifier(string s)
{
    switch (s.toLower)
    {
        case "auto": return RuntimeIdentifier.Auto;
        case "win-x64": case "winx64": return RuntimeIdentifier.WinX64;
        case "win-x86": case "winx86": return RuntimeIdentifier.WinX86;
        case "win-arm64": case "winarm64": return RuntimeIdentifier.WinArm64;
        case "linux-x64": case "linuxx64": return RuntimeIdentifier.LinuxX64;
        case "linux-arm64": case "linuxarm64": return RuntimeIdentifier.LinuxArm64;
        case "linux-arm": case "linuxarm": return RuntimeIdentifier.LinuxArm;
        case "osx-x64": case "osxx64": return RuntimeIdentifier.OsxX64;
        case "osx-arm64": case "osxarm64": return RuntimeIdentifier.OsxArm64;
        case "portable": return RuntimeIdentifier.Portable;
        case "custom": return RuntimeIdentifier.Custom;
        default: return RuntimeIdentifier.Auto;
    }
}

private CSharpTestFramework toCSharpTestFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return CSharpTestFramework.Auto;
        case "xunit": return CSharpTestFramework.XUnit;
        case "nunit": return CSharpTestFramework.NUnit;
        case "mstest": return CSharpTestFramework.MSTest;
        case "none": return CSharpTestFramework.None;
        default: return CSharpTestFramework.Auto;
    }
}

private CSharpAnalyzer toCSharpAnalyzer(string s)
{
    switch (s.toLower)
    {
        case "auto": return CSharpAnalyzer.Auto;
        case "roslyn": return CSharpAnalyzer.Roslyn;
        case "stylecop": return CSharpAnalyzer.StyleCop;
        case "sonaranalyzer": case "sonar": return CSharpAnalyzer.SonarAnalyzer;
        case "roslynator": return CSharpAnalyzer.Roslynator;
        case "fxcop": return CSharpAnalyzer.FxCop;
        case "none": return CSharpAnalyzer.None;
        default: return CSharpAnalyzer.Auto;
    }
}

private CSharpFormatter toCSharpFormatter(string s)
{
    switch (s.toLower)
    {
        case "auto": return CSharpFormatter.Auto;
        case "dotnet-format": case "dotnetformat": return CSharpFormatter.DotNetFormat;
        case "csharpier": return CSharpFormatter.CSharpier;
        case "none": return CSharpFormatter.None;
        default: return CSharpFormatter.Auto;
    }
}

