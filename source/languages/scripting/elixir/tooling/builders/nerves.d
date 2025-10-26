module languages.scripting.elixir.tooling.builders.nerves;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.scripting.elixir.tooling.builders.mix;
import languages.scripting.elixir.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.logging.logger;

/// Nerves builder - embedded systems firmware
class NervesBuilder : MixProjectBuilder
{
    override ElixirBuildResult build(
        string[] sources,
        ElixirConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ElixirBuildResult result;
        
        Logger.debug_("Building Nerves firmware");
        
        string workDir = workspace.root;
        if (!sources.empty)
            workDir = dirName(sources[0]);
        
        // Setup Nerves environment
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        if (!config.nerves.target.empty)
        {
            env["MIX_TARGET"] = config.nerves.target;
            Logger.info("Building for Nerves target: " ~ config.nerves.target);
        }
        
        // Build Mix project first
        result = super.build(sources, config, target, workspace);
        
        if (!result.success)
            return result;
        
        // Build firmware
        Logger.info("Creating Nerves firmware");
        
        auto cmd = ["mix", "firmware"];
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Firmware build failed: " ~ res.output;
            result.success = false;
            return result;
        }
        
        // Find firmware file
        string fwPath = buildPath(workDir, "_build", config.nerves.target, "nerves", "images");
        if (exists(fwPath))
        {
            // Look for .fw file
            foreach (entry; dirEntries(fwPath, "*.fw", SpanMode.shallow))
            {
                result.outputs ~= entry.name;
                Logger.info("Firmware created: " ~ entry.name);
            }
        }
        
        return result;
    }
    
    override string name() const
    {
        return "Nerves";
    }
}

