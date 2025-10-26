module languages.scripting.javascript.bundlers.base;

import languages.scripting.javascript.bundlers.config;
import config.schema.schema;

/// Base interface for JavaScript bundlers
interface Bundler
{
    /// Bundle JavaScript files
    BundleResult bundle(
        string[] sources,
        JSConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    /// Check if bundler is available on system
    bool isAvailable();
    
    /// Get bundler name
    string name() const;
    
    /// Get bundler version
    string getVersion();
}

/// Factory for creating bundlers
class BundlerFactory
{
    /// Create bundler based on type
    static Bundler create(BundlerType type, JSConfig config)
    {
        import languages.scripting.javascript.bundlers.esbuild;
        import languages.scripting.javascript.bundlers.webpack;
        import languages.scripting.javascript.bundlers.rollup;
        
        final switch (type)
        {
            case BundlerType.Auto:
                return createAuto(config);
            case BundlerType.ESBuild:
                return new ESBuildBundler();
            case BundlerType.Webpack:
                return new WebpackBundler();
            case BundlerType.Rollup:
                return new RollupBundler();
            case BundlerType.None:
                return new NullBundler();
        }
    }
    
    /// Auto-detect best available bundler
    private static Bundler createAuto(JSConfig config)
    {
        import languages.scripting.javascript.bundlers.esbuild;
        import languages.scripting.javascript.bundlers.webpack;
        import languages.scripting.javascript.bundlers.rollup;
        
        // Priority: esbuild > webpack > rollup
        // esbuild is fastest and handles most cases
        auto esbuild = new ESBuildBundler();
        if (esbuild.isAvailable())
            return esbuild;
        
        // Webpack for complex projects
        auto webpack = new WebpackBundler();
        if (webpack.isAvailable())
            return webpack;
        
        // Rollup for libraries
        auto rollup = new RollupBundler();
        if (rollup.isAvailable())
            return rollup;
        
        // Fallback to null bundler (validation only)
        return new NullBundler();
    }
}

/// Null bundler - validates but doesn't bundle
class NullBundler : Bundler
{
    BundleResult bundle(
        string[] sources,
        JSConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        import std.process : execute;
        import std.path : buildPath;
        import utils.files.hash : FastHash;
        
        BundleResult result;
        
        // Just validate syntax with Node.js
        foreach (source; sources)
        {
            auto cmd = ["node", "--check", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Syntax error in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(sources);
        
        // Sources are outputs in this case
        result.outputs = sources;
        
        return result;
    }
    
    bool isAvailable()
    {
        import std.process : execute;
        auto res = execute(["node", "--version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        import std.process : execute;
        auto res = execute(["node", "--version"]);
        if (res.status == 0)
            return res.output;
        return "unknown";
    }
}

