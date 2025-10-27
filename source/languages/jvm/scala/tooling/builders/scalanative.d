module languages.jvm.scala.tooling.builders.scalanative;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv : octal;
import languages.jvm.scala.tooling.builders.base;
import languages.jvm.scala.core.config;
import languages.jvm.scala.tooling.detection;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Scala Native builder - compiles Scala to native binary via LLVM
class ScalaNativeBuilder : ScalaBuilder
{
    override ScalaBuildResult build(
        in string[] sources,
        in ScalaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        ScalaBuildResult result;
        
        Logger.debug_("Building Scala Native target: " ~ target.name);
        
        // Detect build tool
        ScalaBuildTool buildTool = config.buildTool;
        if (buildTool == ScalaBuildTool.Auto)
            buildTool = ScalaToolDetection.detectBuildTool(workspace.root);
        
        // Use sbt for Scala Native
        if (buildTool == ScalaBuildTool.SBT)
        {
            return buildWithSbt(target, config, workspace, result);
        }
        
        // Use Mill for Scala Native
        if (buildTool == ScalaBuildTool.Mill)
        {
            return buildWithMill(target, config, workspace, result);
        }
        
        result.error = "Scala Native requires sbt or Mill build tool";
        return result;
    }
    
    override bool isAvailable()
    {
        return ScalaToolDetection.isSBTAvailable() || 
               ScalaToolDetection.isMillAvailable();
    }
    
    override string name() const
    {
        return "ScalaNative";
    }
    
    override bool supportsMode(ScalaBuildMode mode)
    {
        return mode == ScalaBuildMode.ScalaNative;
    }
    
    private ScalaBuildResult buildWithSbt(
        const Target target,
        const ScalaConfig config,
        const WorkspaceConfig workspace,
        ScalaBuildResult result
    )
    {
        string[] cmd = ["sbt"];
        
        // Scala Native link task
        cmd ~= "nativeLink";
        
        Logger.info("Running sbt nativeLink...");
        Logger.debug_("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "Scala Native compilation failed:\n" ~ res.output;
            return result;
        }
        
        // Find generated binary
        string targetDir = buildPath(workspace.root, "target", "scala-" ~ config.versionInfo.binaryVersion());
        string binary = findNativeBinary(targetDir);
        
        if (binary.empty)
        {
            result.error = "Could not find generated native binary";
            return result;
        }
        
        // Copy to output location
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        copy(binary, outputPath);
        
        // Make executable on Unix
        version(Posix)
        {
            execute(["chmod", "+x", outputPath]);
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private ScalaBuildResult buildWithMill(
        const Target target,
        const ScalaConfig config,
        const WorkspaceConfig workspace,
        ScalaBuildResult result
    )
    {
        string[] cmd = ["mill"];
        
        // Mill Scala Native task
        cmd ~= target.name ~ ".nativeLink";
        
        Logger.info("Running Mill nativeLink...");
        Logger.debug_("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "Scala Native compilation failed:\n" ~ res.output;
            return result;
        }
        
        // Mill output is typically in out/ directory
        string outDir = buildPath(workspace.root, "out");
        string binary = findNativeBinary(outDir);
        
        if (binary.empty)
        {
            result.error = "Could not find generated native binary";
            return result;
        }
        
        // Copy to output location
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        copy(binary, outputPath);
        
        // Make executable on Unix
        version(Posix)
        {
            execute(["chmod", "+x", outputPath]);
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private string findNativeBinary(string searchDir)
    {
        if (!exists(searchDir) || !isDir(searchDir))
            return "";
        
        try
        {
            foreach (entry; dirEntries(searchDir, SpanMode.depth))
            {
                if (entry.isFile)
                {
                    string name = baseName(entry.name);
                    // Look for executable files without extensions or with .out
                    version(Windows)
                    {
                        if (name.endsWith(".exe"))
                            return entry.name;
                    }
                    else
                    {
                        // Check if file is executable
                        auto perms = getAttributes(entry.name);
                        if ((perms & octal!111) != 0) // Check execute bits
                            return entry.name;
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Error searching for native binary: " ~ e.msg);
        }
        
        return "";
    }
    
    private string getOutputPath(const Target target, const WorkspaceConfig workspace)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        version(Windows)
            name ~= ".exe";
        
        return buildPath(workspace.options.outputDir, name);
    }
}

