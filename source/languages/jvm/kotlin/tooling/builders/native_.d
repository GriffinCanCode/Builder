module languages.jvm.kotlin.tooling.builders.native_;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.jvm.kotlin.tooling.builders.base;
import languages.jvm.kotlin.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Kotlin/Native builder for native executables
class NativeBuilder : KotlinBuilder
{
    override KotlinBuildResult build(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        KotlinBuildResult result;
        
        Logger.debug_("Building Kotlin/Native executable");
        
        // Determine output path
        string outputPath;
        if (!target.outputPath.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name);
        }
        
        string outputDir = dirName(outputPath);
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build with kotlin-native compiler
        auto cmd = ["kotlinc-native"];
        
        // Add target platform
        if (!config.native.target.empty)
        {
            cmd ~= ["-target", config.native.target];
        }
        
        // Optimization
        if (config.native.optimization == "release")
        {
            cmd ~= ["-opt"];
        }
        else if (config.native.optimization == "debug")
        {
            cmd ~= ["-g"];
        }
        
        // Libraries
        foreach (lib; config.native.libraries)
        {
            cmd ~= ["-l", lib];
        }
        
        // Include directories
        foreach (incDir; config.native.includeDirs)
        {
            cmd ~= ["-includedir", incDir];
        }
        
        // Static linking
        if (config.native.staticLink)
        {
            cmd ~= ["-Xstatic-framework"];
        }
        
        // C interop
        if (config.native.cinterop && !config.native.cinteropDef.empty)
        {
            cmd ~= ["-cinterop", config.native.cinteropDef];
        }
        
        // Compiler flags
        cmd ~= config.compilerFlags;
        
        // Add sources
        cmd ~= sources;
        
        // Output
        cmd ~= ["-o", outputPath];
        
        Logger.debug_("Executing: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "kotlin-native compilation failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        
        if (exists(outputPath))
        {
            result.outputHash = FastHash.hashFile(outputPath);
        }
        
        return result;
    }
    
    override bool isAvailable()
    {
        auto result = execute(["kotlinc-native", "-version"]);
        return result.status == 0;
    }
    
    override string name() const
    {
        return "Native";
    }
    
    override bool supportsMode(KotlinBuildMode mode)
    {
        return mode == KotlinBuildMode.Native;
    }
}

