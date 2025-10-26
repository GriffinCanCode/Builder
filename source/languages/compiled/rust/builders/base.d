module languages.compiled.rust.builders.base;

import languages.compiled.rust.config;
import config.schema.schema;

/// Base interface for Rust builders
interface RustBuilder
{
    /// Build Rust project
    RustCompileResult build(
        string[] sources,
        RustConfig config,
        Target target,
        WorkspaceConfig workspace
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
    /// Create builder based on compiler type
    static RustBuilder create(RustCompiler compiler, RustConfig config)
    {
        import languages.compiled.rust.builders.cargo;
        import languages.compiled.rust.builders.rustc;
        
        final switch (compiler)
        {
            case RustCompiler.Auto:
                return createAuto(config);
            case RustCompiler.Cargo:
                return new CargoBuilder();
            case RustCompiler.Rustc:
                return new RustcBuilder();
        }
    }
    
    /// Auto-detect best available builder
    private static RustBuilder createAuto(RustConfig config)
    {
        import languages.compiled.rust.builders.cargo;
        import languages.compiled.rust.builders.rustc;
        import languages.compiled.rust.manifest;
        
        // If Cargo.toml exists or is specified, prefer cargo
        if (!config.manifest.empty)
        {
            auto cargo = new CargoBuilder();
            if (cargo.isAvailable())
                return cargo;
        }
        
        // Try to find Cargo.toml
        auto manifest = CargoParser.findManifest([config.entry]);
        if (!manifest.empty)
        {
            auto cargo = new CargoBuilder();
            if (cargo.isAvailable())
                return cargo;
        }
        
        // Fallback to rustc for simple projects
        auto rustc = new RustcBuilder();
        if (rustc.isAvailable())
            return rustc;
        
        // Default to cargo
        return new CargoBuilder();
    }
}

/// Null builder - check only
class NullRustBuilder : RustBuilder
{
    RustCompileResult build(
        string[] sources,
        RustConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        import std.process : execute;
        import utils.files.hash : FastHash;
        
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
        result.outputs = sources;
        
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
        import languages.compiled.rust.toolchain;
        return RustCompiler.getVersion();
    }
    
    bool supportsFeature(string feature)
    {
        return feature == "check";
    }
}


