module languages.jvm.java.tooling.builders.native_;

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
import languages.jvm.java.tooling.detection;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// GraalVM Native Image builder
class NativeImageBuilder : JARBuilder
{
    override string name() const
    {
        return "NativeImage";
    }
    
    override bool supportsMode(JavaBuildMode mode)
    {
        return mode == JavaBuildMode.NativeImage;
    }
    
    override bool isAvailable()
    {
        return super.isAvailable() && JavaToolDetection.isNativeImageAvailable();
    }
    
    override JavaBuildResult build(
        string[] sources,
        JavaConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        JavaBuildResult result;
        
        if (!isAvailable())
        {
            result.error = "GraalVM native-image tool not found. Install GraalVM and native-image component.";
            return result;
        }
        
        if (!config.nativeImage.enabled)
        {
            result.error = "Native image build not enabled in configuration";
            return result;
        }
        
        Logger.debug_("Building Native Image: " ~ target.name);
        
        // First, build a regular JAR
        string outputPath = getOutputPath(target, workspace, config);
        string outputDir = dirName(outputPath);
        string jarPath = buildPath(outputDir, target.name.split(":")[$ - 1] ~ "-temp.jar");
        
        // Temporarily change output path for JAR building
        string originalOutput = target.outputPath;
        target.outputPath = jarPath;
        
        auto jarResult = super.build(sources, config, target, workspace);
        
        target.outputPath = originalOutput;
        
        if (!jarResult.success)
        {
            result.error = "Failed to build JAR for native image: " ~ jarResult.error;
            return result;
        }
        
        // Now build native image from JAR
        if (!buildNativeImage(jarPath, outputPath, config, result))
        {
            // Clean up temp JAR
            if (exists(jarPath))
                remove(jarPath);
            return result;
        }
        
        // Clean up temp JAR
        if (exists(jarPath))
            remove(jarPath);
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private bool buildNativeImage(
        string jarPath,
        string outputPath,
        JavaConfig config,
        ref JavaBuildResult result
    )
    {
        Logger.info("Building GraalVM native image");
        
        string[] cmd = ["native-image"];
        
        // Add main class
        if (!config.nativeImage.mainClass.empty)
            cmd ~= ["-cp", jarPath, config.nativeImage.mainClass];
        else if (!config.packaging.mainClass.empty)
            cmd ~= ["-cp", jarPath, config.packaging.mainClass];
        else
            cmd ~= ["-jar", jarPath];
        
        // Output name
        string imageName = config.nativeImage.imageName;
        if (imageName.empty)
            imageName = baseName(outputPath).stripExtension;
        
        cmd ~= ["-o", outputPath];
        
        // Static linking
        if (config.nativeImage.staticImage)
            cmd ~= "--static";
        
        // No fallback
        if (config.nativeImage.noFallback)
            cmd ~= "--no-fallback";
        
        // Initialize at build time
        if (!config.nativeImage.initializeAtBuildTime.empty)
        {
            foreach (cls; config.nativeImage.initializeAtBuildTime)
                cmd ~= ["--initialize-at-build-time=" ~ cls];
        }
        
        // Initialize at run time
        if (!config.nativeImage.initializeAtRunTime.empty)
        {
            foreach (cls; config.nativeImage.initializeAtRunTime)
                cmd ~= ["--initialize-at-run-time=" ~ cls];
        }
        
        // Enable reflection
        if (config.nativeImage.enableReflection)
        {
            // Look for reflect-config.json in resources
            string[] configDirs = [
                "src/main/resources/META-INF/native-image",
                "resources/META-INF/native-image",
                "META-INF/native-image"
            ];
            
            foreach (dir; configDirs)
            {
                if (exists(dir))
                {
                    cmd ~= ["-H:ReflectionConfigurationFiles=" ~ buildPath(dir, "reflect-config.json")];
                    break;
                }
            }
        }
        
        // Add custom build arguments
        cmd ~= config.nativeImage.buildArgs;
        
        // Verbose output
        if (config.warnings)
            cmd ~= "--verbose";
        
        Logger.debug_("Native image command: " ~ cmd.join(" "));
        Logger.info("Building native image (this may take several minutes)...");
        
        auto nativeRes = execute(cmd);
        
        if (nativeRes.status != 0)
        {
            result.error = "native-image failed:\n" ~ nativeRes.output;
            return false;
        }
        
        if (!nativeRes.output.empty)
            result.warnings ~= nativeRes.output.splitLines;
        
        Logger.info("Native image built successfully");
        
        return true;
    }
    
    protected override string getOutputPath(Target target, WorkspaceConfig workspace, JavaConfig config)
    {
        if (!target.outputPath.empty)
            return buildPath(workspace.options.outputDir, target.outputPath);
        
        string name = target.name.split(":")[$ - 1];
        
        // Native executables don't have .jar extension
        version(Windows)
            name ~= ".exe";
        
        return buildPath(workspace.options.outputDir, name);
    }
}

