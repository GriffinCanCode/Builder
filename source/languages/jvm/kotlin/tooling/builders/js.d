module languages.jvm.kotlin.tooling.builders.js;

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

/// Kotlin/JS builder for JavaScript output
class JSBuilder : KotlinBuilder
{
    override KotlinBuildResult build(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        KotlinBuildResult result;
        
        Logger.debug_("Building Kotlin/JS");
        
        // Determine output path
        string outputPath;
        if (!target.outputPath.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name ~ ".js");
        }
        
        string outputDir = dirName(outputPath);
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build with kotlin-js compiler
        auto cmd = ["kotlinc-js"];
        
        // IR backend (default for modern Kotlin)
        cmd ~= ["-Xir-produce-js"];
        
        // Module kind
        cmd ~= ["-module-kind", "umd"]; // or "commonjs", "amd", "plain"
        
        // Source map
        cmd ~= ["-source-map"];
        
        // Compiler flags
        cmd ~= config.compilerFlags;
        
        // Add language version
        if (config.languageVersion.major > 0)
            cmd ~= ["-language-version", config.languageVersion.toString()];
        
        // Add API version
        if (config.apiVersion.major > 0)
            cmd ~= ["-api-version", config.apiVersion.toString()];
        
        // Add sources
        cmd ~= sources;
        
        // Output
        cmd ~= ["-output", outputPath];
        
        Logger.debug_("Executing: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "kotlinc-js compilation failed: " ~ res.output;
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
        auto result = execute(["kotlinc-js", "-version"]);
        return result.status == 0;
    }
    
    override string name() const
    {
        return "JS";
    }
    
    override bool supportsMode(KotlinBuildMode mode)
    {
        return mode == KotlinBuildMode.JS;
    }
}

