module languages.compiled.swift.config.build;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

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
    string toString() const @system pure
    {
        import std.format : format;
        
        if (patch == 0)
            return format!"%d.%d"(major, minor);
        return format!"%d.%d.%d"(major, minor, patch);
    }
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

/// Swift Build Configuration
struct SwiftBuildConfig_
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
    
    /// Platform targets
    PlatformTarget[] platforms;
    
    /// Library type (for library projects)
    SwiftLibraryType libraryType = SwiftLibraryType.Auto;
    
    /// Product name to build
    string product;
    
    /// Target name to build
    string target;
    
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

