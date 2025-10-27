module languages.jvm.scala.tooling.builders.scalajs;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.jvm.scala.tooling.builders.base;
import languages.jvm.scala.core.config;
import languages.jvm.scala.tooling.detection;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Scala.js builder - compiles Scala to JavaScript
class ScalaJSBuilder : ScalaBuilder
{
    override ScalaBuildResult build(
        in string[] sources,
        in ScalaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        ScalaBuildResult result;
        
        Logger.debugLog("Building Scala.js target: " ~ target.name);
        
        // Detect build tool
        ScalaBuildTool buildTool = config.buildTool;
        if (buildTool == ScalaBuildTool.Auto)
            buildTool = ScalaToolDetection.detectBuildTool(workspace.root);
        
        // Use sbt for Scala.js
        if (buildTool == ScalaBuildTool.SBT)
        {
            return buildWithSbt(target, config, workspace, result);
        }
        
        // Use Mill for Scala.js
        if (buildTool == ScalaBuildTool.Mill)
        {
            return buildWithMill(target, config, workspace, result);
        }
        
        result.error = "Scala.js requires sbt or Mill build tool";
        return result;
    }
    
    override bool isAvailable()
    {
        return ScalaToolDetection.isSBTAvailable() || 
               ScalaToolDetection.isMillAvailable();
    }
    
    override string name() const
    {
        return "ScalaJS";
    }
    
    override bool supportsMode(ScalaBuildMode mode)
    {
        return mode == ScalaBuildMode.ScalaJS;
    }
    
    private ScalaBuildResult buildWithSbt(
        const Target target,
        const ScalaConfig config,
        const WorkspaceConfig workspace,
        ScalaBuildResult result
    )
    {
        string[] cmd = ["sbt"];
        
        // Determine task based on optimization mode
        string task;
        if (config.scalaJs.mode == "fullOpt")
            task = "fullOptJS";
        else
            task = "fastOptJS";
        
        cmd ~= task;
        
        Logger.info("Running sbt " ~ task ~ "...");
        Logger.debugLog("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "Scala.js compilation failed:\n" ~ res.output;
            return result;
        }
        
        // Find generated JS file
        string targetDir = buildPath(workspace.root, "target", "scala-" ~ config.versionInfo.binaryVersion());
        string jsFile = findJSFile(targetDir, config.scalaJs.mode);
        
        if (jsFile.empty)
        {
            result.error = "Could not find generated JavaScript file";
            return result;
        }
        
        // Copy to output location
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        copy(jsFile, outputPath);
        
        // Copy source map if exists
        if (config.scalaJs.sourceMaps)
        {
            string sourceMapFile = jsFile ~ ".map";
            if (exists(sourceMapFile))
                copy(sourceMapFile, outputPath ~ ".map");
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
        
        // Mill Scala.js task
        string task = config.scalaJs.mode == "fullOpt" ? "fullOpt" : "fastOpt";
        cmd ~= target.name ~ "." ~ task;
        
        Logger.info("Running Mill " ~ task ~ "...");
        Logger.debugLog("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "Scala.js compilation failed:\n" ~ res.output;
            return result;
        }
        
        // Mill output is typically in out/ directory
        string outDir = buildPath(workspace.root, "out");
        string jsFile = findJSFile(outDir, config.scalaJs.mode);
        
        if (jsFile.empty)
        {
            result.error = "Could not find generated JavaScript file";
            return result;
        }
        
        // Copy to output location
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        copy(jsFile, outputPath);
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private string findJSFile(string searchDir, string mode)
    {
        if (!exists(searchDir) || !isDir(searchDir))
            return "";
        
        try
        {
            string pattern = mode == "fullOpt" ? "*-opt.js" : "*-fastopt.js";
            
            foreach (entry; dirEntries(searchDir, SpanMode.depth))
            {
                if (entry.isFile && entry.name.endsWith(".js"))
                {
                    string name = baseName(entry.name);
                    if ((mode == "fullOpt" && name.canFind("-opt.js")) ||
                        (mode == "fastOpt" && name.canFind("-fastopt.js")))
                        return entry.name;
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Error searching for JS file: " ~ e.msg);
        }
        
        return "";
    }
    
    private string getOutputPath(const Target target, const WorkspaceConfig workspace)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        return buildPath(workspace.options.outputDir, name ~ ".js");
    }
}

