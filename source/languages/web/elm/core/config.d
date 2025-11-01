module languages.web.elm.core.config;

import std.json;

/// Elm build mode
enum ElmBuildMode
{
    /// Development mode - no optimization
    Debug,
    /// Production mode - full optimization
    Optimize,
    /// Watch mode with automatic recompilation
    Watch
}

/// Elm output target
enum ElmOutputTarget
{
    /// JavaScript output (standard)
    JavaScript,
    /// HTML output with embedded JavaScript
    HTML
}

/// Elm-specific configuration
struct ElmConfig
{
    /// Build mode
    ElmBuildMode mode = ElmBuildMode.Debug;
    
    /// Output target
    ElmOutputTarget outputTarget = ElmOutputTarget.JavaScript;
    
    /// Entry file (Main.elm)
    string entry;
    
    /// Output file path
    string output;
    
    /// Enable optimization (production builds)
    bool optimize = false;
    
    /// Enable debug mode
    bool debugMode = true;
    
    /// Generate documentation
    bool docs = false;
    
    /// Run elm-format before build
    bool format = false;
    
    /// Run elm-review for code quality
    bool review = false;
    
    /// Install dependencies before build
    bool installDeps = true;
    
    /// Elm version to use (empty = system default)
    string elmVersion;
    
    /// Additional compiler flags
    string[] compilerFlags;
    
    /// Source directories (from elm.json)
    string[] sourceDirs;
    
    /// Parse from JSON
    static ElmConfig fromJSON(JSONValue json)
    {
        ElmConfig config;
        
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr)
            {
                case "debug": config.mode = ElmBuildMode.Debug; break;
                case "optimize": config.mode = ElmBuildMode.Optimize; break;
                case "watch": config.mode = ElmBuildMode.Watch; break;
                default: config.mode = ElmBuildMode.Debug; break;
            }
        }
        
        if ("outputTarget" in json)
        {
            string targetStr = json["outputTarget"].str;
            switch (targetStr)
            {
                case "javascript": case "js": config.outputTarget = ElmOutputTarget.JavaScript; break;
                case "html": config.outputTarget = ElmOutputTarget.HTML; break;
                default: config.outputTarget = ElmOutputTarget.JavaScript; break;
            }
        }
        
        if ("entry" in json) config.entry = json["entry"].str;
        if ("output" in json) config.output = json["output"].str;
        if ("elmVersion" in json) config.elmVersion = json["elmVersion"].str;
        
        if ("optimize" in json) config.optimize = json["optimize"].type == JSONType.true_;
        if ("debug" in json) config.debugMode = json["debug"].type == JSONType.true_;
        if ("docs" in json) config.docs = json["docs"].type == JSONType.true_;
        if ("format" in json) config.format = json["format"].type == JSONType.true_;
        if ("review" in json) config.review = json["review"].type == JSONType.true_;
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        
        if ("compilerFlags" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.compilerFlags = json["compilerFlags"].array.map!(e => e.str).array;
        }
        
        if ("sourceDirs" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.sourceDirs = json["sourceDirs"].array.map!(e => e.str).array;
        }
        
        // Auto-configure based on mode
        if (config.mode == ElmBuildMode.Optimize)
        {
            config.optimize = true;
            config.debugMode = false;
        }
        
        return config;
    }
}

/// Elm compilation result
struct ElmCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    string[] warnings;
}

