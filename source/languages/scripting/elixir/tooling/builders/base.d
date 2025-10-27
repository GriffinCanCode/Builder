module languages.scripting.elixir.tooling.builders.base;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base.base;
import languages.scripting.elixir.core.config;
import config.schema.schema;
import analysis.targets.types;

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
}

/// Builder factory - creates appropriate builder based on project type
class BuilderFactory
{
    /// Create builder based on project type
    static ElixirBuilder create(ElixirProjectType type, ElixirConfig config)
    {
        final switch (type)
        {
            case ElixirProjectType.Script:
                import languages.scripting.elixir.tooling.builders.script;
                return new ScriptBuilder();
            
            case ElixirProjectType.MixProject:
            case ElixirProjectType.Library:
                import languages.scripting.elixir.tooling.builders.mix;
                return new MixProjectBuilder();
            
            case ElixirProjectType.Phoenix:
            case ElixirProjectType.PhoenixLiveView:
                import languages.scripting.elixir.tooling.builders.phoenix;
                return new PhoenixBuilder();
            
            case ElixirProjectType.Umbrella:
                import languages.scripting.elixir.tooling.builders.umbrella;
                return new UmbrellaBuilder();
            
            case ElixirProjectType.Escript:
                import languages.scripting.elixir.tooling.builders.escript;
                return new EscriptBuilder();
            
            case ElixirProjectType.Nerves:
                import languages.scripting.elixir.tooling.builders.nerves;
                return new NervesBuilder();
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

