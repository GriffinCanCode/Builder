module languages.jvm.kotlin.tooling.builders.jar;

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

/// Standard JAR builder for Kotlin
class JARBuilder : KotlinBuilder
{
    override KotlinBuildResult build(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        KotlinBuildResult result;
        
        Logger.debug_("Building standard Kotlin JAR");
        
        // Determine output path
        string outputPath;
        if (!target.outputPath.empty)
        {
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name ~ ".jar");
        }
        
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Use Gradle if available and configured
        if (config.buildTool == KotlinBuildTool.Gradle)
        {
            return buildWithGradle(sources, config, target, workspace, outputPath);
        }
        
        // Use Maven if available and configured
        if (config.buildTool == KotlinBuildTool.Maven)
        {
            return buildWithMaven(sources, config, target, workspace, outputPath);
        }
        
        // Direct kotlinc compilation
        return buildWithKotlinC(sources, config, target, workspace, outputPath);
    }
    
    override bool isAvailable()
    {
        // Check if kotlinc is available
        auto result = execute(["kotlinc", "-version"]);
        return result.status == 0;
    }
    
    override string name() const
    {
        return "JAR";
    }
    
    override bool supportsMode(KotlinBuildMode mode)
    {
        return mode == KotlinBuildMode.JAR || mode == KotlinBuildMode.Compile;
    }
    
    private KotlinBuildResult buildWithGradle(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace,
        string outputPath
    )
    {
        KotlinBuildResult result;
        
        import languages.jvm.kotlin.managers.gradle;
        
        string projectDir = ".";
        if (!sources.empty)
        {
            projectDir = dirName(sources[0]);
            // Navigate to project root (where build.gradle.kts is)
            while (!exists(buildPath(projectDir, "build.gradle.kts")) && 
                   !exists(buildPath(projectDir, "build.gradle")) &&
                   projectDir != dirName(projectDir))
            {
                projectDir = dirName(projectDir);
            }
        }
        
        bool success = GradleOps.jar(projectDir, true);
        
        if (success)
        {
            result.success = true;
            result.outputs = [outputPath];
            
            // Try to find the actual JAR in build/libs
            string libsDir = buildPath(projectDir, "build", "libs");
            if (exists(libsDir))
            {
                auto jars = dirEntries(libsDir, "*.jar", SpanMode.shallow)
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
            result.error = "Gradle JAR build failed";
        }
        
        return result;
    }
    
    private KotlinBuildResult buildWithMaven(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace,
        string outputPath
    )
    {
        KotlinBuildResult result;
        
        import languages.jvm.kotlin.managers.maven;
        
        string projectDir = ".";
        if (!sources.empty)
        {
            projectDir = dirName(sources[0]);
            // Navigate to project root (where pom.xml is)
            while (!exists(buildPath(projectDir, "pom.xml")) &&
                   projectDir != dirName(projectDir))
            {
                projectDir = dirName(projectDir);
            }
        }
        
        bool success = MavenOps.package_(projectDir, config.maven.skipTests);
        
        if (success)
        {
            result.success = true;
            result.outputs = [outputPath];
            
            // Try to find the actual JAR in target/
            string targetDir = buildPath(projectDir, "target");
            if (exists(targetDir))
            {
                auto jars = dirEntries(targetDir, "*.jar", SpanMode.shallow)
                    .filter!(e => !e.name.endsWith("-sources.jar") && !e.name.endsWith("-javadoc.jar"))
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
            result.error = "Maven package failed";
        }
        
        return result;
    }
    
    private KotlinBuildResult buildWithKotlinC(
        string[] sources,
        KotlinConfig config,
        Target target,
        WorkspaceConfig workspace,
        string outputPath
    )
    {
        KotlinBuildResult result;
        
        // Compile with kotlinc
        auto cmd = ["kotlinc"];
        
        // Add language version
        if (config.languageVersion.major > 0)
            cmd ~= ["-language-version", config.languageVersion.toString()];
        
        // Add API version
        if (config.apiVersion.major > 0)
            cmd ~= ["-api-version", config.apiVersion.toString()];
        
        // Add JVM target
        if (config.platform == KotlinPlatform.JVM)
        {
            cmd ~= ["-jvm-target", config.jvmTarget.toString()];
        }
        
        // Include runtime for executables
        if (config.packaging.includeRuntime && target.type == TargetType.Executable)
        {
            cmd ~= ["-include-runtime"];
        }
        
        // Add classpath if dependencies exist
        if (!target.deps.empty || !config.classpath.empty)
        {
            string[] classpaths = config.classpath.dup;
            
            // Add dependency outputs
            foreach (dep; target.deps)
            {
                auto depTarget = workspace.findTarget(dep);
                if (depTarget !is null && !depTarget.outputPath.empty)
                {
                    classpaths ~= buildPath(workspace.options.outputDir, depTarget.outputPath);
                }
            }
            
            if (!classpaths.empty)
            {
                version(Windows)
                    cmd ~= ["-classpath", classpaths.join(";")];
                else
                    cmd ~= ["-classpath", classpaths.join(":")];
            }
        }
        
        // Add compiler flags
        cmd ~= target.flags;
        cmd ~= config.compilerFlags;
        
        // Enable progressive mode
        if (config.progressive)
            cmd ~= ["-progressive"];
        
        // Enable explicit API mode
        if (config.explicitApi)
            cmd ~= ["-Xexplicit-api=strict"];
        
        // Warnings
        if (config.allWarnings)
            cmd ~= ["-Xall-warnings"];
        if (config.warningsAsErrors)
            cmd ~= ["-Werror"];
        
        // Verbose
        if (config.verbose)
            cmd ~= ["-verbose"];
        
        // Add sources
        cmd ~= sources;
        
        // Specify output
        cmd ~= ["-d", outputPath];
        
        Logger.debug_("Executing: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "kotlinc failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        
        if (exists(outputPath))
        {
            result.outputHash = FastHash.hashFile(outputPath);
        }
        else
        {
            result.outputHash = FastHash.hashStrings(sources);
        }
        
        return result;
    }
}

