module languages.scripting.r.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.string;
import languages.base.base;
import languages.scripting.r.core.config;
import languages.scripting.r.tooling.info;
import languages.scripting.r.managers.packages;
import languages.scripting.r.managers.environments;
import languages.scripting.r.tooling.checkers;
import languages.scripting.r.analysis.dependencies;
import languages.scripting.r.builders;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// R language handler - comprehensive and modular
class RHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building R target: " ~ target.name);
        
        // Parse R configuration
        RConfig rConfig = parseRConfig(target);
        
        // Auto-detect mode and enhance config from project structure
        enhanceConfigFromProject(rConfig, target, config);
        
        // Validate R installation
        if (!validateRInstallation(rConfig))
        {
            result.error = "R/Rscript not available. Install from: https://www.r-project.org/";
            return result;
        }
        
        Logger.debug_("Using R: " ~ getRVersion(rConfig.rCommand));
        
        // Setup environment if configured
        if (rConfig.env.enabled)
        {
            auto envResult = setupEnvironment(rConfig, config.root);
            if (!envResult.success)
            {
                result.error = "Environment setup failed: " ~ envResult.error;
                return result;
            }
        }
        
        // Install dependencies if requested
        if (rConfig.installDeps)
        {
            if (!installProjectDependencies(rConfig, target, config))
            {
                result.error = "Failed to install dependencies";
                return result;
            }
        }
        
        // Run linter if configured
        if (rConfig.lint.linter != RLinter.None && !target.sources.empty)
        {
            auto lintResult = lintFiles(target.sources, rConfig.lint, rConfig.rExecutable, config.root);
            if (!lintResult.success)
            {
                if (rConfig.lint.failOnWarnings || lintResult.errorCount > 0)
                {
                    result.error = "Linting failed with " ~ lintResult.errorCount.to!string ~ " error(s)";
                    return result;
                }
            }
        }
        
        // Run formatter if configured
        if (rConfig.format.autoFormat && !target.sources.empty)
        {
            auto formatResult = formatFiles(target.sources, rConfig.format, rConfig.rExecutable, config.root);
            if (!formatResult.success)
            {
                Logger.warning("Formatting failed: " ~ formatResult.error);
            }
        }
        
        // Build based on target type and mode
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, rConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, rConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, rConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, rConfig);
                break;
        }
        
        // Snapshot environment if configured
        if (result.success && rConfig.env.autoSnapshot && rConfig.env.enabled)
        {
            snapshotEnvironment(rConfig.env.manager, config.root, rConfig.rExecutable, rConfig);
        }
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
    {
        RConfig rConfig = parseRConfig(target);
        enhanceConfigFromProject(rConfig, target, config);
        
        // Get builder for mode
        auto builder = getBuilder(rConfig.mode);
        if (builder)
        {
            return builder.getOutputs(target, config, rConfig);
        }
        
        // Fallback
        return [buildPath(config.options.outputDir, target.name.split(":")[$ - 1])];
    }
    
    /// Build executable target
    private LanguageBuildResult buildExecutable(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        auto builder = getBuilder(rConfig.mode);
        if (!builder)
        {
            LanguageBuildResult result;
            result.error = "No builder available for mode: " ~ rConfig.mode.to!string;
            return result;
        }
        
        if (!builder.validate(target, rConfig))
        {
            LanguageBuildResult result;
            result.error = "Build validation failed";
            return result;
        }
        
        return builder.build(target, config, rConfig, rConfig.rExecutable);
    }
    
    /// Build library target (R package)
    private LanguageBuildResult buildLibrary(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        // Libraries in R are packages
        rConfig.mode = RBuildMode.Package;
        return buildExecutable(target, config, rConfig);
    }
    
    /// Run tests
    private LanguageBuildResult runTests(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        if (target.sources.empty)
        {
            result.error = "No test files specified";
            return result;
        }
        
        // Auto-detect test framework
        if (rConfig.test.framework == RTestFramework.Auto)
        {
            rConfig.test.framework = detectBestTestFramework(rConfig.rExecutable);
        }
        
        string workDir = config.root;
        if (!target.sources.empty)
            workDir = dirName(target.sources[0]);
        
        final switch (rConfig.test.framework)
        {
            case RTestFramework.Auto:
            case RTestFramework.None:
                // Run R scripts directly
                return runTestScripts(target, config, rConfig, workDir);
                
            case RTestFramework.Testthat:
                return runTestthatTests(target, config, rConfig, workDir);
                
            case RTestFramework.Tinytest:
                return runTinytestTests(target, config, rConfig, workDir);
                
            case RTestFramework.RUnit:
                return runRUnitTests(target, config, rConfig, workDir);
        }
    }
    
    /// Build custom target
    private LanguageBuildResult buildCustom(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse R configuration from target
    private RConfig parseRConfig(Target target)
    {
        RConfig config;
        
        // Try language-specific keys
        if ("r" in target.langConfig)
        {
            try
            {
                auto json = parseJSON(target.langConfig["r"]);
                config = RConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse R config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration from project structure
    private void enhanceConfigFromProject(
        ref RConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Auto-detect package structure
        if (exists(buildPath(sourceDir, "DESCRIPTION")))
        {
            if (config.mode == RBuildMode.Script)
            {
                config.mode = RBuildMode.Package;
                Logger.debug_("Detected R package structure");
            }
        }
        
        // Auto-detect Shiny app
        if (exists(buildPath(sourceDir, "app.R")) || 
            (exists(buildPath(sourceDir, "server.R")) && exists(buildPath(sourceDir, "ui.R"))))
        {
            if (config.mode == RBuildMode.Script)
            {
                config.mode = RBuildMode.Shiny;
                Logger.debug_("Detected Shiny app");
            }
        }
        
        // Auto-detect RMarkdown
        if (target.sources[0].endsWith(".Rmd") || target.sources[0].endsWith(".rmd"))
        {
            if (config.mode == RBuildMode.Script)
            {
                config.mode = RBuildMode.RMarkdown;
                Logger.debug_("Detected RMarkdown document");
            }
        }
        
        // Auto-detect environment
        if (config.env.manager == REnvManager.Auto)
        {
            if (usesRenv(sourceDir))
            {
                config.env.manager = REnvManager.Renv;
                config.env.enabled = true;
                Logger.debug_("Detected renv environment");
            }
            else if (usesPackrat(sourceDir))
            {
                config.env.manager = REnvManager.Packrat;
                config.env.enabled = true;
                Logger.debug_("Detected packrat environment");
            }
        }
    }
    
    /// Validate R installation
    private bool validateRInstallation(RConfig config)
    {
        auto rInfo = detectR(config.rCommand);
        auto rscriptInfo = detectRscript(config.rExecutable);
        
        if (!rInfo.available || !rscriptInfo.available)
        {
            Logger.error("R not found. Please install R from https://www.r-project.org/");
            return false;
        }
        
        // Check version requirement
        if (!config.rVersion.empty && !rInfo.meetsVersion(config.rVersion))
        {
            Logger.error("R version " ~ rInfo.version_ ~ " does not meet requirement: " ~ config.rVersion);
            return false;
        }
        
        return true;
    }
    
    /// Setup environment
    private EnvResult setupEnvironment(ref RConfig config, string workDir)
    {
        // Check if environment exists
        auto status = getEnvironmentStatus(config.env.manager, workDir, config.rExecutable);
        
        if (status.hasLockfile && !status.exists)
        {
            // Restore from lockfile
            Logger.info("Restoring R environment from lockfile");
            return restoreEnvironment(config.env.manager, workDir, config.rExecutable, config);
        }
        else if (!status.exists && config.env.autoCreate)
        {
            // Initialize new environment
            Logger.info("Creating new R environment");
            return initializeEnvironment(config.env.manager, workDir, config.rExecutable, config);
        }
        
        return EnvResult(true, "", "");
    }
    
    /// Install project dependencies
    private bool installProjectDependencies(ref RConfig config, Target target, WorkspaceConfig workspace)
    {
        string projectDir = workspace.root;
        if (!target.sources.empty)
            projectDir = dirName(target.sources[0]);
        
        // Detect dependencies
        auto deps = detectDependencies(projectDir);
        
        if (deps.empty)
        {
            Logger.debug_("No dependencies detected");
            return true;
        }
        
        Logger.info("Installing " ~ deps.length.to!string ~ " dependencies");
        
        auto result = installPackages(
            deps,
            config.packageManager,
            config.rExecutable,
            projectDir,
            config
        );
        
        if (!result.success)
        {
            Logger.error("Dependency installation failed: " ~ result.error);
            return false;
        }
        
        return true;
    }
    
    /// Get builder for mode
    private RBuilder getBuilder(RBuildMode mode)
    {
        final switch (mode)
        {
            case RBuildMode.Script:
                return new RScriptBuilder();
            case RBuildMode.Package:
            case RBuildMode.Check:
            case RBuildMode.Vignette:
                return new RPackageBuilder();
            case RBuildMode.Shiny:
                return new RShinyBuilder();
            case RBuildMode.RMarkdown:
                return new RMarkdownBuilder();
        }
    }
    
    /// Run testthat tests
    private LanguageBuildResult runTestthatTests(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string workDir
    )
    {
        LanguageBuildResult result;
        
        string testCode = "testthat::test_dir('" ~ workDir ~ "', reporter='" ~ rConfig.test.reporter ~ "')";
        
        if (rConfig.test.coverage)
        {
            testCode = "covr::package_coverage(path='" ~ dirName(workDir) ~ "', type='tests')";
        }
        
        Logger.info("Running testthat tests");
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute([rConfig.rExecutable, "-e", testCode], env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Run tinytest tests
    private LanguageBuildResult runTinytestTests(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string workDir
    )
    {
        LanguageBuildResult result;
        
        string testCode = "tinytest::test_all('" ~ workDir ~ "')";
        
        Logger.info("Running tinytest tests");
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute([rConfig.rExecutable, "-e", testCode], env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Run RUnit tests
    private LanguageBuildResult runRUnitTests(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string workDir
    )
    {
        LanguageBuildResult result;
        
        string testCode = "RUnit::runTestSuite(RUnit::defineTestSuite('tests', dirs='" ~ workDir ~ "'))";
        
        Logger.info("Running RUnit tests");
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute([rConfig.rExecutable, "-e", testCode], env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Run test scripts directly
    private LanguageBuildResult runTestScripts(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string workDir
    )
    {
        LanguageBuildResult result;
        
        foreach (source; target.sources)
        {
            Logger.info("Running R test: " ~ source);
            
            auto env = prepareEnvironment(rConfig);
            auto res = execute([rConfig.rExecutable, source], env, Config.none, size_t.max, workDir);
            
            if (res.status != 0)
            {
                result.error = "Test failed in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Prepare environment variables
    private string[string] prepareEnvironment(ref RConfig config)
    {
        import std.process : environment;
        
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        foreach (key, value; config.rEnv)
            env[key] = value;
        
        if (!config.libPaths.empty)
        {
            env["R_LIBS_USER"] = config.libPaths.join(":");
        }
        
        if (!config.cranMirror.empty)
        {
            env["R_CRAN_MIRROR"] = config.cranMirror;
        }
        
        return env;
    }
    
    /// Analyze imports in R files
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.R);
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
                Logger.warning("Failed to analyze imports in " ~ source ~ ": " ~ e.msg);
            }
        }
        
        return allImports;
    }
}

