module languages.elixir;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base;
import config.schema;
import analysis.types;
import analysis.spec;
import utils.hash;
import utils.logger;

/// Elixir build handler
class ElixirHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Elixir target: " ~ target.name);
        
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config);
                break;
            case TargetType.Test:
                result = runTests(target, config);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
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
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Compile with elixirc or use mix
        if (exists("mix.exs"))
        {
            // Use mix build
            auto cmd = ["mix", "compile"];
            cmd ~= target.flags;
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "mix compile failed: " ~ res.output;
                return result;
            }
        }
        else
        {
            // Compile individual files with elixirc
            auto outputDir = buildPath(config.options.outputDir, ".elixir-build");
            if (!exists(outputDir))
                mkdirRecurse(outputDir);
            
            auto cmd = ["elixirc", "-o", outputDir];
            cmd ~= target.sources;
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "elixirc failed: " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        return buildExecutable(target, config);
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Run tests with mix test or elixir
        auto cmd = exists("mix.exs") ? ["mix", "test"] : ["elixir"];
        
        if (cmd[0] == "elixir")
            cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Elixir);
        if (spec is null)
            return [];
        
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                auto imports = spec.scanImports(source, content);
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
}

