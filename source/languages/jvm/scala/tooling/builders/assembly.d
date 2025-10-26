module languages.jvm.scala.tooling.builders.assembly;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.jvm.scala.tooling.builders.base;
import languages.jvm.scala.tooling.builders.jar;
import languages.jvm.scala.core.config;
import languages.jvm.scala.tooling.detection;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Assembly (fat JAR) builder - packages all dependencies
class AssemblyBuilder : ScalaBuilder
{
    override ScalaBuildResult build(
        string[] sources,
        ScalaConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ScalaBuildResult result;
        
        Logger.debug_("Building Scala assembly JAR: " ~ target.name);
        
        // Detect build tool
        auto buildTool = config.buildTool;
        if (buildTool == ScalaBuildTool.Auto)
            buildTool = ScalaToolDetection.detectBuildTool(workspace.root);
        
        // Use sbt-assembly if available
        if (buildTool == ScalaBuildTool.SBT && ScalaToolDetection.usesSbtAssembly(workspace.root))
        {
            return buildWithSbtAssembly(target, config, workspace, result);
        }
        
        // Use Mill if available
        if (buildTool == ScalaBuildTool.Mill)
        {
            return buildWithMill(target, config, workspace, result);
        }
        
        // Fallback: Build normal JAR and manually merge dependencies
        Logger.warning("sbt-assembly not available, building basic JAR");
        auto jarBuilder = new JARBuilder();
        return jarBuilder.build(sources, config, target, workspace);
    }
    
    override bool isAvailable()
    {
        return ScalaToolDetection.isSBTAvailable() || 
               ScalaToolDetection.isMillAvailable() ||
               ScalaToolDetection.isScalacAvailable();
    }
    
    override string name() const
    {
        return "Assembly";
    }
    
    override bool supportsMode(ScalaBuildMode mode)
    {
        return mode == ScalaBuildMode.Assembly;
    }
    
    private ScalaBuildResult buildWithSbtAssembly(
        Target target,
        ScalaConfig config,
        WorkspaceConfig workspace,
        ScalaBuildResult result
    )
    {
        string[] cmd = ["sbt"];
        
        // Add configuration
        if (config.sbt.clean)
            cmd ~= "clean";
        
        // Run assembly task
        cmd ~= "assembly";
        
        Logger.info("Running sbt assembly...");
        Logger.debug_("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "sbt assembly failed:\n" ~ res.output;
            return result;
        }
        
        // Find generated assembly JAR
        string targetDir = buildPath(workspace.root, "target");
        string assemblyJar = findAssemblyJar(targetDir);
        
        if (assemblyJar.empty)
        {
            result.error = "Could not find generated assembly JAR";
            return result;
        }
        
        // Copy to output location
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        copy(assemblyJar, outputPath);
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private ScalaBuildResult buildWithMill(
        Target target,
        ScalaConfig config,
        WorkspaceConfig workspace,
        ScalaBuildResult result
    )
    {
        string[] cmd = ["mill"];
        
        // Add Mill-specific assembly task
        cmd ~= "assembly";
        
        Logger.info("Running Mill assembly...");
        Logger.debug_("Command: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "Mill assembly failed:\n" ~ res.output;
            return result;
        }
        
        // Find generated JAR in out/ directory
        string outDir = buildPath(workspace.root, "out");
        string assemblyJar = findAssemblyJar(outDir);
        
        if (assemblyJar.empty)
        {
            result.error = "Could not find generated assembly JAR";
            return result;
        }
        
        // Copy to output location
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        copy(assemblyJar, outputPath);
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private string findAssemblyJar(string searchDir)
    {
        if (!exists(searchDir) || !isDir(searchDir))
            return "";
        
        try
        {
            // Look for *-assembly-*.jar files
            foreach (entry; dirEntries(searchDir, SpanMode.depth))
            {
                if (entry.isFile && entry.name.endsWith(".jar"))
                {
                    string name = baseName(entry.name);
                    if (name.canFind("assembly") || name.canFind("fat"))
                        return entry.name;
                }
            }
            
            // Fallback: look for any JAR
            foreach (entry; dirEntries(searchDir, "*.jar", SpanMode.depth))
            {
                if (entry.isFile)
                    return entry.name;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Error searching for assembly JAR: " ~ e.msg);
        }
        
        return "";
    }
    
    private string getOutputPath(Target target, WorkspaceConfig workspace)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        return buildPath(workspace.options.outputDir, name ~ "-assembly.jar");
    }
}

