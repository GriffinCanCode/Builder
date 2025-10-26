module languages.scripting.lua;

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

/// Lua build handler
class LuaHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Lua target: " ~ target.name);
        
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
        
        // Lua is interpreted - validate syntax with luac
        foreach (source; target.sources)
        {
            auto cmd = ["luac", "-p", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Syntax error in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        // Create executable wrapper
        auto outputs = getOutputs(target, config);
        if (!outputs.empty && !target.sources.empty)
        {
            auto outputPath = outputs[0];
            auto outputDir = dirName(outputPath);
            auto mainFile = target.sources[0];
            
            // Ensure output directory exists
            if (!exists(outputDir))
                mkdirRecurse(outputDir);
            
            // Create wrapper script
            auto wrapper = "#!/usr/bin/env lua\n";
            auto absPath = "arg[0]:match('(.*/)')";
            wrapper ~= "local script_dir = " ~ absPath ~ " or './'\n";
            wrapper ~= "dofile(script_dir .. '../" ~ mainFile ~ "')\n";
            
            std.file.write(outputPath, wrapper);
            
            // Make executable
            version(Posix)
            {
                executeShell("chmod +x " ~ outputPath);
            }
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Validate syntax
        foreach (source; target.sources)
        {
            auto cmd = ["luac", "-p", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Syntax error in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        // Optionally compile to bytecode
        auto outputs = getOutputs(target, config);
        if (!outputs.empty)
        {
            auto outputPath = outputs[0] ~ ".luac";
            auto outputDir = dirName(outputPath);
            
            if (!exists(outputDir))
                mkdirRecurse(outputDir);
            
            // Compile to bytecode
            if (!target.sources.empty)
            {
                auto cmd = ["luac", "-o", outputPath];
                cmd ~= target.sources;
                
                auto res = execute(cmd);
                
                if (res.status != 0)
                {
                    result.error = "luac compilation failed: " ~ res.output;
                    return result;
                }
            }
        }
        
        result.success = true;
        result.outputs = target.sources;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Run tests with busted or plain lua
        foreach (source; target.sources)
        {
            // Try busted first
            auto bustedCmd = ["busted", source];
            auto bustedRes = execute(bustedCmd);
            
            if (bustedRes.status == 0)
                continue;
            
            // Fallback to lua
            auto luaCmd = ["lua", source];
            auto luaRes = execute(luaCmd);
            
            if (luaRes.status != 0)
            {
                result.error = "Test failed in " ~ source;
                return result;
            }
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
        auto spec = getLanguageSpec(TargetLanguage.Lua);
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

