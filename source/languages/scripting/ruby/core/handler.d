module languages.scripting.ruby.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import std.json;
import languages.base.base;
import languages.base.mixins;
import languages.scripting.ruby.core.config;
import languages.scripting.ruby.tooling.info;
import languages.scripting.ruby.managers;
import languages.scripting.ruby.tooling.checkers;
import languages.scripting.ruby.tooling.formatters;
import languages.scripting.ruby.tooling.builders;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import core.caching.action;

/// Ruby build handler with action-level caching
class RubyHandler : BaseLanguageHandler
{
    mixin CachingHandlerMixin!"ruby";
    mixin ConfigParsingMixin!(RubyConfig, "parseRubyConfig", ["ruby", "rubyConfig"]);
    mixin OutputResolutionMixin!(RubyConfig, "parseRubyConfig");
    mixin BuildOrchestrationMixin!(RubyConfig, "parseRubyConfig", string);
    
    private string setupBuildContext(RubyConfig rubyConfig, in WorkspaceConfig config)
    {
        return setupRubyEnvironment(rubyConfig, config.root);
    }
    
    private void enhanceConfigFromProject(
        ref RubyConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        if (config.gemManager == GemManager.Auto)
        {
            config.gemManager = GemManagerFactory.detectFromProject(sourceDir);
            Logger.debugLog("Detected gem manager: " ~ config.gemManager.to!string);
        }
        
        if (config.versionManager == VersionManager.Auto)
        {
            config.versionManager = VersionManagerDetector.detect(sourceDir);
            Logger.debugLog("Detected version manager: " ~ config.versionManager.to!string);
        }
    }
    
    private LanguageBuildResult buildExecutable(
        const Target target,
        const WorkspaceConfig config,
        RubyConfig rubyConfig,
        string rubyCmd
    )
    {
        LanguageBuildResult result;
        
        if (rubyConfig.installDeps && !installDependencies(rubyConfig, config.root))
            {
                result.error = "Failed to install dependencies";
                return result;
        }
        
        if (rubyConfig.format.autoFormat && rubyConfig.format.formatter != RubyFormatter.None)
        {
            Logger.info("Auto-formatting code");
            auto formatter = FormatterFactory.create(rubyConfig.format.formatter);
            auto fmtResult = formatter.format(target.sources, rubyConfig.format, rubyConfig.format.autoCorrect);
            
            if (!fmtResult.success)
                Logger.warning("Formatting failed, continuing anyway");
            else if (fmtResult.hasOffenses())
            {
                Logger.info("Found " ~ fmtResult.offenseCount.to!string ~ " style offenses");
                if (fmtResult.autoFixed)
                    Logger.info("Auto-fixed offenses");
            }
        }
        
        if (rubyConfig.typeCheck.enabled)
        {
            auto typeResult = typeCheckWithCache(target, rubyConfig);
            
            if (typeResult.hasErrors())
            {
                result.error = "Type checking failed:\n" ~ typeResult.errors.join("\n");
                return result;
            }
            
            if (typeResult.hasWarnings() && rubyConfig.typeCheck.strict)
            {
                result.error = "Type checking warnings in strict mode:\n" ~ typeResult.warnings.join("\n");
                return result;
                }
            }
        
        auto checkResult = SyntaxChecker.check(target.sources, rubyCmd);
        if (!checkResult.success)
        {
            result.error = checkResult.error;
            return result;
        }
        
        auto outputs = getOutputs(target, config);
        if (!outputs.empty && !target.sources.empty)
        {
            auto outputPath = outputs[0];
            auto mainFile = target.sources[0];
            
            WrapperGenerator.generate(mainFile, outputPath, rubyCmd);
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        const Target target,
        const WorkspaceConfig config,
        RubyConfig rubyConfig,
        string rubyCmd
    )
    {
        LanguageBuildResult result;
        
        if (rubyConfig.installDeps && !installDependencies(rubyConfig, config.root))
            {
                result.error = "Failed to install dependencies";
                return result;
        }
        
        if (rubyConfig.typeCheck.enabled)
        {
            auto typeResult = typeCheckWithCache(target, rubyConfig);
            if (typeResult.hasErrors())
            {
                result.error = "Type checking failed:\n" ~ typeResult.errors.join("\n");
                return result;
            }
        }
        
        auto checkResult = SyntaxChecker.check(target.sources, rubyCmd);
        if (!checkResult.success)
        {
            result.error = checkResult.error;
            return result;
        }
        
        if (rubyConfig.buildGem)
        {
            auto builder = GemBuilder(rubyConfig, config.root);
            if (!builder.build())
            {
                result.error = "Failed to build gem";
                return result;
            }
        }
        
        result.success = true;
        result.outputs = target.sources.dup;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        const Target target,
        const WorkspaceConfig config,
        RubyConfig rubyConfig,
        string rubyCmd
    )
    {
        LanguageBuildResult result;
        
        auto runner = rubyConfig.test.framework;
        if (runner == RubyTestFramework.Auto)
            runner = detectTestFramework(config.root);
        
        final switch (runner)
        {
            case RubyTestFramework.Auto:
                runner = RubyTestFramework.Minitest;
                goto case RubyTestFramework.Minitest;
            
            case RubyTestFramework.Minitest:
                result = runMinitest(target, rubyConfig, rubyCmd);
                break;
            
            case RubyTestFramework.RSpec:
                result = runRSpec(target, rubyConfig, rubyCmd);
                break;
            
            case RubyTestFramework.TestUnit:
                result = runTestUnit(target, rubyConfig, rubyCmd);
                break;
            
            case RubyTestFramework.Cucumber:
                // Not implemented yet
                result.success = true;
                break;
            
            case RubyTestFramework.None:
                result.success = true;
                break;
        }
        
        return result;
    }
    
    // ===== Helper methods =====
    
    private string setupRubyEnvironment(RubyConfig config, string projectRoot)
    {
        string rubyCmd = "ruby";
        
        if (!config.rubyVersion.empty)
        {
            auto versionManager = VersionManagerFactory.create(config.versionManager);
            if (versionManager.ensureVersion(config.rubyVersion, projectRoot))
            {
                rubyCmd = versionManager.getRubyCommand(config.rubyVersion);
                Logger.debugLog("Using Ruby version: " ~ config.rubyVersion);
            }
        }
        
        return rubyCmd;
    }
    
    private bool installDependencies(RubyConfig config, string projectRoot)
    {
        auto gemManager = GemManagerFactory.create(config.gemManager);
        
        if (gemManager.hasDependencyFile(projectRoot))
                {
            Logger.info("Installing dependencies");
            return gemManager.install(projectRoot, config.gemInstallArgs);
        }
        
        return true;
    }
    
    private RubyTestFramework detectTestFramework(string projectRoot)
    {
        if (exists(buildPath(projectRoot, "spec")))
            return RubyTestFramework.RSpec;
        if (exists(buildPath(projectRoot, "test")))
            return RubyTestFramework.Minitest;
        return RubyTestFramework.Minitest;
    }
    
    private LanguageBuildResult runMinitest(in Target target, RubyConfig config, string rubyCmd)
    {
        LanguageBuildResult result;
        
        string[] cmd = [rubyCmd, "-Ilib:test"];
        foreach (source; target.sources)
            cmd ~= ["-r", source];
        cmd ~= config.test.minitestArgs;
        
        auto res = execute(cmd);
        result.success = (res.status == 0);
        if (!result.success)
            result.error = "Minitest failed";
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult runRSpec(in Target target, RubyConfig config, string rubyCmd)
    {
        LanguageBuildResult result;
        
        string[] cmd = ["rspec"];
        cmd ~= config.test.rspecArgs;
            cmd ~= target.sources;
        
        auto res = execute(cmd);
        result.success = (res.status == 0);
        if (!result.success)
            result.error = "RSpec failed";
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult runTestUnit(in Target target, RubyConfig config, string rubyCmd)
    {
        LanguageBuildResult result;
        
        string[] cmd = [rubyCmd];
            cmd ~= target.sources;
        
        auto res = execute(cmd);
        result.success = (res.status == 0);
        if (!result.success)
            result.error = "Test::Unit failed";
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private auto typeCheckWithCache(in Target target, RubyConfig config)
    {
        auto actionId = ActionId(ActionType.TypeCheck, target.name);
        actionId.inputHash = FastHash.hashStrings(target.sources);
        
        string[string] metadata;
        metadata["checker"] = config.typeCheck.checker.to!string;
        
        if (getCache().isCached(actionId, target.sources, metadata))
            {
            Logger.debugLog("  [Cached] Type checking");
            return TypeCheckResult();
            }
            
        auto checker = TypeCheckerFactory.create(config.typeCheck.checker);
        auto result = checker.check(target.sources, config.typeCheck);
        
        getCache().update(actionId, target.sources, [], metadata, !result.hasErrors());
        
        return result;
    }
}
