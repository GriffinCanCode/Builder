module languages.compiled.zig.builders.base;

import std.algorithm;
import std.range;
import std.string;
import languages.compiled.zig.core.config;
import config.schema.schema;

/// Base interface for Zig builders
interface ZigBuilder
{
    /// Build Zig project
    ZigCompileResult build(
        string[] sources,
        ZigConfig config,
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

/// Factory for creating Zig builders
class ZigBuilderFactory
{
    /// Create builder based on type
    static ZigBuilder create(ZigBuilderType builderType, ZigConfig config)
    {
        import languages.compiled.zig.builders.build;
        import languages.compiled.zig.builders.compile;
        
        final switch (builderType)
        {
            case ZigBuilderType.Auto:
                return createAuto(config);
            case ZigBuilderType.BuildZig:
                return new BuildZigBuilder();
            case ZigBuilderType.Compile:
                return new CompileBuilder();
        }
    }
    
    /// Create builder from string name
    static ZigBuilder createFromName(string name, ZigConfig config)
    {
        import languages.compiled.zig.builders.build;
        import languages.compiled.zig.builders.compile;
        
        switch (name.toLower)
        {
            case "auto":
                return createAuto(config);
            case "build-zig":
            case "build":
                return new BuildZigBuilder();
            case "compile":
            case "direct":
                return new CompileBuilder();
            default:
                return createAuto(config);
        }
    }
    
    /// Auto-detect best available builder
    static ZigBuilder createAuto(ZigConfig config)
    {
        import languages.compiled.zig.builders.build;
        import languages.compiled.zig.builders.compile;
        import languages.compiled.zig.analysis.builder;
        
        // If build.zig path is specified or exists, prefer BuildZig
        if (!config.buildZig.path.empty || BuildZigParser.isBuildZigProject("."))
        {
            auto buildZig = new BuildZigBuilder();
            if (buildZig.isAvailable())
                return buildZig;
        }
        
        // Fallback to direct compilation
        auto compile = new CompileBuilder();
        if (compile.isAvailable())
            return compile;
        
        // Default to BuildZig
        return new BuildZigBuilder();
    }
}

/// Null builder - check only
class NullZigBuilder : ZigBuilder
{
    ZigCompileResult build(
        string[] sources,
        ZigConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        import std.process : execute;
        import utils.files.hash : FastHash;
        
        ZigCompileResult result;
        
        // Just check syntax with ast-check
        foreach (source; sources)
        {
            auto cmd = ["zig", "ast-check", source];
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
        auto res = execute(["zig", "version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        import languages.compiled.zig.tooling.tools;
        return ZigTools.getZigVersion();
    }
    
    bool supportsFeature(string feature)
    {
        return feature == "check";
    }
}


