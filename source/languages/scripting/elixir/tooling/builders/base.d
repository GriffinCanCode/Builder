module languages.scripting.elixir.tooling.builders.base;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base.base;
import languages.scripting.elixir.config;
import config.schema.schema;
import analysis.targets.types;
import core.caching.action : ActionCache;

/// Build result structure
struct ElixirBuildResult
{
    bool success;
    string[] outputs;
    string[] errors;
}

/// Base interface for Elixir builders
interface ElixirBuilder
{
    /// Build Elixir project
    ElixirBuildResult build(
        in string[] sources,
        in ElixirConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Set action cache for this builder
    void setActionCache(ActionCache cache);
}

/// Builder factory - creates appropriate builder based on project type
class BuilderFactory
{
    /// Create builder based on project type with optional action cache
    static ElixirBuilder create(ElixirProjectType type, ElixirConfig config, ActionCache cache = null)
    {
        final switch (type)
        {
            case ElixirProjectType.Script:
                import languages.scripting.elixir.tooling.builders.script;
                auto builder = new ScriptBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
            
            case ElixirProjectType.MixProject:
            case ElixirProjectType.Library:
                import languages.scripting.elixir.tooling.builders.mix;
                auto builder = new MixProjectBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
            
            case ElixirProjectType.Phoenix:
            case ElixirProjectType.PhoenixLiveView:
                import languages.scripting.elixir.tooling.builders.phoenix;
                auto builder = new PhoenixBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
            
            case ElixirProjectType.Umbrella:
                import languages.scripting.elixir.tooling.builders.umbrella;
                auto builder = new UmbrellaBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
            
            case ElixirProjectType.Escript:
                import languages.scripting.elixir.tooling.builders.escript;
                auto builder = new EscriptBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
            
            case ElixirProjectType.Nerves:
                import languages.scripting.elixir.tooling.builders.nerves;
                auto builder = new NervesBuilder();
                if (cache) builder.setActionCache(cache);
                return builder;
        }
    }
    
    /// Auto-detect and create appropriate builder
    static ElixirBuilder createAuto(string[] sources, ElixirConfig config, WorkspaceConfig workspace)
    {
        import languages.scripting.elixir.tooling.detection;
        
        string projectRoot = workspace.root;
        if (!sources.empty)
            projectRoot = dirName(sources[0]);
        
        auto projectType = ProjectDetector.detectProjectType(projectRoot);
        return create(projectType, config);
    }
}

