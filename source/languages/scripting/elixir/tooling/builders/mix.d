module languages.scripting.elixir.tooling.builders.mix;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import languages.scripting.elixir.tooling.builders.base;
import languages.scripting.elixir.core.config;
import languages.scripting.elixir.managers.mix;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Mix project builder - standard OTP applications and libraries
class MixProjectBuilder : ElixirBuilder
{
    override ElixirBuildResult build(
        string[] sources,
        ElixirConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ElixirBuildResult result;
        
        Logger.debug_("Building Mix project");
        
        string workDir = workspace.root;
        if (!sources.empty)
            workDir = dirName(sources[0]);
        
        // Check for mix.exs
        string mixExsPath = buildPath(workDir, config.project.mixExsPath);
        if (!exists(mixExsPath))
        {
            result.error = "mix.exs not found at: " ~ mixExsPath;
            return result;
        }
        
        // Setup environment
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Set MIX_ENV
        string mixEnv = envToString(config.env);
        if (config.env == MixEnv.Custom && !config.customEnv.empty)
            mixEnv = config.customEnv;
        env["MIX_ENV"] = mixEnv;
        
        // Merge custom environment variables
        foreach (key, value; config.env_)
            env[key] = value;
        
        // Build Mix command
        string[] cmd = ["mix", "compile"];
        
        if (config.verbose)
            cmd ~= "--verbose";
        
        if (config.warningsAsErrors)
            cmd ~= "--warnings-as-errors";
        
        if (!config.debugInfo)
            cmd ~= "--no-debug-info";
        
        // Add compiler options
        if (!config.compilerOpts.empty)
        {
            cmd ~= "--erl-opts";
            cmd ~= config.compilerOpts.join(" ");
        }
        
        Logger.info("Compiling Mix project: " ~ cmd.join(" "));
        
        // Execute compilation
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Compilation failed: " ~ res.output;
            
            // Parse warnings from output
            result.warnings = parseCompilerWarnings(res.output);
            
            return result;
        }
        
        // Parse warnings even on success
        result.warnings = parseCompilerWarnings(res.output);
        
        // Determine output paths
        string buildPath = config.project.buildPath;
        string outputDir = buildPath(buildPath, mixEnv, "lib");
        
        if (exists(outputDir))
        {
            result.outputs ~= outputDir;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(sources);
        
        // Compile protocols if requested
        if (config.compileProtocols)
        {
            Logger.info("Consolidating protocols");
            auto protCmd = ["mix", "compile.protocols"];
            auto protRes = execute(protCmd, env, Config.none, size_t.max, workDir);
            
            if (protRes.status != 0)
            {
                result.warnings ~= "Protocol consolidation failed";
            }
        }
        
        return result;
    }
    
    override bool isAvailable()
    {
        auto res = execute(["mix", "--version"]);
        return res.status == 0;
    }
    
    override string name() const
    {
        return "Mix Project";
    }
    
    /// Parse compiler warnings from output
    private string[] parseCompilerWarnings(string output)
    {
        string[] warnings;
        
        import std.regex;
        import std.string : strip;
        
        // Match Elixir compiler warnings
        // Format: warning: message
        //         lib/file.ex:line
        auto warningRegex = regex(r"warning:.*?(?=\n\n|\n[^[:space:]]|$)", "s");
        
        foreach (match; output.matchAll(warningRegex))
        {
            warnings ~= match[0].strip;
        }
        
        return warnings;
    }
    
    /// Convert MixEnv to string
    private string envToString(MixEnv env)
    {
        final switch (env)
        {
            case MixEnv.Dev: return "dev";
            case MixEnv.Test: return "test";
            case MixEnv.Prod: return "prod";
            case MixEnv.Custom: return "custom";
        }
    }
}

