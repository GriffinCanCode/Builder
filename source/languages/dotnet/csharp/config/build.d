module languages.dotnet.csharp.config.build;

import std.json;
import std.conv;

/// C# build modes
enum CSharpBuildMode
{
    Standard,    /// Standard DLL or EXE
    SingleFile,  /// Single-file publish
    ReadyToRun,  /// Ready-to-run (R2R) with ahead-of-time compilation
    NativeAOT,   /// Native AOT compilation (.NET 7+)
    Trimmed,     /// Trimmed publish (IL trimming)
    NuGet,       /// NuGet package (.nupkg)
    Compile      /// Compilation only, no publishing
}

/// Build tool selection
enum CSharpBuildTool
{
    Auto,     /// Auto-detect from project structure
    DotNet,   /// dotnet CLI (recommended)
    MSBuild,  /// MSBuild directly
    Direct,   /// Direct csc compiler (legacy)
    CSC,      /// No build tool (legacy)
    None      /// None - manual control
}

/// .NET target framework
enum DotNetFramework
{
    Auto,          /// Auto-detect from project
    Net48,         /// .NET Framework 4.8 (Windows only)
    Net472,        /// .NET Framework 4.7.2 (Windows only)
    Net461,        /// .NET Framework 4.6.1 (Windows only)
    Net6,          /// .NET 6 (LTS)
    Net7,          /// .NET 7
    Net8,          /// .NET 8 (LTS)
    Net9,          /// .NET 9
    NetStandard21, /// .NET Standard 2.1
    NetStandard20, /// .NET Standard 2.0
    Mono,          /// Mono
    Custom         /// Custom/Other
}

/// Project types
enum CSharpProjectType
{
    Console,        /// Console application
    Library,        /// Class library
    WebAPI,         /// ASP.NET Core Web API
    WebMVC,         /// ASP.NET Core MVC
    BlazorWasm,     /// Blazor WebAssembly
    BlazorServer,   /// Blazor Server
    MAUI,           /// .NET MAUI application
    WinForms,       /// Windows Forms
    WPF,            /// WPF application
    AzureFunctions, /// Azure Functions
    GRPC,           /// gRPC service
    Worker,         /// Worker service
    RazorClassLib,  /// Razor Class Library
    Test,           /// Test project
    Custom          /// Custom
}

/// Runtime identifier for cross-platform publishing
enum RuntimeIdentifier
{
    Auto,       /// Auto-detect current platform
    WinX64,     /// Windows x64
    WinX86,     /// Windows x86
    WinArm64,   /// Windows ARM64
    LinuxX64,   /// Linux x64
    LinuxArm64, /// Linux ARM64
    LinuxArm,   /// Linux ARM32
    OsxX64,     /// macOS x64 (Intel)
    OsxArm64,   /// macOS ARM64 (Apple Silicon)
    Portable,   /// Portable (no runtime included)
    Custom      /// Custom RID
}

/// C# language version
struct CSharpVersion
{
    int major = 12;
    int minor = 0;
    
    static CSharpVersion parse(string ver) @safe
    {
        import std.string : split;
        
        CSharpVersion v;
        if (ver.empty)
            return v;
        
        auto parts = ver.split(".");
        if (parts.length >= 1)
            v.major = parts[0].to!int;
        if (parts.length >= 2)
            v.minor = parts[1].to!int;
        
        return v;
    }
    
    string toString() const @safe
    {
        import std.format : format;
        
        if (minor == 0)
            return format("%d", major);
        return format("%d.%d", major, minor);
    }
}

/// MSBuild configuration
struct MSBuildConfig
{
    bool restore = true;
    bool clean = false;
    bool rebuild = false;
    string[] properties;
    string[] targets;
    int maxCpuCount = 0;
    string verbosity = "minimal";
    bool noLogo = true;
    string[] args;
}

/// Core C# build configuration
struct CSharpBuildConfig
{
    CSharpBuildMode mode = CSharpBuildMode.Standard;
    CSharpBuildTool buildTool = CSharpBuildTool.Auto;
    CSharpProjectType projectType = CSharpProjectType.Console;
    DotNetFramework framework = DotNetFramework.Auto;
    string customFramework;
    RuntimeIdentifier runtime = RuntimeIdentifier.Auto;
    string customRuntime;
    CSharpVersion languageVersion;
    string configuration = "Release";
    MSBuildConfig msbuild;
    
    bool nullable = true;
    bool warningsAsErrors = false;
    string[] compilerArgs;
    string[] defines;
    bool optimize = true;
    bool allowUnsafe = false;
    bool deterministic = true;
}

