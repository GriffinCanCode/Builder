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

/// Ruby build handler - comprehensive and modular
class RubyHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debugLog("Building Ruby target: " ~ target.name);
        
        // Parse Ruby configuration
        RubyConfig rubyConfig = parseRubyConfig(target);
        
        // Auto-detect and enhance configuration from project structure
        enhanceConfigFromProject(rubyConfig, target, config);
        
        // Setup Ruby environment
        string rubyCmd = setupRubyEnvironment(rubyConfig, config.root);
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, rubyConfig, rubyCmd);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, rubyConfig, rubyCmd);
                break;
            case TargetType.Test:
                result = runTests(target, config, rubyConfig, rubyCmd);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, rubyConfig, rubyCmd);
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
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        const Target target,
        const WorkspaceConfig config,
        RubyConfig rubyConfig,
        string rubyCmd
    )
    {
        LanguageBuildResult result;
        
        // Install dependencies if requested
        if (rubyConfig.installDeps)
        {
            if (!installDependencies(rubyConfig, config.root))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Auto-format if configured
        if (rubyConfig.format.autoFormat && rubyConfig.format.formatter != RubyFormatter.None)
        {
            Logger.info("Auto-formatting code");
            auto formatter = FormatterFactory.create(rubyConfig.format.formatter);
            auto fmtResult = formatter.format(target.sources, rubyConfig.format, rubyConfig.format.autoCorrect);
            
            if (!fmtResult.success)
            {
                Logger.warning("Formatting failed, continuing anyway");
            }
            else if (fmtResult.hasOffenses())
            {
                Logger.info("Found " ~ fmtResult.offenseCount.to!string ~ " style offenses");
                if (fmtResult.autoFixed)
                    Logger.info("Auto-fixed offenses");
            }
        }
        
        // Type check if configured
        if (rubyConfig.typeCheck.enabled)
        {
            Logger.info("Running type checking");
            auto checker = TypeCheckerFactory.create(rubyConfig.typeCheck.checker);
            auto typeResult = checker.check(target.sources, rubyConfig.typeCheck);
            
            if (typeResult.hasErrors())
            {
                result.error = "Type checking failed:\n" ~ typeResult.errors.join("\n");
                return result;
            }
            
            if (typeResult.hasWarnings())
            {
                Logger.warning("Type checking warnings:");
                foreach (warning; typeResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
            }
        }
        
        // Validate Ruby syntax
        string[] syntaxErrors;
        if (!SyntaxChecker.check(target.sources, syntaxErrors))
        {
            result.error = syntaxErrors.join("\n");
            return result;
        }
        
        // Build using appropriate builder
        auto builder = BuilderFactory.create(rubyConfig.mode);
        auto buildResult = builder.build(target.sources, rubyConfig, target, config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        // Report tool warnings
        if (!buildResult.toolWarnings.empty)
        {
            Logger.info("Build completed with warnings:");
            foreach (warning; buildResult.toolWarnings)
            {
                Logger.warning("  " ~ warning);
            }
        }
        
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
        
        // Install dependencies if requested
        if (rubyConfig.installDeps)
        {
            if (!installDependencies(rubyConfig, config.root))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Type check if configured
        if (rubyConfig.typeCheck.enabled)
        {
            Logger.info("Running type checking");
            auto checker = TypeCheckerFactory.create(rubyConfig.typeCheck.checker);
            auto typeResult = checker.check(target.sources, rubyConfig.typeCheck);
            
            if (typeResult.hasErrors())
            {
                result.error = "Type checking failed:\n" ~ typeResult.errors.join("\n");
                return result;
            }
        }
        
        // Validate syntax
        string[] syntaxErrors;
        if (!SyntaxChecker.check(target.sources, syntaxErrors))
        {
            result.error = syntaxErrors.join("\n");
            return result;
        }
        
        // Build using appropriate builder
        auto builder = BuilderFactory.create(rubyConfig.mode);
        auto buildResult = builder.build(target.sources, rubyConfig, target, config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        // Generate documentation if configured
        if (rubyConfig.documentation.generator != RubyDocGenerator.None)
        {
            Logger.info("Generating documentation");
            DocGenerator.generate(target.sources, rubyConfig.documentation);
        }
        
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
        
        // Determine test framework
        auto framework = rubyConfig.test.framework;
        if (framework == RubyTestFramework.Auto)
        {
            framework = detectTestFramework(config.root);
        }
        
        // Run tests based on framework
        final switch (framework)
        {
            case RubyTestFramework.Auto:
                // Fallback to RSpec if available, else Minitest
                framework = RubyTools.isRSpecAvailable() ? RubyTestFramework.RSpec : RubyTestFramework.Minitest;
                goto case RubyTestFramework.RSpec;
            
            case RubyTestFramework.RSpec:
                result = runRSpec(target, rubyConfig, config.root);
                break;
            
            case RubyTestFramework.Minitest:
                result = runMinitest(target, rubyConfig, config.root);
                break;
            
            case RubyTestFramework.TestUnit:
                result = runTestUnit(target, rubyConfig, config.root);
                break;
            
            case RubyTestFramework.Cucumber:
                result = runCucumber(target, rubyConfig, config.root);
                break;
            
            case RubyTestFramework.None:
                result.success = true;
                break;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        const Target target,
        const WorkspaceConfig config,
        RubyConfig rubyConfig,
        string rubyCmd
    )
    {
        LanguageBuildResult result;
        
        // Execute Rake tasks if specified
        if (!rubyConfig.rakeTasks.empty)
        {
            auto rake = new RakeTool(config.root);
            foreach (task; rubyConfig.rakeTasks)
            {
                Logger.info("Running Rake task: " ~ task);
                auto res = rake.runTask(task);
                if (res.status != 0)
                {
                    result.error = "Rake task '" ~ task ~ "' failed: " ~ res.output;
                    return result;
                }
            }
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse Ruby configuration from target
    private RubyConfig parseRubyConfig(const Target target)
    {
        RubyConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("ruby" in target.langConfig)
            configKey = "ruby";
        else if ("rubyConfig" in target.langConfig)
            configKey = "rubyConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = RubyConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Ruby config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration based on project structure
    private void enhanceConfigFromProject(
        ref RubyConfig config,
        const Target target,
        const WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Auto-detect package manager if set to auto
        if (config.packageManager == RubyPackageManager.Auto)
        {
            if (ProjectDetector.usesBundler(sourceDir))
            {
                config.packageManager = RubyPackageManager.Bundler;
                Logger.debugLog("Detected Bundler from Gemfile");
            }
            else
            {
                config.packageManager = RubyPackageManager.RubyGems;
            }
        }
        
        // Auto-detect build mode
        if (config.mode == RubyBuildMode.Script)
        {
            auto detectedMode = ProjectDetector.detectProjectType(sourceDir);
            if (detectedMode != RubyBuildMode.Script)
            {
                config.mode = detectedMode;
                Logger.debugLog("Detected project type: " ~ detectedMode.to!string);
            }
        }
        
        // Auto-detect test framework
        if (config.test.framework == RubyTestFramework.Auto)
        {
            if (ProjectDetector.usesRSpec(sourceDir))
            {
                config.test.framework = RubyTestFramework.RSpec;
                Logger.debugLog("Detected RSpec from spec/ directory");
            }
            else if (ProjectDetector.usesMinitest(sourceDir))
            {
                config.test.framework = RubyTestFramework.Minitest;
                Logger.debugLog("Detected Minitest from test/ directory");
            }
        }
        
        // Check for .ruby-version file
        if (config.rubyVersion.hasVersionFile())
        {
            auto version_ = RubyVersionUtil.parseVersionFile(config.rubyVersion.versionFile);
            if (!version_.empty)
            {
                Logger.debugLog("Found Ruby version in .ruby-version: " ~ version_);
            }
        }
    }
    
    /// Setup Ruby environment and return Ruby command to use
    private string setupRubyEnvironment(RubyConfig config, string projectRoot)
    {
        string rubyCmd = "ruby";
        
        // Use specific interpreter if configured
        if (!config.rubyVersion.interpreterPath.empty)
        {
            rubyCmd = config.rubyVersion.interpreterPath;
        }
        else if (config.versionManager != RubyVersionManager.None)
        {
            // Use version manager
            auto vm = VersionManagerFactory.create(config.versionManager, projectRoot);
            
            if (vm.isAvailable())
            {
                rubyCmd = vm.getRubyPath();
                Logger.info("Using Ruby from " ~ vm.name() ~ ": " ~ vm.getCurrentVersion());
            }
        }
        
        // Verify Ruby is available
        if (!RubyVersionUtil.isRubyAvailable(rubyCmd))
        {
            Logger.warning("Ruby not available at: " ~ rubyCmd ~ ", falling back to 'ruby'");
            rubyCmd = "ruby";
        }
        
        auto version_ = RubyVersionUtil.getRubyVersion(rubyCmd);
        Logger.debugLog("Using Ruby: " ~ rubyCmd ~ " (" ~ version_ ~ ")");
        
        return rubyCmd;
    }
    
    /// Install dependencies using configured package manager
    private bool installDependencies(RubyConfig config, string projectRoot)
    {
        auto pm = PackageManagerFactory.create(config.packageManager, projectRoot);
        
        if (!pm.isAvailable())
        {
            Logger.error("Package manager not available: " ~ pm.name());
            return false;
        }
        
        Logger.info("Using package manager: " ~ pm.name() ~ " (" ~ pm.getVersion() ~ ")");
        
        // Install from Gemfile if using Bundler
        if (config.packageManager == RubyPackageManager.Bundler)
        {
            auto bundler = cast(BundlerManager)pm;
            if (bundler)
            {
                auto result = bundler.installWithConfig(config.bundler);
                if (!result.success)
                {
                    Logger.error("Failed to install gems: " ~ result.error);
                    return false;
                }
                Logger.info("Installed " ~ result.installedGems.length.to!string ~ " gems");
                return true;
            }
        }
        
        // Install specified gems
        if (!config.gems.empty)
        {
            auto gemNames = config.gems.map!(g => g.name).array;
            auto result = pm.install(gemNames);
            if (!result.success)
            {
                Logger.error("Failed to install gems: " ~ result.error);
                return false;
            }
        }
        
        return true;
    }
    
    /// Detect test framework from project
    private RubyTestFramework detectTestFramework(string projectRoot)
    {
        if (ProjectDetector.usesRSpec(projectRoot))
            return RubyTestFramework.RSpec;
        
        if (ProjectDetector.usesMinitest(projectRoot))
            return RubyTestFramework.Minitest;
        
        if (RubyTools.isRSpecAvailable())
            return RubyTestFramework.RSpec;
        
        return RubyTestFramework.Minitest;
    }
    
    /// Run tests with RSpec
    private LanguageBuildResult runRSpec(const Target target, RubyConfig config, string projectRoot)
    {
        LanguageBuildResult result;
        
        if (!RubyTools.isRSpecAvailable())
        {
            result.error = "RSpec not available (install: gem install rspec)";
            return result;
        }
        
        string[] cmd = ["rspec"];
        
        // Add RSpec-specific options
        if (!config.test.rspec.format.empty)
            cmd ~= ["--format", config.test.rspec.format];
        
        if (config.test.rspec.color)
            cmd ~= "--color";
        
        if (config.test.rspec.profile)
        {
            cmd ~= "--profile";
            cmd ~= config.test.rspec.profileCount.to!string;
        }
        
        if (config.test.rspec.failFast)
            cmd ~= "--fail-fast";
        
        if (!config.test.rspec.seed.empty)
            cmd ~= ["--seed", config.test.rspec.seed];
        
        if (config.test.rspec.bisect)
            cmd ~= "--bisect";
        
        // Tags
        foreach (tag; config.test.rspec.tags)
            cmd ~= ["--tag", tag];
        
        foreach (tag; config.test.rspec.excludeTags)
            cmd ~= ["--tag", "~" ~ tag];
        
        // Test paths
        if (!config.test.testPaths.empty)
            cmd ~= config.test.testPaths;
        else if (!target.sources.empty)
            cmd ~= target.sources;
        
        Logger.info("Running RSpec tests: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (res.status != 0)
        {
            result.error = "RSpec tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run tests with Minitest
    private LanguageBuildResult runMinitest(const Target target, RubyConfig config, string projectRoot)
    {
        LanguageBuildResult result;
        
        string[] cmd = ["ruby", "-Itest"];
        
        if (config.test.verbose)
            cmd ~= "-v";
        
        // Add test files
        if (!target.sources.empty)
            cmd ~= target.sources;
        else
        {
            // Run all tests in test/ directory
            cmd ~= ["-e", "Dir['test/**/*_test.rb'].each { |f| require_relative f }"];
        }
        
        Logger.info("Running Minitest tests");
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (res.status != 0)
        {
            result.error = "Minitest tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run tests with Test::Unit
    private LanguageBuildResult runTestUnit(const Target target, RubyConfig config, string projectRoot)
    {
        LanguageBuildResult result;
        
        string[] cmd = ["ruby", "-Itest"];
        
        if (!target.sources.empty)
            cmd ~= target.sources;
        else
            cmd ~= ["-e", "Dir['test/**/*_test.rb'].each { |f| require f }"];
        
        Logger.info("Running Test::Unit tests");
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (res.status != 0)
        {
            result.error = "Test::Unit tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run tests with Cucumber
    private LanguageBuildResult runCucumber(const Target target, RubyConfig config, string projectRoot)
    {
        LanguageBuildResult result;
        
        string[] cmd = ["cucumber"];
        
        if (config.test.verbose)
            cmd ~= "--verbose";
        
        if (!target.sources.empty)
            cmd ~= target.sources;
        
        Logger.info("Running Cucumber tests");
        
        auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (res.status != 0)
        {
            result.error = "Cucumber tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
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
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
}


