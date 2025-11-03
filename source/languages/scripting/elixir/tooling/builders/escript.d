module languages.scripting.elixir.tooling.builders.escript;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.scripting.elixir.tooling.builders.base;
import languages.scripting.elixir.tooling.builders.mix;
import languages.scripting.elixir.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;

/// Escript builder - standalone executables
class EscriptBuilder : MixProjectBuilder
{
    override ElixirBuildResult build(
        in string[] sources,
        in ElixirConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        ElixirBuildResult result;
        
        Logger.debugLog("Building escript");
        
        string workDir = workspace.root;
        if (!sources.empty)
            workDir = dirName(sources[0]);
        
        // Build Mix project first
        result = super.build(sources, config, target, workspace);
        
        if (!result.success)
            return result;
        
        // Build escript
        Logger.info("Creating escript executable");
        
        auto cmd = ["mix", "escript.build"];
        auto res = execute(cmd, null, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.errors ~= "Escript build failed: " ~ res.output;
            result.success = false;
            return result;
        }
        
        // Find generated escript
        string escriptName = config.project.app.empty ? config.project.name : config.project.app;
        string escriptPath = buildPath(workDir, escriptName);
        
        if (exists(escriptPath))
        {
            // result.escriptPath = escriptPath; // Property doesn't exist in ElixirBuildResult
            result.outputs ~= escriptPath;
            Logger.info("Escript created: " ~ escriptPath);
        }
        
        return result;
    }
    
    override string name() const
    {
        return "Escript";
    }
}

