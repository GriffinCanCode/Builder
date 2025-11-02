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
import core.caching.actions.action;

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
        
        if (config.packageManager == RubyPackageManager.Auto)
        {
            config.packageManager = detectPackageManager(sourceDir);
            Logger.debugLog("Detected package manager: " ~ config.packageManager.to!string);
        }
        
        if (config.versionManager == RubyVersionManager.Auto)
        {
            config.versionManager = detectVersionManager(sourceDir);
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
        
        if (target.sources.empty)
        {
            result.error = "No source files provided";
            return result;
        }
        
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
        
        string[] checkErrors;
        auto checkSuccess = SyntaxChecker.check(target.sources, checkErrors);
        if (!checkSuccess)
        {
            result.error = checkErrors.length > 0 ? checkErrors[0] : "Syntax check failed";
            return result;
        }
        
        auto outputs = getOutputs(target, config);
        if (!outputs.empty && !target.sources.empty)
        {
            auto outputPath = outputs[0];
            auto mainFile = target.sources[0];
            
            // Generate wrapper script
            import std.file : write;
            write(outputPath, "#!/usr/bin/env ruby\nrequire_relative '" ~ mainFile ~ "'\n");
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
        
        if (target.sources.empty)
        {
            result.error = "No source files provided";
            return result;
        }
        
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
        
        string[] checkErrors2;
        auto checkSuccess2 = SyntaxChecker.check(target.sources, checkErrors2);
        if (!checkSuccess2)
        {
            result.error = checkErrors2.length > 0 ? checkErrors2[0] : "Syntax check failed";
            return result;
        }
        
        if (rubyConfig.mode == RubyBuildMode.Gem)
        {
            auto builder = new GemBuilder();
            auto buildResult = builder.build(target.sources, rubyConfig, target, config);
            if (!buildResult.success)
            {
                result.error = "Failed to build gem: " ~ buildResult.error;
                return result;
            }
            result.outputs = buildResult.outputs;
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
        
        if (config.rubyVersion.major > 0)
        {
            auto versionManager = VersionManagerFactory.create(config.versionManager, projectRoot);
            string versionStr = config.rubyVersion.toString();
            if (versionManager.isVersionInstalled(versionStr))
            {
                rubyCmd = versionManager.getRubyPath(versionStr);
                Logger.debugLog("Using Ruby version: " ~ versionStr);
            }
        }
        
        return rubyCmd;
    }
    
    private bool installDependencies(RubyConfig config, string projectRoot)
    {
        auto packageManager = PackageManagerFactory.create(config.packageManager, projectRoot);
        
        if (packageManager.hasLockfile())
        {
            Logger.info("Installing dependencies");
            auto result = packageManager.installFromFile(buildPath(projectRoot, "Gemfile"));
            return result.success;
        }
        
        return true;
    }
    
    private RubyPackageManager detectPackageManager(string projectRoot)
    {
        if (exists(buildPath(projectRoot, "Gemfile")))
            return RubyPackageManager.Bundler;
        if (exists(buildPath(projectRoot, "*.gemspec")))
            return RubyPackageManager.RubyGems;
        return RubyPackageManager.Bundler;
    }
    
    private RubyVersionManager detectVersionManager(string projectRoot)
    {
        auto versionFile = buildPath(projectRoot, ".ruby-version");
        if (exists(versionFile))
        {
            import utils.security : execute;
            auto checkRbenv = execute(["which", "rbenv"]);
            if (checkRbenv.status == 0)
                return RubyVersionManager.Rbenv;
            
            auto checkChruby = execute(["which", "chruby"]);
            if (checkChruby.status == 0)
                return RubyVersionManager.Chruby;
        }
        
        if (exists(buildPath(projectRoot, ".rvmrc")))
            return RubyVersionManager.RVM;
        
        if (exists(buildPath(projectRoot, ".tool-versions")))
            return RubyVersionManager.ASDF;
        
        return RubyVersionManager.System;
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
        auto actionId = ActionId(target.name, ActionType.Custom, FastHash.hashStrings(target.sources), "typecheck");
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
    
    /// Analyze imports in Ruby source files
    override Import[] analyzeImports(in string[] sources) @system
    {
        import std.file : readText, exists, isFile;
        
        auto spec = getLanguageSpec(TargetLanguage.Ruby);
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
                // Silently skip unreadable files
            }
        }
        
        return allImports;
    }
}
