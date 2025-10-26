module languages.scripting.r;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.string;
import languages.base.base;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// R build modes
enum RBuildMode
{
    /// Script execution (default)
    Script,
    /// Package development/build
    Package,
    /// Shiny application
    Shiny,
    /// RMarkdown document
    RMarkdown,
    /// Package check/validation
    Check
}

/// R package repository
enum RRepository
{
    /// CRAN (Comprehensive R Archive Network)
    CRAN,
    /// Bioconductor
    Bioconductor,
    /// GitHub
    GitHub,
    /// Custom repository URL
    Custom
}

/// R package dependency configuration
struct RPackageDep
{
    string name;
    string version_; // version specification (e.g., ">= 1.0.0")
    RRepository repository = RRepository.CRAN;
    string customUrl; // For custom repositories
    
    /// Convert to install.packages() format
    string toInstallString() const
    {
        return name; // Basic form, version handled by install.packages args
    }
}

/// R testing configuration
struct RTestConfig
{
    /// Use testthat framework
    bool useTestthat = true;
    
    /// Coverage analysis
    bool coverage = false;
    
    /// Coverage output format (html, xml, json)
    string coverageFormat = "html";
    
    /// Reporter (progress, summary, minimal, etc.)
    string reporter = "progress";
    
    /// Stop on failure
    bool stopOnFailure = false;
    
    /// Generate test flags
    string[] toFlags() const
    {
        string[] flags;
        
        if (!reporter.empty && reporter != "progress")
        {
            flags ~= "--reporter=" ~ reporter;
        }
        if (stopOnFailure)
        {
            flags ~= "--stop-on-failure";
        }
        
        return flags;
    }
}

/// R package build configuration
struct RPackageConfig
{
    /// Package name
    string name;
    
    /// Package version
    string version_ = "0.1.0";
    
    /// Package title
    string title;
    
    /// Package description
    string description;
    
    /// Author(s)
    string[] authors;
    
    /// Maintainer
    string maintainer;
    
    /// License
    string license = "MIT";
    
    /// Package dependencies
    RPackageDep[] depends;
    RPackageDep[] imports;
    RPackageDep[] suggests;
    
    /// Minimum R version required
    string rVersion = "3.5.0";
    
    /// Build vignettes
    bool buildVignettes = false;
    
    /// Run R CMD check
    bool runCheck = false;
    
    /// Check arguments
    string[] checkArgs;
}

/// R-specific configuration
struct RConfig
{
    /// Build mode
    RBuildMode mode = RBuildMode.Script;
    
    /// Package configuration (for Package mode)
    RPackageConfig package_;
    
    /// Test configuration
    RTestConfig test;
    
    /// R executable path (defaults to "Rscript" or "R")
    string rExecutable = "Rscript";
    
    /// R command (for package operations)
    string rCommand = "R";
    
    /// Additional R library paths
    string[] libPaths;
    
    /// Environment variables for R
    string[string] rEnv;
    
    /// Install missing dependencies automatically
    bool installDeps = false;
    
    /// CRAN mirror URL
    string cranMirror = "https://cloud.r-project.org";
    
    /// Additional package repositories
    string[] additionalRepos;
    
    /// Working directory for R execution
    string workDir;
    
    /// Output directory
    string outDir;
    
    /// Additional R options/flags
    string[] rOptions;
    
    /// Shiny-specific options
    string shinyHost = "127.0.0.1";
    int shinyPort = 8080;
    
    /// RMarkdown output format (html_document, pdf_document, etc.)
    string rmdFormat = "html_document";
    
    /// Parse from JSON
    static RConfig fromJSON(JSONValue json)
    {
        RConfig config;
        
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower())
            {
                case "script": config.mode = RBuildMode.Script; break;
                case "package": config.mode = RBuildMode.Package; break;
                case "shiny": config.mode = RBuildMode.Shiny; break;
                case "rmarkdown": config.mode = RBuildMode.RMarkdown; break;
                case "check": config.mode = RBuildMode.Check; break;
                default: config.mode = RBuildMode.Script; break;
            }
        }
        
        // Package configuration
        if ("package" in json)
        {
            auto pkg = json["package"];
            if ("name" in pkg) config.package_.name = pkg["name"].str;
            if ("version" in pkg) config.package_.version_ = pkg["version"].str;
            if ("title" in pkg) config.package_.title = pkg["title"].str;
            if ("description" in pkg) config.package_.description = pkg["description"].str;
            if ("license" in pkg) config.package_.license = pkg["license"].str;
            if ("maintainer" in pkg) config.package_.maintainer = pkg["maintainer"].str;
            if ("rVersion" in pkg) config.package_.rVersion = pkg["rVersion"].str;
            if ("buildVignettes" in pkg) 
                config.package_.buildVignettes = pkg["buildVignettes"].type == JSONType.true_;
            if ("runCheck" in pkg) 
                config.package_.runCheck = pkg["runCheck"].type == JSONType.true_;
            
            if ("authors" in pkg)
                config.package_.authors = pkg["authors"].array.map!(e => e.str).array;
            if ("checkArgs" in pkg)
                config.package_.checkArgs = pkg["checkArgs"].array.map!(e => e.str).array;
        }
        
        // Test configuration
        if ("test" in json)
        {
            auto test = json["test"];
            if ("useTestthat" in test)
                config.test.useTestthat = test["useTestthat"].type == JSONType.true_;
            if ("coverage" in test)
                config.test.coverage = test["coverage"].type == JSONType.true_;
            if ("coverageFormat" in test)
                config.test.coverageFormat = test["coverageFormat"].str;
            if ("reporter" in test)
                config.test.reporter = test["reporter"].str;
            if ("stopOnFailure" in test)
                config.test.stopOnFailure = test["stopOnFailure"].type == JSONType.true_;
        }
        
        // Strings
        if ("rExecutable" in json) config.rExecutable = json["rExecutable"].str;
        if ("rCommand" in json) config.rCommand = json["rCommand"].str;
        if ("cranMirror" in json) config.cranMirror = json["cranMirror"].str;
        if ("workDir" in json) config.workDir = json["workDir"].str;
        if ("outDir" in json) config.outDir = json["outDir"].str;
        if ("shinyHost" in json) config.shinyHost = json["shinyHost"].str;
        if ("rmdFormat" in json) config.rmdFormat = json["rmdFormat"].str;
        
        // Integer
        if ("shinyPort" in json && json["shinyPort"].type == JSONType.integer)
            config.shinyPort = cast(int)json["shinyPort"].integer;
        
        // Booleans
        if ("installDeps" in json)
            config.installDeps = json["installDeps"].type == JSONType.true_;
        
        // Arrays
        if ("libPaths" in json)
            config.libPaths = json["libPaths"].array.map!(e => e.str).array;
        if ("additionalRepos" in json)
            config.additionalRepos = json["additionalRepos"].array.map!(e => e.str).array;
        if ("rOptions" in json)
            config.rOptions = json["rOptions"].array.map!(e => e.str).array;
        
        // Environment variables
        if ("rEnv" in json)
        {
            foreach (string key, value; json["rEnv"].object)
            {
                config.rEnv[key] = value.str;
            }
        }
        
        return config;
    }
}

/// R build result
struct RBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    string[] warnings;
}

/// R build handler
class RHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building R target: " ~ target.name);
        
        // Parse R configuration
        RConfig rConfig = parseRConfig(target);
        
        // Auto-detect mode from project structure
        enhanceConfigFromProject(rConfig, target, config);
        
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
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
    {
        RConfig rConfig = parseRConfig(target);
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            final switch (rConfig.mode)
            {
                case RBuildMode.Script:
                    outputs ~= buildPath(config.options.outputDir, name);
                    break;
            case RBuildMode.Package:
                // Package tarball
                string pkgName = rConfig.package_.name.empty ? name : rConfig.package_.name;
                string pkgVersion = rConfig.package_.version_;
                outputs ~= buildPath(config.options.outputDir, pkgName ~ "_" ~ pkgVersion ~ ".tar.gz");
                break;
                case RBuildMode.Shiny:
                    // Shiny apps don't produce static output
                    outputs ~= buildPath(config.options.outputDir, name ~ ".marker");
                    break;
                case RBuildMode.RMarkdown:
                    // RMarkdown output depends on format
                    string ext = rConfig.rmdFormat.startsWith("html") ? ".html" : 
                                rConfig.rmdFormat.startsWith("pdf") ? ".pdf" : ".html";
                    outputs ~= buildPath(config.options.outputDir, name ~ ext);
                    break;
                case RBuildMode.Check:
                    // Check results
                    outputs ~= buildPath(config.options.outputDir, name ~ ".Rcheck");
                    break;
            }
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        if (!isRAvailable(rConfig))
        {
            result.error = "R/Rscript not available. Install from: https://www.r-project.org/";
            return result;
        }
        
        Logger.debug_("Using R: " ~ getRVersion(rConfig));
        
        // Install dependencies if requested
        if (rConfig.installDeps)
        {
            auto depsResult = installDependencies(target, config, rConfig);
            if (!depsResult.success)
            {
                result.error = "Failed to install dependencies: " ~ depsResult.error;
                return result;
            }
        }
        
        // Build based on mode
        final switch (rConfig.mode)
        {
            case RBuildMode.Script:
                return buildScript(target, config, rConfig);
            case RBuildMode.Package:
                return buildPackage(target, config, rConfig);
            case RBuildMode.Shiny:
                return buildShinyApp(target, config, rConfig);
            case RBuildMode.RMarkdown:
                return buildRMarkdown(target, config, rConfig);
            case RBuildMode.Check:
                return checkPackage(target, config, rConfig);
        }
    }
    
    private LanguageBuildResult buildLibrary(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        // Libraries in R are packages
        rConfig.mode = RBuildMode.Package;
        return buildPackage(target, config, rConfig);
    }
    
    private LanguageBuildResult runTests(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        if (!isRAvailable(rConfig))
        {
            result.error = "R not available for running tests";
            return result;
        }
        
        // Determine working directory
        string workDir = config.root;
        if (!target.sources.empty)
            workDir = dirName(target.sources[0]);
        
        if (rConfig.test.useTestthat)
        {
            // Use testthat framework
            return runTestthatTests(target, config, rConfig, workDir);
        }
        else
        {
            // Run R test scripts directly
            return runRTestScripts(target, config, rConfig, workDir);
        }
    }
    
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
    
    /// Build R script
    private LanguageBuildResult buildScript(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        if (target.sources.empty)
        {
            result.error = "No source files specified";
            return result;
        }
        
        // Validate R syntax
        foreach (source; target.sources)
        {
            if (!validateRSyntax(source, rConfig))
            {
                result.error = "Syntax error in " ~ source;
                return result;
            }
        }
        
        // Create executable wrapper
        auto outputs = getOutputs(target, config);
        if (!outputs.empty)
        {
            auto outputPath = outputs[0];
            auto mainFile = target.sources[0];
            
            createRScriptWrapper(mainFile, outputPath, rConfig);
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Build R package
    private LanguageBuildResult buildPackage(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        // Determine package directory
        string pkgDir = config.root;
        if (!target.sources.empty)
            pkgDir = dirName(target.sources[0]);
        
        // Check for DESCRIPTION file
        string descPath = buildPath(pkgDir, "DESCRIPTION");
        if (!exists(descPath))
        {
            // Generate DESCRIPTION if package config provided
            if (!rConfig.package_.name.empty)
            {
                generateDESCRIPTION(pkgDir, rConfig.package_);
            }
            else
            {
                result.error = "No DESCRIPTION file found and no package configuration provided";
                return result;
            }
        }
        
        // Build package with R CMD build
        string[] cmd = [rConfig.rCommand, "CMD", "build"];
        
        if (rConfig.package_.buildVignettes)
            cmd ~= "--build-vignettes";
        else
            cmd ~= "--no-build-vignettes";
        
        cmd ~= pkgDir;
        
        Logger.info("Building R package: " ~ cmd.join(" "));
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute(cmd, env, Config.none, size_t.max, config.root);
        
        if (res.status != 0)
        {
            result.error = "R package build failed: " ~ res.output;
            return result;
        }
        
        // Run R CMD check if requested
        if (rConfig.package_.runCheck)
        {
            auto checkResult = checkPackage(target, config, rConfig);
            if (!checkResult.success)
            {
                result.error = "Package check failed: " ~ checkResult.error;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Build Shiny application
    private LanguageBuildResult buildShinyApp(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        if (target.sources.empty)
        {
            result.error = "No source files specified for Shiny app";
            return result;
        }
        
        string appDir = dirName(target.sources[0]);
        
        // Check for app.R or server.R/ui.R
        bool hasAppR = exists(buildPath(appDir, "app.R"));
        bool hasServerUI = exists(buildPath(appDir, "server.R")) && 
                          exists(buildPath(appDir, "ui.R"));
        
        if (!hasAppR && !hasServerUI)
        {
            result.error = "Shiny app must have either app.R or server.R/ui.R";
            return result;
        }
        
        // Validate Shiny app syntax
        foreach (source; target.sources)
        {
            if (!validateRSyntax(source, rConfig))
            {
                result.error = "Syntax error in " ~ source;
                return result;
            }
        }
        
        Logger.info("Shiny app validated successfully at: " ~ appDir);
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Build RMarkdown document
    private LanguageBuildResult buildRMarkdown(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        if (target.sources.empty)
        {
            result.error = "No RMarkdown files specified";
            return result;
        }
        
        string rmdFile = target.sources[0];
        
        // Build R command to render RMarkdown
        string rCode = "rmarkdown::render('" ~ rmdFile ~ "', output_format='" ~ 
                       rConfig.rmdFormat ~ "')";
        
        string[] cmd = [rConfig.rExecutable, "-e", rCode];
        
        Logger.info("Rendering RMarkdown: " ~ rmdFile);
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.error = "RMarkdown rendering failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Check R package with R CMD check
    private LanguageBuildResult checkPackage(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        LanguageBuildResult result;
        
        string pkgDir = config.root;
        if (!target.sources.empty)
            pkgDir = dirName(target.sources[0]);
        
        string[] cmd = [rConfig.rCommand, "CMD", "check"];
        cmd ~= rConfig.package_.checkArgs;
        cmd ~= pkgDir;
        
        Logger.info("Checking R package: " ~ cmd.join(" "));
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute(cmd, env, Config.none, size_t.max, config.root);
        
        if (res.status != 0)
        {
            result.error = "R CMD check failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
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
        
        // R code to run testthat
        string testCode = "testthat::test_local(reporter='" ~ rConfig.test.reporter ~ "')";
        
        if (rConfig.test.coverage)
        {
            testCode = "covr::package_coverage(type='tests')";
        }
        
        string[] cmd = [rConfig.rExecutable, "-e", testCode];
        
        Logger.info("Running testthat tests");
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Run R test scripts directly
    private LanguageBuildResult runRTestScripts(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig,
        string workDir
    )
    {
        LanguageBuildResult result;
        
        foreach (source; target.sources)
        {
            string[] cmd = [rConfig.rExecutable, source];
            
            Logger.info("Running R test: " ~ source);
            
            auto env = prepareEnvironment(rConfig);
            auto res = execute(cmd, env, Config.none, size_t.max, workDir);
            
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
    
    /// Install R dependencies
    private RBuildResult installDependencies(
        Target target,
        WorkspaceConfig config,
        RConfig rConfig
    )
    {
        RBuildResult result;
        
        // Build R code to install dependencies
        string installCode = "repos <- c('" ~ rConfig.cranMirror ~ "'";
        foreach (repo; rConfig.additionalRepos)
        {
            installCode ~= ", '" ~ repo ~ "'";
        }
        installCode ~= "); ";
        
        // Check for DESCRIPTION file to read dependencies
        string descPath = findDESCRIPTION(target, config);
        if (!descPath.empty && exists(descPath))
        {
            installCode ~= "devtools::install_deps('" ~ dirName(descPath) ~ "', repos=repos)";
        }
        else
        {
            Logger.warning("No DESCRIPTION file found, skipping dependency installation");
            result.success = true;
            return result;
        }
        
        string[] cmd = [rConfig.rExecutable, "-e", installCode];
        
        Logger.info("Installing R dependencies");
        
        auto env = prepareEnvironment(rConfig);
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.error = "Dependency installation failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        return result;
    }
    
    /// Parse R configuration from target
    private RConfig parseRConfig(Target target)
    {
        RConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("r" in target.langConfig)
            configKey = "r";
        else if ("rConfig" in target.langConfig)
            configKey = "rConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = RConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse R config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration based on project structure
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
                Logger.debug_("Detected R package structure at: " ~ sourceDir);
            }
        }
        
        // Auto-detect Shiny app
        if (exists(buildPath(sourceDir, "app.R")) || 
            (exists(buildPath(sourceDir, "server.R")) && exists(buildPath(sourceDir, "ui.R"))))
        {
            if (config.mode == RBuildMode.Script)
            {
                config.mode = RBuildMode.Shiny;
                Logger.debug_("Detected Shiny app at: " ~ sourceDir);
            }
        }
        
        // Auto-detect RMarkdown
        if (target.sources[0].endsWith(".Rmd") || target.sources[0].endsWith(".rmd"))
        {
            if (config.mode == RBuildMode.Script)
            {
                config.mode = RBuildMode.RMarkdown;
                Logger.debug_("Detected RMarkdown file: " ~ target.sources[0]);
            }
        }
    }
    
    /// Check if R is available
    private bool isRAvailable(RConfig config)
    {
        version(Windows)
        {
            auto res = execute(["where", config.rExecutable]);
        }
        else
        {
            auto res = execute(["which", config.rExecutable]);
        }
        
        return res.status == 0;
    }
    
    /// Get R version
    private string getRVersion(RConfig config)
    {
        auto res = execute([config.rExecutable, "--version"]);
        if (res.status == 0 && !res.output.empty)
        {
            // Extract version from output
            import std.regex;
            auto versionMatch = matchFirst(res.output, regex(r"R version (\S+)"));
            if (versionMatch)
                return versionMatch[1];
        }
        return "unknown";
    }
    
    /// Validate R syntax
    private bool validateRSyntax(string filePath, RConfig config)
    {
        if (!exists(filePath))
            return false;
        
        // Use R's parse() function to check syntax
        string rCode = "tryCatch(parse('" ~ filePath ~ "'), error=function(e) quit(status=1))";
        auto cmd = [config.rExecutable, "-e", rCode];
        
        auto res = execute(cmd);
        return res.status == 0;
    }
    
    /// Create R script wrapper
    private void createRScriptWrapper(string scriptPath, string outputPath, RConfig config)
    {
        string wrapper = "#!/usr/bin/env " ~ config.rExecutable ~ "\n";
        wrapper ~= "source('" ~ scriptPath ~ "')\n";
        
        std.file.write(outputPath, wrapper);
        
        version(Posix)
        {
            import core.sys.posix.sys.stat;
            // Make executable
            auto attrs = getAttributes(outputPath);
            setAttributes(outputPath, attrs | S_IXUSR | S_IXGRP | S_IXOTH);
        }
    }
    
    /// Generate DESCRIPTION file
    private void generateDESCRIPTION(string pkgDir, RPackageConfig pkg)
    {
        string desc = "Package: " ~ pkg.name ~ "\n";
        desc ~= "Type: Package\n";
        desc ~= "Title: " ~ (pkg.title.empty ? pkg.name : pkg.title) ~ "\n";
        desc ~= "Version: " ~ pkg.version_ ~ "\n";
        
        if (!pkg.authors.empty)
            desc ~= "Authors: " ~ pkg.authors.join(", ") ~ "\n";
        
        if (!pkg.maintainer.empty)
            desc ~= "Maintainer: " ~ pkg.maintainer ~ "\n";
        
        if (!pkg.description.empty)
            desc ~= "Description: " ~ pkg.description ~ "\n";
        
        desc ~= "License: " ~ pkg.license ~ "\n";
        desc ~= "Encoding: UTF-8\n";
        desc ~= "LazyData: true\n";
        desc ~= "Depends: R (>= " ~ pkg.rVersion ~ ")\n";
        
        if (!pkg.imports.empty)
        {
            desc ~= "Imports:\n";
            foreach (i, imp; pkg.imports)
            {
                desc ~= "    " ~ imp.name;
                if (!imp.version_.empty)
                    desc ~= " (" ~ imp.version_ ~ ")";
                if (i < pkg.imports.length - 1)
                    desc ~= ",";
                desc ~= "\n";
            }
        }
        
        if (!pkg.suggests.empty)
        {
            desc ~= "Suggests:\n";
            foreach (i, sug; pkg.suggests)
            {
                desc ~= "    " ~ sug.name;
                if (!sug.version_.empty)
                    desc ~= " (" ~ sug.version_ ~ ")";
                if (i < pkg.suggests.length - 1)
                    desc ~= ",";
                desc ~= "\n";
            }
        }
        
        string descPath = buildPath(pkgDir, "DESCRIPTION");
        std.file.write(descPath, desc);
        Logger.info("Generated DESCRIPTION file at: " ~ descPath);
    }
    
    /// Find DESCRIPTION file
    private string findDESCRIPTION(Target target, WorkspaceConfig config)
    {
        if (target.sources.empty)
            return "";
        
        string dir = dirName(target.sources[0]);
        
        // Look up the directory tree
        while (dir != "/" && dir.length > 1)
        {
            string descPath = buildPath(dir, "DESCRIPTION");
            if (exists(descPath))
                return descPath;
            
            dir = dirName(dir);
        }
        
        return "";
    }
    
    /// Prepare environment variables for R execution
    private string[string] prepareEnvironment(RConfig config)
    {
        string[string] env;
        
        // Copy system environment
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Add custom R environment variables
        foreach (key, value; config.rEnv)
            env[key] = value;
        
        // Add library paths
        if (!config.libPaths.empty)
        {
            env["R_LIBS_USER"] = config.libPaths.join(":");
        }
        
        return env;
    }
    
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
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
}

