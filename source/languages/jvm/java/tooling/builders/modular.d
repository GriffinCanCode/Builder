module languages.jvm.java.tooling.builders.modular;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.jvm.java.tooling.builders.base;
import languages.jvm.java.tooling.builders.jar;
import languages.jvm.java.core.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;
import engine.caching.actions.action : ActionCache;

/// Modular JAR builder (Java 9+ module system)
class ModularJARBuilder : JARBuilder
{
    this(ActionCache actionCache = null)
    {
        super(actionCache);
    }
    
    override string name() const
    {
        return "ModularJAR";
    }
    
    override bool supportsMode(JavaBuildMode mode)
    {
        return mode == JavaBuildMode.ModularJAR;
    }
    
    override JavaBuildResult build(
        in string[] sources,
        in JavaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        JavaBuildResult result;
        
        // Verify Java version supports modules
        if (config.sourceVersion.major < 9)
        {
            result.error = "Modular JARs require Java 9 or higher (current: " ~ config.sourceVersion.toString() ~ ")";
            return result;
        }
        
        if (!config.modules.enabled)
        {
            result.error = "Module system not enabled in configuration";
            return result;
        }
        
        Logger.debugLog("Building Modular JAR: " ~ target.name);
        
        // Verify module-info.java exists
        bool hasModuleInfo = sources.any!(s => s.endsWith("module-info.java"));
        if (!hasModuleInfo)
        {
            result.error = "module-info.java not found in sources for modular build";
            return result;
        }
        
        // Use standard JAR building with module-specific flags
        return super.build(sources, config, target, workspace);
    }
    
    override protected bool compileSources(
        const string[] sources,
        string outputDir,
        const JavaConfig config,
        const Target target,
        const WorkspaceConfig workspace,
        ref JavaBuildResult result
    )
    {
        Logger.info("Compiling modular Java sources");
        
        import languages.jvm.java.tooling.detection;
        
        string javacCmd = JavaToolDetection.getJavacCommand();
        string[] cmd = [javacCmd, "-d", outputDir];
        
        // Add source/target version
        if (config.sourceVersion.major > 0)
            cmd ~= ["--release", config.sourceVersion.major.to!string];
        
        // Add encoding
        cmd ~= ["-encoding", config.encoding];
        
        // Add module path
        if (!config.modules.modulePath.empty)
        {
            cmd ~= ["--module-path", config.modules.modulePath.join(pathSeparator)];
        }
        
        // Add add-modules
        if (!config.modules.addModules.empty)
        {
            foreach (mod; config.modules.addModules)
                cmd ~= ["--add-modules", mod];
        }
        
        // Add add-exports
        if (!config.modules.addExports.empty)
        {
            foreach (exp; config.modules.addExports)
                cmd ~= ["--add-exports", exp];
        }
        
        // Add add-opens
        if (!config.modules.addOpens.empty)
        {
            foreach (open; config.modules.addOpens)
                cmd ~= ["--add-opens", open];
        }
        
        // Add add-reads
        if (!config.modules.addReads.empty)
        {
            foreach (read; config.modules.addReads)
                cmd ~= ["--add-reads", read];
        }
        
        // Add patch-module
        foreach (mod, path; config.modules.patchModule)
        {
            cmd ~= ["--patch-module", mod ~ "=" ~ path];
        }
        
        // Add warnings
        if (config.warnings)
            cmd ~= "-Xlint:all";
        if (config.warningsAsErrors)
            cmd ~= "-Werror";
        
        // Add compiler flags
        cmd ~= config.compilerFlags;
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= sources;
        
        Logger.debugLog("Compile command: " ~ cmd.join(" "));
        
        auto compileRes = execute(cmd);
        
        if (compileRes.status != 0)
        {
            result.error = "javac failed:\n" ~ compileRes.output;
            return false;
        }
        
        if (!compileRes.output.empty)
            result.warnings ~= compileRes.output.splitLines;
        
        return true;
    }
    
    override protected bool createJAR(
        string classDir,
        string outputPath,
        const JavaConfig config,
        const Target target,
        ref JavaBuildResult result
    )
    {
        Logger.info("Creating Modular JAR: " ~ outputPath);
        
        import languages.jvm.java.tooling.detection;
        
        string jarCmd = JavaToolDetection.getJarCommand();
        string[] cmd = [jarCmd];
        
        // Create modular JAR
        cmd ~= ["--create", "--file=" ~ outputPath];
        
        // Auto-detect main class for executable JARs if not specified
        string mainClass = config.packaging.mainClass;
        if (mainClass.empty && target.type == TargetType.Executable)
        {
            mainClass = detectMainClass(classDir);
            if (!mainClass.empty)
            {
                Logger.debugLog("Auto-detected main class: " ~ mainClass);
            }
        }
        
        // Add main class if specified
        if (!mainClass.empty)
            cmd ~= ["--main-class=" ~ mainClass];
        
        // Add module version if specified
        if (!config.modules.moduleName.empty && !config.packaging.manifestAttributes.get("Module-Version", "").empty)
        {
            string moduleVersion = config.packaging.manifestAttributes["Module-Version"];
            cmd ~= ["--module-version=" ~ moduleVersion];
        }
        
        // Generate index if requested
        if (config.packaging.createIndex)
            cmd ~= "--generate-index=.";
        
        // Add classes
        cmd ~= ["-C", classDir, "."];
        
        Logger.debugLog("JAR command: " ~ cmd.join(" "));
        
        auto jarRes = execute(cmd);
        
        if (jarRes.status != 0)
        {
            result.error = "Modular JAR creation failed:\n" ~ jarRes.output;
            return false;
        }
        
        return true;
    }
}

