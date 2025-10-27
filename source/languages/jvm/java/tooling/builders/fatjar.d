module languages.jvm.java.tooling.builders.fatjar;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.zip;
import languages.jvm.java.tooling.builders.base;
import languages.jvm.java.tooling.builders.jar;
import languages.jvm.java.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Fat JAR (uber-jar) builder - includes all dependencies
class FatJARBuilder : JARBuilder
{
    override string name() const
    {
        return "FatJAR";
    }
    
    override bool supportsMode(JavaBuildMode mode)
    {
        return mode == JavaBuildMode.FatJAR;
    }
    
    override JavaBuildResult build(
        in string[] sources,
        in JavaConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        JavaBuildResult result;
        
        Logger.debug_("Building Fat JAR: " ~ target.name);
        
        // Determine output path
        string outputPath = getOutputPath(target, workspace, config);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Create atomic temporary directory (prevents TOCTOU attacks)
        import utils.security.tempdir : AtomicTempDir;
        auto atomicTemp = AtomicTempDir.in_(outputDir, ".java-fatjar-" ~ target.name.split(":")[$ - 1].replace(":", "-"));
        string tempDir = atomicTemp.get();
        
        scope(failure)
        {
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
            if (exists(tempDir))
                rmdirRecurse(tempDir);
        }
        
        // Compile sources
        if (!compileSources(sources, tempDir, config, target, workspace, result))
            return result;
        
        // Extract and merge dependencies
        if (!mergeDependencies(tempDir, target, workspace, config, result))
            return result;
        
        // Create fat JAR
        if (!createJAR(tempDir, outputPath, config, result))
            return result;
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private bool mergeDependencies(
        string tempDir,
        const Target target,
        const WorkspaceConfig workspace,
        JavaConfig config,
        ref JavaBuildResult result
    )
    {
        Logger.info("Merging dependencies into Fat JAR");
        
        foreach (dep; target.deps)
        {
            auto depTarget = workspace.findTarget(dep);
            if (depTarget !is null)
            {
                string depJar = getOutputPath(*depTarget, workspace, config);
                if (exists(depJar) && depJar.endsWith(".jar"))
                {
                    if (!extractJar(depJar, tempDir))
                    {
                        Logger.warning("Failed to extract dependency: " ~ depJar);
                    }
                }
            }
        }
        
        // Also extract from classpath entries
        foreach (cpEntry; config.classpath)
        {
            if (exists(cpEntry) && cpEntry.endsWith(".jar"))
            {
                if (!extractJar(cpEntry, tempDir))
                {
                    Logger.warning("Failed to extract classpath entry: " ~ cpEntry);
                }
            }
        }
        
        return true;
    }
    
    private bool extractJar(string jarPath, string targetDir)
    {
        try
        {
            // Use jar command to extract
            auto result = execute(["jar", "xf", jarPath], null, Config.none, size_t.max, targetDir);
            return result.status == 0;
        }
        catch (Exception e)
        {
            Logger.warning("JAR extraction failed: " ~ e.msg);
            return false;
        }
    }
}

