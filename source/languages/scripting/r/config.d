module languages.scripting.r.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// R build modes
enum RBuildMode
{
    /// Script - single file or simple script (default)
    Script,
    /// Package - full R package with DESCRIPTION
    Package,
    /// Shiny - Shiny web application
    Shiny,
    /// RMarkdown - RMarkdown document rendering
    RMarkdown,
    /// Check - R CMD check validation
    Check,
    /// Vignette - Build package vignettes
    Vignette
}

/// Package manager selection
enum RPackageManager
{
    /// Auto-detect best available
    Auto,
    /// install.packages (standard R)
    InstallPackages,
    /// pak (modern, fast, caching)
    Pak,
    /// renv (reproducible environments)
    Renv,
    /// packrat (legacy but still used)
    Packrat,
    /// remotes (GitHub/other sources)
    Remotes,
    /// None - skip package management
    None
}

/// R package repository type
enum RRepository
{
    /// CRAN (Comprehensive R Archive Network)
    CRAN,
    /// Bioconductor
    Bioconductor,
    /// GitHub
    GitHub,
    /// GitLab
    GitLab,
    /// Custom repository URL
    Custom
}

/// Linter selection
enum RLinter
{
    /// Auto-detect best available
    Auto,
    /// lintr (standard R linter)
    Lintr,
    /// goodpractice (comprehensive checks)
    Goodpractice,
    /// None - skip linting
    None
}

/// Formatter selection
enum RFormatter
{
    /// Auto-detect best available
    Auto,
    /// styler (standard R formatter)
    Styler,
    /// formatR (older formatter)
    FormatR,
    /// None - skip formatting
    None
}

/// Testing framework selection
enum RTestFramework
{
    /// Auto-detect from project structure
    Auto,
    /// testthat (most popular)
    Testthat,
    /// tinytest (lightweight)
    Tinytest,
    /// RUnit (older framework)
    RUnit,
    /// None - direct script execution
    None
}

/// Documentation generator selection
enum RDocGenerator
{
    /// Auto-detect best available
    Auto,
    /// roxygen2 (function documentation)
    Roxygen2,
    /// pkgdown (package website)
    Pkgdown,
    /// Both roxygen2 and pkgdown
    Both,
    /// None - skip documentation
    None
}

/// Environment manager selection
enum REnvManager
{
    /// Auto-detect from project structure
    Auto,
    /// renv (modern, recommended)
    Renv,
    /// packrat (legacy)
    Packrat,
    /// None - use system libraries
    None
}

/// RMarkdown output format
enum RMarkdownFormat
{
    /// HTML document
    HTML,
    /// PDF document (requires LaTeX)
    PDF,
    /// Word document
    Word,
    /// Markdown
    Markdown,
    /// Reveal.js presentation
    RevealJS,
    /// Beamer presentation
    Beamer,
    /// Custom format
    Custom
}

/// R package dependency specification
struct RPackageDep
{
    string name;
    string version_; // version specification (e.g., ">= 1.0.0")
    RRepository repository = RRepository.CRAN;
    string customUrl; // For custom repositories
    string gitRef; // For GitHub/GitLab (branch, tag, commit)
    
    /// Convert to install command string
    string toInstallString() const
    {
        return name;
    }
    
    /// Get repository-specific install command
    string getInstallCommand(RPackageManager manager) const
    {
        final switch (repository)
        {
            case RRepository.CRAN:
                return name;
            case RRepository.Bioconductor:
                return name; // BiocManager handles this
            case RRepository.GitHub:
                if (customUrl.empty)
                    return name; // Assume "user/repo" format
                return customUrl;
            case RRepository.GitLab:
                return customUrl;
            case RRepository.Custom:
                return customUrl;
        }
    }
}

/// R testing configuration
struct RTestConfig
{
    /// Testing framework
    RTestFramework framework = RTestFramework.Auto;
    
    /// Coverage analysis
    bool coverage = false;
    
    /// Coverage threshold (0-100)
    double coverageThreshold = 0.0;
    
    /// Coverage output format (html, xml, json, lcov)
    string coverageFormat = "html";
    
    /// Reporter (progress, summary, minimal, junit, tap)
    string reporter = "progress";
    
    /// Stop on failure
    bool stopOnFailure = false;
    
    /// Run tests in parallel
    bool parallel = false;
    
    /// Parallel workers count (0 = auto)
    int parallelWorkers = 0;
    
    /// Filter tests by pattern
    string filter;
    
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
        if (!filter.empty)
        {
            flags ~= "--filter=" ~ filter;
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
    
    /// Author(s) - DESCRIPTION format
    string[] authors;
    
    /// Maintainer
    string maintainer;
    
    /// License
    string license = "MIT";
    
    /// Package dependencies
    RPackageDep[] depends;
    RPackageDep[] imports;
    RPackageDep[] suggests;
    RPackageDep[] linkingTo;
    
    /// Minimum R version required
    string rVersion = "3.5.0";
    
    /// Build vignettes
    bool buildVignettes = false;
    
    /// Run R CMD check
    bool runCheck = false;
    
    /// Check arguments
    string[] checkArgs;
    
    /// Build binary package
    bool buildBinary = false;
    
    /// Use devtools workflow
    bool useDevtools = false;
    
    /// LazyData
    bool lazyData = true;
    
    /// Roxygen2 markdown support
    bool roxygen2Markdown = true;
}

/// Linter configuration
struct RLintConfig
{
    /// Linter to use
    RLinter linter = RLinter.Auto;
    
    /// Auto-fix issues where possible
    bool autoFix = false;
    
    /// Linters to enable (lintr-specific)
    string[] enabledLinters;
    
    /// Linters to disable (lintr-specific)
    string[] disabledLinters;
    
    /// Path to lintr config file
    string configFile;
    
    /// Fail on warnings
    bool failOnWarnings = false;
    
    /// Exclude patterns
    string[] excludePatterns;
}

/// Formatter configuration
struct RFormatConfig
{
    /// Formatter to use
    RFormatter formatter = RFormatter.Auto;
    
    /// Indentation width
    int indentWidth = 2;
    
    /// Use spaces (not tabs)
    bool useSpaces = true;
    
    /// Maximum line length
    int maxLineLength = 80;
    
    /// styler scope (none, spaces, indentation, line_breaks, tokens)
    string stylerScope = "tokens";
    
    /// Auto-format on build
    bool autoFormat = false;
    
    /// Path to formatter config file
    string configFile;
}

/// Documentation configuration
struct RDocConfig
{
    /// Documentation generator
    RDocGenerator generator = RDocGenerator.Auto;
    
    /// Build function documentation (roxygen2)
    bool buildDocs = false;
    
    /// Build package website (pkgdown)
    bool buildSite = false;
    
    /// Site output directory
    string siteDir = "docs";
    
    /// pkgdown config file
    string pkgdownConfig = "_pkgdown.yml";
    
    /// Include vignettes in site
    bool includeVignettes = true;
    
    /// Generate README.md from README.Rmd
    bool generateReadme = false;
}

/// Environment configuration
struct REnvConfig
{
    /// Environment manager
    REnvManager manager = REnvManager.Auto;
    
    /// Enable environment isolation
    bool enabled = false;
    
    /// Auto-create environment if missing
    bool autoCreate = false;
    
    /// Environment directory
    string envDir;
    
    /// Snapshot/restore on build
    bool autoSnapshot = false;
    
    /// Use cache for faster installs
    bool useCache = true;
    
    /// Clean environment before build
    bool clean = false;
}

/// Profiling configuration
struct RProfileConfig
{
    /// Enable profiling
    bool enabled = false;
    
    /// Profiling tool (profvis, Rprof)
    string tool = "profvis";
    
    /// Output file
    string outputFile = "profile.html";
    
    /// Interval (seconds)
    double interval = 0.01;
    
    /// Memory profiling
    bool memoryProfiling = true;
}

/// Shiny configuration
struct RShinyConfig
{
    /// Host to bind to
    string host = "127.0.0.1";
    
    /// Port to bind to
    int port = 8080;
    
    /// Launch browser on start
    bool launchBrowser = false;
    
    /// Display mode (normal, showcase)
    string displayMode = "normal";
    
    /// Auto-reload on file changes
    bool autoReload = false;
}

/// RMarkdown configuration
struct RMarkdownConfig
{
    /// Output format
    RMarkdownFormat format = RMarkdownFormat.HTML;
    
    /// Custom format string (if Custom selected)
    string customFormat;
    
    /// Self-contained output
    bool selfContained = true;
    
    /// Keep intermediate files
    bool keepIntermediates = false;
    
    /// Render parameters
    string[string] params;
    
    /// Output file name
    string outputFile;
}

/// Comprehensive R configuration
struct RConfig
{
    /// Build mode
    RBuildMode mode = RBuildMode.Script;
    
    /// R executable path (Rscript for scripts)
    string rExecutable = "Rscript";
    
    /// R command (R CMD for packages)
    string rCommand = "R";
    
    /// Python version requirement (e.g., "4.0.0", ">= 3.5")
    string rVersion;
    
    /// Package manager
    RPackageManager packageManager = RPackageManager.Auto;
    
    /// Install missing dependencies automatically
    bool installDeps = false;
    
    /// CRAN mirror URL
    string cranMirror = "https://cloud.r-project.org";
    
    /// Additional package repositories
    string[] additionalRepos;
    
    /// Additional R library paths
    string[] libPaths;
    
    /// Working directory for R execution
    string workDir;
    
    /// Output directory
    string outDir;
    
    /// Additional R options/flags
    string[] rOptions;
    
    /// Environment variables for R
    string[string] rEnv;
    
    /// Package configuration
    RPackageConfig package_;
    
    /// Test configuration
    RTestConfig test;
    
    /// Linter configuration
    RLintConfig lint;
    
    /// Formatter configuration
    RFormatConfig format;
    
    /// Documentation configuration
    RDocConfig doc;
    
    /// Environment configuration
    REnvConfig env;
    
    /// Profiling configuration
    RProfileConfig profile;
    
    /// Shiny configuration
    RShinyConfig shiny;
    
    /// RMarkdown configuration
    RMarkdownConfig rmarkdown;
    
    /// Validate syntax before build
    bool validateSyntax = true;
    
    /// Compile bytecode for performance
    bool compileBytecode = false;
    
    /// Optimization level (0-3)
    int optimize = 0;
    
    /// Parse from JSON
    static RConfig fromJSON(JSONValue json)
    {
        RConfig config;
        
        // Mode
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
                case "vignette": config.mode = RBuildMode.Vignette; break;
                default: config.mode = RBuildMode.Script; break;
            }
        }
        
        // Package manager
        if ("packageManager" in json)
        {
            string pmStr = json["packageManager"].str;
            switch (pmStr.toLower())
            {
                case "auto": config.packageManager = RPackageManager.Auto; break;
                case "install.packages":
                case "installpackages": config.packageManager = RPackageManager.InstallPackages; break;
                case "pak": config.packageManager = RPackageManager.Pak; break;
                case "renv": config.packageManager = RPackageManager.Renv; break;
                case "packrat": config.packageManager = RPackageManager.Packrat; break;
                case "remotes": config.packageManager = RPackageManager.Remotes; break;
                case "none": config.packageManager = RPackageManager.None; break;
                default: config.packageManager = RPackageManager.Auto; break;
            }
        }
        
        // Basic strings
        if ("rExecutable" in json) config.rExecutable = json["rExecutable"].str;
        if ("rCommand" in json) config.rCommand = json["rCommand"].str;
        if ("rVersion" in json) config.rVersion = json["rVersion"].str;
        if ("cranMirror" in json) config.cranMirror = json["cranMirror"].str;
        if ("workDir" in json) config.workDir = json["workDir"].str;
        if ("outDir" in json) config.outDir = json["outDir"].str;
        
        // Booleans
        if ("installDeps" in json)
            config.installDeps = json["installDeps"].type == JSONType.true_;
        if ("validateSyntax" in json)
            config.validateSyntax = json["validateSyntax"].type == JSONType.true_;
        if ("compileBytecode" in json)
            config.compileBytecode = json["compileBytecode"].type == JSONType.true_;
        
        // Integer
        if ("optimize" in json && json["optimize"].type == JSONType.integer)
            config.optimize = cast(int)json["optimize"].integer;
        
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
        
        // Package configuration
        if ("package" in json)
        {
            config.package_ = parsePackageConfig(json["package"]);
        }
        
        // Test configuration
        if ("test" in json)
        {
            config.test = parseTestConfig(json["test"]);
        }
        
        // Lint configuration
        if ("lint" in json)
        {
            config.lint = parseLintConfig(json["lint"]);
        }
        
        // Format configuration
        if ("format" in json)
        {
            config.format = parseFormatConfig(json["format"]);
        }
        
        // Doc configuration
        if ("doc" in json)
        {
            config.doc = parseDocConfig(json["doc"]);
        }
        
        // Environment configuration
        if ("env" in json)
        {
            config.env = parseEnvConfig(json["env"]);
        }
        
        // Profile configuration
        if ("profile" in json)
        {
            config.profile = parseProfileConfig(json["profile"]);
        }
        
        // Shiny configuration
        if ("shiny" in json)
        {
            config.shiny = parseShinyConfig(json["shiny"]);
        }
        
        // RMarkdown configuration
        if ("rmarkdown" in json)
        {
            config.rmarkdown = parseRMarkdownConfig(json["rmarkdown"]);
        }
        
        return config;
    }
}

/// Parse package configuration from JSON
private RPackageConfig parsePackageConfig(JSONValue json)
{
    RPackageConfig config;
    
    if ("name" in json) config.name = json["name"].str;
    if ("version" in json) config.version_ = json["version"].str;
    if ("title" in json) config.title = json["title"].str;
    if ("description" in json) config.description = json["description"].str;
    if ("license" in json) config.license = json["license"].str;
    if ("maintainer" in json) config.maintainer = json["maintainer"].str;
    if ("rVersion" in json) config.rVersion = json["rVersion"].str;
    
    if ("buildVignettes" in json)
        config.buildVignettes = json["buildVignettes"].type == JSONType.true_;
    if ("runCheck" in json)
        config.runCheck = json["runCheck"].type == JSONType.true_;
    if ("buildBinary" in json)
        config.buildBinary = json["buildBinary"].type == JSONType.true_;
    if ("useDevtools" in json)
        config.useDevtools = json["useDevtools"].type == JSONType.true_;
    if ("lazyData" in json)
        config.lazyData = json["lazyData"].type == JSONType.true_;
    if ("roxygen2Markdown" in json)
        config.roxygen2Markdown = json["roxygen2Markdown"].type == JSONType.true_;
    
    if ("authors" in json)
        config.authors = json["authors"].array.map!(e => e.str).array;
    if ("checkArgs" in json)
        config.checkArgs = json["checkArgs"].array.map!(e => e.str).array;
    
    return config;
}

/// Parse test configuration from JSON
private RTestConfig parseTestConfig(JSONValue json)
{
    RTestConfig config;
    
    if ("framework" in json)
    {
        string fwStr = json["framework"].str;
        switch (fwStr.toLower())
        {
            case "auto": config.framework = RTestFramework.Auto; break;
            case "testthat": config.framework = RTestFramework.Testthat; break;
            case "tinytest": config.framework = RTestFramework.Tinytest; break;
            case "runit": config.framework = RTestFramework.RUnit; break;
            case "none": config.framework = RTestFramework.None; break;
            default: config.framework = RTestFramework.Auto; break;
        }
    }
    
    if ("coverage" in json)
        config.coverage = json["coverage"].type == JSONType.true_;
    if ("coverageThreshold" in json && json["coverageThreshold"].type == JSONType.float_)
        config.coverageThreshold = json["coverageThreshold"].floating;
    if ("coverageFormat" in json)
        config.coverageFormat = json["coverageFormat"].str;
    if ("reporter" in json)
        config.reporter = json["reporter"].str;
    if ("stopOnFailure" in json)
        config.stopOnFailure = json["stopOnFailure"].type == JSONType.true_;
    if ("parallel" in json)
        config.parallel = json["parallel"].type == JSONType.true_;
    if ("parallelWorkers" in json && json["parallelWorkers"].type == JSONType.integer)
        config.parallelWorkers = cast(int)json["parallelWorkers"].integer;
    if ("filter" in json)
        config.filter = json["filter"].str;
    
    return config;
}

/// Parse lint configuration from JSON
private RLintConfig parseLintConfig(JSONValue json)
{
    RLintConfig config;
    
    if ("linter" in json)
    {
        string lintStr = json["linter"].str;
        switch (lintStr.toLower())
        {
            case "auto": config.linter = RLinter.Auto; break;
            case "lintr": config.linter = RLinter.Lintr; break;
            case "goodpractice": config.linter = RLinter.Goodpractice; break;
            case "none": config.linter = RLinter.None; break;
            default: config.linter = RLinter.Auto; break;
        }
    }
    
    if ("autoFix" in json)
        config.autoFix = json["autoFix"].type == JSONType.true_;
    if ("configFile" in json)
        config.configFile = json["configFile"].str;
    if ("failOnWarnings" in json)
        config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    
    if ("enabledLinters" in json)
        config.enabledLinters = json["enabledLinters"].array.map!(e => e.str).array;
    if ("disabledLinters" in json)
        config.disabledLinters = json["disabledLinters"].array.map!(e => e.str).array;
    if ("excludePatterns" in json)
        config.excludePatterns = json["excludePatterns"].array.map!(e => e.str).array;
    
    return config;
}

/// Parse format configuration from JSON
private RFormatConfig parseFormatConfig(JSONValue json)
{
    RFormatConfig config;
    
    if ("formatter" in json)
    {
        string fmtStr = json["formatter"].str;
        switch (fmtStr.toLower())
        {
            case "auto": config.formatter = RFormatter.Auto; break;
            case "styler": config.formatter = RFormatter.Styler; break;
            case "formatr": config.formatter = RFormatter.FormatR; break;
            case "none": config.formatter = RFormatter.None; break;
            default: config.formatter = RFormatter.Auto; break;
        }
    }
    
    if ("indentWidth" in json && json["indentWidth"].type == JSONType.integer)
        config.indentWidth = cast(int)json["indentWidth"].integer;
    if ("useSpaces" in json)
        config.useSpaces = json["useSpaces"].type == JSONType.true_;
    if ("maxLineLength" in json && json["maxLineLength"].type == JSONType.integer)
        config.maxLineLength = cast(int)json["maxLineLength"].integer;
    if ("stylerScope" in json)
        config.stylerScope = json["stylerScope"].str;
    if ("autoFormat" in json)
        config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("configFile" in json)
        config.configFile = json["configFile"].str;
    
    return config;
}

/// Parse doc configuration from JSON
private RDocConfig parseDocConfig(JSONValue json)
{
    RDocConfig config;
    
    if ("generator" in json)
    {
        string genStr = json["generator"].str;
        switch (genStr.toLower())
        {
            case "auto": config.generator = RDocGenerator.Auto; break;
            case "roxygen2": config.generator = RDocGenerator.Roxygen2; break;
            case "pkgdown": config.generator = RDocGenerator.Pkgdown; break;
            case "both": config.generator = RDocGenerator.Both; break;
            case "none": config.generator = RDocGenerator.None; break;
            default: config.generator = RDocGenerator.Auto; break;
        }
    }
    
    if ("buildDocs" in json)
        config.buildDocs = json["buildDocs"].type == JSONType.true_;
    if ("buildSite" in json)
        config.buildSite = json["buildSite"].type == JSONType.true_;
    if ("siteDir" in json)
        config.siteDir = json["siteDir"].str;
    if ("pkgdownConfig" in json)
        config.pkgdownConfig = json["pkgdownConfig"].str;
    if ("includeVignettes" in json)
        config.includeVignettes = json["includeVignettes"].type == JSONType.true_;
    if ("generateReadme" in json)
        config.generateReadme = json["generateReadme"].type == JSONType.true_;
    
    return config;
}

/// Parse environment configuration from JSON
private REnvConfig parseEnvConfig(JSONValue json)
{
    REnvConfig config;
    
    if ("manager" in json)
    {
        string mgrStr = json["manager"].str;
        switch (mgrStr.toLower())
        {
            case "auto": config.manager = REnvManager.Auto; break;
            case "renv": config.manager = REnvManager.Renv; break;
            case "packrat": config.manager = REnvManager.Packrat; break;
            case "none": config.manager = REnvManager.None; break;
            default: config.manager = REnvManager.Auto; break;
        }
    }
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("autoCreate" in json)
        config.autoCreate = json["autoCreate"].type == JSONType.true_;
    if ("envDir" in json)
        config.envDir = json["envDir"].str;
    if ("autoSnapshot" in json)
        config.autoSnapshot = json["autoSnapshot"].type == JSONType.true_;
    if ("useCache" in json)
        config.useCache = json["useCache"].type == JSONType.true_;
    if ("clean" in json)
        config.clean = json["clean"].type == JSONType.true_;
    
    return config;
}

/// Parse profiling configuration from JSON
private RProfileConfig parseProfileConfig(JSONValue json)
{
    RProfileConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("tool" in json)
        config.tool = json["tool"].str;
    if ("outputFile" in json)
        config.outputFile = json["outputFile"].str;
    if ("interval" in json && json["interval"].type == JSONType.float_)
        config.interval = json["interval"].floating;
    if ("memoryProfiling" in json)
        config.memoryProfiling = json["memoryProfiling"].type == JSONType.true_;
    
    return config;
}

/// Parse Shiny configuration from JSON
private RShinyConfig parseShinyConfig(JSONValue json)
{
    RShinyConfig config;
    
    if ("host" in json)
        config.host = json["host"].str;
    if ("port" in json && json["port"].type == JSONType.integer)
        config.port = cast(int)json["port"].integer;
    if ("launchBrowser" in json)
        config.launchBrowser = json["launchBrowser"].type == JSONType.true_;
    if ("displayMode" in json)
        config.displayMode = json["displayMode"].str;
    if ("autoReload" in json)
        config.autoReload = json["autoReload"].type == JSONType.true_;
    
    return config;
}

/// Parse RMarkdown configuration from JSON
private RMarkdownConfig parseRMarkdownConfig(JSONValue json)
{
    RMarkdownConfig config;
    
    if ("format" in json)
    {
        string fmtStr = json["format"].str;
        switch (fmtStr.toLower())
        {
            case "html": config.format = RMarkdownFormat.HTML; break;
            case "pdf": config.format = RMarkdownFormat.PDF; break;
            case "word": config.format = RMarkdownFormat.Word; break;
            case "markdown":
            case "md": config.format = RMarkdownFormat.Markdown; break;
            case "revealjs": config.format = RMarkdownFormat.RevealJS; break;
            case "beamer": config.format = RMarkdownFormat.Beamer; break;
            case "custom": config.format = RMarkdownFormat.Custom; break;
            default: config.format = RMarkdownFormat.HTML; break;
        }
    }
    
    if ("customFormat" in json)
        config.customFormat = json["customFormat"].str;
    if ("selfContained" in json)
        config.selfContained = json["selfContained"].type == JSONType.true_;
    if ("keepIntermediates" in json)
        config.keepIntermediates = json["keepIntermediates"].type == JSONType.true_;
    if ("outputFile" in json)
        config.outputFile = json["outputFile"].str;
    
    if ("params" in json)
    {
        foreach (string key, value; json["params"].object)
        {
            config.params[key] = value.str;
        }
    }
    
    return config;
}

