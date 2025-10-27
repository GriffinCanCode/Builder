module languages.jvm.java.tooling.builders.jar;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import languages.jvm.java.tooling.builders.base;
import languages.jvm.java.core.config;
import languages.jvm.java.tooling.detection;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Standard JAR builder
class JARBuilder : JavaBuilder
{
    override JavaBuildResult build(
        in string[] sources,
        in JavaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        JavaBuildResult result;
        
        Logger.debug_("Building JAR: " ~ target.name);
        
        // Determine output path
        string outputPath = getOutputPath(target, workspace, config);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Create temporary build directory
        string tempDir = buildPath(outputDir, ".java-build-" ~ target.name.split(":")[$ - 1]);
        if (exists(tempDir))
            rmdirRecurse(tempDir);
        mkdirRecurse(tempDir);
        
        scope(failure)
        {
            // Clean up temp directory on failure
            if (exists(tempDir))
            {
                try {
                    rmdirRecurse(tempDir);
                }
                catch (Exception e) {
                    // Ignore cleanup errors
                }
            }
        }
        
        scope(success)
        {
            // Clean up temp directory on success
            if (exists(tempDir))
                rmdirRecurse(tempDir);
        }
        
        // Compile sources
        if (!compileSources(sources, tempDir, config, target, workspace, result))
            return result;
        
        // Create JAR
        if (!createJAR(tempDir, outputPath, config, target, result))
            return result;
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    override bool isAvailable()
    {
        return JavaToolDetection.isJavacAvailable() && JavaToolDetection.isJarAvailable();
    }
    
    override string name() const
    {
        return "JAR";
    }
    
    override bool supportsMode(JavaBuildMode mode)
    {
        return mode == JavaBuildMode.JAR || mode == JavaBuildMode.Compile;
    }
    
    protected bool compileSources(
        const string[] sources,
        string outputDir,
        const JavaConfig config,
        const Target target,
        const WorkspaceConfig workspace,
        ref JavaBuildResult result
    )
    {
        Logger.info("Compiling Java sources");
        
        string javacCmd = JavaToolDetection.getJavacCommand();
        string[] cmd = [javacCmd, "-d", outputDir];
        
        // Add source/target version
        if (config.sourceVersion.major > 0)
            cmd ~= ["-source", config.sourceVersion.toString()];
        if (config.targetVersion.major > 0)
            cmd ~= ["-target", config.targetVersion.toString()];
        
        // Add encoding
        cmd ~= ["-encoding", config.encoding];
        
        // Add warnings
        if (config.warnings)
            cmd ~= "-Xlint:all";
        if (config.warningsAsErrors)
            cmd ~= "-Werror";
        if (config.deprecation)
            cmd ~= "-Xlint:deprecation";
        
        // Add preview features
        if (config.enablePreview)
            cmd ~= "--enable-preview";
        
        // Add classpath
        string classpath = buildClasspath(target, workspace, config);
        if (!classpath.empty)
            cmd ~= ["-cp", classpath];
        
        // Add module path if using modules
        if (config.modules.enabled && !config.modules.modulePath.empty)
        {
            cmd ~= ["--module-path", config.modules.modulePath.join(pathSeparator)];
        }
        
        // Add annotation processor options
        if (config.processors.enabled)
        {
            if (!config.processors.processorPath.empty)
                cmd ~= ["--processor-path", config.processors.processorPath.join(pathSeparator)];
            if (!config.processors.processors.empty)
                cmd ~= ["-processor", config.processors.processors.join(",")];
        }
        
        // Add compiler flags
        cmd ~= config.compilerFlags;
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= sources;
        
        Logger.debug_("Compile command: " ~ cmd.join(" "));
        
        auto compileRes = execute(cmd);
        
        if (compileRes.status != 0)
        {
            result.error = "javac failed:\n" ~ compileRes.output;
            return false;
        }
        
        // Capture warnings
        if (!compileRes.output.empty)
            result.warnings ~= compileRes.output.splitLines;
        
        return true;
    }
    
    protected bool createJAR(
        string classDir,
        string outputPath,
        const JavaConfig config,
        const Target target,
        ref JavaBuildResult result
    )
    {
        Logger.info("Creating JAR: " ~ outputPath);
        
        string jarCmd = JavaToolDetection.getJarCommand();
        string[] cmd = [jarCmd];
        
        // Auto-detect main class for executable JARs if not specified
        string mainClass = config.packaging.mainClass;
        if (mainClass.empty && target.type == TargetType.Executable)
        {
            mainClass = detectMainClass(classDir);
            if (!mainClass.empty)
            {
                Logger.debug_("Auto-detected main class: " ~ mainClass);
            }
        }
        
        // Determine if this is an executable JAR
        bool isExecutable = !mainClass.empty;
        bool hasManifestAttrs = !config.packaging.manifestAttributes.empty;
        
        // Build JAR command flags
        // Order matters: c=create, f=file, m=manifest, e=entry(main)
        // Note: 'i' (index) cannot be combined with 'c' in short-form commands
        string flags = "cf";
        
        // Decide whether to use manifest file or 'e' flag
        // Use manifest file if there are custom attributes, otherwise use 'e' flag for simplicity
        bool useManifestFile = hasManifestAttrs || isExecutable;
        string manifestFile;
        
        if (useManifestFile)
        {
            flags ~= "m";
            manifestFile = buildPath(classDir, "MANIFEST.MF");
            createManifestWithMainClass(manifestFile, config, mainClass);
        }
        
        // Add flags and output path
        cmd ~= [flags, outputPath];
        
        // Add manifest file if using it
        if (useManifestFile)
            cmd ~= manifestFile;
        
        // Add classes
        cmd ~= ["-C", classDir, "."];
        
        Logger.debug_("JAR command: " ~ cmd.join(" "));
        
        auto jarRes = execute(cmd);
        
        if (jarRes.status != 0)
        {
            result.error = "jar creation failed:\n" ~ jarRes.output;
            return false;
        }
        
        // Add index if requested (must be done after JAR creation)
        if (config.packaging.createIndex)
        {
            Logger.debug_("Adding index to JAR");
            string[] indexCmd = [jarCmd, "i", outputPath];
            auto indexRes = execute(indexCmd);
            
            if (indexRes.status != 0)
            {
                // Index creation is not critical, just log warning
                Logger.warning("Failed to create JAR index: " ~ indexRes.output);
            }
        }
        
        return true;
    }
    
    protected void createManifestWithMainClass(string manifestPath, const JavaConfig config, string mainClass)
    {
        auto f = File(manifestPath, "w");
        
        f.writeln("Manifest-Version: 1.0");
        
        if (!mainClass.empty)
            f.writeln("Main-Class: " ~ mainClass);
        
        foreach (key, value; config.packaging.manifestAttributes)
            f.writeln(key ~ ": " ~ value);
        
        f.close();
    }
    
    /// Auto-detect main class by searching for classes with public static void main(String[]) method
    protected string detectMainClass(string classDir)
    {
        import std.file : dirEntries, SpanMode;
        import std.algorithm : endsWith;
        
        // Search for .class files
        foreach (entry; dirEntries(classDir, SpanMode.depth))
        {
            if (!entry.isFile || !entry.name.endsWith(".class"))
                continue;
            
            // Get class name from path
            string relPath = entry.name[classDir.length + 1 .. $];
            if (relPath.startsWith("./"))
                relPath = relPath[2 .. $];
            
            // Convert path to class name (remove .class and replace / with .)
            string className = relPath[0 .. $ - 6].replace("/", ".").replace("\\", ".");
            
            // Skip inner classes (containing $)
            if (className.indexOf('$') >= 0)
                continue;
            
            // Check if this class has a main method using javap
            if (hasMainMethod(className, classDir))
            {
                return className;
            }
        }
        
        return "";
    }
    
    /// Check if a class has a public static void main(String[]) method
    private bool hasMainMethod(string className, string classDir)
    {
        try
        {
            // Use javap to inspect the class
            auto result = execute(["javap", "-cp", classDir, "-public", className]);
            
            if (result.status == 0)
            {
                // Look for main method signature
                auto regex = regex(`public\s+static\s+void\s+main\s*\(\s*java\.lang\.String\s*\[\s*\]\s*\)`);
                return !matchFirst(result.output, regex).empty;
            }
        }
        catch (Exception e)
        {
            // Ignore errors
        }
        
        return false;
    }
    
    protected string buildClasspath(const Target target, const WorkspaceConfig workspace, const JavaConfig config)
    {
        string[] paths;
        
        // Add explicitly configured classpath
        paths ~= config.classpath;
        
        // Add dependencies
        foreach (dep; target.deps)
        {
            auto depTarget = workspace.findTarget(dep);
            if (depTarget !is null)
            {
                // Find the output JAR of the dependency
                string depOutput = getOutputPath(*depTarget, workspace, config);
                if (exists(depOutput))
                    paths ~= depOutput;
            }
        }
        
        version(Windows)
            return paths.join(";");
        else
            return paths.join(":");
    }
    
    protected string pathSeparator()
    {
        version(Windows)
            return ";";
        else
            return ":";
    }
    
    protected string getOutputPath(const Target target, const WorkspaceConfig workspace, const JavaConfig config)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        return buildPath(workspace.options.outputDir, name ~ ".jar");
    }
}

