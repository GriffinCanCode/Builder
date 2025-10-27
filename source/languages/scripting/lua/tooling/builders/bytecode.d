module languages.scripting.lua.tooling.builders.bytecode;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.scripting.lua.tooling.builders.base;
import languages.scripting.lua.tooling.detection : isAvailable, getCompilerCommand;
import languages.scripting.lua.core.config;
import config.schema.schema;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Bytecode builder - compiles Lua to bytecode using luac
class BytecodeBuilder : LuaBuilder
{
    override BuildResult build(
        in string[] sources,
        in LuaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        BuildResult result;
        
        if (sources.empty)
        {
            result.error = "No sources provided";
            return result;
        }
        
        // Get Lua compiler
        string luacCmd = getCompilerCommand(config.runtime);
        
        if (!.isAvailable(luacCmd))
        {
            result.error = "Lua compiler not found: " ~ luacCmd;
            return result;
        }
        
        // Get output path
        string outputPath;
        if (!config.bytecode.outputFile.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, config.bytecode.outputFile);
        }
        else if (!target.outputPath.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name ~ ".luac");
        }
        
        // Create output directory
        auto outputDir = dirName(outputPath);
        if (!exists(outputDir))
        {
            mkdirRecurse(outputDir);
        }
        
        // Build luac command
        string[] cmd = [luacCmd];
        
        // Add flags based on configuration
        cmd ~= "-o";
        cmd ~= outputPath;
        
        // Optimization flags
        final switch (config.bytecode.optLevel)
        {
            case BytecodeOptLevel.None:
                // No optimization flags
                break;
            case BytecodeOptLevel.Basic:
                // Default luac behavior
                break;
            case BytecodeOptLevel.Full:
                // Strip debug info for smaller bytecode
                if (config.bytecode.stripDebug)
                {
                    cmd ~= "-s";
                }
                break;
        }
        
        // List dependencies
        if (config.bytecode.listDeps)
        {
            cmd ~= "-l";
        }
        
        // Add source files
        cmd ~= sources;
        
        // Compile bytecode
        Logger.debugLog("Compiling bytecode: " ~ cmd.join(" "));
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Bytecode compilation failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return .isAvailable("luac") || .isAvailable("luac5.4") ||
               .isAvailable("luac5.3") || .isAvailable("luac5.2") ||
               .isAvailable("luac5.1");
    }
    
    override string name() const
    {
        return "Bytecode";
    }
}

