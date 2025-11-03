module languages.jvm.kotlin.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.base.base;
import languages.base.mixins;
import languages.jvm.kotlin.core.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import infrastructure.analysis.targets.spec;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;

/// Kotlin build handler with action-level caching
class KotlinHandler : BaseLanguageHandler
{
    mixin CachingHandlerMixin!"kotlin";
    mixin SimpleBuildOrchestrationMixin!(KotlinConfig, "parseKotlinConfig");
    
    private void enhanceConfigFromProject(
        ref KotlinConfig ktConfig,
        in Target target,
        in WorkspaceConfig config
    )
    {
        // Auto-detect build tool if needed
        if (ktConfig.buildTool == KotlinBuildTool.Auto)
        {
            ktConfig.buildTool = detectBuildTool();
        }
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        KotlinConfig ktConfig = parseKotlinConfig(target);
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Determine output based on mode and platform
            final switch (ktConfig.mode)
            {
                case KotlinBuildMode.JAR:
                case KotlinBuildMode.FatJAR:
                case KotlinBuildMode.Android:
                case KotlinBuildMode.Compile:
                    outputs ~= buildPath(config.options.outputDir, name ~ ".jar");
                    break;
                case KotlinBuildMode.Native:
                    outputs ~= buildPath(config.options.outputDir, name);
                    break;
                case KotlinBuildMode.JS:
                    outputs ~= buildPath(config.options.outputDir, name ~ ".js");
                    break;
                case KotlinBuildMode.Multiplatform:
                    // Multiple outputs for multiplatform
                    foreach (platform; ktConfig.multiplatform.targets)
                    {
                        final switch (platform)
                        {
                            case KotlinPlatform.JVM:
                            case KotlinPlatform.Android:
                                outputs ~= buildPath(config.options.outputDir, name ~ "-jvm.jar");
                                break;
                            case KotlinPlatform.JS:
                                outputs ~= buildPath(config.options.outputDir, name ~ "-js.js");
                                break;
                            case KotlinPlatform.Native:
                                outputs ~= buildPath(config.options.outputDir, name ~ "-native");
                                break;
                            case KotlinPlatform.Common:
                                outputs ~= buildPath(config.options.outputDir, name ~ "-common.jar");
                                break;
                            case KotlinPlatform.Wasm:
                                outputs ~= buildPath(config.options.outputDir, name ~ ".wasm");
                                break;
                        }
                    }
                    break;
            }
        }
        
        return outputs;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Kotlin);
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
    
    private LanguageBuildResult buildExecutable(in Target target, in WorkspaceConfig config, KotlinConfig ktConfig)
    {
        // Delegate to appropriate builder based on mode
        import languages.jvm.kotlin.tooling.builders;
        
        auto builder = KotlinBuilderFactory.create(ktConfig.mode, ktConfig, actionCache);
        if (builder is null)
        {
            LanguageBuildResult result;
            result.error = "Unsupported build mode: " ~ ktConfig.mode.to!string;
            return result;
        }
        
        auto buildResult = builder.build(target.sources, ktConfig, target, config);
        
        // Convert to LanguageBuildResult
        LanguageBuildResult result;
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(in Target target, in WorkspaceConfig config, KotlinConfig ktConfig)
    {
        // Libraries typically don't include runtime
        ktConfig.packaging.includeRuntime = false;
        
        return buildExecutable(target, config, ktConfig);
    }
    
    private LanguageBuildResult runTests(in Target target, in WorkspaceConfig config, KotlinConfig ktConfig)
    {
        LanguageBuildResult result;
        
        // Use Gradle/Maven if available, otherwise fallback to direct kotlinc
        if (ktConfig.buildTool == KotlinBuildTool.Gradle)
        {
            import languages.jvm.kotlin.managers.gradle;
            
            string projectDir = ".";
            if (!target.sources.empty)
            {
                projectDir = dirName(target.sources[0]);
            }
            
            bool success = GradleOps.test(projectDir, true);
            result.success = success;
            if (!success)
                result.error = "Gradle tests failed";
        }
        else if (ktConfig.buildTool == KotlinBuildTool.Maven)
        {
            import languages.jvm.kotlin.managers.maven;
            
            string projectDir = ".";
            if (!target.sources.empty)
            {
                projectDir = dirName(target.sources[0]);
            }
            
            bool success = MavenOps.test(projectDir);
            result.success = success;
            if (!success)
                result.error = "Maven tests failed";
        }
        else
        {
            // Direct kotlinc test build
            auto outputs = getOutputs(target, config);
            auto tempJar = buildPath(config.options.outputDir, ".kotlin-test.jar");
            
            auto buildCmd = ["kotlinc"];
            
            // Add runtime for tests
            buildCmd ~= ["-include-runtime"];
            
            // Add classpath if dependencies exist
            if (!target.deps.empty)
                buildCmd ~= ["-classpath", buildClasspath(target, config)];
            
            // Add flags
            buildCmd ~= target.flags;
            buildCmd ~= ktConfig.compilerFlags;
            
            // Add language version
            if (ktConfig.languageVersion.major > 0)
                buildCmd ~= ["-language-version", ktConfig.languageVersion.toString()];
            
            // Add API version
            if (ktConfig.apiVersion.major > 0)
                buildCmd ~= ["-api-version", ktConfig.apiVersion.toString()];
            
            // Add JVM target
            if (ktConfig.platform == KotlinPlatform.JVM)
                buildCmd ~= ["-jvm-target", ktConfig.jvmTarget.toString()];
            
            buildCmd ~= target.sources;
            buildCmd ~= ["-d", tempJar];
            
            auto buildRes = execute(buildCmd);
            
            if (buildRes.status != 0)
            {
                result.error = "Test compilation failed: " ~ buildRes.output;
                return result;
            }
            
            // Determine test runner class
            string testClass = ktConfig.test.framework == KotlinTestFramework.JUnit5 
                ? "org.junit.platform.console.ConsoleLauncher"
                : "TestKt";
            
            // Run tests
            auto runCmd = ["kotlin", "-classpath", tempJar];
            runCmd ~= ktConfig.jvmFlags;
            runCmd ~= testClass;
            runCmd ~= ktConfig.test.testFlags;
            
            auto runRes = execute(runCmd);
            
            if (runRes.status != 0)
            {
                result.error = "Tests failed: " ~ runRes.output;
                // Clean up
                if (exists(tempJar))
                    remove(tempJar);
                return result;
            }
            
            // Clean up
            if (exists(tempJar))
                remove(tempJar);
            
            result.success = true;
            result.outputHash = FastHash.hashStrings(target.sources);
        }
        
        return result;
    }
    
    /// Detect build tool from project structure
    private KotlinBuildTool detectBuildTool()
    {
        // Check for Gradle
        if (exists("build.gradle.kts") || exists("build.gradle") || 
            exists("gradlew") || exists("gradle.properties"))
        {
            return KotlinBuildTool.Gradle;
        }
        
        // Check for Maven
        if (exists("pom.xml"))
        {
            return KotlinBuildTool.Maven;
        }
        
        // Default to direct compilation
        return KotlinBuildTool.Direct;
    }
    
    /// Build classpath from dependencies
    private string buildClasspath(const Target target, const WorkspaceConfig config)
    {
        string[] paths;
        
        foreach (dep; target.deps)
        {
            auto depTarget = config.findTarget(dep);
            if (depTarget !is null)
            {
                auto depOutputs = getOutputs(*depTarget, config);
                paths ~= depOutputs;
            }
        }
        
        version(Windows)
            return paths.join(";");
        else
            return paths.join(":");
    }
}

