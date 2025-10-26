module languages.scripting.r.builders.script;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import languages.base.base : LanguageBuildResult;
import config.schema.schema : WorkspaceConfig, Target;
import languages.scripting.r.config;
import languages.scripting.r.builders.base;
import languages.scripting.r.checker;
import utils.files.hash;
import utils.logging.logger;

/// Script builder - creates executable wrappers for R scripts
class RScriptBuilder : RBuilder
{
    override LanguageBuildResult build(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string rCmd
    )
    {
        LanguageBuildResult result;
        
        if (target.sources.empty)
        {
            result.error = "No source files specified";
            return result;
        }
        
        // Validate syntax if requested
        if (rConfig.validateSyntax)
        {
            if (!validateSyntax(target.sources, rCmd, config.root))
            {
                result.error = "Syntax validation failed";
                return result;
            }
        }
        
        // Create executable wrapper
        auto outputs = getOutputs(target, config, rConfig);
        if (!outputs.empty)
        {
            auto outputPath = outputs[0];
            auto mainFile = target.sources[0];
            
            if (!createScriptWrapper(mainFile, outputPath, rConfig))
            {
                result.error = "Failed to create script wrapper";
                return result;
            }
            
            Logger.info("Created R script wrapper: " ~ outputPath);
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config, RConfig rConfig)
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
    }
    
    override bool validate(Target target, RConfig rConfig)
    {
        if (target.sources.empty)
        {
            Logger.error("No source files specified for R script");
            return false;
        }
        
        // Check if main file exists
        if (!exists(target.sources[0]))
        {
            Logger.error("Main R script not found: " ~ target.sources[0]);
            return false;
        }
        
        return true;
    }
    
    /// Create R script wrapper
    private bool createScriptWrapper(string scriptPath, string outputPath, ref RConfig config)
    {
        try
        {
            // Ensure output directory exists
            string outDir = dirName(outputPath);
            if (!exists(outDir))
                mkdirRecurse(outDir);
            
            // Create wrapper script
            string wrapper = "#!/usr/bin/env " ~ config.rExecutable ~ "\n\n";
            
            // Add library paths if specified
            if (!config.libPaths.empty)
            {
                wrapper ~= ".libPaths(c(" ~ config.libPaths.map!(p => `"` ~ p ~ `"`).join(",") ~ ", .libPaths()))\n";
            }
            
            // Source the main script
            wrapper ~= "source('" ~ scriptPath ~ "')\n";
            
            std.file.write(outputPath, wrapper);
            
            // Make executable on POSIX systems
            version(Posix)
            {
                import core.sys.posix.sys.stat;
                auto attrs = getAttributes(outputPath);
                setAttributes(outputPath, attrs | S_IXUSR | S_IXGRP | S_IXOTH);
            }
            
            return true;
        }
        catch (Exception e)
        {
            Logger.error("Failed to create script wrapper: " ~ e.msg);
            return false;
        }
    }
}

