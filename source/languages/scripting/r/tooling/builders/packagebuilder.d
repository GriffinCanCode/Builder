module languages.scripting.r.tooling.builders.packagebuilder;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import config.schema.schema;
import languages.scripting.r.core.config;
import languages.scripting.r.tooling.builders.base;
import languages.scripting.r.analysis.dependencies;
import utils.files.hash;
import utils.logging.logger;

/// Package builder - builds R packages
class RPackageBuilder : RBuilder
{
    override BuildResult build(
        in Target target,
        in WorkspaceConfig config,
        in RConfig rConfig,
        in string rCmd
    )
    {
        BuildResult result;
        
        string packageRoot = config.root;
        
        // Check if DESCRIPTION file exists
        string descPath = buildPath(packageRoot, "DESCRIPTION");
        if (!exists(descPath))
        {
            result.error = "DESCRIPTION file not found at: " ~ descPath;
            return result;
        }
        
        Logger.info("Building R package from: " ~ packageRoot);
        
        // Check or install dependencies first
        if (rConfig.installDeps)
        {
            auto deps = parseDESCRIPTION(descPath);
            if (!deps.empty)
            {
                Logger.info("Package has " ~ deps.length.to!string ~ " dependencies");
                // TODO: Install dependencies if needed
            }
        }
        
        // Determine build mode
        string[] cmdArgs;
        string outputPath;
        
        final switch (rConfig.mode)
        {
            case RBuildMode.Package:
                // Build source package
                cmdArgs = [rCmd, "CMD", "build"];
                if (!rConfig.package_.buildVignettes)
                    cmdArgs ~= "--no-build-vignettes";
                cmdArgs ~= packageRoot;
                outputPath = buildPath(config.options.outputDir, target.name ~ ".tar.gz");
                break;
                
            case RBuildMode.Check:
                // Check package
                cmdArgs = [rCmd, "CMD", "check"];
                // Don't run tests by default during check
                cmdArgs ~= "--no-tests";
                if (!rConfig.package_.buildVignettes)
                    cmdArgs ~= "--no-build-vignettes";
                cmdArgs ~= packageRoot;
                outputPath = buildPath(config.options.outputDir, "check.log");
                break;
                
            case RBuildMode.Vignette:
                // Build vignettes
                cmdArgs = [rCmd, "CMD", "build", "--no-manual"];
                cmdArgs ~= packageRoot;
                outputPath = buildPath(config.options.outputDir, "vignettes");
                break;
                
            case RBuildMode.Script:
            case RBuildMode.Shiny:
            case RBuildMode.RMarkdown:
                result.error = "Invalid build mode for package builder";
                return result;
        }
        
        Logger.debug_("Running: " ~ cmdArgs.join(" "));
        
        try
        {
            auto res = execute(cmdArgs);
            
            if (res.status != 0)
            {
                result.error = "R CMD failed with status " ~ res.status.to!string;
                result.toolWarnings ~= res.output;
                return result;
            }
            
            result.success = true;
            result.outputs = [outputPath];
            result.outputHash = FastHash.hashFile(descPath);
            
            Logger.info("R package build completed successfully");
            
            return result;
        }
        catch (Exception e)
        {
            result.error = "Failed to build package: " ~ e.msg;
            return result;
        }
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config, in RConfig rConfig)
    {
        string[] outputs;
        
        final switch (rConfig.mode)
        {
            case RBuildMode.Package:
                outputs ~= buildPath(config.options.outputDir, target.name ~ ".tar.gz");
                break;
            case RBuildMode.Check:
                outputs ~= buildPath(config.options.outputDir, "check.log");
                break;
            case RBuildMode.Vignette:
                outputs ~= buildPath(config.options.outputDir, "vignettes");
                break;
            case RBuildMode.Script:
            case RBuildMode.Shiny:
            case RBuildMode.RMarkdown:
                break;
        }
        
        return outputs;
    }
    
    override bool validate(in Target target, in RConfig rConfig)
    {
        // Package builds don't necessarily need source files specified,
        // as they build the entire package directory
        return true;
    }
}

