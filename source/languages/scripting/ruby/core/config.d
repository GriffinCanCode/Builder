module languages.scripting.ruby.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Ruby build modes
enum RubyBuildMode
{
    /// Script - single file or simple script (default)
    Script,
    /// Gem - Ruby gem/library package
    Gem,
    /// Rails - Ruby on Rails application
    Rails,
    /// Rack - Rack application
    Rack,
    /// CLI - Command-line tool
    CLI,
    /// Library - Plain Ruby library
    Library
}

/// Package manager selection
enum RubyPackageManager
{
    /// Auto-detect best available
    Auto,
    /// bundler (standard, Gemfile-based)
    Bundler,
    /// gem (RubyGems direct install)
    RubyGems,
    /// None - skip package management
    None
}

/// Ruby version manager selection
enum RubyVersionManager
{
    /// Auto-detect from project
    Auto,
    /// rbenv (lightweight, shim-based)
    Rbenv,
    /// rvm (full-featured, function-based)
    RVM,
    /// chruby (minimal, elegant)
    Chruby,
    /// asdf (multi-language)
    ASDF,
    /// System Ruby
    System,
    /// None - use Ruby from PATH
    None
}

/// Type checker selection
enum RubyTypeChecker
{
    /// Auto-detect best available
    Auto,
    /// Sorbet (Stripe, fast gradual typing)
    Sorbet,
    /// RBS (Ruby 3.0+ built-in type signatures)
    RBS,
    /// Steep (RBS-based type checker)
    Steep,
    /// None - skip type checking
    None
}

/// Formatter/Linter selection
enum RubyFormatter
{
    /// Auto-detect best available
    Auto,
    /// RuboCop (comprehensive, configurable)
    RuboCop,
    /// StandardRB (opinionated, zero-config)
    Standard,
    /// Reek (code smell detector)
    Reek,
    /// None - skip formatting/linting
    None
}

/// Test framework selection
enum RubyTestFramework
{
    /// Auto-detect from project structure
    Auto,
    /// RSpec (BDD-style, most popular)
    RSpec,
    /// Minitest (standard library)
    Minitest,
    /// Test::Unit (classic Ruby testing)
    TestUnit,
    /// Cucumber (BDD with Gherkin)
    Cucumber,
    /// None - skip tests
    None
}

/// Documentation generator selection
enum RubyDocGenerator
{
    /// Auto-detect best available
    Auto,
    /// YARD (modern, tag-based)
    YARD,
    /// RDoc (standard library)
    RDoc,
    /// Both YARD and RDoc
    Both,
    /// None - skip documentation
    None
}

/// Build tool selection
enum RubyBuildTool
{
    /// Auto-detect from project
    Auto,
    /// Rake (standard Ruby build tool)
    Rake,
    /// Gemspec (gem build)
    Gemspec,
    /// Rails commands
    Rails,
    /// None - direct execution
    None
}

/// Ruby version specification
struct RubyVersion
{
    /// Major version (e.g., 3)
    int major = 3;
    
    /// Minor version (e.g., 3)
    int minor = 3;
    
    /// Patch version (e.g., 0)
    int patch = 0;
    
    /// Specific interpreter path (overrides version)
    string interpreterPath;
    
    /// Version file (.ruby-version)
    string versionFile = ".ruby-version";
    
    /// Convert to string (e.g., "3.3.0")
    string toString() const
    {
        if (patch == 0 && minor > 0)
            return major.to!string ~ "." ~ minor.to!string;
        return major.to!string ~ "." ~ minor.to!string ~ "." ~ patch.to!string;
    }
    
    /// Check if version file exists
    bool hasVersionFile() const
    {
        import std.file : exists;
        return !versionFile.empty && exists(versionFile);
    }
}

/// Bundler configuration
struct BundlerConfig
{
    /// Use Bundler
    bool enabled = true;
    
    /// Gemfile path
    string gemfilePath = "Gemfile";
    
    /// Install path (vendor/bundle, .bundle, etc.)
    string path;
    
    /// Deployment mode (no dev/test gems)
    bool deployment = false;
    
    /// Use local gems
    bool local = false;
    
    /// Frozen lockfile (fail if out of sync)
    bool frozen = false;
    
    /// Number of parallel install jobs
    int jobs = 4;
    
    /// Retry failed gem downloads
    int retry_ = 3;
    
    /// Without groups (e.g., "development:test")
    string[] without;
    
    /// With groups (e.g., "production")
    string[] with_;
    
    /// Clean unused gems
    bool clean = false;
}

/// Gem specification
struct GemSpec
{
    string name;
    string version_;
    string source; // Git URL, local path, or repository
    string group;  // development, test, production
    string platform; // ruby, jruby, mingw, x64_mingw
    bool required = true;
}

/// Testing configuration
struct RubyTestConfig
{
    /// Testing framework
    RubyTestFramework framework = RubyTestFramework.Auto;
    
    /// Test directory/pattern
    string[] testPaths;
    
    /// Verbose output
    bool verbose = false;
    
    /// Generate coverage
    bool coverage = false;
    
    /// Coverage tool (simplecov)
    string coverageTool = "simplecov";
    
    /// Coverage output directory
    string coverageDir = "coverage";
    
    /// Minimum coverage percentage
    float minCoverage = 0.0;
    
    /// Fail if below minimum coverage
    bool failUnderCoverage = false;
    
    /// Run tests in parallel
    bool parallel = false;
    
    /// Number of parallel workers (0 = auto)
    int workers = 0;
    
    /// RSpec-specific options
    struct RSpecOptions
    {
        string format = "progress"; // progress, documentation, html, json
        bool color = true;
        bool profile = false; // Show slowest examples
        int profileCount = 10;
        string[] tags;        // Filter by tags
        string[] excludeTags;
        bool failFast = false;
        string seed;          // Random seed for order
        bool bisect = false;  // Find minimal reproduction
    }
    
    RSpecOptions rspec;
}

/// Type checking configuration
struct TypeCheckConfig
{
    /// Enable type checking
    bool enabled = false;
    
    /// Type checker to use
    RubyTypeChecker checker = RubyTypeChecker.Auto;
    
    /// Strict mode
    bool strict = false;
    
    /// Sorbet-specific configuration
    struct SorbetConfig
    {
        /// Strictness level (false, true, strict, strong)
        string level = "true";
        
        /// Generate RBI files
        bool generateRBI = false;
        
        /// Sorbet configuration file
        string configFile = "sorbet/config";
        
        /// Ignore paths
        string[] ignore;
    }
    
    SorbetConfig sorbet;
    
    /// RBS configuration
    struct RBSConfig
    {
        /// RBS directory
        string dir = "sig";
        
        /// Generate RBS from code
        bool generate = false;
        
        /// Validate RBS files
        bool validate = true;
    }
    
    RBSConfig rbs;
    
    /// Steep configuration
    struct SteepConfig
    {
        /// Steepfile path
        string configFile = "Steepfile";
        
        /// Check entire project
        bool checkAll = false;
    }
    
    SteepConfig steep;
}

/// Formatting/Linting configuration
struct FormatConfig
{
    /// Formatter/linter to use
    RubyFormatter formatter = RubyFormatter.Auto;
    
    /// Auto-format code
    bool autoFormat = false;
    
    /// Auto-correct issues
    bool autoCorrect = false;
    
    /// Configuration file
    string configFile; // .rubocop.yml, .standard.yml, etc.
    
    /// Fail on warnings
    bool failOnWarning = false;
    
    /// Display cop names
    bool displayCopNames = true;
    
    /// RuboCop-specific options
    struct RuboCopOptions
    {
        /// Only run specific cops
        string[] only;
        
        /// Exclude specific cops
        string[] except;
        
        /// Rails cops
        bool rails = false;
        
        /// Display style guide URLs
        bool displayStyleGuide = false;
        
        /// Extra details in offense messages
        bool extraDetails = false;
        
        /// Parallel execution
        bool parallel = true;
    }
    
    RuboCopOptions rubocop;
}

/// Rails-specific configuration
struct RailsConfig
{
    /// Rails environment (development, test, production)
    string environment = "development";
    
    /// Database adapter
    string database;
    
    /// Precompile assets
    bool precompileAssets = false;
    
    /// Run migrations
    bool runMigrations = false;
    
    /// Seed database
    bool seedDatabase = false;
    
    /// Rails command prefix
    string commandPrefix = "bin/rails";
}

/// Gem build configuration
struct GemBuildConfig
{
    /// Gemspec file
    string gemspecFile;
    
    /// Output directory
    string outputDir = "pkg";
    
    /// Sign gem
    bool sign = false;
    
    /// Key for signing
    string key;
    
    /// Build platform-specific gems
    string[] platforms;
    
    /// Include files
    string[] includeFiles;
    
    /// Exclude files
    string[] excludeFiles;
}

/// Documentation configuration
struct DocConfig
{
    /// Documentation generator
    RubyDocGenerator generator = RubyDocGenerator.Auto;
    
    /// Output directory
    string outputDir = "doc";
    
    /// YARD-specific options
    struct YARDOptions
    {
        /// Markup format (markdown, rdoc, textile)
        string markup = "markdown";
        
        /// Include private methods
        bool private_ = false;
        
        /// Include protected methods
        bool protected_ = true;
        
        /// Template to use
        string template = "default";
        
        /// Additional files to include
        string[] files;
    }
    
    YARDOptions yard;
}

/// Ruby-specific build configuration
struct RubyConfig
{
    /// Build mode
    RubyBuildMode mode = RubyBuildMode.Script;
    
    /// Ruby version requirement
    RubyVersion rubyVersion;
    
    /// Version manager
    RubyVersionManager versionManager = RubyVersionManager.Auto;
    
    /// Bundler configuration
    BundlerConfig bundler;
    
    /// Package manager
    RubyPackageManager packageManager = RubyPackageManager.Auto;
    
    /// Type checking configuration
    TypeCheckConfig typeCheck;
    
    /// Formatting configuration
    FormatConfig format;
    
    /// Testing configuration
    RubyTestConfig test;
    
    /// Rails configuration (if mode == Rails)
    RailsConfig rails;
    
    /// Gem build configuration (if mode == Gem)
    GemBuildConfig gemBuild;
    
    /// Documentation configuration
    DocConfig documentation;
    
    /// Build tool
    RubyBuildTool buildTool = RubyBuildTool.Auto;
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Gem dependencies
    GemSpec[] gems;
    
    /// Require Bundler
    bool requireBundler = true;
    
    /// Load path additions
    string[] loadPath;
    
    /// Environment variables for build
    string[string] env;
    
    /// Rake tasks to run
    string[] rakeTasks;
    
    /// Parse from JSON
    static RubyConfig fromJSON(JSONValue json)
    {
        RubyConfig config;
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower)
            {
                case "script": config.mode = RubyBuildMode.Script; break;
                case "gem": config.mode = RubyBuildMode.Gem; break;
                case "rails": config.mode = RubyBuildMode.Rails; break;
                case "rack": config.mode = RubyBuildMode.Rack; break;
                case "cli": config.mode = RubyBuildMode.CLI; break;
                case "library": config.mode = RubyBuildMode.Library; break;
                default: config.mode = RubyBuildMode.Script; break;
            }
        }
        
        // Ruby version
        if ("rubyVersion" in json)
        {
            auto v = json["rubyVersion"];
            if (v.type == JSONType.string)
            {
                auto parts = v.str.split(".");
                if (parts.length >= 1) config.rubyVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.rubyVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.rubyVersion.patch = parts[2].to!int;
            }
            else if (v.type == JSONType.object)
            {
                if ("major" in v) config.rubyVersion.major = cast(int)v["major"].integer;
                if ("minor" in v) config.rubyVersion.minor = cast(int)v["minor"].integer;
                if ("patch" in v) config.rubyVersion.patch = cast(int)v["patch"].integer;
                if ("interpreterPath" in v) config.rubyVersion.interpreterPath = v["interpreterPath"].str;
                if ("versionFile" in v) config.rubyVersion.versionFile = v["versionFile"].str;
            }
        }
        
        // Version manager
        if ("versionManager" in json)
        {
            string vmStr = json["versionManager"].str;
            switch (vmStr.toLower)
            {
                case "auto": config.versionManager = RubyVersionManager.Auto; break;
                case "rbenv": config.versionManager = RubyVersionManager.Rbenv; break;
                case "rvm": config.versionManager = RubyVersionManager.RVM; break;
                case "chruby": config.versionManager = RubyVersionManager.Chruby; break;
                case "asdf": config.versionManager = RubyVersionManager.ASDF; break;
                case "system": config.versionManager = RubyVersionManager.System; break;
                case "none": config.versionManager = RubyVersionManager.None; break;
                default: break;
            }
        }
        
        // Bundler configuration
        if ("bundler" in json)
        {
            auto b = json["bundler"];
            if ("enabled" in b) config.bundler.enabled = b["enabled"].type == JSONType.true_;
            if ("gemfilePath" in b) config.bundler.gemfilePath = b["gemfilePath"].str;
            if ("path" in b) config.bundler.path = b["path"].str;
            if ("deployment" in b) config.bundler.deployment = b["deployment"].type == JSONType.true_;
            if ("local" in b) config.bundler.local = b["local"].type == JSONType.true_;
            if ("frozen" in b) config.bundler.frozen = b["frozen"].type == JSONType.true_;
            if ("jobs" in b) config.bundler.jobs = cast(int)b["jobs"].integer;
            if ("retry" in b) config.bundler.retry_ = cast(int)b["retry"].integer;
            if ("clean" in b) config.bundler.clean = b["clean"].type == JSONType.true_;
            
            if ("without" in b)
                config.bundler.without = b["without"].array.map!(e => e.str).array;
            if ("with" in b)
                config.bundler.with_ = b["with"].array.map!(e => e.str).array;
        }
        
        // Package manager
        if ("packageManager" in json)
        {
            string pmStr = json["packageManager"].str;
            switch (pmStr.toLower)
            {
                case "auto": config.packageManager = RubyPackageManager.Auto; break;
                case "bundler": config.packageManager = RubyPackageManager.Bundler; break;
                case "rubygems": case "gem": config.packageManager = RubyPackageManager.RubyGems; break;
                case "none": config.packageManager = RubyPackageManager.None; break;
                default: break;
            }
        }
        
        // Type checking
        if ("typeCheck" in json)
        {
            auto tc = json["typeCheck"];
            if ("enabled" in tc) config.typeCheck.enabled = tc["enabled"].type == JSONType.true_;
            if ("strict" in tc) config.typeCheck.strict = tc["strict"].type == JSONType.true_;
            
            if ("checker" in tc)
            {
                string checkerStr = tc["checker"].str;
                switch (checkerStr.toLower)
                {
                    case "auto": config.typeCheck.checker = RubyTypeChecker.Auto; break;
                    case "sorbet": config.typeCheck.checker = RubyTypeChecker.Sorbet; break;
                    case "rbs": config.typeCheck.checker = RubyTypeChecker.RBS; break;
                    case "steep": config.typeCheck.checker = RubyTypeChecker.Steep; break;
                    case "none": config.typeCheck.checker = RubyTypeChecker.None; break;
                    default: break;
                }
            }
            
            // Sorbet config
            if ("sorbet" in tc)
            {
                auto s = tc["sorbet"];
                if ("level" in s) config.typeCheck.sorbet.level = s["level"].str;
                if ("generateRBI" in s) config.typeCheck.sorbet.generateRBI = s["generateRBI"].type == JSONType.true_;
                if ("configFile" in s) config.typeCheck.sorbet.configFile = s["configFile"].str;
                if ("ignore" in s)
                    config.typeCheck.sorbet.ignore = s["ignore"].array.map!(e => e.str).array;
            }
            
            // RBS config
            if ("rbs" in tc)
            {
                auto r = tc["rbs"];
                if ("dir" in r) config.typeCheck.rbs.dir = r["dir"].str;
                if ("generate" in r) config.typeCheck.rbs.generate = r["generate"].type == JSONType.true_;
                if ("validate" in r) config.typeCheck.rbs.validate = r["validate"].type == JSONType.true_;
            }
            
            // Steep config
            if ("steep" in tc)
            {
                auto st = tc["steep"];
                if ("configFile" in st) config.typeCheck.steep.configFile = st["configFile"].str;
                if ("checkAll" in st) config.typeCheck.steep.checkAll = st["checkAll"].type == JSONType.true_;
            }
        }
        
        // Formatting
        if ("format" in json)
        {
            auto f = json["format"];
            if ("autoFormat" in f) config.format.autoFormat = f["autoFormat"].type == JSONType.true_;
            if ("autoCorrect" in f) config.format.autoCorrect = f["autoCorrect"].type == JSONType.true_;
            if ("configFile" in f) config.format.configFile = f["configFile"].str;
            if ("failOnWarning" in f) config.format.failOnWarning = f["failOnWarning"].type == JSONType.true_;
            if ("displayCopNames" in f) config.format.displayCopNames = f["displayCopNames"].type == JSONType.true_;
            
            if ("formatter" in f)
            {
                string fmtStr = f["formatter"].str;
                switch (fmtStr.toLower)
                {
                    case "auto": config.format.formatter = RubyFormatter.Auto; break;
                    case "rubocop": config.format.formatter = RubyFormatter.RuboCop; break;
                    case "standard": case "standardrb": config.format.formatter = RubyFormatter.Standard; break;
                    case "reek": config.format.formatter = RubyFormatter.Reek; break;
                    case "none": config.format.formatter = RubyFormatter.None; break;
                    default: break;
                }
            }
            
            // RuboCop options
            if ("rubocop" in f)
            {
                auto rc = f["rubocop"];
                if ("rails" in rc) config.format.rubocop.rails = rc["rails"].type == JSONType.true_;
                if ("displayStyleGuide" in rc) config.format.rubocop.displayStyleGuide = rc["displayStyleGuide"].type == JSONType.true_;
                if ("extraDetails" in rc) config.format.rubocop.extraDetails = rc["extraDetails"].type == JSONType.true_;
                if ("parallel" in rc) config.format.rubocop.parallel = rc["parallel"].type == JSONType.true_;
                
                if ("only" in rc)
                    config.format.rubocop.only = rc["only"].array.map!(e => e.str).array;
                if ("except" in rc)
                    config.format.rubocop.except = rc["except"].array.map!(e => e.str).array;
            }
        }
        
        // Testing
        if ("test" in json)
        {
            auto t = json["test"];
            if ("verbose" in t) config.test.verbose = t["verbose"].type == JSONType.true_;
            if ("coverage" in t) config.test.coverage = t["coverage"].type == JSONType.true_;
            if ("coverageTool" in t) config.test.coverageTool = t["coverageTool"].str;
            if ("coverageDir" in t) config.test.coverageDir = t["coverageDir"].str;
            if ("minCoverage" in t) config.test.minCoverage = cast(float)t["minCoverage"].floating;
            if ("failUnderCoverage" in t) config.test.failUnderCoverage = t["failUnderCoverage"].type == JSONType.true_;
            if ("parallel" in t) config.test.parallel = t["parallel"].type == JSONType.true_;
            if ("workers" in t) config.test.workers = cast(int)t["workers"].integer;
            
            if ("testPaths" in t)
                config.test.testPaths = t["testPaths"].array.map!(e => e.str).array;
            
            if ("framework" in t)
            {
                string fwStr = t["framework"].str;
                switch (fwStr.toLower)
                {
                    case "auto": config.test.framework = RubyTestFramework.Auto; break;
                    case "rspec": config.test.framework = RubyTestFramework.RSpec; break;
                    case "minitest": config.test.framework = RubyTestFramework.Minitest; break;
                    case "testunit": case "test::unit": config.test.framework = RubyTestFramework.TestUnit; break;
                    case "cucumber": config.test.framework = RubyTestFramework.Cucumber; break;
                    case "none": config.test.framework = RubyTestFramework.None; break;
                    default: break;
                }
            }
            
            // RSpec options
            if ("rspec" in t)
            {
                auto rs = t["rspec"];
                if ("format" in rs) config.test.rspec.format = rs["format"].str;
                if ("color" in rs) config.test.rspec.color = rs["color"].type == JSONType.true_;
                if ("profile" in rs) config.test.rspec.profile = rs["profile"].type == JSONType.true_;
                if ("profileCount" in rs) config.test.rspec.profileCount = cast(int)rs["profileCount"].integer;
                if ("failFast" in rs) config.test.rspec.failFast = rs["failFast"].type == JSONType.true_;
                if ("seed" in rs) config.test.rspec.seed = rs["seed"].str;
                if ("bisect" in rs) config.test.rspec.bisect = rs["bisect"].type == JSONType.true_;
                
                if ("tags" in rs)
                    config.test.rspec.tags = rs["tags"].array.map!(e => e.str).array;
                if ("excludeTags" in rs)
                    config.test.rspec.excludeTags = rs["excludeTags"].array.map!(e => e.str).array;
            }
        }
        
        // Rails configuration
        if ("rails" in json)
        {
            auto r = json["rails"];
            if ("environment" in r) config.rails.environment = r["environment"].str;
            if ("database" in r) config.rails.database = r["database"].str;
            if ("precompileAssets" in r) config.rails.precompileAssets = r["precompileAssets"].type == JSONType.true_;
            if ("runMigrations" in r) config.rails.runMigrations = r["runMigrations"].type == JSONType.true_;
            if ("seedDatabase" in r) config.rails.seedDatabase = r["seedDatabase"].type == JSONType.true_;
            if ("commandPrefix" in r) config.rails.commandPrefix = r["commandPrefix"].str;
        }
        
        // Gem build configuration
        if ("gemBuild" in json)
        {
            auto g = json["gemBuild"];
            if ("gemspecFile" in g) config.gemBuild.gemspecFile = g["gemspecFile"].str;
            if ("outputDir" in g) config.gemBuild.outputDir = g["outputDir"].str;
            if ("sign" in g) config.gemBuild.sign = g["sign"].type == JSONType.true_;
            if ("key" in g) config.gemBuild.key = g["key"].str;
            
            if ("platforms" in g)
                config.gemBuild.platforms = g["platforms"].array.map!(e => e.str).array;
            if ("includeFiles" in g)
                config.gemBuild.includeFiles = g["includeFiles"].array.map!(e => e.str).array;
            if ("excludeFiles" in g)
                config.gemBuild.excludeFiles = g["excludeFiles"].array.map!(e => e.str).array;
        }
        
        // Documentation
        if ("documentation" in json)
        {
            auto d = json["documentation"];
            if ("outputDir" in d) config.documentation.outputDir = d["outputDir"].str;
            
            if ("generator" in d)
            {
                string genStr = d["generator"].str;
                switch (genStr.toLower)
                {
                    case "auto": config.documentation.generator = RubyDocGenerator.Auto; break;
                    case "yard": config.documentation.generator = RubyDocGenerator.YARD; break;
                    case "rdoc": config.documentation.generator = RubyDocGenerator.RDoc; break;
                    case "both": config.documentation.generator = RubyDocGenerator.Both; break;
                    case "none": config.documentation.generator = RubyDocGenerator.None; break;
                    default: break;
                }
            }
            
            // YARD options
            if ("yard" in d)
            {
                auto y = d["yard"];
                if ("markup" in y) config.documentation.yard.markup = y["markup"].str;
                if ("private" in y) config.documentation.yard.private_ = y["private"].type == JSONType.true_;
                if ("protected" in y) config.documentation.yard.protected_ = y["protected"].type == JSONType.true_;
                if ("template" in y) config.documentation.yard.template = y["template"].str;
                
                if ("files" in y)
                    config.documentation.yard.files = y["files"].array.map!(e => e.str).array;
            }
        }
        
        // Build tool
        if ("buildTool" in json)
        {
            string btStr = json["buildTool"].str;
            switch (btStr.toLower)
            {
                case "auto": config.buildTool = RubyBuildTool.Auto; break;
                case "rake": config.buildTool = RubyBuildTool.Rake; break;
                case "gemspec": config.buildTool = RubyBuildTool.Gemspec; break;
                case "rails": config.buildTool = RubyBuildTool.Rails; break;
                case "none": config.buildTool = RubyBuildTool.None; break;
                default: break;
            }
        }
        
        // Booleans
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        if ("requireBundler" in json) config.requireBundler = json["requireBundler"].type == JSONType.true_;
        
        // Arrays
        if ("loadPath" in json)
            config.loadPath = json["loadPath"].array.map!(e => e.str).array;
        if ("rakeTasks" in json)
            config.rakeTasks = json["rakeTasks"].array.map!(e => e.str).array;
        
        // Environment
        if ("env" in json)
        {
            foreach (string key, value; json["env"].object)
            {
                config.env[key] = value.str;
            }
        }
        
        // Gems
        if ("gems" in json)
        {
            foreach (gemJson; json["gems"].array)
            {
                GemSpec gem;
                if ("name" in gemJson) gem.name = gemJson["name"].str;
                if ("version" in gemJson) gem.version_ = gemJson["version"].str;
                if ("source" in gemJson) gem.source = gemJson["source"].str;
                if ("group" in gemJson) gem.group = gemJson["group"].str;
                if ("platform" in gemJson) gem.platform = gemJson["platform"].str;
                if ("required" in gemJson) gem.required = gemJson["required"].type == JSONType.true_;
                config.gems ~= gem;
            }
        }
        
        return config;
    }
}

/// Ruby build result (extends base LanguageBuildResult)
struct RubyBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Type check warnings
    string[] typeWarnings;
    bool hadTypeErrors;
    
    /// Format/lint warnings
    string[] formatWarnings;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
    
    /// Gem build info
    string gemFile;
    string gemVersion;
}


