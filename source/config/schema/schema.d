module config.schema.schema;

import std.algorithm;
import std.array;
import std.conv;

/// Target type enumeration
enum TargetType
{
    Executable,
    Library,
    Test,
    Custom
}

/// Supported languages
enum TargetLanguage
{
    D,
    Python,
    JavaScript,
    TypeScript,
    Go,
    Rust,
    Cpp,
    C,
    Java,
    Kotlin,
    CSharp,
    Zig,
    Swift,
    Ruby,
    PHP,
    Scala,
    Elixir,
    Nim,
    Lua,
    Generic
}

/// Build target configuration
struct Target
{
    string name;
    TargetType type;
    TargetLanguage language;
    string[] sources;
    string[] deps;
    string[string] env;
    string[] flags;
    string outputPath;
    string[] includes;
    
    /// Get fully qualified target name
    string fullName() const
    {
        return name;
    }
}

/// Workspace configuration
struct WorkspaceConfig
{
    string root;
    Target[] targets;
    string[string] globalEnv;
    BuildOptions options;
    
    /// Find a target by name
    Target* findTarget(string name)
    {
        foreach (ref target; targets)
        {
            if (target.name == name)
                return &target;
        }
        return null;
    }
}

/// Build options
struct BuildOptions
{
    bool verbose;
    bool incremental = true;
    bool parallel = true;
    size_t maxJobs = 0; // 0 = auto
    string cacheDir = ".builder-cache";
    string outputDir = "bin";
}

/// Language-specific build result
struct LanguageBuildResult
{
    bool success;
    string error;
    string outputHash;
    string[] outputs;
}

/// Import Result type for new error handling
import errors : Result, BuildError;

