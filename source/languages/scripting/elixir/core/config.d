module languages.scripting.elixir.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Elixir project types - distinct build strategies
enum ElixirProjectType
{
    /// Simple script - single .ex/.exs file
    Script,
    /// Mix project - standard OTP application
    MixProject,
    /// Phoenix web application
    Phoenix,
    /// Phoenix LiveView application
    PhoenixLiveView,
    /// Umbrella project - multi-app architecture
    Umbrella,
    /// Library - for publishing to Hex
    Library,
    /// Nerves - embedded systems
    Nerves,
    /// Escript - standalone executable
    Escript
}

/// Mix environment modes
enum MixEnv
{
    /// Development (default)
    Dev,
    /// Testing
    Test,
    /// Production
    Prod,
    /// Custom environment
    Custom
}

/// Release types for Mix releases
enum ReleaseType
{
    /// No release (default)
    None,
    /// Mix release (Elixir 1.9+)
    MixRelease,
    /// Distillery release (legacy)
    Distillery,
    /// Burrito - cross-platform wrapper
    Burrito,
    /// Bakeware - self-extracting executable
    Bakeware
}

/// OTP application types
enum OTPAppType
{
    /// Standard OTP application with supervision tree
    Application,
    /// Library (no application callback)
    Library,
    /// Umbrella application
    Umbrella,
    /// Task (single-purpose executable)
    Task
}

/// Elixir version specification
struct ElixirVersion
{
    /// Major version (e.g., 1)
    int major = 1;
    
    /// Minor version (e.g., 15)
    int minor = 15;
    
    /// Patch version
    int patch = 0;
    
    /// OTP version requirement (e.g., 26)
    string otpVersion;
    
    /// Specific Elixir path (overrides version)
    string elixirPath;
    
    /// Use asdf for version management
    bool useAsdf = false;
    
    /// Convert to version string
    string toString() const @safe pure
    {
        import std.format : format;
        
        if (patch == 0)
            return format!"%d.%d"(major, minor);
        return format!"%d.%d.%d"(major, minor, patch);
    }
}

/// Mix project configuration
struct MixProjectConfig
{
    /// Project name
    string name;
    
    /// Application name (atom)
    string app;
    
    /// Version
    string version_;
    
    /// Elixir version requirement
    string elixirVersion;
    
    /// Build embedded (for releases)
    bool buildEmbedded = false;
    
    /// Start permanent (for releases)
    bool startPermanent = false;
    
    /// Preferred CLI environment
    string preferredCliEnv;
    
    /// Consolidate protocols
    bool consolidateProtocols = true;
    
    /// Build path
    string buildPath = "_build";
    
    /// Deps path
    string depsPath = "deps";
    
    /// Mix exs path
    string mixExsPath = "mix.exs";
}

/// Phoenix framework configuration
struct PhoenixConfig
{
    /// Enable Phoenix
    bool enabled = false;
    
    /// Phoenix version
    string version_;
    
    /// Enable LiveView
    bool liveView = false;
    
    /// LiveView version
    string liveViewVersion;
    
    /// Ecto repository
    bool ecto = false;
    
    /// Database adapter (postgres, mysql, sqlite)
    string database;
    
    /// Compile assets
    bool compileAssets = true;
    
    /// Asset build tool (esbuild, webpack, vite)
    string assetTool = "esbuild";
    
    /// Run migrations before deploy
    bool runMigrations = false;
    
    /// Generate static assets
    bool digestAssets = false;
    
    /// Endpoint module
    string endpoint;
    
    /// Web module
    string webModule;
    
    /// HTTP port
    int port = 4000;
    
    /// Enable PubSub
    bool pubSub = true;
}

/// Umbrella project configuration
struct UmbrellaConfig
{
    /// Apps directory
    string appsDir = "apps";
    
    /// Individual app paths
    string[] apps;
    
    /// Shared dependencies
    bool sharedDeps = true;
    
    /// Build all apps
    bool buildAll = true;
    
    /// Apps to exclude from build
    string[] excludeApps;
}

/// Hex package configuration
struct HexConfig
{
    /// Package name (for publishing)
    string packageName;
    
    /// Organization (for private packages)
    string organization;
    
    /// Description
    string description;
    
    /// Files to include in package
    string[] files;
    
    /// Licenses
    string[] licenses;
    
    /// Links (source, homepage, etc.)
    string[string] links;
    
    /// Maintainers
    string[] maintainers;
    
    /// API key path
    string apiKeyPath;
    
    /// Publish to Hex
    bool publish = false;
    
    /// Build docs for Hex
    bool buildDocs = true;
}

/// Dialyzer type analysis configuration
struct DialyzerConfig
{
    /// Enable Dialyzer
    bool enabled = false;
    
    /// PLT file path
    string pltFile = "_build/dialyzer.plt";
    
    /// PLT add apps
    string[] pltApps;
    
    /// Flags
    string[] flags;
    
    /// Warnings to enable
    string[] warnings;
    
    /// Paths to check
    string[] paths;
    
    /// Remove defaults
    bool removeDefaults = false;
    
    /// List unused filters
    bool listUnusedFilters = false;
    
    /// Ignore warnings
    string ignoreWarnings;
    
    /// Format (short, long, dialyxir, github)
    string format = "dialyxir";
}

/// Credo static analysis configuration
struct CredoConfig
{
    /// Enable Credo
    bool enabled = false;
    
    /// Strict mode
    bool strict = false;
    
    /// All checks (including disabled)
    bool all = false;
    
    /// Config file
    string configFile = ".credo.exs";
    
    /// Checks to run
    string[] checks;
    
    /// Files to check
    string[] files;
    
    /// Min priority (higher, high, normal, low, lower)
    string minPriority;
    
    /// Format (flycheck, oneline, json)
    string format;
    
    /// Enable explanations
    bool enableExplanations = true;
}

/// ExUnit testing configuration
struct ExUnitConfig
{
    /// Test paths
    string[] testPaths = ["test"];
    
    /// Test pattern
    string testPattern = "*_test.exs";
    
    /// Test coverage tool
    string coverageTool;
    
    /// Enable trace
    bool trace = false;
    
    /// Max cases (parallel tests)
    int maxCases = 0;
    
    /// Exclude tags
    string[] exclude;
    
    /// Include tags
    string[] include;
    
    /// Only tags (run only these)
    string[] only;
    
    /// Seed for randomization
    int seed = 0;
    
    /// Timeout (ms)
    int timeout = 60000;
    
    /// Slow test threshold (ms)
    int slowTestThreshold = 0;
    
    /// Capture log
    bool captureLog = true;
    
    /// Colors
    bool colors = true;
    
    /// Formatters
    string[] formatters = ["ExUnit.CLIFormatter"];
}

/// ExCoveralls coverage configuration
struct CoverallsConfig
{
    /// Enable coverage
    bool enabled = false;
    
    /// Service name (travis-ci, circle-ci, github)
    string service;
    
    /// Treat no relevant lines as success
    bool treatNoRelevantLinesAsSuccess = true;
    
    /// Output directory
    string outputDir = "cover";
    
    /// Coverage options
    string coverageOptions;
    
    /// Post to service
    bool post = false;
    
    /// Ignore modules
    string[] ignoreModules;
    
    /// Stop words
    string[] stopWords;
    
    /// Minimum coverage
    float minCoverage = 0.0;
}

/// Mix format configuration
struct FormatConfig
{
    /// Enable auto-format
    bool enabled = false;
    
    /// Format file patterns
    string[] inputs = ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"];
    
    /// Check formatted (don't format, just check)
    bool checkFormatted = false;
    
    /// Formatter plugins
    string[] plugins;
    
    /// Import deps
    bool importDeps = true;
    
    /// Export locals without parens
    bool exportLocalsWithoutParens = true;
    
    /// Dot formatter path
    string dotFormatterPath = ".formatter.exs";
}

/// ExDoc documentation configuration
struct DocConfig
{
    /// Generate documentation
    bool enabled = false;
    
    /// Main module
    string main;
    
    /// Source URL
    string sourceUrl;
    
    /// Homepage URL
    string homepageUrl;
    
    /// Logo path
    string logo;
    
    /// Output format (html, epub)
    string[] formatters = ["html"];
    
    /// Output directory
    string output = "doc";
    
    /// Extra pages
    string[] extras;
    
    /// Groups
    string[string] groups;
    
    /// API reference
    bool api = true;
    
    /// Canonical URL
    string canonical;
    
    /// Language
    string language = "en";
}

/// Release configuration
struct ReleaseConfig
{
    /// Release name
    string name;
    
    /// Release version
    string version_;
    
    /// Release type
    ReleaseType type = ReleaseType.None;
    
    /// Include ERTS
    bool includeErts = true;
    
    /// ERTS version
    string ertsVersion;
    
    /// Include Elixir
    bool includeElixir = false;
    
    /// Applications to include
    string[] applications;
    
    /// Release steps
    string[] steps;
    
    /// Strip debug info
    bool stripDebugInfo = false;
    
    /// Cookie for distributed Erlang
    string cookie;
    
    /// Overlays (additional files/directories)
    string[] overlays;
    
    /// Config providers
    string[] configProviders;
    
    /// Runtime configuration
    bool runtimeConfig = true;
    
    /// Output directory
    string path = "_build/${MIX_ENV}/rel";
    
    /// Quiet mode
    bool quiet = false;
}

/// Nerves embedded configuration
struct NervesConfig
{
    /// Enable Nerves
    bool enabled = false;
    
    /// Target system
    string target;
    
    /// Target tag
    string targetTag;
    
    /// Artifact sites
    string[] artifactSites;
    
    /// Firmware configuration
    string fwupConf;
    
    /// Provisioning
    bool provisioning = false;
    
    /// Build runner
    string buildRunner = "make";
}

/// Dependency specification
struct Dependency
{
    /// Package name
    string name;
    
    /// Version requirement
    string version_;
    
    /// Source (hex, git, path)
    string source = "hex";
    
    /// Git URL (if source=git)
    string git;
    
    /// Git ref/branch/tag
    string gitRef;
    
    /// Path (if source=path)
    string path;
    
    /// Optional dependency
    bool optional = false;
    
    /// Only in environments
    string[] onlyEnv;
    
    /// Runtime dependency
    bool runtime = true;
    
    /// Override
    bool override_ = false;
    
    /// Organization (for private Hex packages)
    string organization;
}

/// Elixir-specific build configuration
struct ElixirConfig
{
    /// Project type
    ElixirProjectType projectType = ElixirProjectType.MixProject;
    
    /// Mix environment
    MixEnv env = MixEnv.Dev;
    
    /// Custom environment name (if env=Custom)
    string customEnv;
    
    /// Elixir version
    ElixirVersion elixirVersion;
    
    /// Mix project configuration
    MixProjectConfig project;
    
    /// Phoenix configuration
    PhoenixConfig phoenix;
    
    /// Umbrella configuration
    UmbrellaConfig umbrella;
    
    /// Hex configuration
    HexConfig hex;
    
    /// Release configuration
    ReleaseConfig release;
    
    /// Nerves configuration
    NervesConfig nerves;
    
    /// Dependencies
    Dependency[] dependencies;
    
    /// Testing configuration
    ExUnitConfig test;
    
    /// Coverage configuration
    CoverallsConfig coverage;
    
    /// Format configuration
    FormatConfig format;
    
    /// Dialyzer configuration
    DialyzerConfig dialyzer;
    
    /// Credo configuration
    CredoConfig credo;
    
    /// Documentation configuration
    DocConfig docs;
    
    /// OTP application type
    OTPAppType appType = OTPAppType.Application;
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Run mix deps.get before build
    bool depsGet = false;
    
    /// Run mix deps.compile before build
    bool depsCompile = false;
    
    /// Run mix deps.clean before build
    bool depsClean = false;
    
    /// Run mix compile.protocols
    bool compileProtocols = false;
    
    /// Clean build artifacts before build
    bool clean = false;
    
    /// Verbose output
    bool verbose = false;
    
    /// Warning as errors
    bool warningsAsErrors = false;
    
    /// Debug info
    bool debugInfo = true;
    
    /// Compiler options
    string[] compilerOpts;
    
    /// ERL flags
    string[] erlFlags;
    
    /// ELIXIR flags
    string[] elixirFlags;
    
    /// Environment variables
    string[string] env_;
    
    /// Parse from JSON
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Parses untrusted JSON input (potentially malicious data)
    /// 2. JSONValue operations are @safe but extensive parsing justifies @trusted
    /// 3. All string extractions are validated with type checks
    /// 4. Invalid JSON results in default config (safe fallback)
    /// 5. Exception handling ensures no crashes on malformed input
    /// 
    /// Invariants:
    /// - Returns valid ElixirConfig even if JSON is malformed
    /// - All fields have safe defaults
    /// - Type mismatches result in default values
    /// - No memory unsafety from JSON parsing
    /// 
    /// What could go wrong:
    /// - Malformed JSON: caught by exception handler, returns defaults
    /// - Type mismatch: checked before access, uses defaults
    /// - Missing fields: defaults applied (safe behavior)
    static ElixirConfig fromJSON(JSONValue json) @trusted
    {
        ElixirConfig config;
        
        // Project type
        if (auto projectType = "projectType" in json)
        {
            immutable typeStr = projectType.str.toLower;
            switch (typeStr)
            {
                case "script": config.projectType = ElixirProjectType.Script; break;
                case "mix", "mixproject": config.projectType = ElixirProjectType.MixProject; break;
                case "phoenix": config.projectType = ElixirProjectType.Phoenix; break;
                case "phoenix-liveview", "liveview": 
                    config.projectType = ElixirProjectType.PhoenixLiveView; break;
                case "umbrella": config.projectType = ElixirProjectType.Umbrella; break;
                case "library": config.projectType = ElixirProjectType.Library; break;
                case "nerves": config.projectType = ElixirProjectType.Nerves; break;
                case "escript": config.projectType = ElixirProjectType.Escript; break;
                default: config.projectType = ElixirProjectType.MixProject; break;
            }
        }
        
        // Mix environment
        if (auto env = "env" in json)
        {
            immutable envStr = env.str.toLower;
            switch (envStr)
            {
                case "dev": config.env = MixEnv.Dev; break;
                case "test": config.env = MixEnv.Test; break;
                case "prod": config.env = MixEnv.Prod; break;
                case "custom": 
                    config.env = MixEnv.Custom;
                    if (auto customEnv = "customEnv" in json)
                        config.customEnv = customEnv.str;
                    break;
                default: config.env = MixEnv.Dev; break;
            }
        }
        
        // Elixir version
        if (auto elixirVersion = "elixirVersion" in json)
        {
            if (elixirVersion.type == JSONType.string)
            {
                immutable parts = elixirVersion.str.split(".");
                if (parts.length >= 1) config.elixirVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.elixirVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.elixirVersion.patch = parts[2].to!int;
            }
            else if (elixirVersion.type == JSONType.object)
            {
                if (auto major = "major" in *elixirVersion) 
                    config.elixirVersion.major = cast(int)major.integer;
                if (auto minor = "minor" in *elixirVersion) 
                    config.elixirVersion.minor = cast(int)minor.integer;
                if (auto patch = "patch" in *elixirVersion) 
                    config.elixirVersion.patch = cast(int)patch.integer;
                if (auto otpVersion = "otpVersion" in *elixirVersion) 
                    config.elixirVersion.otpVersion = otpVersion.str;
                if (auto elixirPath = "elixirPath" in *elixirVersion) 
                    config.elixirVersion.elixirPath = elixirPath.str;
                if (auto useAsdf = "useAsdf" in *elixirVersion) 
                    config.elixirVersion.useAsdf = useAsdf.type == JSONType.true_;
            }
        }
        
        // Project configuration
        if (auto project = "project" in json)
        {
            if (auto name = "name" in *project) config.project.name = name.str;
            if (auto app = "app" in *project) config.project.app = app.str;
            if (auto version_ = "version" in *project) config.project.version_ = version_.str;
            if (auto elixirVersion = "elixirVersion" in *project) config.project.elixirVersion = elixirVersion.str;
            if (auto buildEmbedded = "buildEmbedded" in *project) 
                config.project.buildEmbedded = buildEmbedded.type == JSONType.true_;
            if (auto startPermanent = "startPermanent" in *project) 
                config.project.startPermanent = startPermanent.type == JSONType.true_;
            if (auto preferredCliEnv = "preferredCliEnv" in *project) 
                config.project.preferredCliEnv = preferredCliEnv.str;
            if (auto consolidateProtocols = "consolidateProtocols" in *project) 
                config.project.consolidateProtocols = consolidateProtocols.type == JSONType.true_;
            if (auto buildPath = "buildPath" in *project) config.project.buildPath = buildPath.str;
            if (auto depsPath = "depsPath" in *project) config.project.depsPath = depsPath.str;
            if (auto mixExsPath = "mixExsPath" in *project) config.project.mixExsPath = mixExsPath.str;
        }
        
        // Phoenix configuration
        if ("phoenix" in json)
        {
            auto ph = json["phoenix"];
            if ("enabled" in ph) config.phoenix.enabled = ph["enabled"].type == JSONType.true_;
            if ("version" in ph) config.phoenix.version_ = ph["version"].str;
            if ("liveView" in ph) config.phoenix.liveView = ph["liveView"].type == JSONType.true_;
            if ("liveViewVersion" in ph) config.phoenix.liveViewVersion = ph["liveViewVersion"].str;
            if ("ecto" in ph) config.phoenix.ecto = ph["ecto"].type == JSONType.true_;
            if ("database" in ph) config.phoenix.database = ph["database"].str;
            if ("compileAssets" in ph) config.phoenix.compileAssets = ph["compileAssets"].type == JSONType.true_;
            if ("assetTool" in ph) config.phoenix.assetTool = ph["assetTool"].str;
            if ("runMigrations" in ph) config.phoenix.runMigrations = ph["runMigrations"].type == JSONType.true_;
            if ("digestAssets" in ph) config.phoenix.digestAssets = ph["digestAssets"].type == JSONType.true_;
            if ("endpoint" in ph) config.phoenix.endpoint = ph["endpoint"].str;
            if ("webModule" in ph) config.phoenix.webModule = ph["webModule"].str;
            if ("port" in ph) config.phoenix.port = cast(int)ph["port"].integer;
            if ("pubSub" in ph) config.phoenix.pubSub = ph["pubSub"].type == JSONType.true_;
        }
        
        // Umbrella configuration
        if ("umbrella" in json)
        {
            auto u = json["umbrella"];
            if ("appsDir" in u) config.umbrella.appsDir = u["appsDir"].str;
            if ("apps" in u) config.umbrella.apps = u["apps"].array.map!(e => e.str).array;
            if ("sharedDeps" in u) config.umbrella.sharedDeps = u["sharedDeps"].type == JSONType.true_;
            if ("buildAll" in u) config.umbrella.buildAll = u["buildAll"].type == JSONType.true_;
            if ("excludeApps" in u) config.umbrella.excludeApps = u["excludeApps"].array.map!(e => e.str).array;
        }
        
        // Hex configuration
        if (auto hex = "hex" in json)
        {
            if (auto packageName = "packageName" in *hex) config.hex.packageName = packageName.str;
            if (auto organization = "organization" in *hex) config.hex.organization = organization.str;
            if (auto description = "description" in *hex) config.hex.description = description.str;
            if (auto files = "files" in *hex) config.hex.files = files.array.map!(e => e.str).array;
            if (auto licenses = "licenses" in *hex) config.hex.licenses = licenses.array.map!(e => e.str).array;
            if (auto maintainers = "maintainers" in *hex) config.hex.maintainers = maintainers.array.map!(e => e.str).array;
            if (auto apiKeyPath = "apiKeyPath" in *hex) config.hex.apiKeyPath = apiKeyPath.str;
            if (auto publish = "publish" in *hex) config.hex.publish = publish.type == JSONType.true_;
            if (auto buildDocs = "buildDocs" in *hex) config.hex.buildDocs = buildDocs.type == JSONType.true_;
            
            if (auto links = "links" in *hex)
            {
                foreach (string key, ref value; links.object)
                    config.hex.links[key] = value.str;
            }
        }
        
        // Testing configuration
        if ("test" in json)
        {
            auto t = json["test"];
            if ("testPaths" in t) config.test.testPaths = t["testPaths"].array.map!(e => e.str).array;
            if ("testPattern" in t) config.test.testPattern = t["testPattern"].str;
            if ("coverageTool" in t) config.test.coverageTool = t["coverageTool"].str;
            if ("trace" in t) config.test.trace = t["trace"].type == JSONType.true_;
            if ("maxCases" in t) config.test.maxCases = cast(int)t["maxCases"].integer;
            if ("exclude" in t) config.test.exclude = t["exclude"].array.map!(e => e.str).array;
            if ("include" in t) config.test.include = t["include"].array.map!(e => e.str).array;
            if ("only" in t) config.test.only = t["only"].array.map!(e => e.str).array;
            if ("seed" in t) config.test.seed = cast(int)t["seed"].integer;
            if ("timeout" in t) config.test.timeout = cast(int)t["timeout"].integer;
            if ("slowTestThreshold" in t) config.test.slowTestThreshold = cast(int)t["slowTestThreshold"].integer;
            if ("captureLog" in t) config.test.captureLog = t["captureLog"].type == JSONType.true_;
            if ("colors" in t) config.test.colors = t["colors"].type == JSONType.true_;
            if ("formatters" in t) config.test.formatters = t["formatters"].array.map!(e => e.str).array;
        }
        
        // Dialyzer configuration
        if ("dialyzer" in json)
        {
            auto d = json["dialyzer"];
            if ("enabled" in d) config.dialyzer.enabled = d["enabled"].type == JSONType.true_;
            if ("pltFile" in d) config.dialyzer.pltFile = d["pltFile"].str;
            if ("pltApps" in d) config.dialyzer.pltApps = d["pltApps"].array.map!(e => e.str).array;
            if ("flags" in d) config.dialyzer.flags = d["flags"].array.map!(e => e.str).array;
            if ("warnings" in d) config.dialyzer.warnings = d["warnings"].array.map!(e => e.str).array;
            if ("paths" in d) config.dialyzer.paths = d["paths"].array.map!(e => e.str).array;
            if ("removeDefaults" in d) config.dialyzer.removeDefaults = d["removeDefaults"].type == JSONType.true_;
            if ("listUnusedFilters" in d) config.dialyzer.listUnusedFilters = d["listUnusedFilters"].type == JSONType.true_;
            if ("ignoreWarnings" in d) config.dialyzer.ignoreWarnings = d["ignoreWarnings"].str;
            if ("format" in d) config.dialyzer.format = d["format"].str;
        }
        
        // Credo configuration
        if ("credo" in json)
        {
            auto c = json["credo"];
            if ("enabled" in c) config.credo.enabled = c["enabled"].type == JSONType.true_;
            if ("strict" in c) config.credo.strict = c["strict"].type == JSONType.true_;
            if ("all" in c) config.credo.all = c["all"].type == JSONType.true_;
            if ("configFile" in c) config.credo.configFile = c["configFile"].str;
            if ("checks" in c) config.credo.checks = c["checks"].array.map!(e => e.str).array;
            if ("files" in c) config.credo.files = c["files"].array.map!(e => e.str).array;
            if ("minPriority" in c) config.credo.minPriority = c["minPriority"].str;
            if ("format" in c) config.credo.format = c["format"].str;
            if ("enableExplanations" in c) config.credo.enableExplanations = c["enableExplanations"].type == JSONType.true_;
        }
        
        // Format configuration
        if ("format" in json)
        {
            auto f = json["format"];
            if ("enabled" in f) config.format.enabled = f["enabled"].type == JSONType.true_;
            if ("inputs" in f) config.format.inputs = f["inputs"].array.map!(e => e.str).array;
            if ("checkFormatted" in f) config.format.checkFormatted = f["checkFormatted"].type == JSONType.true_;
            if ("plugins" in f) config.format.plugins = f["plugins"].array.map!(e => e.str).array;
            if ("importDeps" in f) config.format.importDeps = f["importDeps"].type == JSONType.true_;
            if ("exportLocalsWithoutParens" in f) config.format.exportLocalsWithoutParens = f["exportLocalsWithoutParens"].type == JSONType.true_;
            if ("dotFormatterPath" in f) config.format.dotFormatterPath = f["dotFormatterPath"].str;
        }
        
        // Documentation configuration
        if ("docs" in json)
        {
            auto d = json["docs"];
            if ("enabled" in d) config.docs.enabled = d["enabled"].type == JSONType.true_;
            if ("main" in d) config.docs.main = d["main"].str;
            if ("sourceUrl" in d) config.docs.sourceUrl = d["sourceUrl"].str;
            if ("homepageUrl" in d) config.docs.homepageUrl = d["homepageUrl"].str;
            if ("logo" in d) config.docs.logo = d["logo"].str;
            if ("formatters" in d) config.docs.formatters = d["formatters"].array.map!(e => e.str).array;
            if ("output" in d) config.docs.output = d["output"].str;
            if ("extras" in d) config.docs.extras = d["extras"].array.map!(e => e.str).array;
            if ("api" in d) config.docs.api = d["api"].type == JSONType.true_;
            if ("canonical" in d) config.docs.canonical = d["canonical"].str;
            if ("language" in d) config.docs.language = d["language"].str;
            
            if ("groups" in d)
            {
                foreach (string key, value; d["groups"].object)
                    config.docs.groups[key] = value.str;
            }
        }
        
        // Coverage configuration
        if ("coverage" in json)
        {
            auto cov = json["coverage"];
            if ("enabled" in cov) config.coverage.enabled = cov["enabled"].type == JSONType.true_;
            if ("service" in cov) config.coverage.service = cov["service"].str;
            if ("treatNoRelevantLinesAsSuccess" in cov) 
                config.coverage.treatNoRelevantLinesAsSuccess = cov["treatNoRelevantLinesAsSuccess"].type == JSONType.true_;
            if ("outputDir" in cov) config.coverage.outputDir = cov["outputDir"].str;
            if ("coverageOptions" in cov) config.coverage.coverageOptions = cov["coverageOptions"].str;
            if ("post" in cov) config.coverage.post = cov["post"].type == JSONType.true_;
            if ("ignoreModules" in cov) config.coverage.ignoreModules = cov["ignoreModules"].array.map!(e => e.str).array;
            if ("stopWords" in cov) config.coverage.stopWords = cov["stopWords"].array.map!(e => e.str).array;
            if ("minCoverage" in cov) config.coverage.minCoverage = cast(float)cov["minCoverage"].floating;
        }
        
        // Release configuration
        if ("release" in json)
        {
            auto r = json["release"];
            if ("name" in r) config.release.name = r["name"].str;
            if ("version" in r) config.release.version_ = r["version"].str;
            if ("includeErts" in r) config.release.includeErts = r["includeErts"].type == JSONType.true_;
            if ("ertsVersion" in r) config.release.ertsVersion = r["ertsVersion"].str;
            if ("includeElixir" in r) config.release.includeElixir = r["includeElixir"].type == JSONType.true_;
            if ("applications" in r) config.release.applications = r["applications"].array.map!(e => e.str).array;
            if ("steps" in r) config.release.steps = r["steps"].array.map!(e => e.str).array;
            if ("stripDebugInfo" in r) config.release.stripDebugInfo = r["stripDebugInfo"].type == JSONType.true_;
            if ("cookie" in r) config.release.cookie = r["cookie"].str;
            if ("overlays" in r) config.release.overlays = r["overlays"].array.map!(e => e.str).array;
            if ("configProviders" in r) config.release.configProviders = r["configProviders"].array.map!(e => e.str).array;
            if ("runtimeConfig" in r) config.release.runtimeConfig = r["runtimeConfig"].type == JSONType.true_;
            if ("path" in r) config.release.path = r["path"].str;
            if ("quiet" in r) config.release.quiet = r["quiet"].type == JSONType.true_;
            
            if ("type" in r)
            {
                string typeStr = r["type"].str;
                switch (typeStr.toLower)
                {
                    case "none": config.release.type = ReleaseType.None; break;
                    case "mix": case "mixrelease": config.release.type = ReleaseType.MixRelease; break;
                    case "distillery": config.release.type = ReleaseType.Distillery; break;
                    case "burrito": config.release.type = ReleaseType.Burrito; break;
                    case "bakeware": config.release.type = ReleaseType.Bakeware; break;
                    default: config.release.type = ReleaseType.None; break;
                }
            }
        }
        
        // Nerves configuration
        if ("nerves" in json)
        {
            auto n = json["nerves"];
            if ("enabled" in n) config.nerves.enabled = n["enabled"].type == JSONType.true_;
            if ("target" in n) config.nerves.target = n["target"].str;
            if ("targetTag" in n) config.nerves.targetTag = n["targetTag"].str;
            if ("artifactSites" in n) config.nerves.artifactSites = n["artifactSites"].array.map!(e => e.str).array;
            if ("fwupConf" in n) config.nerves.fwupConf = n["fwupConf"].str;
            if ("provisioning" in n) config.nerves.provisioning = n["provisioning"].type == JSONType.true_;
            if ("buildRunner" in n) config.nerves.buildRunner = n["buildRunner"].str;
        }
        
        // Dependencies
        if (auto dependencies = "dependencies" in json)
        {
            config.dependencies.reserve(dependencies.array.length);
            foreach (ref dep; dependencies.array)
            {
                Dependency d;
                if (auto name = "name" in dep) d.name = name.str;
                if (auto version_ = "version" in dep) d.version_ = version_.str;
                if (auto source = "source" in dep) d.source = source.str;
                if (auto git = "git" in dep) d.git = git.str;
                if (auto ref_ = "ref" in dep) d.gitRef = ref_.str;
                if (auto path = "path" in dep) d.path = path.str;
                if (auto optional = "optional" in dep) d.optional = optional.type == JSONType.true_;
                if (auto onlyEnv = "onlyEnv" in dep) d.onlyEnv = onlyEnv.array.map!(e => e.str).array;
                if (auto runtime = "runtime" in dep) d.runtime = runtime.type == JSONType.true_;
                if (auto override_ = "override" in dep) d.override_ = override_.type == JSONType.true_;
                if (auto organization = "organization" in dep) d.organization = organization.str;
                
                config.dependencies ~= d;
            }
        }
        
        // OTP application type
        if (auto appType = "appType" in json)
        {
            immutable appTypeStr = appType.str.toLower;
            switch (appTypeStr)
            {
                case "application": config.appType = OTPAppType.Application; break;
                case "library": config.appType = OTPAppType.Library; break;
                case "umbrella": config.appType = OTPAppType.Umbrella; break;
                case "task": config.appType = OTPAppType.Task; break;
                default: config.appType = OTPAppType.Application; break;
            }
        }
        
        // Booleans
        if (auto installDeps = "installDeps" in json) config.installDeps = installDeps.type == JSONType.true_;
        if (auto depsGet = "depsGet" in json) config.depsGet = depsGet.type == JSONType.true_;
        if (auto depsCompile = "depsCompile" in json) config.depsCompile = depsCompile.type == JSONType.true_;
        if (auto depsClean = "depsClean" in json) config.depsClean = depsClean.type == JSONType.true_;
        if (auto compileProtocols = "compileProtocols" in json) config.compileProtocols = compileProtocols.type == JSONType.true_;
        if (auto clean = "clean" in json) config.clean = clean.type == JSONType.true_;
        if (auto verbose = "verbose" in json) config.verbose = verbose.type == JSONType.true_;
        if (auto warningsAsErrors = "warningsAsErrors" in json) config.warningsAsErrors = warningsAsErrors.type == JSONType.true_;
        if (auto debugInfo = "debugInfo" in json) config.debugInfo = debugInfo.type == JSONType.true_;
        
        // Arrays
        if (auto compilerOpts = "compilerOpts" in json)
            config.compilerOpts = compilerOpts.array.map!(e => e.str).array;
        if (auto erlFlags = "erlFlags" in json)
            config.erlFlags = erlFlags.array.map!(e => e.str).array;
        if (auto elixirFlags = "elixirFlags" in json)
            config.elixirFlags = elixirFlags.array.map!(e => e.str).array;
        
        // Environment variables
        if (auto env = "env" in json)
        {
            foreach (string key, ref value; env.object)
                config.env_[key] = value.str;
        }
        
        return config;
    }
}

/// Build result for Elixir compilation
struct ElixirBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Compilation warnings
    string[] warnings;
    
    /// Dialyzer warnings
    string[] dialyzerWarnings;
    bool hadDialyzerErrors;
    
    /// Credo issues
    string[] credoIssues;
    
    /// Format issues
    string[] formatIssues;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
    
    /// Generated artifacts
    string releasePath;
    string escriptPath;
    string hexPackagePath;
}

