module config.schema.schema;

import std.algorithm;
import std.array;
import std.conv;
import std.string;

/// Import Result type for error handling
import errors : Result, BuildError, ParseError;

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
    this(string name) pure nothrow @safe
    {
        this("", "", name);
    }
    
    /// Create target ID with all components
    this(string workspace, string path, string name) pure nothrow @safe
    {
        this.workspace = workspace;
        this.path = path;
        this.name = name;
    }
    
    /// Parse qualified target ID from string
    /// Format: "workspace//path:name" or "//path:name" or "name"
    static Result!(TargetId, BuildError) parse(string qualified) @safe
    {
        if (qualified.empty)
        {
            auto error = new ParseError("Empty target ID", null);
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
            auto error = new ParseError("Target name cannot be empty in: " ~ qualified, null);
            return Result!(TargetId, BuildError).err(error);
        }
        
        return Result!(TargetId, BuildError).ok(TargetId(workspace, path, name));
    }
    
    /// Convert to fully-qualified string representation
    string toString() const pure nothrow @safe
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
    string simpleName() const pure nothrow @safe
    {
        return name;
    }
    
    /// Check if this is a simple name (no workspace or path)
    bool isSimple() const pure nothrow @safe
    {
        return workspace.empty && path.empty;
    }
    
    /// Equality comparison
    bool opEquals(const TargetId other) const pure nothrow @safe
    {
        return workspace == other.workspace &&
               path == other.path &&
               name == other.name;
    }
    
    /// Hash for use as associative array key
    size_t toHash() const nothrow @safe
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
    int opCmp(const TargetId other) const pure nothrow @safe
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
    bool matches(string filter) const pure nothrow @safe
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
    TargetId withName(string newName) const pure nothrow @safe
    {
        return TargetId(workspace, path, newName);
    }
    
    /// Create a TargetId in a different path (same workspace)
    TargetId withPath(string newPath) const pure nothrow @safe
    {
        return TargetId(workspace, newPath, name);
    }
    
    /// Parse or create - never fails, falls back to simple name
    static TargetId parseOrSimple(string str) nothrow @safe
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
    PHP,
    Scala,
    Elixir,
    Nim,
    Lua,
    R,
    CSS,
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
    
    /// Language-specific configuration stored as JSON
    /// This allows each language handler to define its own config schema
    string[string] langConfig;
    
    /// Strongly-typed target identifier (lazily computed)
    private TargetId _id;
    private bool _idCached = false;
    
    /// Get target as TargetId (cached for performance)
    /// 
    /// Safety: This property is @trusted because:
    /// 1. The const-cast is safe as we only mutate cache fields (_id, _idCached)
    /// 2. The caching is logically const (doesn't change observable behavior)
    /// 3. Result unwrap operations are safe (properly handles union access)
    @property TargetId id() const @trusted
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