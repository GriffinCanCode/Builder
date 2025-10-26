module languages.compiled.swift.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Swift project types - distinct build strategies
enum SwiftProjectType
{
    /// Executable binary
    Executable,
    /// Library (static or dynamic)
    Library,
    /// System module (C library wrapper)
    SystemModule,
    /// Test target
    Test,
    /// Macro (Swift 5.9+)
    Macro,
    /// Plugin
    Plugin
}

/// Swift Package Manager build modes
enum SPMBuildMode
{
    /// Standard compilation
    Build,
    /// Build and run
    Run,
    /// Build and test
    Test,
    /// Check only (no build)
    Check,
    /// Clean build artifacts
    Clean,
    /// Generate Xcode project
    GenerateXcodeproj,
    /// Custom command
    Custom
}

/// Swift toolchain selection
enum SwiftToolchain
{
    /// System default Swift
    System,
    /// Xcode-bundled Swift
    Xcode,
    /// Custom toolchain path
    Custom,
    /// Swift.org snapshot
    Snapshot
}

/// Build configuration
enum SwiftBuildConfig
{
    /// Debug configuration (fast compile, no optimization)
    Debug,
    /// Release configuration (optimized, no debug info)
    Release,
    /// Custom configuration
    Custom
}

/// Library type
enum SwiftLibraryType
{
    /// Automatic (SPM decides)
    Auto,
    /// Static library
    Static,
    /// Dynamic library
    Dynamic
}

/// Platform targets
enum SwiftPlatform
{
    /// macOS
    macOS,
    /// iOS
    iOS,
    /// iOS Simulator
    iOSSimulator,
    /// tvOS
    tvOS,
    /// watchOS
    watchOS,
    /// Linux
    Linux,
    /// Windows
    Windows,
    /// Android (experimental)
    Android
}

/// Swift language version
enum SwiftLanguageVersion
{
    /// Swift 4
    Swift4,
    /// Swift 4.2
    Swift4_2,
    /// Swift 5
    Swift5,
    /// Swift 5.1
    Swift5_1,
    /// Swift 5.2
    Swift5_2,
    /// Swift 5.3
    Swift5_3,
    /// Swift 5.4
    Swift5_4,
    /// Swift 5.5
    Swift5_5,
    /// Swift 5.6
    Swift5_6,
    /// Swift 5.7
    Swift5_7,
    /// Swift 5.8
    Swift5_8,
    /// Swift 5.9
    Swift5_9,
    /// Swift 5.10
    Swift5_10,
    /// Swift 6
    Swift6
}

/// Optimization level
enum SwiftOptimization
{
    /// No optimization (-Onone)
    None,
    /// Basic optimization (-O)
    Speed,
    /// Size optimization (-Osize)
    Size,
    /// Unchecked optimization (-Ounchecked)
    Unchecked
}

/// Sanitizer options
enum SwiftSanitizer
{
    /// No sanitizer
    None,
    /// Address sanitizer
    Address,
    /// Thread sanitizer
    Thread,
    /// Undefined behavior sanitizer
    Undefined
}

/// Code coverage mode
enum SwiftCoverage
{
    /// No coverage
    None,
    /// Generate coverage data
    Generate,
    /// Show coverage
    Show
}

/// Swift version specification
struct SwiftVersion
{
    /// Major version
    int major = 5;
    
    /// Minor version
    int minor = 10;
    
    /// Patch version
    int patch = 0;
    
    /// Custom toolchain path
    string toolchainPath;
    
    /// Use Xcode Swift
    bool useXcode = false;
    
    /// Snapshot identifier
    string snapshot;
    
    /// Convert to version string
    string toString() const @safe pure
    {
        import std.format : format;
        
        if (patch == 0)
            return format!"%d.%d"(major, minor);
        return format!"%d.%d.%d"(major, minor, patch);
    }
}

/// Package.swift manifest information
struct PackageManifest
{
    /// Package name
    string name;
    
    /// Tools version
    string toolsVersion;
    
    /// Platforms
    string[] platforms;
    
    /// Products (libraries, executables)
    string[] products;
    
    /// Dependencies
    Dependency[] dependencies;
    
    /// Targets
    string[] targets;
    
    /// Swift language versions
    string[] swiftLanguageVersions;
    
    /// C language standard
    string cLanguageStandard;
    
    /// C++ language standard
    string cxxLanguageStandard;
    
    /// Manifest path
    string manifestPath = "Package.swift";
}

/// Platform deployment target
struct PlatformTarget
{
    /// Platform name
    SwiftPlatform platform;
    
    /// Minimum deployment version
    string minVersion;
    
    /// SDK path (optional)
    string sdkPath;
    
    /// Architecture
    string arch; // arm64, x86_64, etc.
}

/// Dependency specification
struct Dependency
{
    /// Package name
    string name;
    
    /// Source URL (git, local path)
    string url;
    
    /// Version requirement
    string version_;
    
    /// Branch name (if using branch)
    string branch;
    
    /// Revision/commit (if using exact revision)
    string revision;
    
    /// Local path dependency
    string path;
    
    /// From version
    string from;
    
    /// Exact version
    string exact;
    
    /// Version range (e.g., "1.0.0"..<"2.0.0")
    string range;
}

/// Build settings for specific targets
struct BuildSettings
{
    /// Custom C flags
    string[] cFlags;
    
    /// Custom C++ flags
    string[] cxxFlags;
    
    /// Custom Swift flags
    string[] swiftFlags;
    
    /// Linker flags
    string[] linkerFlags;
    
    /// Define macros
    string[] defines;
    
    /// Header search paths
    string[] headerSearchPaths;
    
    /// Linked libraries
    string[] linkedLibraries;
    
    /// Linked frameworks
    string[] linkedFrameworks;
    
    /// Unsafe flags (bypass validation)
    bool unsafeFlags = false;
}

/// SwiftLint configuration
struct SwiftLintConfig
{
    /// Enable SwiftLint
    bool enabled = false;
    
    /// Config file path
    string configFile = ".swiftlint.yml";
    
    /// Strict mode (warnings as errors)
    bool strict = false;
    
    /// Lint mode (lint, analyze)
    string mode = "lint";
    
    /// Rules to enable
    string[] enableRules;
    
    /// Rules to disable
    string[] disableRules;
    
    /// Paths to lint
    string[] includePaths;
    
    /// Paths to exclude
    string[] excludePaths;
    
    /// Reporter format
    string reporter = "xcode";
    
    /// Quiet mode
    bool quiet = false;
    
    /// Force exclude
    bool forceExclude = false;
    
    /// Autocorrect
    bool autocorrect = false;
}

/// SwiftFormat configuration
struct SwiftFormatConfig
{
    /// Enable SwiftFormat
    bool enabled = false;
    
    /// Config file path
    string configFile = ".swift-format.json";
    
    /// Check only (don't format)
    bool checkOnly = false;
    
    /// In-place formatting
    bool inPlace = true;
    
    /// Rules
    string[] rules;
    
    /// Indent width
    int indentWidth = 4;
    
    /// Use tabs
    bool useTabs = false;
    
    /// Line length
    int lineLength = 100;
    
    /// Respect existing line breaks
    bool respectsExistingLineBreaks = true;
}

/// Swift-DocC documentation configuration
struct DocCConfig
{
    /// Enable documentation generation
    bool enabled = false;
    
    /// Output path
    string outputPath = ".docs";
    
    /// Hosting base path
    string hostingBasePath;
    
    /// Transform for archive
    bool transformForStaticHosting = false;
    
    /// Additional symbol graph options
    string[] symbolGraphOptions;
    
    /// Enable experimental features
    bool experimentalFeatures = false;
    
    /// Enable diagnostics
    bool enableDiagnostics = true;
}

/// Testing configuration
struct SwiftTestConfig
{
    /// Test filter (run specific tests)
    string[] filter;
    
    /// Skip tests
    string[] skip;
    
    /// Enable code coverage
    bool enableCodeCoverage = false;
    
    /// Parallel testing
    bool parallel = true;
    
    /// Number of workers
    int numWorkers = 0; // 0 = auto
    
    /// Repeat tests
    int repeat = 1;
    
    /// Test product
    string testProduct;
    
    /// XCTest arguments
    string[] xctestArgs;
    
    /// Enable test discovery
    bool enableTestDiscovery = true;
    
    /// Enable experimental test output
    bool experimentalTestOutput = false;
}

/// XCFramework configuration
struct XCFrameworkConfig
{
    /// Enable XCFramework generation
    bool enabled = false;
    
    /// Output path
    string outputPath;
    
    /// Framework name
    string frameworkName;
    
    /// Platforms to build for
    SwiftPlatform[] platforms;
    
    /// Allow internal distribution
    bool allowInternalDistribution = false;
}

/// Cross-compilation configuration
struct CrossCompilationConfig
{
    /// Target triple (e.g., x86_64-apple-macosx)
    string targetTriple;
    
    /// SDK path
    string sdkPath;
    
    /// Architecture
    string arch;
    
    /// Additional flags
    string[] flags;
}

/// Swift-specific build configuration
struct SwiftConfig
{
    /// Project type
    SwiftProjectType projectType = SwiftProjectType.Executable;
    
    /// Build mode
    SPMBuildMode mode = SPMBuildMode.Build;
    
    /// Build configuration (debug/release)
    SwiftBuildConfig buildConfig = SwiftBuildConfig.Release;
    
    /// Custom configuration name
    string customConfig;
    
    /// Swift toolchain
    SwiftToolchain toolchain = SwiftToolchain.System;
    
    /// Swift version
    SwiftVersion swiftVersion;
    
    /// Swift language version
    SwiftLanguageVersion languageVersion = SwiftLanguageVersion.Swift5_10;
    
    /// Package manifest
    PackageManifest manifest;
    
    /// Platform targets
    PlatformTarget[] platforms;
    
    /// Library type (for library projects)
    SwiftLibraryType libraryType = SwiftLibraryType.Auto;
    
    /// Product name to build
    string product;
    
    /// Target name to build
    string target;
    
    /// Dependencies
    Dependency[] dependencies;
    
    /// Build settings
    BuildSettings buildSettings;
    
    /// Optimization level
    SwiftOptimization optimization = SwiftOptimization.Speed;
    
    /// Enable whole module optimization
    bool wholeModuleOptimization = true;
    
    /// Enable incremental compilation
    bool incrementalCompilation = true;
    
    /// Enable index-while-building
    bool indexWhileBuilding = true;
    
    /// Enable batch mode
    bool batchMode = false;
    
    /// Parallel jobs
    int jobs = 0; // 0 = auto
    
    /// Build path
    string buildPath = ".build";
    
    /// Scratch path for intermediate files
    string scratchPath;
    
    /// Package path
    string packagePath = ".";
    
    /// Enable verbose output
    bool verbose = false;
    
    /// Very verbose output
    bool veryVerbose = false;
    
    /// Enable debug info
    bool debugInfo = false;
    
    /// Enable testability
    bool enableTestability = false;
    
    /// Sanitizer
    SwiftSanitizer sanitizer = SwiftSanitizer.None;
    
    /// Code coverage
    SwiftCoverage coverage = SwiftCoverage.None;
    
    /// Static Swift stdlib
    bool staticSwiftStdlib = false;
    
    /// Disable sandbox (for SPM)
    bool disableSandbox = false;
    
    /// Skip updating dependencies
    bool skipUpdate = false;
    
    /// Disable automatic resolution
    bool disableAutomaticResolution = false;
    
    /// Force resolved versions
    bool forceResolvedVersions = false;
    
    /// Enable library evolution
    bool enableLibraryEvolution = false;
    
    /// Emit module interface
    bool emitModuleInterface = false;
    
    /// Enable bare slash regex
    bool enableBareSlashRegex = false;
    
    /// Enable upcoming features
    string[] upcomingFeatures;
    
    /// Experimental features
    string[] experimentalFeatures;
    
    /// Cross-compilation configuration
    CrossCompilationConfig crossCompilation;
    
    /// XCFramework configuration
    XCFrameworkConfig xcframework;
    
    /// Testing configuration
    SwiftTestConfig testing;
    
    /// SwiftLint configuration
    SwiftLintConfig swiftlint;
    
    /// SwiftFormat configuration
    SwiftFormatConfig swiftformat;
    
    /// Documentation configuration
    DocCConfig documentation;
    
    /// Arch-specific settings (for universal binaries)
    string arch;
    
    /// Triple (target triple)
    string triple;
    
    /// SDK path
    string sdk;
    
    /// Enable Xcode integration
    bool xcodeIntegration = false;
    
    /// Generate Xcode project
    bool generateXcodeProject = false;
    
    /// Xcode scheme
    string xcodeScheme;
    
    /// Xcode configuration
    string xcodeConfiguration;
    
    /// Custom Swift compiler path
    string swiftcPath;
    
    /// Environment variables
    string[string] env;
    
    /// Parse from JSON
    static SwiftConfig fromJSON(JSONValue json) @trusted
    {
        SwiftConfig config;
        
        // Project type
        if (auto projectType = "projectType" in json)
        {
            immutable typeStr = projectType.str.toLower;
            switch (typeStr)
            {
                case "executable": config.projectType = SwiftProjectType.Executable; break;
                case "library": config.projectType = SwiftProjectType.Library; break;
                case "systemmodule", "system": config.projectType = SwiftProjectType.SystemModule; break;
                case "test": config.projectType = SwiftProjectType.Test; break;
                case "macro": config.projectType = SwiftProjectType.Macro; break;
                case "plugin": config.projectType = SwiftProjectType.Plugin; break;
                default: config.projectType = SwiftProjectType.Executable; break;
            }
        }
        
        // Build mode
        if (auto mode = "mode" in json)
        {
            immutable modeStr = mode.str.toLower;
            switch (modeStr)
            {
                case "build": config.mode = SPMBuildMode.Build; break;
                case "run": config.mode = SPMBuildMode.Run; break;
                case "test": config.mode = SPMBuildMode.Test; break;
                case "check": config.mode = SPMBuildMode.Check; break;
                case "clean": config.mode = SPMBuildMode.Clean; break;
                case "generate-xcodeproj": config.mode = SPMBuildMode.GenerateXcodeproj; break;
                case "custom": config.mode = SPMBuildMode.Custom; break;
                default: config.mode = SPMBuildMode.Build; break;
            }
        }
        
        // Build configuration
        if (auto buildConfig = "buildConfig" in json)
        {
            immutable configStr = buildConfig.str.toLower;
            switch (configStr)
            {
                case "debug": config.buildConfig = SwiftBuildConfig.Debug; break;
                case "release": config.buildConfig = SwiftBuildConfig.Release; break;
                case "custom": 
                    config.buildConfig = SwiftBuildConfig.Custom;
                    if (auto custom = "customConfig" in json)
                        config.customConfig = custom.str;
                    break;
                default: config.buildConfig = SwiftBuildConfig.Release; break;
            }
        }
        
        // Toolchain
        if (auto toolchain = "toolchain" in json)
        {
            immutable tcStr = toolchain.str.toLower;
            switch (tcStr)
            {
                case "system": config.toolchain = SwiftToolchain.System; break;
                case "xcode": config.toolchain = SwiftToolchain.Xcode; break;
                case "custom": config.toolchain = SwiftToolchain.Custom; break;
                case "snapshot": config.toolchain = SwiftToolchain.Snapshot; break;
                default: config.toolchain = SwiftToolchain.System; break;
            }
        }
        
        // Swift version
        if (auto swiftVersion = "swiftVersion" in json)
        {
            if (swiftVersion.type == JSONType.string)
            {
                immutable parts = swiftVersion.str.split(".");
                if (parts.length >= 1) config.swiftVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.swiftVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.swiftVersion.patch = parts[2].to!int;
            }
            else if (swiftVersion.type == JSONType.object)
            {
                if (auto major = "major" in *swiftVersion)
                    config.swiftVersion.major = cast(int)major.integer;
                if (auto minor = "minor" in *swiftVersion)
                    config.swiftVersion.minor = cast(int)minor.integer;
                if (auto patch = "patch" in *swiftVersion)
                    config.swiftVersion.patch = cast(int)patch.integer;
                if (auto toolchainPath = "toolchainPath" in *swiftVersion)
                    config.swiftVersion.toolchainPath = toolchainPath.str;
                if (auto useXcode = "useXcode" in *swiftVersion)
                    config.swiftVersion.useXcode = useXcode.type == JSONType.true_;
                if (auto snapshot = "snapshot" in *swiftVersion)
                    config.swiftVersion.snapshot = snapshot.str;
            }
        }
        
        // Language version
        if (auto langVersion = "languageVersion" in json)
        {
            immutable langStr = langVersion.str.replace(".", "_");
            switch (langStr)
            {
                case "4": config.languageVersion = SwiftLanguageVersion.Swift4; break;
                case "4_2": config.languageVersion = SwiftLanguageVersion.Swift4_2; break;
                case "5": config.languageVersion = SwiftLanguageVersion.Swift5; break;
                case "5_1": config.languageVersion = SwiftLanguageVersion.Swift5_1; break;
                case "5_2": config.languageVersion = SwiftLanguageVersion.Swift5_2; break;
                case "5_3": config.languageVersion = SwiftLanguageVersion.Swift5_3; break;
                case "5_4": config.languageVersion = SwiftLanguageVersion.Swift5_4; break;
                case "5_5": config.languageVersion = SwiftLanguageVersion.Swift5_5; break;
                case "5_6": config.languageVersion = SwiftLanguageVersion.Swift5_6; break;
                case "5_7": config.languageVersion = SwiftLanguageVersion.Swift5_7; break;
                case "5_8": config.languageVersion = SwiftLanguageVersion.Swift5_8; break;
                case "5_9": config.languageVersion = SwiftLanguageVersion.Swift5_9; break;
                case "5_10": config.languageVersion = SwiftLanguageVersion.Swift5_10; break;
                case "6": config.languageVersion = SwiftLanguageVersion.Swift6; break;
                default: config.languageVersion = SwiftLanguageVersion.Swift5_10; break;
            }
        }
        
        // Library type
        if (auto libType = "libraryType" in json)
        {
            immutable libStr = libType.str.toLower;
            switch (libStr)
            {
                case "auto": config.libraryType = SwiftLibraryType.Auto; break;
                case "static": config.libraryType = SwiftLibraryType.Static; break;
                case "dynamic": config.libraryType = SwiftLibraryType.Dynamic; break;
                default: config.libraryType = SwiftLibraryType.Auto; break;
            }
        }
        
        // Optimization
        if (auto opt = "optimization" in json)
        {
            immutable optStr = opt.str.toLower;
            switch (optStr)
            {
                case "none": config.optimization = SwiftOptimization.None; break;
                case "speed": config.optimization = SwiftOptimization.Speed; break;
                case "size": config.optimization = SwiftOptimization.Size; break;
                case "unchecked": config.optimization = SwiftOptimization.Unchecked; break;
                default: config.optimization = SwiftOptimization.Speed; break;
            }
        }
        
        // Sanitizer
        if (auto sanitizer = "sanitizer" in json)
        {
            immutable sanStr = sanitizer.str.toLower;
            switch (sanStr)
            {
                case "none": config.sanitizer = SwiftSanitizer.None; break;
                case "address": config.sanitizer = SwiftSanitizer.Address; break;
                case "thread": config.sanitizer = SwiftSanitizer.Thread; break;
                case "undefined": config.sanitizer = SwiftSanitizer.Undefined; break;
                default: config.sanitizer = SwiftSanitizer.None; break;
            }
        }
        
        // Coverage
        if (auto coverage = "coverage" in json)
        {
            immutable covStr = coverage.str.toLower;
            switch (covStr)
            {
                case "none": config.coverage = SwiftCoverage.None; break;
                case "generate": config.coverage = SwiftCoverage.Generate; break;
                case "show": config.coverage = SwiftCoverage.Show; break;
                default: config.coverage = SwiftCoverage.None; break;
            }
        }
        
        // String fields
        if (auto product = "product" in json) config.product = product.str;
        if (auto target = "target" in json) config.target = target.str;
        if (auto buildPath = "buildPath" in json) config.buildPath = buildPath.str;
        if (auto scratchPath = "scratchPath" in json) config.scratchPath = scratchPath.str;
        if (auto packagePath = "packagePath" in json) config.packagePath = packagePath.str;
        if (auto arch = "arch" in json) config.arch = arch.str;
        if (auto triple = "triple" in json) config.triple = triple.str;
        if (auto sdk = "sdk" in json) config.sdk = sdk.str;
        if (auto xcodeScheme = "xcodeScheme" in json) config.xcodeScheme = xcodeScheme.str;
        if (auto xcodeConfiguration = "xcodeConfiguration" in json) config.xcodeConfiguration = xcodeConfiguration.str;
        if (auto swiftcPath = "swiftcPath" in json) config.swiftcPath = swiftcPath.str;
        
        // Numeric fields
        if (auto jobs = "jobs" in json) config.jobs = cast(int)jobs.integer;
        
        // Boolean fields
        if (auto verbose = "verbose" in json) config.verbose = verbose.type == JSONType.true_;
        if (auto veryVerbose = "veryVerbose" in json) config.veryVerbose = veryVerbose.type == JSONType.true_;
        if (auto debugInfo = "debugInfo" in json) config.debugInfo = debugInfo.type == JSONType.true_;
        if (auto enableTestability = "enableTestability" in json) config.enableTestability = enableTestability.type == JSONType.true_;
        if (auto wholeModuleOptimization = "wholeModuleOptimization" in json) 
            config.wholeModuleOptimization = wholeModuleOptimization.type == JSONType.true_;
        if (auto incrementalCompilation = "incrementalCompilation" in json)
            config.incrementalCompilation = incrementalCompilation.type == JSONType.true_;
        if (auto indexWhileBuilding = "indexWhileBuilding" in json)
            config.indexWhileBuilding = indexWhileBuilding.type == JSONType.true_;
        if (auto batchMode = "batchMode" in json) config.batchMode = batchMode.type == JSONType.true_;
        if (auto staticSwiftStdlib = "staticSwiftStdlib" in json)
            config.staticSwiftStdlib = staticSwiftStdlib.type == JSONType.true_;
        if (auto disableSandbox = "disableSandbox" in json)
            config.disableSandbox = disableSandbox.type == JSONType.true_;
        if (auto skipUpdate = "skipUpdate" in json) config.skipUpdate = skipUpdate.type == JSONType.true_;
        if (auto disableAutomaticResolution = "disableAutomaticResolution" in json)
            config.disableAutomaticResolution = disableAutomaticResolution.type == JSONType.true_;
        if (auto forceResolvedVersions = "forceResolvedVersions" in json)
            config.forceResolvedVersions = forceResolvedVersions.type == JSONType.true_;
        if (auto enableLibraryEvolution = "enableLibraryEvolution" in json)
            config.enableLibraryEvolution = enableLibraryEvolution.type == JSONType.true_;
        if (auto emitModuleInterface = "emitModuleInterface" in json)
            config.emitModuleInterface = emitModuleInterface.type == JSONType.true_;
        if (auto enableBareSlashRegex = "enableBareSlashRegex" in json)
            config.enableBareSlashRegex = enableBareSlashRegex.type == JSONType.true_;
        if (auto xcodeIntegration = "xcodeIntegration" in json)
            config.xcodeIntegration = xcodeIntegration.type == JSONType.true_;
        if (auto generateXcodeProject = "generateXcodeProject" in json)
            config.generateXcodeProject = generateXcodeProject.type == JSONType.true_;
        
        // Array fields
        if (auto upcomingFeatures = "upcomingFeatures" in json)
            config.upcomingFeatures = upcomingFeatures.array.map!(e => e.str).array;
        if (auto experimentalFeatures = "experimentalFeatures" in json)
            config.experimentalFeatures = experimentalFeatures.array.map!(e => e.str).array;
        
        // Platform targets
        if (auto platforms = "platforms" in json)
        {
            foreach (ref platform; platforms.array)
            {
                PlatformTarget pt;
                if (auto name = "platform" in platform)
                {
                    immutable platStr = name.str.toLower;
                    switch (platStr)
                    {
                        case "macos": pt.platform = SwiftPlatform.macOS; break;
                        case "ios": pt.platform = SwiftPlatform.iOS; break;
                        case "iossimulator": pt.platform = SwiftPlatform.iOSSimulator; break;
                        case "tvos": pt.platform = SwiftPlatform.tvOS; break;
                        case "watchos": pt.platform = SwiftPlatform.watchOS; break;
                        case "linux": pt.platform = SwiftPlatform.Linux; break;
                        case "windows": pt.platform = SwiftPlatform.Windows; break;
                        case "android": pt.platform = SwiftPlatform.Android; break;
                        default: pt.platform = SwiftPlatform.macOS; break;
                    }
                }
                if (auto minVersion = "minVersion" in platform) pt.minVersion = minVersion.str;
                if (auto sdkPath = "sdkPath" in platform) pt.sdkPath = sdkPath.str;
                if (auto arch = "arch" in platform) pt.arch = arch.str;
                
                config.platforms ~= pt;
            }
        }
        
        // Build settings
        if (auto buildSettings = "buildSettings" in json)
        {
            if (auto cFlags = "cFlags" in *buildSettings)
                config.buildSettings.cFlags = cFlags.array.map!(e => e.str).array;
            if (auto cxxFlags = "cxxFlags" in *buildSettings)
                config.buildSettings.cxxFlags = cxxFlags.array.map!(e => e.str).array;
            if (auto swiftFlags = "swiftFlags" in *buildSettings)
                config.buildSettings.swiftFlags = swiftFlags.array.map!(e => e.str).array;
            if (auto linkerFlags = "linkerFlags" in *buildSettings)
                config.buildSettings.linkerFlags = linkerFlags.array.map!(e => e.str).array;
            if (auto defines = "defines" in *buildSettings)
                config.buildSettings.defines = defines.array.map!(e => e.str).array;
            if (auto headerSearchPaths = "headerSearchPaths" in *buildSettings)
                config.buildSettings.headerSearchPaths = headerSearchPaths.array.map!(e => e.str).array;
            if (auto linkedLibraries = "linkedLibraries" in *buildSettings)
                config.buildSettings.linkedLibraries = linkedLibraries.array.map!(e => e.str).array;
            if (auto linkedFrameworks = "linkedFrameworks" in *buildSettings)
                config.buildSettings.linkedFrameworks = linkedFrameworks.array.map!(e => e.str).array;
            if (auto unsafeFlags = "unsafeFlags" in *buildSettings)
                config.buildSettings.unsafeFlags = unsafeFlags.type == JSONType.true_;
        }
        
        // SwiftLint configuration
        if (auto swiftlint = "swiftlint" in json)
        {
            if (auto enabled = "enabled" in *swiftlint)
                config.swiftlint.enabled = enabled.type == JSONType.true_;
            if (auto configFile = "configFile" in *swiftlint)
                config.swiftlint.configFile = configFile.str;
            if (auto strict = "strict" in *swiftlint)
                config.swiftlint.strict = strict.type == JSONType.true_;
            if (auto mode = "mode" in *swiftlint)
                config.swiftlint.mode = mode.str;
            if (auto enableRules = "enableRules" in *swiftlint)
                config.swiftlint.enableRules = enableRules.array.map!(e => e.str).array;
            if (auto disableRules = "disableRules" in *swiftlint)
                config.swiftlint.disableRules = disableRules.array.map!(e => e.str).array;
            if (auto includePaths = "includePaths" in *swiftlint)
                config.swiftlint.includePaths = includePaths.array.map!(e => e.str).array;
            if (auto excludePaths = "excludePaths" in *swiftlint)
                config.swiftlint.excludePaths = excludePaths.array.map!(e => e.str).array;
            if (auto reporter = "reporter" in *swiftlint)
                config.swiftlint.reporter = reporter.str;
            if (auto quiet = "quiet" in *swiftlint)
                config.swiftlint.quiet = quiet.type == JSONType.true_;
            if (auto forceExclude = "forceExclude" in *swiftlint)
                config.swiftlint.forceExclude = forceExclude.type == JSONType.true_;
            if (auto autocorrect = "autocorrect" in *swiftlint)
                config.swiftlint.autocorrect = autocorrect.type == JSONType.true_;
        }
        
        // SwiftFormat configuration
        if (auto swiftformat = "swiftformat" in json)
        {
            if (auto enabled = "enabled" in *swiftformat)
                config.swiftformat.enabled = enabled.type == JSONType.true_;
            if (auto configFile = "configFile" in *swiftformat)
                config.swiftformat.configFile = configFile.str;
            if (auto checkOnly = "checkOnly" in *swiftformat)
                config.swiftformat.checkOnly = checkOnly.type == JSONType.true_;
            if (auto inPlace = "inPlace" in *swiftformat)
                config.swiftformat.inPlace = inPlace.type == JSONType.true_;
            if (auto rules = "rules" in *swiftformat)
                config.swiftformat.rules = rules.array.map!(e => e.str).array;
            if (auto indentWidth = "indentWidth" in *swiftformat)
                config.swiftformat.indentWidth = cast(int)indentWidth.integer;
            if (auto useTabs = "useTabs" in *swiftformat)
                config.swiftformat.useTabs = useTabs.type == JSONType.true_;
            if (auto lineLength = "lineLength" in *swiftformat)
                config.swiftformat.lineLength = cast(int)lineLength.integer;
            if (auto respectsExistingLineBreaks = "respectsExistingLineBreaks" in *swiftformat)
                config.swiftformat.respectsExistingLineBreaks = respectsExistingLineBreaks.type == JSONType.true_;
        }
        
        // Testing configuration
        if (auto testing = "testing" in json)
        {
            if (auto filter = "filter" in *testing)
                config.testing.filter = filter.array.map!(e => e.str).array;
            if (auto skip = "skip" in *testing)
                config.testing.skip = skip.array.map!(e => e.str).array;
            if (auto enableCodeCoverage = "enableCodeCoverage" in *testing)
                config.testing.enableCodeCoverage = enableCodeCoverage.type == JSONType.true_;
            if (auto parallel = "parallel" in *testing)
                config.testing.parallel = parallel.type == JSONType.true_;
            if (auto numWorkers = "numWorkers" in *testing)
                config.testing.numWorkers = cast(int)numWorkers.integer;
            if (auto repeat = "repeat" in *testing)
                config.testing.repeat = cast(int)repeat.integer;
            if (auto testProduct = "testProduct" in *testing)
                config.testing.testProduct = testProduct.str;
            if (auto xctestArgs = "xctestArgs" in *testing)
                config.testing.xctestArgs = xctestArgs.array.map!(e => e.str).array;
            if (auto enableTestDiscovery = "enableTestDiscovery" in *testing)
                config.testing.enableTestDiscovery = enableTestDiscovery.type == JSONType.true_;
            if (auto experimentalTestOutput = "experimentalTestOutput" in *testing)
                config.testing.experimentalTestOutput = experimentalTestOutput.type == JSONType.true_;
        }
        
        // Documentation configuration
        if (auto documentation = "documentation" in json)
        {
            if (auto enabled = "enabled" in *documentation)
                config.documentation.enabled = enabled.type == JSONType.true_;
            if (auto outputPath = "outputPath" in *documentation)
                config.documentation.outputPath = outputPath.str;
            if (auto hostingBasePath = "hostingBasePath" in *documentation)
                config.documentation.hostingBasePath = hostingBasePath.str;
            if (auto transformForStaticHosting = "transformForStaticHosting" in *documentation)
                config.documentation.transformForStaticHosting = transformForStaticHosting.type == JSONType.true_;
            if (auto symbolGraphOptions = "symbolGraphOptions" in *documentation)
                config.documentation.symbolGraphOptions = symbolGraphOptions.array.map!(e => e.str).array;
            if (auto experimentalFeatures = "experimentalFeatures" in *documentation)
                config.documentation.experimentalFeatures = experimentalFeatures.type == JSONType.true_;
            if (auto enableDiagnostics = "enableDiagnostics" in *documentation)
                config.documentation.enableDiagnostics = enableDiagnostics.type == JSONType.true_;
        }
        
        // XCFramework configuration
        if (auto xcframework = "xcframework" in json)
        {
            if (auto enabled = "enabled" in *xcframework)
                config.xcframework.enabled = enabled.type == JSONType.true_;
            if (auto outputPath = "outputPath" in *xcframework)
                config.xcframework.outputPath = outputPath.str;
            if (auto frameworkName = "frameworkName" in *xcframework)
                config.xcframework.frameworkName = frameworkName.str;
            if (auto allowInternalDistribution = "allowInternalDistribution" in *xcframework)
                config.xcframework.allowInternalDistribution = allowInternalDistribution.type == JSONType.true_;
            
            if (auto platforms = "platforms" in *xcframework)
            {
                foreach (ref platformVal; platforms.array)
                {
                    immutable platStr = platformVal.str.toLower;
                    SwiftPlatform plat;
                    switch (platStr)
                    {
                        case "macos": plat = SwiftPlatform.macOS; break;
                        case "ios": plat = SwiftPlatform.iOS; break;
                        case "iossimulator": plat = SwiftPlatform.iOSSimulator; break;
                        case "tvos": plat = SwiftPlatform.tvOS; break;
                        case "watchos": plat = SwiftPlatform.watchOS; break;
                        default: plat = SwiftPlatform.macOS; break;
                    }
                    config.xcframework.platforms ~= plat;
                }
            }
        }
        
        // Cross-compilation configuration
        if (auto crossCompilation = "crossCompilation" in json)
        {
            if (auto targetTriple = "targetTriple" in *crossCompilation)
                config.crossCompilation.targetTriple = targetTriple.str;
            if (auto sdkPath = "sdkPath" in *crossCompilation)
                config.crossCompilation.sdkPath = sdkPath.str;
            if (auto arch = "arch" in *crossCompilation)
                config.crossCompilation.arch = arch.str;
            if (auto flags = "flags" in *crossCompilation)
                config.crossCompilation.flags = flags.array.map!(e => e.str).array;
        }
        
        // Environment variables
        if (auto env = "env" in json)
        {
            foreach (string key, ref value; env.object)
                config.env[key] = value.str;
        }
        
        return config;
    }
}

/// Build result for Swift compilation
struct SwiftBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Compilation warnings
    string[] warnings;
    
    /// SwiftLint warnings
    string[] lintWarnings;
    bool hadLintErrors;
    
    /// Format issues
    string[] formatIssues;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
    
    /// Generated artifacts
    string frameworkPath;
    string xcframeworkPath;
    string documentationPath;
    string symbolGraphPath;
}

