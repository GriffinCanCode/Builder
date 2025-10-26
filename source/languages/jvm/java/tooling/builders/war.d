module languages.jvm.java.tooling.builders.war;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.jvm.java.tooling.builders.base;
import languages.jvm.java.tooling.builders.jar;
import languages.jvm.java.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// WAR (Web Application Archive) builder
class WARBuilder : JARBuilder
{
    override string name() const
    {
        return "WAR";
    }
    
    override bool supportsMode(JavaBuildMode mode)
    {
        return mode == JavaBuildMode.WAR || mode == JavaBuildMode.EAR || mode == JavaBuildMode.RAR;
    }
    
    override JavaBuildResult build(
        string[] sources,
        JavaConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        JavaBuildResult result;
        
        Logger.debug_("Building WAR: " ~ target.name);
        
        // Determine output path
        string outputPath = getOutputPath(target, workspace, config);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Create temporary build directory with WAR structure
        string tempDir = buildPath(outputDir, ".java-war-" ~ target.name.split(":")[$ - 1]);
        if (exists(tempDir))
            rmdirRecurse(tempDir);
        
        // Create WAR directory structure
        string webInfDir = buildPath(tempDir, "WEB-INF");
        string classesDir = buildPath(webInfDir, "classes");
        string libDir = buildPath(webInfDir, "lib");
        
        mkdirRecurse(classesDir);
        mkdirRecurse(libDir);
        
        scope(exit)
        {
            if (exists(tempDir))
            {
                try { rmdirRecurse(tempDir); }
                catch (Exception) {}
            }
        }
        
        // Compile sources to WEB-INF/classes
        if (!compileSources(sources, classesDir, config, target, workspace, result))
            return result;
        
        // Copy web resources (if they exist)
        copyWebResources(tempDir, workspace.root);
        
        // Copy dependencies to WEB-INF/lib
        copyDependenciesToLib(libDir, target, workspace, config);
        
        // Create WAR file
        if (!createWAR(tempDir, outputPath, result))
            return result;
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    protected override string getOutputPath(Target target, WorkspaceConfig workspace, JavaConfig config)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        string ext = ".war";
        
        // Determine extension based on mode
        if (config.mode == JavaBuildMode.EAR)
            ext = ".ear";
        else if (config.mode == JavaBuildMode.RAR)
            ext = ".rar";
        
        return buildPath(workspace.options.outputDir, name ~ ext);
    }
    
    private void copyWebResources(string warDir, string projectRoot)
    {
        // Look for standard web resources locations
        string[] webDirs = [
            buildPath(projectRoot, "src", "main", "webapp"),
            buildPath(projectRoot, "webapp"),
            buildPath(projectRoot, "web")
        ];
        
        foreach (webDir; webDirs)
        {
            if (exists(webDir) && isDir(webDir))
            {
                Logger.info("Copying web resources from: " ~ webDir);
                copyRecursive(webDir, warDir);
                break;
            }
        }
    }
    
    private void copyDependenciesToLib(
        string libDir,
        Target target,
        WorkspaceConfig workspace,
        JavaConfig config
    )
    {
        foreach (dep; target.deps)
        {
            auto depTarget = workspace.findTarget(dep);
            if (depTarget !is null)
            {
                string depJar = super.getOutputPath(*depTarget, workspace, config);
                if (exists(depJar) && depJar.endsWith(".jar"))
                {
                    string destPath = buildPath(libDir, baseName(depJar));
                    copy(depJar, destPath);
                }
            }
        }
    }
    
    private void copyRecursive(string source, string dest)
    {
        import std.file : dirEntries, SpanMode;
        
        foreach (entry; dirEntries(source, SpanMode.depth))
        {
            string relativePath = entry.relativePath(source);
            string destPath = buildPath(dest, relativePath);
            
            if (entry.isDir)
            {
                if (!exists(destPath))
                    mkdirRecurse(destPath);
            }
            else if (entry.isFile)
            {
                string destDir = dirName(destPath);
                if (!exists(destDir))
                    mkdirRecurse(destDir);
                copy(entry, destPath);
            }
        }
    }
    
    private bool createWAR(string warDir, string outputPath, ref JavaBuildResult result)
    {
        Logger.info("Creating WAR: " ~ outputPath);
        
        string[] cmd = ["jar", "cf", outputPath, "-C", warDir, "."];
        
        auto jarRes = execute(cmd);
        
        if (jarRes.status != 0)
        {
            result.error = "WAR creation failed:\n" ~ jarRes.output;
            return false;
        }
        
        return true;
    }
}

