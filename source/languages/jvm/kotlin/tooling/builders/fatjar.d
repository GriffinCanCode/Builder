module languages.jvm.kotlin.tooling.builders.fatjar;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.jvm.kotlin.tooling.builders.base;
import languages.jvm.kotlin.core.config;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;
import core.caching.action : ActionCache;

/// Fat JAR builder for Kotlin (includes all dependencies)
class FatJARBuilder : KotlinBuilder
{
    this(ActionCache cache = null) {}
    
    override KotlinBuildResult build(
        in string[] sources,
        in KotlinConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        KotlinBuildResult result;
        
        Logger.debugLog("Building Kotlin Fat JAR");
        
        // Fat JARs are best built with Gradle or Maven
        if (config.buildTool == KotlinBuildTool.Gradle)
        {
            return buildWithGradle(sources, config, target, workspace);
        }
        
        if (config.buildTool == KotlinBuildTool.Maven)
        {
            return buildWithMaven(sources, config, target, workspace);
        }
        
        // Fallback: build regular JAR and warn about dependencies
        Logger.warning("Fat JAR requires Gradle or Maven. Building regular JAR instead.");
        
        import languages.jvm.kotlin.tooling.builders.jar;
        auto jarBuilder = new JARBuilder();
        return jarBuilder.build(sources, config, target, workspace);
    }
    
    override bool isAvailable()
    {
        return true; // Depends on build tool availability
    }
    
    override string name() const
    {
        return "FatJAR";
    }
    
    override bool supportsMode(KotlinBuildMode mode)
    {
        return mode == KotlinBuildMode.FatJAR;
    }
    
    private KotlinBuildResult buildWithGradle(
        const string[] sources,
        const KotlinConfig config,
        const Target target,
        const WorkspaceConfig workspace
    )
    {
        KotlinBuildResult result;
        
        import languages.jvm.kotlin.managers.gradle;
        
        string projectDir = findProjectRoot(sources, ["build.gradle.kts", "build.gradle"]);
        
        // Gradle with shadow plugin for fat JAR
        // Usually requires: id("com.github.johnrengelman.shadow")
        auto res = GradleOps.executeGradleWrapper(["shadowJar"], projectDir);
        
        if (res.status != 0)
        {
            // Try regular JAR task
            res = GradleOps.executeGradleWrapper(["jar"], projectDir);
        }
        
        if (res.status == 0)
        {
            result.success = true;
            
            // Find output JAR
            string libsDir = buildPath(projectDir, "build", "libs");
            if (exists(libsDir))
            {
                auto jars = dirEntries(libsDir, "*.jar", SpanMode.shallow)
                    .filter!(e => e.name.canFind("all") || e.name.canFind("shadow") || !e.name.canFind("plain"))
                    .map!(e => e.name)
                    .array;
                if (!jars.empty)
                {
                    result.outputs = jars;
                    result.outputHash = FastHash.hashFile(jars[0]);
                }
            }
        }
        else
        {
            result.error = "Gradle shadow/fat JAR build failed: " ~ res.output;
        }
        
        return result;
    }
    
    private KotlinBuildResult buildWithMaven(
        const string[] sources,
        const KotlinConfig config,
        const Target target,
        const WorkspaceConfig workspace
    )
    {
        KotlinBuildResult result;
        
        import languages.jvm.kotlin.managers.maven;
        
        string projectDir = findProjectRoot(sources, ["pom.xml"]);
        
        // Maven with shade plugin for fat JAR
        auto res = MavenOps.executeMaven(["package"], projectDir);
        
        if (res.status == 0)
        {
            result.success = true;
            
            // Find output JAR
            string targetDir = buildPath(projectDir, "target");
            if (exists(targetDir))
            {
                auto jars = dirEntries(targetDir, "*.jar", SpanMode.shallow)
                    .filter!(e => e.name.canFind("shaded") || e.name.canFind("uber") || 
                                  (!e.name.endsWith("-sources.jar") && !e.name.endsWith("-javadoc.jar")))
                    .map!(e => e.name)
                    .array;
                if (!jars.empty)
                {
                    result.outputs = jars;
                    result.outputHash = FastHash.hashFile(jars[0]);
                }
            }
        }
        else
        {
            result.error = "Maven fat JAR build failed: " ~ res.output;
        }
        
        return result;
    }
    
    private string findProjectRoot(const string[] sources, string[] markers)
    {
        if (sources.empty)
            return ".";
        
        string projectDir = dirName(sources[0]);
        
        while (projectDir != dirName(projectDir))
        {
            foreach (marker; markers)
            {
                if (exists(buildPath(projectDir, marker)))
                    return projectDir;
            }
            projectDir = dirName(projectDir);
        }
        
        return ".";
    }
}

