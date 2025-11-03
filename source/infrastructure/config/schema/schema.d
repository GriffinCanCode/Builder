module infrastructure.config.schema.schema;

import std.algorithm;
import std.array;
import std.conv;
import std.string;

/// Import Result type for error handling
import infrastructure.errors : Result, BuildError, ParseError;

/// Strongly-typed target identifier
/// Represents a fully-qualified target in the format: workspace//path:name
/// - workspace: Optional workspace name (empty for current workspace)
/// - path: Optional relative path within workspace
/// - name: Required target name
struct TargetId
{
    string workspace;  // Empty for current workspace
    string path;       // Relative path within workspace
    string name;       // Target name (required)
    
    /// Create simple target ID with just a name
    this(string name) pure nothrow @system
    {
        this("", "", name);
    }
    
    /// Create target ID with all components
    this(string workspace, string path, string name) pure nothrow @system
    {
        this.workspace = workspace;
        this.path = path;
        this.name = name;
    }
    
    /// Parse qualified target ID from string
    /// Format: "workspace//path:name" or "//path:name" or "name"
    static Result!(TargetId, BuildError) parse(string qualified) @system
    {
        if (qualified.empty)
        {
            auto error = new ParseError("Empty target ID - target identifier cannot be empty", null);
            error.addSuggestion("Provide a valid target identifier in the format 'name' or 'namespace:name'");
            error.addSuggestion("Check that the target definition has a non-empty 'name' field");
            error.addSuggestion("See docs/architecture/DSL.md for target naming conventions");
            return Result!(TargetId, BuildError).err(error);
        }
        
        string workspace = "";
        string path = "";
        string name = qualified;
        
        // Check for workspace separator "//"
        auto workspaceSep = qualified.indexOf("//");
        if (workspaceSep >= 0)
        {
            workspace = qualified[0 .. workspaceSep];
            qualified = qualified[workspaceSep + 2 .. $];
        }
        
        // Check for target name separator ":"
        auto nameSep = qualified.lastIndexOf(":");
        if (nameSep >= 0)
        {
            path = qualified[0 .. nameSep];
            name = qualified[nameSep + 1 .. $];
        }
        else
        {
            name = qualified;
        }
        
        // Validate name is not empty
        if (name.empty)
        {
            auto error = new ParseError("Target name cannot be empty in qualified ID: " ~ qualified, null);
            error.addSuggestion("Ensure target names are non-empty after namespace delimiter");
            error.addSuggestion("Format should be 'name' or 'namespace:name' where both parts are non-empty");
            error.addSuggestion("Check for trailing colons or double colons in target IDs");
            return Result!(TargetId, BuildError).err(error);
        }
        
        return Result!(TargetId, BuildError).ok(TargetId(workspace, path, name));
    }
    
    /// Convert to fully-qualified string representation
    string toString() const pure nothrow @system
    {
        if (workspace.empty && path.empty)
            return name;
        if (workspace.empty)
            return "//" ~ path ~ ":" ~ name;
        if (path.empty)
            return workspace ~ "//:" ~ name;
        return workspace ~ "//" ~ path ~ ":" ~ name;
    }
    
    /// Get simple name (without workspace/path)
    string simpleName() const pure nothrow @system
    {
        return name;
    }
    
    /// Check if this is a simple name (no workspace or path)
    bool isSimple() const pure nothrow @system
    {
        return workspace.empty && path.empty;
    }
    
    /// Equality comparison
    bool opEquals(const TargetId other) const pure nothrow @system
    {
        return workspace == other.workspace &&
               path == other.path &&
               name == other.name;
    }
    
    /// Hash for use as associative array key
    size_t toHash() const nothrow @system
    {
        size_t hash = 0;
        foreach (char c; workspace)
            hash = hash * 31 + c;
        foreach (char c; path)
            hash = hash * 31 + c;
        foreach (char c; name)
            hash = hash * 31 + c;
        return hash;
    }
    
    /// Comparison for sorting
    int opCmp(const TargetId other) const pure nothrow @system
    {
        if (workspace != other.workspace)
            return workspace < other.workspace ? -1 : 1;
        if (path != other.path)
            return path < other.path ? -1 : 1;
        if (name != other.name)
            return name < other.name ? -1 : 1;
        return 0;
    }
    
    /// Check if this ID matches a filter string
    /// Supports partial matching on name, path, or full qualified name
    bool matches(string filter) const pure nothrow @system
    {
        if (filter.empty)
            return true;
        
        import std.algorithm : canFind;
        
        // Try matching against name
        if (name.canFind(filter))
            return true;
        
        // Try matching against path
        if (!path.empty && path.canFind(filter))
            return true;
        
        // Try matching against full qualified name
        auto fullStr = toString();
        if (fullStr.canFind(filter))
            return true;
        
        return false;
    }
    
    /// Create a TargetId in the same workspace/path with different name
    /// Useful for relative target references
    TargetId withName(string newName) const pure nothrow @system
    {
        return TargetId(workspace, path, newName);
    }
    
    /// Create a TargetId in a different path (same workspace)
    TargetId withPath(string newPath) const pure nothrow @system
    {
        return TargetId(workspace, newPath, name);
    }
    
    /// Parse or create - never fails, falls back to simple name
    static TargetId parseOrSimple(string str) nothrow @system
    {
        try
        {
            auto result = parse(str);
            // Use unwrapOr to avoid throwing - falls back to simple name if parsing fails
            return result.unwrapOr(TargetId(str));
        }
        catch (Exception e)
        {
            // Fallback to simple name if parsing throws
            return TargetId(str);
        }
    }
}

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
    FSharp,
    Zig,
    Swift,
    Ruby,
    Perl,
    PHP,
    Scala,
    Elixir,
    Nim,
    Lua,
    R,
    CSS,
    Protobuf,
    OCaml,
    Haskell,
    Elm,
    Generic
}

/// Build target configuration
/// 
/// Migration to TargetId:
/// - Use `target.id` to get strongly-typed TargetId
/// - Use `target.name` for backward compatibility (string)
/// - Use `Target.withId()` to create targets with TargetId
/// - TargetId provides type safety and prevents typo bugs
struct Target
{
    string name;  // Keep for backward compatibility
    TargetType type;
    TargetLanguage language;
    string[] sources;
    string[] deps;
    string[string] env;
    string[] flags;
    string outputPath;
    string[] includes;
    
    /// Target platform for cross-compilation (e.g., "linux-arm64", "x86_64-unknown-linux-gnu")
    string platform;
    
    /// Toolchain reference (e.g., "@toolchains//arm:gcc-11", "clang-15")
    string toolchain;
    
    /// Language-specific configuration stored as JSON
    /// This allows each language handler to define its own config schema
    string[string] langConfig;
    
    /// Strongly-typed target identifier (lazily computed)
    private TargetId _id;
    private bool _idCached = false;
    
    /// Get target as TargetId (cached for performance)
    /// 
    /// Safety: This property is @system because:
    /// 1. The const-cast is safe as we only mutate cache fields (_id, _idCached)
    /// 2. The caching is logically const (doesn't change observable behavior)
    /// 3. Result unwrap operations are safe (properly handles union access)
    @property TargetId id() const @system
    {
        // Need to cast away const for caching, but logically const
        auto self = cast(Target*)&this;
        if (!self._idCached)
        {
            auto parseResult = TargetId.parse(name);
            if (parseResult.isOk)
            {
                self._id = parseResult.unwrap();
            }
            else
            {
                // Fallback: simple name if parsing fails
                self._id = TargetId(name);
            }
            self._idCached = true;
        }
        return _id;
    }
    
    /// Set target ID (updates both id and name for consistency)
    void setId(TargetId targetId)
    {
        this._id = targetId;
        this.name = targetId.toString();
        this._idCached = true;
    }
    
    /// Get fully qualified target name
    string fullName() const
    {
        return name;
    }
    
    /// Create target with TargetId
    static Target withId(TargetId id, TargetType type, TargetLanguage language)
    {
        Target target;
        target.setId(id);
        target.type = type;
        target.language = language;
        return target;
    }
}

/// Workspace configuration
struct WorkspaceConfig
{
    string root;
    Target[] targets;
    string[string] globalEnv;
    BuildOptions options;
    
    // Repository rules (external dependencies)
    import infrastructure.repository.core.types : RepositoryRule;
    RepositoryRule[] repositories;
    
    /// Find a target by name (string version for backward compatibility)
    const(Target)* findTarget(string name) const
    {
        foreach (ref target; targets)
        {
            if (target.name == name)
                return &target;
        }
        return null;
    }
    
    /// Find a target by TargetId (type-safe version)
    const(Target)* findTargetById(TargetId id) const
    {
        auto targetStr = id.toString();
        foreach (ref target; targets)
        {
            if (target.name == targetStr || target.id == id)
                return &target;
        }
        return null;
    }
    
    /// Check if workspace contains a target
    bool hasTarget(TargetId id) const
    {
        return findTargetById(id) !is null;
    }
}

/// Distributed build configuration
struct DistributedConfig
{
    bool enabled = false;                   // Enable distributed builds
    string coordinatorUrl = "";              // Coordinator URL (http://host:port)
    size_t localWorkers = 0;                // Local workers for hybrid mode (0 = distributed only)
    bool autoDiscover = true;               // Auto-discover coordinator
    
    // Remote execution settings
    bool remoteExecution = false;           // Enable remote execution (not just caching)
    string artifactStoreUrl = "";           // Artifact store URL for remote execution
    size_t minWorkers = 2;                  // Minimum worker pool size
    size_t maxWorkers = 50;                 // Maximum worker pool size
    bool enableAutoScale = true;            // Enable autoscaling
    
    /// Load from environment variables
    static DistributedConfig fromEnvironment() @safe
    {
        import std.process : environment;
        
        DistributedConfig config;
        
        immutable enabled = environment.get("BUILDER_DISTRIBUTED_ENABLED", "");
        config.enabled = (enabled == "1" || enabled == "true");
        
        config.coordinatorUrl = environment.get("BUILDER_COORDINATOR_URL", "");
        
        immutable localWorkers = environment.get("BUILDER_LOCAL_WORKERS", "");
        if (localWorkers.length > 0)
        {
            try
            {
                import std.conv : to;
                config.localWorkers = localWorkers.to!size_t;
            }
            catch (Exception) {}
        }
        
        // Remote execution settings
        immutable remoteExec = environment.get("BUILDER_REMOTE_EXECUTION", "");
        config.remoteExecution = (remoteExec == "1" || remoteExec == "true");
        
        config.artifactStoreUrl = environment.get("BUILDER_ARTIFACT_STORE_URL", "");
        
        immutable minWorkers = environment.get("BUILDER_MIN_WORKERS", "");
        if (minWorkers.length > 0)
        {
            try
            {
                import std.conv : to;
                config.minWorkers = minWorkers.to!size_t;
            }
            catch (Exception) {}
        }
        
        immutable maxWorkers = environment.get("BUILDER_MAX_WORKERS", "");
        if (maxWorkers.length > 0)
        {
            try
            {
                import std.conv : to;
                config.maxWorkers = maxWorkers.to!size_t;
            }
            catch (Exception) {}
        }
        
        immutable autoScale = environment.get("BUILDER_AUTOSCALE", "");
        if (autoScale == "0" || autoScale == "false")
            config.enableAutoScale = false;
        
        return config;
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
    DistributedConfig distributed;
}

/// Language-specific build result
struct LanguageBuildResult
{
    bool success;
    string error;
    string outputHash;
    string[] outputs;
}