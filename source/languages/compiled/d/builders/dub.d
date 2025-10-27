module languages.compiled.d.builders.dub;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.d.builders.base;
import languages.compiled.d.core.config;
import languages.compiled.d.analysis.manifest;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// DUB builder implementation
class DubBuilder : DBuilder
{
    private DConfig config;
    
    this(DConfig config)
    {
        this.config = config;
    }
    
    DCompileResult build(
        in string[] sources,
        in DConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        DCompileResult result;
        
        // Determine project directory
        string projectDir = dirName(config.dub.packagePath);
        if (projectDir.empty || projectDir == ".")
        {
            projectDir = getcwd();
        }
        
        // Build command
        string[] cmd = ["dub"];
        
        // Add command (build, test, run, etc.)
        cmd ~= config.dub.command;
        
        // Add compiler selection
        if (!config.dub.compiler.empty)
        {
            cmd ~= "--compiler=" ~ config.dub.compiler;
        }
        else
        {
            // Use configured compiler
            cmd ~= "--compiler=" ~ getCompilerCommand(config.compiler, config.customCompiler);
        }
        
        // Add build configuration
        if (!config.dub.configuration.empty)
        {
            cmd ~= "--config=" ~ config.dub.configuration;
        }
        
        // Add architecture
        if (!config.dub.arch.empty)
        {
            cmd ~= "--arch=" ~ config.dub.arch;
        }
        
        // Add build type based on buildConfig
        string buildType = buildConfigToDubBuild(config.buildConfig);
        if (!buildType.empty)
        {
            cmd ~= "--build=" ~ buildType;
        }
        
        // Package selection
        if (!config.dub.package_.empty)
        {
            cmd ~= config.dub.package_;
        }
        
        // Flags
        if (config.dub.force)
            cmd ~= "--force";
        if (config.dub.combined)
            cmd ~= "--combined";
        if (config.dub.printCommands)
            cmd ~= "--print-commands";
        if (config.dub.deep)
            cmd ~= "--deep";
        if (config.dub.single && !sources.empty)
            cmd ~= "--single";
        if (config.dub.verbose)
            cmd ~= "--verbose";
        if (config.dub.vverbose)
            cmd ~= "--vverbose";
        if (config.dub.quiet)
            cmd ~= "--quiet";
        if (!config.dub.verifyDeps)
            cmd ~= "--skip-registry=all";
        if (config.dub.skipRegistry)
            cmd ~= "--skip-registry=all";
        
        // Registry
        if (!config.dub.registry.empty)
        {
            cmd ~= "--registry=" ~ config.dub.registry;
        }
        
        // Jobs
        if (config.dub.jobs > 0)
        {
            cmd ~= "--parallel";
        }
        
        // Additional DUB flags
        cmd ~= config.dub.dubFlags;
        
        // Overrides
        foreach (pack, path; config.dub.overrides)
        {
            cmd ~= "--override-config=" ~ pack ~ "/" ~ path;
        }
        
        // Add sources for single file mode
        if (config.dub.single && !sources.empty)
        {
            cmd ~= sources;
        }
        
        Logger.debug_("DUB command: " ~ cmd.join(" "));
        
        // Set environment variables
        string[string] env = environment.toAA();
        foreach (key, value; config.env)
        {
            env[key] = value;
        }
        
        // Execute
        auto res = execute(cmd, env, std.process.Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = "DUB build failed:\n" ~ res.output;
            
            // Try to extract warnings even on failure
            extractWarnings(res.output, result);
            
            return result;
        }
        
        // Extract warnings from output
        extractWarnings(res.output, result);
        
        // Determine output files
        result.outputs = determineOutputs(config, target, workspace, projectDir);
        
        // Generate hash
        if (!result.outputs.empty && exists(result.outputs[0]))
        {
            result.outputHash = FastHash.hashFile(result.outputs[0]);
        }
        else
        {
            result.outputHash = FastHash.hashStrings(sources);
        }
        
        // Handle coverage if test mode
        if (config.mode == DBuildMode.Test && config.test.coverage)
        {
            result.coveragePercent = extractCoverage(projectDir);
        }
        
        result.success = true;
        return result;
    }
    
    bool isAvailable()
    {
        try
        {
            auto res = execute(["dub", "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    string name() const
    {
        return "dub";
    }
    
    string getVersion()
    {
        try
        {
            auto res = execute(["dub", "--version"]);
            if (res.status == 0)
            {
                // Parse version from output
                auto lines = res.output.split("\n");
                if (lines.length > 0)
                {
                    return lines[0].strip();
                }
            }
        }
        catch (Exception e)
        {
        }
        return "unknown";
    }
    
    private string getCompilerCommand(DCompiler compiler, string customPath)
    {
        if (compiler == DCompiler.Custom)
            return customPath.empty ? "ldc2" : customPath;
        
        final switch (compiler)
        {
            case DCompiler.Auto:
            case DCompiler.LDC:
                return "ldc2";
            case DCompiler.DMD:
                return "dmd";
            case DCompiler.GDC:
                return "gdc";
            case DCompiler.Custom:
                return customPath;
        }
    }
    
    private string buildConfigToDubBuild(BuildConfig config)
    {
        final switch (config)
        {
            case BuildConfig.Debug:
                return "debug";
            case BuildConfig.Plain:
                return "plain";
            case BuildConfig.Release:
                return "release";
            case BuildConfig.ReleaseNoBounds:
                return "release-nobounds";
            case BuildConfig.Unittest:
                return "unittest";
            case BuildConfig.Profile:
                return "profile";
            case BuildConfig.Cov:
                return "cov";
            case BuildConfig.UnittestCov:
                return "unittest-cov";
            case BuildConfig.SyntaxOnly:
                return "syntax";
        }
    }
    
    private void extractWarnings(string output, ref DCompileResult result)
    {
        foreach (line; output.split("\n"))
        {
            if (line.canFind("Warning:") || line.canFind("warning:") || 
                line.canFind("Deprecation:") || line.canFind("deprecation:"))
            {
                result.hadWarnings = true;
                result.warnings ~= line.strip();
            }
        }
    }
    
    private string[] determineOutputs(
        in DConfig config,
        in Target target,
        in WorkspaceConfig workspace,
        string projectDir
    )
    {
        string[] outputs;
        
        // Check if target has explicit output path
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(workspace.options.outputDir, target.outputPath);
            return outputs;
        }
        
        // Try to parse dub package for output name
        if (!config.dub.packagePath.empty && exists(config.dub.packagePath))
        {
            auto manifest = DubManifest.parse(config.dub.packagePath);
            if (manifest.name)
            {
                string outputName = manifest.name;
                
                // Determine output directory (usually projectDir or projectDir/bin)
                string outputPath = buildPath(projectDir, outputName);
                
                // Check common locations
                if (exists(outputPath))
                {
                    outputs ~= outputPath;
                }
                else if (exists(buildPath(projectDir, "bin", outputName)))
                {
                    outputs ~= buildPath(projectDir, "bin", outputName);
                }
                else if (exists(buildPath(projectDir, outputName ~ ".exe")))
                {
                    outputs ~= buildPath(projectDir, outputName ~ ".exe");
                }
                else
                {
                    // Fallback to workspace output dir
                    outputs ~= buildPath(workspace.options.outputDir, outputName);
                }
            }
        }
        
        // Final fallback
        if (outputs.empty)
        {
            auto name = target.name.split(":")[$ - 1];
            outputs ~= buildPath(workspace.options.outputDir, name);
        }
        
        return outputs;
    }
    
    private float extractCoverage(string projectDir)
    {
        // Look for .lst files (D coverage output)
        string[] lstFiles;
        
        if (exists(projectDir))
        {
            foreach (entry; dirEntries(projectDir, "*.lst", SpanMode.shallow))
            {
                lstFiles ~= entry.name;
            }
        }
        
        if (lstFiles.empty)
            return 0.0;
        
        // Simple coverage calculation from .lst files
        size_t totalLines = 0;
        size_t coveredLines = 0;
        
        foreach (lstFile; lstFiles)
        {
            try
            {
                auto content = readText(lstFile);
                foreach (line; content.split("\n"))
                {
                    if (line.length > 7)
                    {
                        auto prefix = line[0..7].strip();
                        if (!prefix.empty && prefix != "0000000")
                        {
                            totalLines++;
                            if (prefix != "0000000")
                                coveredLines++;
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse coverage file: " ~ lstFile);
            }
        }
        
        if (totalLines == 0)
            return 0.0;
        
        return (cast(float)coveredLines / cast(float)totalLines) * 100.0;
    }
}


