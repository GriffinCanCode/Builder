module languages.jvm.scala.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.base.base;
import languages.jvm.scala.core.config;
import languages.jvm.scala.tooling.builders;
import languages.jvm.scala.tooling.formatters;
import languages.jvm.scala.tooling.checkers;
import languages.jvm.scala.tooling.detection;
import languages.jvm.scala.tooling.info;
import languages.jvm.scala.managers.sbt;
import languages.jvm.scala.managers.mill;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Scala build handler - modular and comprehensive
class ScalaHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Scala target: " ~ target.name);
        
        // Parse Scala configuration
        ScalaConfig scalaConfig = parseScalaConfig(target);
        
        // Auto-detect Scala version if not specified
        if (scalaConfig.versionInfo.major == 0 || scalaConfig.versionInfo.minor == 0)
        {
            scalaConfig.versionInfo = ScalaToolDetection.detectScalaVersion(config.root);
        }
        
        // Auto-detect build tool if not specified
        if (scalaConfig.buildTool == ScalaBuildTool.Auto)
        {
            scalaConfig.buildTool = ScalaToolDetection.detectBuildTool(config.root);
            Logger.debug_("Auto-detected build tool: " ~ scalaConfig.buildTool.to!string);
        }
        
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, scalaConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, scalaConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, scalaConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, scalaConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Check for special build modes
            ScalaConfig scalaConfig = parseScalaConfig(target);
            
            if (scalaConfig.mode == ScalaBuildMode.ScalaJS)
                outputs ~= buildPath(config.options.outputDir, name ~ ".js");
            else if (scalaConfig.mode == ScalaBuildMode.ScalaNative)
            {
                version(Windows)
                    outputs ~= buildPath(config.options.outputDir, name ~ ".exe");
                else
                    outputs ~= buildPath(config.options.outputDir, name);
            }
            else if (scalaConfig.mode == ScalaBuildMode.Assembly)
                outputs ~= buildPath(config.options.outputDir, name ~ "-assembly.jar");
            else
                outputs ~= buildPath(config.options.outputDir, name ~ ".jar");
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config, ScalaConfig scalaConfig)
    {
        LanguageBuildResult result;
        
        // Format sources if enabled
        if (scalaConfig.formatter.enabled && scalaConfig.formatter.autoFormat)
        {
            formatSources(target.sources, scalaConfig, config.root);
        }
        
        // Run linter if enabled
        if (scalaConfig.linter.enabled)
        {
            bool lintOk = checkSources(target.sources, scalaConfig, config.root);
            if (!lintOk && scalaConfig.linter.failOnWarnings)
            {
                result.error = "Linter found issues";
                return result;
            }
        }
        
        // Get appropriate builder
        auto builder = ScalaBuilderFactory.createAuto(scalaConfig, config.root);
        
        Logger.debug_("Using builder: " ~ builder.name());
        
        // Build
        auto buildResult = builder.build(target.sources, scalaConfig, target, config);
        
        // Convert to LanguageBuildResult
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config, ScalaConfig scalaConfig)
    {
        // Libraries are built the same way as executables, just packaged differently
        return buildExecutable(target, config, scalaConfig);
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config, ScalaConfig scalaConfig)
    {
        LanguageBuildResult result;
        
        if (!scalaConfig.test.enabled)
        {
            Logger.info("Tests disabled in configuration");
            result.success = true;
            result.outputHash = FastHash.hashStrings(target.sources);
            return result;
        }
        
        // Detect test framework
        auto framework = scalaConfig.test.framework;
        if (framework == ScalaTestFramework.Auto)
        {
            framework = ScalaToolDetection.detectTestFramework(config.root);
        }
        
        Logger.info("Running tests with framework: " ~ framework.to!string);
        
        // Use build tool for tests
        bool testsPassed = false;
        
        final switch (scalaConfig.buildTool)
        {
            case ScalaBuildTool.SBT:
                testsPassed = SbtOps.test(config.root);
                break;
            
            case ScalaBuildTool.Mill:
                testsPassed = MillOps.test(config.root);
                break;
            
            case ScalaBuildTool.ScalaCLI:
            case ScalaBuildTool.Direct:
            case ScalaBuildTool.Maven:
            case ScalaBuildTool.Gradle:
            case ScalaBuildTool.Bloop:
            case ScalaBuildTool.Auto:
            case ScalaBuildTool.None:
                // Fallback: compile and try to run
                auto builder = ScalaBuilderFactory.create(ScalaBuildMode.JAR, scalaConfig);
                auto buildResult = builder.build(target.sources, scalaConfig, target, config);
                testsPassed = buildResult.success;
                break;
        }
        
        if (!testsPassed)
        {
            result.error = "Tests failed";
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config, ScalaConfig scalaConfig)
    {
        LanguageBuildResult result;
        
        if (target.commands.empty)
        {
            result.error = "Custom target requires commands";
            return result;
        }
        
        foreach (cmd; target.commands)
        {
            auto res = executeShell(cmd);
            if (res.status != 0)
            {
                result.error = "Command failed: " ~ cmd ~ "\n" ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        
        return result;
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Scala);
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
    
    // Helper methods
    
    private void formatSources(string[] sources, ScalaConfig config, string workingDir)
    {
        auto formatter = FormatterFactory.create(config.formatter.formatter, workingDir);
        
        if (!formatter.isAvailable())
        {
            Logger.warning("Formatter not available: " ~ formatter.name());
            return;
        }
        
        Logger.info("Formatting sources with " ~ formatter.name());
        
        auto result = formatter.format(sources, config.formatter, workingDir, false);
        
        if (!result.success)
        {
            Logger.warning("Formatting had issues: " ~ result.error);
        }
        else
        {
            Logger.debug_("Formatted " ~ result.filesFormatted.to!string ~ " files");
        }
    }
    
    private bool checkSources(string[] sources, ScalaConfig config, string workingDir)
    {
        auto checker = CheckerFactory.create(config.linter.linter, workingDir);
        
        if (!checker.isAvailable())
        {
            Logger.warning("Checker not available: " ~ checker.name());
            return true;
        }
        
        Logger.info("Checking sources with " ~ checker.name());
        
        auto result = checker.check(sources, config.linter, workingDir);
        
        if (!result.success)
        {
            Logger.warning("Linter found " ~ result.issuesFound.to!string ~ " issues");
            foreach (violation; result.violations)
                Logger.warning(violation);
            return false;
        }
        
        return true;
    }
}

