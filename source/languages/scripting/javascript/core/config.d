module languages.scripting.javascript.core.config;

import std.json;

/// JavaScript build modes
enum JSBuildMode
{
    /// Node.js script - no bundling, just validation
    Node,
    /// Browser bundle - full bundling with dependencies
    Bundle,
    /// Library - multiple output formats
    Library
}

/// Bundler type selection
enum BundlerType
{
    /// Auto-detect based on project
    Auto,
    /// esbuild (default, fastest)
    ESBuild,
    /// webpack (advanced features)
    Webpack,
    /// Rollup (library optimization)
    Rollup,
    /// Vite (modern dev server with HMR)
    Vite,
    /// None - skip bundling
    None
}

/// Output format for bundles
enum OutputFormat
{
    /// ES modules
    ESM,
    /// CommonJS
    CommonJS,
    /// Immediately Invoked Function Expression
    IIFE,
    /// Universal Module Definition
    UMD
}

/// Target platform
enum Platform
{
    /// Browser environment
    Browser,
    /// Node.js environment
    Node,
    /// Both (requires multiple builds)
    Neutral
}

/// JavaScript-specific configuration
struct JSConfig
{
    /// Build mode
    JSBuildMode mode = JSBuildMode.Node;
    
    /// Bundler selection
    BundlerType bundler = BundlerType.Auto;
    
    /// Entry point for bundling
    string entry;
    
    /// Target platform
    Platform platform = Platform.Node;
    
    /// Output format
    OutputFormat format = OutputFormat.CommonJS;
    
    /// Minify output
    bool minify = false;
    
    /// Generate source maps
    bool sourcemap = false;
    
    /// External packages (don't bundle)
    string[] external;
    
    /// Custom config file path
    string configFile;
    
    /// Package manager
    string packageManager = "npm";
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Target ES version (e.g., "es2020")
    string target = "es2018";
    
    /// Enable JSX/TSX support
    bool jsx = false;
    
    /// JSX factory function
    string jsxFactory = "React.createElement";
    
    /// Additional loader configurations
    string[string] loaders;
    
    /// Parse from JSON
    static JSConfig fromJSON(JSONValue json)
    {
        JSConfig config;
        
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr)
            {
                case "node": config.mode = JSBuildMode.Node; break;
                case "bundle": config.mode = JSBuildMode.Bundle; break;
                case "library": config.mode = JSBuildMode.Library; break;
                default: config.mode = JSBuildMode.Node; break;
            }
        }
        
        if ("bundler" in json)
        {
            string bundlerStr = json["bundler"].str;
            switch (bundlerStr)
            {
                case "auto": config.bundler = BundlerType.Auto; break;
                case "esbuild": config.bundler = BundlerType.ESBuild; break;
                case "webpack": config.bundler = BundlerType.Webpack; break;
                case "rollup": config.bundler = BundlerType.Rollup; break;
                case "vite": config.bundler = BundlerType.Vite; break;
                case "none": config.bundler = BundlerType.None; break;
                default: config.bundler = BundlerType.Auto; break;
            }
        }
        
        if ("entry" in json) config.entry = json["entry"].str;
        
        if ("platform" in json)
        {
            string platformStr = json["platform"].str;
            switch (platformStr)
            {
                case "browser": config.platform = Platform.Browser; break;
                case "node": config.platform = Platform.Node; break;
                case "neutral": config.platform = Platform.Neutral; break;
                default: config.platform = Platform.Node; break;
            }
        }
        
        if ("format" in json)
        {
            string formatStr = json["format"].str;
            switch (formatStr)
            {
                case "esm": config.format = OutputFormat.ESM; break;
                case "cjs": case "commonjs": config.format = OutputFormat.CommonJS; break;
                case "iife": config.format = OutputFormat.IIFE; break;
                case "umd": config.format = OutputFormat.UMD; break;
                default: config.format = OutputFormat.CommonJS; break;
            }
        }
        
        if ("minify" in json) config.minify = json["minify"].type == JSONType.true_;
        if ("sourcemap" in json) config.sourcemap = json["sourcemap"].type == JSONType.true_;
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        if ("jsx" in json) config.jsx = json["jsx"].type == JSONType.true_;
        
        if ("external" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.external = json["external"].array.map!(e => e.str).array;
        }
        
        if ("configFile" in json) config.configFile = json["configFile"].str;
        if ("packageManager" in json) config.packageManager = json["packageManager"].str;
        if ("target" in json) config.target = json["target"].str;
        if ("jsxFactory" in json) config.jsxFactory = json["jsxFactory"].str;
        
        if ("loaders" in json)
        {
            foreach (string key, value; json["loaders"].object)
            {
                config.loaders[key] = value.str;
            }
        }
        
        return config;
    }
}

/// Bundler result
struct BundleResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
}

