module languages.jvm.scala.tooling.builders.jar;

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
import languages.jvm.scala.tooling.info;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Standard JAR builder using scalac
class JARBuilder : ScalaBuilder
{
    override ScalaBuildResult build(
        in string[] sources,
        in ScalaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        ScalaBuildResult result;
        
        Logger.debug_("Building Scala JAR: " ~ target.name);
        
        // Determine output path
        string outputPath = getOutputPath(target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Create temp directory for class files
        auto tempDir = buildPath(outputDir, ".scala-build-" ~ target.name.replace(":", "-"));
        if (!exists(tempDir))
            mkdirRecurse(tempDir);
        
        scope(failure)
        {
            // Clean up temp directory on failure
            if (exists(tempDir))
                rmdirRecurse(tempDir);
        }
        
        scope(success)
        {
            // Clean up temp directory on success
            if (exists(tempDir))
                rmdirRecurse(tempDir);
        }
        
        // Compile sources
        bool compiled = compileSources(sources, tempDir, config, target, workspace, result);
        if (!compiled)
            return result;
        
        // Package into JAR
        bool packaged = packageJAR(tempDir, outputPath, config, target, result);
        if (!packaged)
            return result;
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return ScalaToolDetection.isScalacAvailable();
    }
    
    override string name() const
    {
        return "JAR";
    }
    
    override bool supportsMode(ScalaBuildMode mode)
    {
        return mode == ScalaBuildMode.JAR || mode == ScalaBuildMode.Compile;
    }
    
    private bool compileSources(
        const string[] sources,
        string outputDir,
        ScalaConfig config,
        const Target target,
        const WorkspaceConfig workspace,
        ref ScalaBuildResult result
    )
    {
        // Build scalac command
        string[] cmd = [ScalaToolDetection.getScalacCommand()];
        
        // Output directory
        cmd ~= ["-d", outputDir];
        
        // Classpath
        string cp = buildClasspath(target, workspace);
        if (!cp.empty)
            cmd ~= ["-classpath", cp];
        
        // Add compiler options
        cmd ~= buildCompilerOptions(config);
        
        // Add target flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= sources;
        
        Logger.debug_("Scalac command: " ~ cmd.join(" "));
        
        // Execute compilation
        auto compileRes = execute(cmd);
        
        if (compileRes.status != 0)
        {
            result.error = "Scala compilation failed:\n" ~ compileRes.output;
            result.compilerMessages ~= compileRes.output;
            return false;
        }
        
        // Capture warnings
        if (!compileRes.output.empty)
        {
            result.warnings ~= compileRes.output;
            result.compilerMessages ~= compileRes.output;
        }
        
        return true;
    }
    
    private bool packageJAR(
        string classDir,
        string outputPath,
        ScalaConfig config,
        const Target target,
        ref ScalaBuildResult result
    )
    {
        // Build jar command
        string[] cmd = ["jar"];
        
        // Create with manifest if needed
        if (target.type == TargetType.Executable)
        {
            // Find main class
            string mainClass = detectMainClass(classDir, config);
            if (mainClass.empty)
            {
                Logger.warning("No main class found for executable");
            }
            else
            {
                // Create manifest
                string manifestPath = buildPath(classDir, "MANIFEST.MF");
                createManifest(manifestPath, mainClass);
                cmd ~= ["cfm", outputPath, manifestPath];
            }
        }
        else
        {
            cmd ~= ["cf", outputPath];
        }
        
        // Add class files
        cmd ~= ["-C", classDir, "."];
        
        Logger.debug_("JAR command: " ~ cmd.join(" "));
        
        // Execute jar packaging
        auto jarRes = execute(cmd);
        
        if (jarRes.status != 0)
        {
            result.error = "JAR creation failed:\n" ~ jarRes.output;
            return false;
        }
        
        return true;
    }
    
    private string[] buildCompilerOptions(ScalaConfig config)
    {
        string[] options;
        
        // Version-specific
        if (config.versionInfo.isScala3())
        {
            // Scala 3 options
            if (config.compiler.experimental)
                options ~= "-experimental";
            
            if (config.compiler.explainTypes)
                options ~= "-explain";
            
            if (config.compiler.safeInit)
                options ~= "-Ysafe-init";
        }
        else
        {
            // Scala 2 options
            if (config.compiler.optimization != OptimizationLevel.None)
            {
                auto optOpts = ScalaInfoDetector.getOptimizationOptions(
                    config.compiler.optimization, 
                    config.versionInfo
                );
                options ~= optOpts;
            }
        }
        
        // Common options
        if (config.compiler.deprecation)
            options ~= "-deprecation";
        
        if (config.compiler.feature)
            options ~= "-feature";
        
        if (config.compiler.unchecked)
            options ~= "-unchecked";
        
        if (config.compiler.warnings)
        {
            if (config.compiler.warningsAsErrors)
                options ~= "-Xfatal-warnings";
        }
        
        // Target JVM
        if (!config.compiler.target.empty)
            options ~= ["-target:jvm-" ~ config.compiler.target];
        
        // Encoding
        options ~= ["-encoding", config.compiler.encoding];
        
        // Language features
        foreach (feature; config.compiler.languageFeatures)
            options ~= "-language:" ~ feature;
        
        // Plugins
        foreach (plugin; config.compiler.plugins)
            options ~= ["-Xplugin:" ~ plugin];
        
        // Additional options
        options ~= config.compiler.options;
        
        return options;
    }
    
    private string buildClasspath(const Target target, const WorkspaceConfig workspace)
    {
        string[] paths;
        
        // Add dependency outputs
        foreach (dep; target.deps)
        {
            auto depTarget = workspace.findTarget(dep);
            if (depTarget !is null)
            {
                string depOutput = buildPath(workspace.options.outputDir, depTarget.outputPath);
                if (depOutput.empty)
                    depOutput = buildPath(workspace.options.outputDir, dep.split(":")[$ - 1] ~ ".jar");
                paths ~= depOutput;
            }
        }
        
        // Add explicit classpath
        // paths ~= config.classpath;
        
        version(Windows)
            return paths.join(";");
        else
            return paths.join(":");
    }
    
    private string detectMainClass(string classDir, ScalaConfig config)
    {
        // TODO: Scan class files for main method
        // For now, return empty string
        return "";
    }
    
    private void createManifest(string path, string mainClass)
    {
        auto f = File(path, "w");
        f.writeln("Manifest-Version: 1.0");
        f.writeln("Main-Class: " ~ mainClass);
        f.close();
    }
    
    private string getOutputPath(const Target target, const WorkspaceConfig workspace)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        return buildPath(workspace.options.outputDir, name ~ ".jar");
    }
}

