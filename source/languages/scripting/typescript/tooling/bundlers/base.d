module languages.scripting.typescript.tooling.bundlers.base;

import std.array;
import languages.scripting.typescript.core.config;
import config.schema.schema;

/// Base interface for TypeScript compilers/bundlers
interface TSBundler
{
    /// Compile/bundle TypeScript files
    TSCompileResult compile(
        string[] sources,
        TSConfig config,
        Target target,
        WorkspaceConfig workspace
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
    /// Create bundler based on type
    static TSBundler create(TSCompiler type, TSConfig config)
    {
        import languages.scripting.typescript.tooling.bundlers.tsc;
        import languages.scripting.typescript.tooling.bundlers.swc;
        import languages.scripting.typescript.tooling.bundlers.esbuild;
        
        final switch (type)
        {
            case TSCompiler.Auto:
                return createAuto(config);
            case TSCompiler.TSC:
                return new TSCBundler();
            case TSCompiler.SWC:
                return new SWCBundler();
            case TSCompiler.ESBuild:
                return new TSESBuildBundler();
            case TSCompiler.None:
                return new NullTSBundler();
        }
    }
    
    /// Auto-detect best available bundler
    private static TSBundler createAuto(TSConfig config)
    {
        import languages.scripting.typescript.tooling.bundlers.tsc;
        import languages.scripting.typescript.tooling.bundlers.swc;
        import languages.scripting.typescript.tooling.bundlers.esbuild;
        
        // For library mode with declarations, prefer tsc (most accurate)
        if (config.mode == TSBuildMode.Library && config.declaration)
        {
            auto tsc = new TSCBundler();
            if (tsc.isAvailable())
                return tsc;
        }
        
        // For speed, prefer swc > esbuild > tsc
        auto swc = new SWCBundler();
        if (swc.isAvailable())
            return swc;
        
        auto esbuild = new TSESBuildBundler();
        if (esbuild.isAvailable())
            return esbuild;
        
        auto tsc = new TSCBundler();
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
        string[] sources,
        TSConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        import languages.scripting.typescript.tooling.checker;
        import utils.files.hash : FastHash;
        
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
        result.outputs = sources;
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    bool isAvailable()
    {
        import languages.scripting.typescript.tooling.checker;
        return TypeChecker.isTSCAvailable();
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        import languages.scripting.typescript.tooling.checker;
        return TypeChecker.getTSCVersion();
    }
    
    bool supportsTypeCheck()
    {
        return true;
    }
}

