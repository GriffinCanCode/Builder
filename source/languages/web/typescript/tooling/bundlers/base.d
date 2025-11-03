module languages.web.typescript.tooling.bundlers.base;

import std.array;
import languages.web.typescript.core.config;
import infrastructure.config.schema.schema;
import engine.caching.actions.action : ActionCache;

/// Base interface for TypeScript compilers/bundlers
interface TSBundler
{
    /// Compile/bundle TypeScript files
    TSCompileResult compile(
        const(string[]) sources,
        TSConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if bundler is available on system
    bool isAvailable();
    
    /// Get bundler name
    string name() const;
    
    /// Get bundler version
    string getVersion();
    
    /// Check if this bundler supports type checking
    bool supportsTypeCheck();
}

/// Factory for creating TypeScript bundlers
class TSBundlerFactory
{
    /// Create bundler based on type with optional action cache
    static TSBundler create(TSCompiler type, TSConfig config, ActionCache cache = null)
    {
        import languages.web.typescript.tooling.bundlers.tsc;
        import languages.web.typescript.tooling.bundlers.swc;
        import languages.web.typescript.tooling.bundlers.esbuild;
        import languages.web.typescript.tooling.bundlers.webpack;
        import languages.web.typescript.tooling.bundlers.rollup;
        import languages.web.typescript.tooling.bundlers.vite;
        
        final switch (type)
        {
            case TSCompiler.Auto:
                return createAuto(config, cache);
            case TSCompiler.TSC:
                return new TSCBundler(cache);
            case TSCompiler.SWC:
                return new SWCBundler();
            case TSCompiler.ESBuild:
                return new TSESBuildBundler();
            case TSCompiler.Webpack:
                return new TSWebpackBundler();
            case TSCompiler.Rollup:
                return new TSRollupBundler();
            case TSCompiler.Vite:
                return new TSViteBundler();
            case TSCompiler.None:
                return new NullTSBundler();
        }
    }
    
    /// Auto-detect best available bundler with optional action cache
    private static TSBundler createAuto(TSConfig config, ActionCache cache)
    {
        import languages.web.typescript.tooling.bundlers.tsc;
        import languages.web.typescript.tooling.bundlers.swc;
        import languages.web.typescript.tooling.bundlers.esbuild;
        import languages.web.typescript.tooling.bundlers.webpack;
        import languages.web.typescript.tooling.bundlers.rollup;
        import languages.web.typescript.tooling.bundlers.vite;
        
        // For library mode with declarations, prefer rollup (best tree-shaking) or tsc (most accurate)
        if (config.mode == TSBuildMode.Library)
        {
            if (config.declaration)
            {
                // Prefer rollup for libraries with tree-shaking
                auto rollup = new TSRollupBundler();
                if (rollup.isAvailable())
                    return rollup;
                
                // Fallback to tsc for accurate declaration files
                auto tsc = new TSCBundler(cache);
                if (tsc.isAvailable())
                    return tsc;
            }
            else
            {
                // Without declarations, prefer rollup for tree-shaking
                auto rollup = new TSRollupBundler();
                if (rollup.isAvailable())
                    return rollup;
            }
        }
        
        // For bundle mode, prefer modern bundlers with framework support
        if (config.mode == TSBuildMode.Bundle)
        {
            // Check if this is a framework project (has jsx/tsx)
            // Prefer Vite for modern framework projects
            auto vite = new TSViteBundler();
            if (vite.isAvailable())
                return vite;
            
            // Fallback to webpack for complex bundling
            auto webpack = new TSWebpackBundler();
            if (webpack.isAvailable())
                return webpack;
        }
        
        // For speed in compile mode, prefer swc > esbuild > tsc
        auto swc = new SWCBundler();
        if (swc.isAvailable())
            return swc;
        
        auto esbuild = new TSESBuildBundler();
        if (esbuild.isAvailable())
            return esbuild;
        
        auto tsc = new TSCBundler(cache);
        if (tsc.isAvailable())
            return tsc;
        
        // Fallback to null bundler (type check only)
        return new NullTSBundler();
    }
}

/// Null bundler - type checks but doesn't compile
class NullTSBundler : TSBundler
{
    TSCompileResult compile(
        const(string[]) sources,
        TSConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        import languages.web.typescript.tooling.checker;
        import infrastructure.utils.files.hash : FastHash;
        
        TSCompileResult result;
        
        // Only type check
        auto checkResult = TypeChecker.check(sources, config, workspace.root);
        
        if (!checkResult.success)
        {
            result.error = "Type check failed:\n" ~ checkResult.errors.join("\n");
            result.hadTypeErrors = true;
            result.typeErrors = checkResult.errors;
            return result;
        }
        
        result.success = true;
        result.outputs = sources.dup;
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    bool isAvailable()
    {
        import languages.web.typescript.tooling.checker;
        return TypeChecker.isTSCAvailable();
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        import languages.web.typescript.tooling.checker;
        return TypeChecker.getTSCVersion();
    }
    
    bool supportsTypeCheck()
    {
        return true;
    }
}

