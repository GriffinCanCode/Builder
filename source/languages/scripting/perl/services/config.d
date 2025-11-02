module languages.scripting.perl.services.config;

import languages.scripting.perl.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.logging.logger;
import std.json : JSONValue;

/// Configuration service interface
interface IPerlConfigService
{
    /// Parse and enhance Perl configuration from target
    PerlConfig parse(in Target target, in WorkspaceConfig workspace);
    
    /// Validate Perl interpreter availability
    bool validateInterpreter(in PerlConfig config);
}

/// Concrete Perl configuration service
final class PerlConfigService : IPerlConfigService
{
    PerlConfig parse(in Target target, in WorkspaceConfig workspace) @trusted
    {
        import std.json : parseJSON;
        import std.array : empty;
        import std.path : buildPath;
        import std.file : exists;
        
        // Parse base config from target
        PerlConfig config;
        if (!target.config.empty)
        {
            auto json = parseJSON(target.config);
            config = parsePerlConfig(json);
        }
        
        // Auto-detect from project structure
        enhanceFromProject(config, target, workspace);
        
        return config;
    }
    
    bool validateInterpreter(in PerlConfig config) @trusted
    {
        import std.process : execute;
        
        string perlCmd = config.perlVersion.interpreterPath.empty 
            ? "perl" 
            : config.perlVersion.interpreterPath;
        
        try
        {
            auto result = execute([perlCmd, "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    private void enhanceFromProject(
        ref PerlConfig config,
        in Target target,
        in WorkspaceConfig workspace
    ) @trusted
    {
        import std.path : buildPath;
        import std.file : exists;
        
        // Auto-detect build mode
        if (config.mode == PerlBuildMode.Auto)
        {
            if (exists(buildPath(workspace.root, "cpanfile")))
                config.mode = PerlBuildMode.CPAN;
            else
                config.mode = PerlBuildMode.Script;
        }
        
        // Auto-detect build tool
        if (config.mode == PerlBuildMode.CPAN)
        {
            if (exists(buildPath(workspace.root, "Build.PL")))
                config.buildTool = PerlBuildTool.ModuleBuild;
            else if (exists(buildPath(workspace.root, "Makefile.PL")))
                config.buildTool = PerlBuildTool.MakeMaker;
            else if (exists(buildPath(workspace.root, "dist.ini")))
                config.buildTool = PerlBuildTool.DistZilla;
            else if (exists(buildPath(workspace.root, "minil.toml")))
                config.buildTool = PerlBuildTool.Minilla;
        }
        
        // Validate interpreter
        if (!validateInterpreter(config))
        {
            Logger.warning("Perl interpreter not available: " ~ 
                          (config.perlVersion.interpreterPath.empty 
                           ? "perl" 
                           : config.perlVersion.interpreterPath));
        }
    }
    
    private PerlConfig parsePerlConfig(in JSONValue json) @trusted
    {
        import config.parsing.parser : ConfigParser;
        auto parser = new ConfigParser();
        return parser.parsePerlConfigFromJSON(json);
    }
}

