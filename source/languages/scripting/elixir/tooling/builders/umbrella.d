module languages.scripting.elixir.tooling.builders.umbrella;

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

/// Umbrella builder - multi-app projects
class UmbrellaBuilder : MixProjectBuilder
{
    override ElixirBuildResult build(
        string[] sources,
        ElixirConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ElixirBuildResult result;
        
        Logger.debug_("Building Umbrella project");
        
        string workDir = workspace.root;
        if (!sources.empty)
            workDir = dirName(sources[0]);
        
        // Build umbrella root
        result = super.build(sources, config, target, workspace);
        
        if (!result.success)
            return result;
        
        // Build individual apps if specified
        if (!config.umbrella.buildAll)
        {
            Logger.info("Building individual umbrella apps");
            
            string appsDir = buildPath(workDir, config.umbrella.appsDir);
            
            foreach (app; config.umbrella.apps)
            {
                if (config.umbrella.excludeApps.canFind(app))
                {
                    Logger.debug_("Skipping excluded app: " ~ app);
                    continue;
                }
                
                Logger.info("Building app: " ~ app);
                
                string appDir = buildPath(appsDir, app);
                if (!exists(appDir))
                {
                    result.warnings ~= "App directory not found: " ~ app;
                    continue;
                }
                
                auto cmd = ["mix", "compile"];
                auto res = execute(cmd, null, Config.none, size_t.max, appDir);
                
                if (res.status != 0)
                {
                    result.warnings ~= "Failed to build app " ~ app ~ ": " ~ res.output;
                }
            }
        }
        
        return result;
    }
    
    override string name() const
    {
        return "Umbrella";
    }
}

