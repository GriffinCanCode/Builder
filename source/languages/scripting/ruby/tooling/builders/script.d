module languages.scripting.ruby.builders.script;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.ruby.config;
import languages.scripting.ruby.builders.base;
import languages.scripting.ruby.tools;
import languages.base.base;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Script builder for Ruby scripts and simple applications
class ScriptBuilder : Builder
{
    override BuildResult build(
        string[] sources,
        RubyConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        BuildResult result;
        
        if (sources.empty)
        {
            result.error = "No source files specified";
            return result;
        }
        
        // Validate syntax
        string[] errors;
        if (!SyntaxChecker.check(sources, errors))
        {
            result.error = "Syntax errors:\n" ~ errors.join("\n");
            return result;
        }
        
        // Create executable wrapper
        auto outputPath = getOutputPath(target, workspace);
        auto mainFile = sources[0];
        
        if (!createWrapper(mainFile, outputPath, config, workspace.root))
        {
            result.error = "Failed to create executable wrapper";
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return RubyTools.isRubyAvailable();
    }
    
    override string name() const
    {
        return "Ruby Script Builder";
    }
    
    private string getOutputPath(Target target, WorkspaceConfig workspace)
    {
        if (!target.outputPath.empty)
        {
            return buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            return buildPath(workspace.options.outputDir, name);
        }
    }
    
    private bool createWrapper(
        string mainFile,
        string outputPath,
        RubyConfig config,
        string projectRoot
    )
    {
        auto outputDir = dirName(outputPath);
        
        // Ensure output directory exists
        if (!exists(outputDir))
        {
            try
            {
                mkdirRecurse(outputDir);
            }
            catch (Exception e)
            {
                Logger.error("Failed to create output directory: " ~ e.msg);
                return false;
            }
        }
        
        // Build wrapper script
        string wrapper = "#!/usr/bin/env ruby\n";
        wrapper ~= "# frozen_string_literal: true\n\n";
        
        // Add load paths
        if (!config.loadPath.empty)
        {
            foreach (path; config.loadPath)
            {
                wrapper ~= "$LOAD_PATH.unshift('" ~ path ~ "')\n";
            }
            wrapper ~= "\n";
        }
        
        // Add Bundler setup if configured
        if (config.requireBundler && config.bundler.enabled)
        {
            wrapper ~= "require 'bundler/setup'\n";
            wrapper ~= "Bundler.require(:default)\n\n";
        }
        
        // Load main file
        auto relPath = relativePath(mainFile, outputDir);
        wrapper ~= "load File.join(File.dirname(__FILE__), '..', '" ~ relPath ~ "')\n";
        
        // Write wrapper
        try
        {
            std.file.write(outputPath, wrapper);
        }
        catch (Exception e)
        {
            Logger.error("Failed to write wrapper: " ~ e.msg);
            return false;
        }
        
        // Make executable on POSIX systems
        version(Posix)
        {
            auto res = executeShell("chmod +x " ~ outputPath);
            if (res.status != 0)
            {
                Logger.warning("Failed to make wrapper executable");
            }
        }
        
        Logger.info("Created executable wrapper: " ~ outputPath);
        return true;
    }
}


