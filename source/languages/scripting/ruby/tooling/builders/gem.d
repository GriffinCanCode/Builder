module languages.scripting.ruby.tooling.builders.gem;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.ruby.core.config;
import languages.scripting.ruby.tooling.builders.base;
import languages.scripting.ruby.tooling.info;
import languages.scripting.ruby.managers.rubygems;
import languages.base.base;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Gem builder for Ruby gems/libraries
class GemBuilder : Builder
{
    override BuildResult build(
        in string[] sources,
        in RubyConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        BuildResult result;
        
        // Find gemspec file
        string gemspecFile = config.gemBuild.gemspecFile;
        if (gemspecFile.empty)
        {
            auto gemspecs = GemspecUtil.findGemspecs(workspace.root);
            if (gemspecs.empty)
            {
                result.error = "No gemspec file found";
                return result;
            }
            gemspecFile = gemspecs[0];
            Logger.debugLog("Using gemspec: " ~ gemspecFile);
        }
        
        if (!exists(gemspecFile))
        {
            result.error = "Gemspec file not found: " ~ gemspecFile;
            return result;
        }
        
        // Validate syntax of source files
        if (!sources.empty)
        {
            string[] errors;
            if (!SyntaxChecker.check(sources, errors))
            {
                result.error = "Syntax errors:\n" ~ errors.join("\n");
                return result;
            }
        }
        
        // Build gem
        auto gemFile = buildGem(gemspecFile, config.gemBuild, workspace.root);
        if (gemFile.empty)
        {
            result.error = "Failed to build gem";
            return result;
        }
        
        // Move gem to output directory if specified
        if (!config.gemBuild.outputDir.empty)
        {
            auto targetPath = buildPath(config.gemBuild.outputDir, baseName(gemFile));
            
            if (!exists(config.gemBuild.outputDir))
            {
                try
                {
                    mkdirRecurse(config.gemBuild.outputDir);
                }
                catch (Exception e)
                {
                    Logger.warning("Failed to create output directory: " ~ e.msg);
                }
            }
            
            if (gemFile != targetPath)
            {
                try
                {
                    if (exists(targetPath))
                        remove(targetPath);
                    rename(gemFile, targetPath);
                    gemFile = targetPath;
                }
                catch (Exception e)
                {
                    Logger.warning("Failed to move gem to output directory: " ~ e.msg);
                }
            }
        }
        
        result.success = true;
        result.outputs = [gemFile];
        result.outputHash = FastHash.hashStrings(sources);
        
        Logger.info("Gem built successfully: " ~ gemFile);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return RubyTools.isRubyAvailable();
    }
    
    override string name() const
    {
        return "Ruby Gem Builder";
    }
    
    private string buildGem(string gemspecFile, const GemBuildConfig config, string workDir)
    {
        string[] cmd = ["gem", "build", gemspecFile];
        
        // Sign gem if configured
        if (config.sign && !config.key.empty)
        {
            cmd ~= ["--sign", config.key];
        }
        
        Logger.info("Building gem from " ~ gemspecFile);
        
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            Logger.error("Gem build failed: " ~ res.output);
            return "";
        }
        
        // Parse output to get gem filename
        // Output typically looks like: "Successfully built RubyGem\nName: gem-name\nVersion: 1.0.0\nFile: gem-name-1.0.0.gem"
        string gemFile;
        foreach (line; res.output.lineSplitter)
        {
            if (line.strip.startsWith("File:"))
            {
                gemFile = line.strip[5..$].strip;
                break;
            }
        }
        
        if (gemFile.empty)
        {
            // Fallback: look for .gem files in current directory
            try
            {
                foreach (entry; dirEntries(workDir, "*.gem", SpanMode.shallow))
                {
                    if (entry.isFile)
                    {
                        gemFile = entry.name;
                        break;
                    }
                }
            }
            catch (Exception e)
            {
                Logger.warning("Failed to find gem file: " ~ e.msg);
            }
        }
        
        if (gemFile.empty)
        {
            Logger.error("Could not determine gem filename");
            return "";
        }
        
        // Make path absolute
        if (!isAbsolute(gemFile))
            gemFile = buildPath(workDir, gemFile);
        
        return gemFile;
    }
}


