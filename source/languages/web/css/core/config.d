module languages.web.css.core.config;

import std.json;

/// CSS processor type
enum CSSProcessorType
{
    /// No processing - pure CSS
    None,
    /// PostCSS with plugins
    PostCSS,
    /// SCSS/Sass
    SCSS,
    /// Less CSS
    Less,
    /// Stylus
    Stylus,
    /// Auto-detect from file extension and config
    Auto
}

/// CSS framework/utility integration
enum CSSFramework
{
    /// No framework
    None,
    /// Tailwind CSS
    Tailwind,
    /// Bootstrap
    Bootstrap,
    /// Bulma
    Bulma
}

/// CSS build mode
enum CSSBuildMode
{
    /// Compile only
    Compile,
    /// Compile and minify
    Production,
    /// Watch mode
    Watch
}

/// CSS-specific configuration
struct CSSConfig
{
    /// Processor to use
    CSSProcessorType processor = CSSProcessorType.Auto;
    
    /// Framework integration
    CSSFramework framework = CSSFramework.None;
    
    /// Build mode
    CSSBuildMode mode = CSSBuildMode.Compile;
    
    /// Entry file
    string entry;
    
    /// Output file
    string output;
    
    /// Minify output
    bool minify = false;
    
    /// Generate source maps
    bool sourcemap = false;
    
    /// Auto-prefix for browser compatibility
    bool autoprefix = true;
    
    /// Target browsers (browserslist format)
    string[] targets;
    
    /// PostCSS plugins
    string[] postcssPlugins;
    
    /// SCSS include paths
    string[] includePaths;
    
    /// Tailwind config path
    string tailwindConfig;
    
    /// Purge unused CSS
    bool purge = false;
    
    /// Content paths for purging (Tailwind/PurgeCSS)
    string[] contentPaths;
    
    /// Parse from JSON
    static CSSConfig fromJSON(JSONValue json)
    {
        CSSConfig config;
        
        if ("processor" in json)
        {
            string procStr = json["processor"].str;
            switch (procStr)
            {
                case "none": config.processor = CSSProcessorType.None; break;
                case "postcss": config.processor = CSSProcessorType.PostCSS; break;
                case "scss": case "sass": config.processor = CSSProcessorType.SCSS; break;
                case "less": config.processor = CSSProcessorType.Less; break;
                case "stylus": config.processor = CSSProcessorType.Stylus; break;
                case "auto": config.processor = CSSProcessorType.Auto; break;
                default: config.processor = CSSProcessorType.Auto; break;
            }
        }
        
        if ("framework" in json)
        {
            string fwStr = json["framework"].str;
            switch (fwStr)
            {
                case "none": config.framework = CSSFramework.None; break;
                case "tailwind": config.framework = CSSFramework.Tailwind; break;
                case "bootstrap": config.framework = CSSFramework.Bootstrap; break;
                case "bulma": config.framework = CSSFramework.Bulma; break;
                default: config.framework = CSSFramework.None; break;
            }
        }
        
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr)
            {
                case "compile": config.mode = CSSBuildMode.Compile; break;
                case "production": config.mode = CSSBuildMode.Production; break;
                case "watch": config.mode = CSSBuildMode.Watch; break;
                default: config.mode = CSSBuildMode.Compile; break;
            }
        }
        
        if ("entry" in json) config.entry = json["entry"].str;
        if ("output" in json) config.output = json["output"].str;
        if ("tailwindConfig" in json) config.tailwindConfig = json["tailwindConfig"].str;
        
        if ("minify" in json) config.minify = json["minify"].type == JSONType.true_;
        if ("sourcemap" in json) config.sourcemap = json["sourcemap"].type == JSONType.true_;
        if ("autoprefix" in json) config.autoprefix = json["autoprefix"].type == JSONType.true_;
        if ("purge" in json) config.purge = json["purge"].type == JSONType.true_;
        
        if ("targets" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.targets = json["targets"].array.map!(e => e.str).array;
        }
        
        if ("postcssPlugins" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.postcssPlugins = json["postcssPlugins"].array.map!(e => e.str).array;
        }
        
        if ("includePaths" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.includePaths = json["includePaths"].array.map!(e => e.str).array;
        }
        
        if ("contentPaths" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.contentPaths = json["contentPaths"].array.map!(e => e.str).array;
        }
        
        return config;
    }
}

/// CSS compilation result
struct CSSCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
}

