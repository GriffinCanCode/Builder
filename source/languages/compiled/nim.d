module languages.compiled.nim;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base.base;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Nim build handler
class NimHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Nim target: " ~ target.name);
        
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
        
        auto outputs = getOutputs(target, config);
        auto outputPath = outputs[0];
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build with nim compile
        auto cmd = ["nim", "c"];
        
        // Add output path
        cmd ~= ["--out:" ~ outputPath];
        
        // Add optimization flags
        cmd ~= ["-d:release"];
        
        // Add custom flags
        cmd ~= target.flags;
        
        // Add main source (first one)
        if (!target.sources.empty)
            cmd ~= target.sources[0];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "nim compile failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        auto outputs = getOutputs(target, config);
        auto outputPath = outputs[0] ~ ".so";
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build as library
        auto cmd = ["nim", "c", "--app:lib"];
        
        // Add output path
        cmd ~= ["--out:" ~ outputPath];
        
        // Add flags
        cmd ~= target.flags;
        
        // Add main source
        if (!target.sources.empty)
            cmd ~= target.sources[0];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "nim compile failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Build and run tests
        foreach (source; target.sources)
        {
            auto tempExe = buildPath(config.options.outputDir, ".nim-test");
            
            auto buildCmd = ["nim", "c", "-r", "--out:" ~ tempExe, source];
            buildCmd ~= target.flags;
            
            auto res = execute(buildCmd);
            
            if (res.status != 0)
            {
                result.error = "Test failed in " ~ source ~ ": " ~ res.output;
                return result;
            }
            
            // Clean up
            if (exists(tempExe))
                remove(tempExe);
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
        auto spec = getLanguageSpec(TargetLanguage.Nim);
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

