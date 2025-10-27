module languages.scripting.ruby.tooling.builders.base;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base.base;
import languages.scripting.ruby.core.config;
import config.schema.schema;
import analysis.targets.types;

/// Build result specific to builders
struct BuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    string[] toolWarnings;
}

/// Builder interface - different build strategies for Ruby
interface Builder
{
    /// Build target
    BuildResult build(
        in string[] sources,
        in RubyConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name() const;
}

/// Builder factory
class BuilderFactory
{
    /// Create builder based on build mode
    static Builder create(RubyBuildMode mode)
    {
        final switch (mode)
        {
            case RubyBuildMode.Script:
            case RubyBuildMode.Library:
            case RubyBuildMode.CLI:
                import languages.scripting.ruby.tooling.builders.script;
                return new ScriptBuilder();
            
            case RubyBuildMode.Gem:
                import languages.scripting.ruby.tooling.builders.gem;
                return new GemBuilder();
            
            case RubyBuildMode.Rails:
                import languages.scripting.ruby.tooling.builders.rails;
                return new RailsBuilder();
            
            case RubyBuildMode.Rack:
                import languages.scripting.ruby.tooling.builders.script;
                return new ScriptBuilder(); // Rack apps are similar to scripts
        }
    }
    
    /// Auto-detect and create appropriate builder
    static Builder createAuto(string[] sources, WorkspaceConfig workspace)
    {
        import languages.scripting.ruby.tooling.info;
        
        string projectRoot = workspace.root;
        if (!sources.empty)
            projectRoot = dirName(sources[0]);
        
        auto projectType = ProjectDetector.detectProjectType(projectRoot);
        return create(projectType);
    }
}


