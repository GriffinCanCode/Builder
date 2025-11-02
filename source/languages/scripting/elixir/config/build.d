module languages.scripting.elixir.config.build;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Elixir project types - distinct build strategies
enum ElixirProjectType
{
    /// Simple script - single .ex/.exs file
    Script,
    /// Mix project - standard OTP application
    MixProject,
    /// Phoenix web application
    Phoenix,
    /// Phoenix LiveView application
    PhoenixLiveView,
    /// Umbrella project - multi-app architecture
    Umbrella,
    /// Library - for publishing to Hex
    Library,
    /// Nerves - embedded systems
    Nerves,
    /// Escript - standalone executable
    Escript
}

/// Mix environment modes
enum MixEnv
{
    /// Development (default)
    Dev,
    /// Testing
    Test,
    /// Production
    Prod,
    /// Custom environment
    Custom
}

/// Release types for Mix releases
enum ReleaseType
{
    /// No release (default)
    None,
    /// Mix release (Elixir 1.9+)
    MixRelease,
    /// Distillery release (legacy)
    Distillery,
    /// Burrito - cross-platform wrapper
    Burrito,
    /// Bakeware - self-extracting executable
    Bakeware
}

/// OTP application types
enum OTPAppType
{
    /// Standard OTP application with supervision tree
    Application,
    /// Library (no application callback)
    Library,
    /// Umbrella application
    Umbrella,
    /// Task (single-purpose executable)
    Task
}

/// Elixir version specification
struct ElixirVersion
{
    /// Major version (e.g., 1)
    int major = 1;
    
    /// Minor version (e.g., 15)
    int minor = 15;
    
    /// Patch version
    int patch = 0;
    
    /// OTP version requirement (e.g., 26)
    string otpVersion;
    
    /// Specific Elixir path (overrides version)
    string elixirPath;
    
    /// Use asdf for version management
    bool useAsdf = false;
    
    /// Convert to version string
    string toString() const @system pure
    {
        import std.format : format;
        
        if (patch == 0)
            return format!"%d.%d"(major, minor);
        return format!"%d.%d.%d"(major, minor, patch);
    }
}

/// Mix project configuration
struct MixProjectConfig
{
    /// Project name
    string name;
    
    /// Application name (atom)
    string app;
    
    /// Version
    string version_;
    
    /// Elixir version requirement
    string elixirVersion;
    
    /// Build embedded (for releases)
    bool buildEmbedded = false;
    
    /// Start permanent (for releases)
    bool startPermanent = false;
    
    /// Preferred CLI environment
    string preferredCliEnv;
    
    /// Consolidate protocols
    bool consolidateProtocols = true;
    
    /// Build path
    string buildPath = "_build";
    
    /// Deps path
    string depsPath = "deps";
    
    /// Mix exs path
    string mixExsPath = "mix.exs";
}

/// Phoenix framework configuration
struct PhoenixConfig
{
    /// Enable Phoenix
    bool enabled = false;
    
    /// Phoenix version
    string version_;
    
    /// Enable LiveView
    bool liveView = false;
    
    /// LiveView version
    string liveViewVersion;
    
    /// Ecto repository
    bool ecto = false;
    
    /// Database adapter (postgres, mysql, sqlite)
    string database;
    
    /// Compile assets
    bool compileAssets = true;
    
    /// Asset build tool (esbuild, webpack, vite)
    string assetTool = "esbuild";
    
    /// Run migrations before deploy
    bool runMigrations = false;
    
    /// Generate static assets
    bool digestAssets = false;
    
    /// Endpoint module
    string endpoint;
    
    /// Web module
    string webModule;
    
    /// HTTP port
    int port = 4000;
    
    /// Enable PubSub
    bool pubSub = true;
}

/// Release configuration
struct ReleaseConfig
{
    /// Release name
    string name;
    
    /// Release type
    ReleaseType type = ReleaseType.None;
    
    /// Release version
    string version_;
    
    /// Applications to include
    string[] applications;
    
    /// Include ERTS
    bool includeErts = true;
    
    /// Include executables
    bool includeExecutables = true;
    
    /// Strip beams
    bool stripBeams = false;
    
    /// Cookie
    string cookie;
    
    /// Steps
    string[] steps;
    
    /// Path
    string path = "_build";
    
    /// Quiet
    bool quiet = false;
    
    /// Overwrite
    bool overwrite = false;
}

/// Nerves configuration
struct NervesConfig
{
    string target;
    string system;
    string version_;
}

/// Elixir Build Configuration
struct ElixirBuildConfig
{
    /// Project type
    ElixirProjectType projectType = ElixirProjectType.MixProject;
    
    /// Mix environment
    MixEnv mixEnv = MixEnv.Dev;
    
    /// Custom environment name
    string customEnv;
    
    /// OTP application type
    OTPAppType appType = OTPAppType.Application;
    
    /// Elixir version
    ElixirVersion elixirVersion;
    
    /// Mix project configuration
    MixProjectConfig mixProject;
    
    /// Phoenix configuration
    PhoenixConfig phoenix;
    
    /// Release configuration
    ReleaseConfig release;
    
    /// Nerves configuration
    NervesConfig nerves;
    
    /// Compile warnings as errors
    bool warningsAsErrors = false;
    
    /// Debug info
    bool debugInfo = true;
    
    /// Verbose output
    bool verbose = false;
    
    /// Force compile
    bool force = false;
    
    /// All warnings
    bool allWarnings = false;
    
    /// No deps check
    bool noDepsCheck = false;
    
    /// No archives check
    bool noArchivesCheck = false;
    
    /// No optional deps
    bool noOptionalDeps = false;
    
    /// Compiler options
    string[] compilerOpts;
    
    /// Compile protocols
    bool compileProtocols = true;
    
    /// Environment variables
    string[string] env;
}

