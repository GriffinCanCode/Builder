module languages.compiled.rust.tooling.builders.base;

import std.range;
import languages.compiled.rust.core.config;
import infrastructure.config.schema.schema;
import engine.caching.actions.action : ActionCache;

/// Base interface for Rust builders
interface RustBuilder
{
    /// Build Rust project
    RustCompileResult build(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get builder version
    string getVersion();
    
    /// Supports specific features
    bool supportsFeature(string feature);
}

/// Factory for creating Rust builders
class RustBuilderFactory
{
    /// Create builder based on compiler type with optional action cache
    static RustBuilder create(RustCompiler compiler, RustConfig config, ActionCache cache = null)
    {
        import languages.compiled.rust.tooling.builders.cargo;
        import languages.compiled.rust.tooling.builders.rustc;
        import engine.caching.actions.action : ActionCache;
        
        final switch (compiler)
        {
            case RustCompiler.Auto:
                return createAuto(config, cache);
            case RustCompiler.Cargo:
                return new CargoBuilder(cache);
            case RustCompiler.Rustc:
                return new RustcBuilder();
        }
    }
    
    /// Auto-detect best available builder with optional action cache
    private static RustBuilder createAuto(RustConfig config, ActionCache cache)
    {
        import languages.compiled.rust.tooling.builders.cargo;
        import languages.compiled.rust.tooling.builders.rustc;
        import languages.compiled.rust.analysis.manifest;
        
        // If Cargo.toml exists or is specified, prefer cargo
        if (!config.manifest.empty)
        {
            auto cargo = new CargoBuilder(cache);
            if (cargo.isAvailable())
                return cargo;
        }
        
        // Try to find Cargo.toml
        auto manifest = CargoParser.findManifest([config.entry]);
        if (!manifest.empty)
        {
            auto cargo = new CargoBuilder(cache);
            if (cargo.isAvailable())
                return cargo;
        }
        
        // Fallback to rustc for simple projects
        auto rustc = new RustcBuilder();
        if (rustc.isAvailable())
            return rustc;
        
        // Default to cargo
        return new CargoBuilder(cache);
    }
}

/// Null builder - check only
class NullRustBuilder : RustBuilder
{
    RustCompileResult build(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        import std.process : execute;
        import infrastructure.utils.files.hash : FastHash;
        
        RustCompileResult result;
        
        // Just check syntax
        foreach (source; sources)
        {
            auto cmd = ["rustc", "--crate-type", "lib", "--emit", "metadata", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Syntax check failed in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(sources);
        result.outputs = sources.dup;
        
        return result;
    }
    
    bool isAvailable()
    {
        import std.process : execute;
        auto res = execute(["rustc", "--version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        import languages.compiled.rust.managers.toolchain;
        return Rustc.getVersion();
    }
    
    bool supportsFeature(string feature)
    {
        return feature == "check";
    }
}


