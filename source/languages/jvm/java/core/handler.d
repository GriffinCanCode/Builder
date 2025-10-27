module languages.jvm.java.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.base.base;
import languages.jvm.java.core.config;
import languages.jvm.java.managers;
import languages.jvm.java.tooling.detection;
import languages.jvm.java.tooling.info;
import languages.jvm.java.tooling.builders;
import languages.jvm.java.tooling.formatters;
import languages.jvm.java.analysis;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Java build handler - comprehensive and modular
class JavaHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Java target: " ~ target.name);
        
        // Parse Java configuration
        JavaConfig javaConfig = parseJavaConfig(target);
        
        // Detect and enhance configuration from project structure
        BuildToolFactory.enhanceConfigFromProject(javaConfig, config.root);
        
        // Validate Java installation
        if (!JavaToolDetection.isJavacAvailable())
        {
            result.error = "Java compiler (javac) not found. Please install JDK.";
            return result;
        }
        
        // Check Java version
        auto javaVersion = JavaInfo.getVersion();
        if (!JavaInfo.meetsMinimumVersion(javaVersion, javaConfig.sourceVersion))
        {
            Logger.warning("Java version " ~ javaVersion.toString() ~ 
                          " may not support source version " ~ javaConfig.sourceVersion.toString());
        }
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, javaConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, javaConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, javaConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, javaConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        
        JavaConfig javaConfig = parseJavaConfig(target);
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Determine extension based on build mode
            string ext = ".jar";
            if (javaConfig.mode == JavaBuildMode.WAR)
                ext = ".war";
            else if (javaConfig.mode == JavaBuildMode.EAR)
                ext = ".ear";
            else if (javaConfig.mode == JavaBuildMode.NativeImage)
            {
                version(Windows)
                    ext = ".exe";
                else
                    ext = "";
            }
            
            outputs ~= buildPath(config.options.outputDir, name ~ ext);
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        const Target target,
        const WorkspaceConfig config,
        JavaConfig javaConfig
    )
    {
        LanguageBuildResult result;
        
        // Use build tool if configured
        if (javaConfig.buildTool != JavaBuildTool.Direct && javaConfig.buildTool != JavaBuildTool.None)
        {
            return buildWithBuildTool(target, config, javaConfig);
        }
        
        // Install dependencies if using Maven/Gradle
        if (javaConfig.maven.autoInstall && JavaToolDetection.hasPomXml(config.root))
        {
            bool useWrapper = BuildToolFactory.shouldUseWrapper(JavaBuildTool.Maven, config.root);
            if (!MavenOps.installDependencies(config.root, useWrapper))
            {
                Logger.warning("Maven dependency installation had issues, continuing anyway");
            }
        }
        else if (javaConfig.gradle.autoInstall && JavaToolDetection.hasBuildGradle(config.root))
        {
            bool useWrapper = BuildToolFactory.shouldUseWrapper(JavaBuildTool.Gradle, config.root);
            if (!GradleOps.installDependencies(config.root, useWrapper))
            {
                Logger.warning("Gradle dependency resolution had issues, continuing anyway");
            }
        }
        
        // Auto-format if configured
        if (javaConfig.formatter.autoFormat && javaConfig.formatter.formatter != languages.jvm.java.core.config.JavaFormatterType.None)
        {
            Logger.info("Auto-formatting code");
            auto formatter = JavaFormatterFactory.create(javaConfig.formatter.formatter, config.root);
            auto formatResult = formatter.format(target.sources, javaConfig.formatter, config.root, javaConfig.formatter.checkOnly);
            
            if (!formatResult.success)
            {
                Logger.warning("Formatting failed, continuing anyway");
            }
        }
        
        // Run static analysis if configured
        if (javaConfig.analysis.enabled && javaConfig.analysis.analyzer != JavaAnalyzer.None)
        {
            Logger.info("Running static analysis");
            auto analyzer = AnalyzerFactory.create(javaConfig.analysis.analyzer, config.root);
            auto analysisResult = analyzer.analyze(target.sources, javaConfig.analysis, config.root);
            
            if (analysisResult.hasErrors() && javaConfig.analysis.failOnErrors)
            {
                result.error = "Static analysis found errors:\n" ~ analysisResult.errors.join("\n");
                return result;
            }
            
            if (analysisResult.hasWarnings())
            {
                Logger.warning("Static analysis warnings:");
                foreach (warning; analysisResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
                
                if (javaConfig.analysis.failOnWarnings)
                {
                    result.error = "Static analysis warnings treated as errors";
                    return result;
                }
            }
        }
        
        // Build using appropriate builder
        auto builder = JavaBuilderFactory.create(javaConfig.mode, javaConfig);
        
        if (!builder.isAvailable())
        {
            result.error = "Builder " ~ builder.name() ~ " not available";
            return result;
        }
        
        auto buildResult = builder.build(target.sources, javaConfig, target, config);
        
        if (!buildResult.success)
        {
            result.error = buildResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        const Target target,
        const WorkspaceConfig config,
        JavaConfig javaConfig
    )
    {
        LanguageBuildResult result;
        
        // Libraries are built similarly to executables, just without main class
        if (javaConfig.packaging.mainClass.empty)
        {
            // Force JAR mode for libraries
            if (javaConfig.mode == JavaBuildMode.FatJAR)
                javaConfig.mode = JavaBuildMode.JAR;
        }
        
        return buildExecutable(target, config, javaConfig);
    }
    
    private LanguageBuildResult runTests(
        const Target target,
        const WorkspaceConfig config,
        JavaConfig javaConfig
    )
    {
        LanguageBuildResult result;
        
        Logger.info("Running Java tests");
        
        // Use build tool for testing if available
        if (javaConfig.buildTool == JavaBuildTool.Maven && JavaToolDetection.hasPomXml(config.root))
        {
            bool useWrapper = BuildToolFactory.shouldUseWrapper(JavaBuildTool.Maven, config.root);
            if (!MavenOps.test(config.root, useWrapper))
            {
                result.error = "Maven tests failed";
                return result;
            }
        }
        else if (javaConfig.buildTool == JavaBuildTool.Gradle && JavaToolDetection.hasBuildGradle(config.root))
        {
            bool useWrapper = BuildToolFactory.shouldUseWrapper(JavaBuildTool.Gradle, config.root);
            if (!GradleOps.test(config.root, useWrapper))
            {
                result.error = "Gradle tests failed";
                return result;
            }
        }
        else
        {
            // Run JUnit directly
            auto testResult = runJUnitTests(target, config, javaConfig);
            if (!testResult.success)
                return testResult;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        const Target target,
        const WorkspaceConfig config,
        JavaConfig javaConfig
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    private LanguageBuildResult buildWithBuildTool(
        Target target,
        WorkspaceConfig config,
        JavaConfig javaConfig
    )
    {
        LanguageBuildResult result;
        
        bool useWrapper = BuildToolFactory.shouldUseWrapper(javaConfig.buildTool, config.root);
        
        final switch (javaConfig.buildTool)
        {
            case JavaBuildTool.Maven:
                if (!MavenOps.packageProject(config.root, javaConfig.maven.skipTests, useWrapper))
                {
                    result.error = "Maven build failed";
                    return result;
                }
                break;
            
            case JavaBuildTool.Gradle:
                if (!GradleOps.build(config.root, javaConfig.gradle.skipTests, useWrapper))
                {
                    result.error = "Gradle build failed";
                    return result;
                }
                break;
            
            case JavaBuildTool.Auto:
            case JavaBuildTool.Direct:
            case JavaBuildTool.Ant:
            case JavaBuildTool.None:
                // Fall back to direct compilation
                return buildExecutable(target, config, javaConfig);
        }
        
        // Find output artifacts
        auto outputs = getOutputs(target, config);
        
        if (outputs.length > 0 && exists(outputs[0]))
        {
            result.success = true;
            result.outputs = outputs;
            result.outputHash = FastHash.hashFile(outputs[0]);
        }
        else
        {
            result.error = "Build succeeded but output not found";
        }
        
        return result;
    }
    
    private LanguageBuildResult runJUnitTests(
        Target target,
        WorkspaceConfig config,
        JavaConfig javaConfig
    )
    {
        LanguageBuildResult result;
        
        Logger.info("Running JUnit tests directly");
        
        // This is a simplified implementation
        // In a real scenario, we'd need to find JUnit JAR and run tests properly
        
        Logger.warning("Direct JUnit execution not fully implemented, use Maven/Gradle for testing");
        
        result.success = true;
        return result;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Java);
        if (spec is null)
            return [];
        
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                auto imports = spec.scanImports(source, content);
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
}
