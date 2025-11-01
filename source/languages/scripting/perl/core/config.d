module languages.scripting.perl.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Perl build modes
enum PerlBuildMode
{
    /// Script - single file or simple script (default)
    Script,
    /// Module - Perl module/library
    Module,
    /// Application - Multi-file application
    Application,
    /// CPAN - CPAN distribution with Build.PL or Makefile.PL
    CPAN
}

/// Package manager selection
enum PerlPackageManager
{
    /// Auto-detect best available
    Auto,
    /// cpanm (cpanminus - modern, fast)
    CPANMinus,
    /// cpan (traditional CPAN client)
    CPAN,
    /// cpm (fast parallel installer)
    CPM,
    /// carton (Bundler-like dependency management)
    Carton,
    /// None - skip package management
    None
}

/// Perl formatter/linter selection
enum PerlFormatter
{
    /// Auto-detect best available
    Auto,
    /// Perl::Tidy (code formatter)
    PerlTidy,
    /// Perl::Critic (policy-based linter)
    PerlCritic,
    /// Both PerlTidy and PerlCritic
    Both,
    /// None - skip formatting/linting
    None
}

/// Test framework selection
enum PerlTestFramework
{
    /// Auto-detect from project
    Auto,
    /// Test::More (standard testing)
    TestMore,
    /// Test2 (modern testing framework)
    Test2,
    /// Test::Class (xUnit-style)
    TestClass,
    /// TAP::Harness (test harness)
    TAPHarness,
    /// prove (command-line test runner)
    Prove,
    /// None - skip tests
    None
}

/// Documentation generator selection
enum PerlDocGenerator
{
    /// Auto-detect best available
    Auto,
    /// pod2html (built-in POD to HTML)
    Pod2HTML,
    /// pod2man (built-in POD to man pages)
    Pod2Man,
    /// Pod::Simple (modern POD processor)
    PodSimple,
    /// Both HTML and man pages
    Both,
    /// None - skip documentation
    None
}

/// Build tool selection
enum PerlBuildTool
{
    /// Auto-detect from project
    Auto,
    /// Module::Build (Build.PL)
    ModuleBuild,
    /// ExtUtils::MakeMaker (Makefile.PL)
    MakeMaker,
    /// Dist::Zilla (distribution builder)
    DistZilla,
    /// Minilla (lightweight alternative to Dist::Zilla)
    Minilla,
    /// None - direct execution
    None
}

/// Perl version specification
struct PerlVersion
{
    /// Major version (e.g., 5)
    int major = 5;
    
    /// Minor version (e.g., 38)
    int minor = 38;
    
    /// Patch version (e.g., 0)
    int patch = 0;
    
    /// Specific interpreter path (overrides version)
    string interpreterPath;
    
    /// Convert to string (e.g., "5.38.0")
    string toString() const
    {
        if (patch == 0 && minor > 0)
            return major.to!string ~ "." ~ minor.to!string;
        return major.to!string ~ "." ~ minor.to!string ~ "." ~ patch.to!string;
    }
}

/// CPAN module specification
struct CPANModule
{
    string name;
    string version_;
    bool optional = false;
    string phase = "runtime"; // runtime, build, test, configure
}

/// Testing configuration
struct PerlTestConfig
{
    /// Testing framework
    PerlTestFramework framework = PerlTestFramework.Auto;
    
    /// Test directory/pattern
    string[] testPaths = ["t/"];
    
    /// Verbose output
    bool verbose = false;
    
    /// Generate coverage
    bool coverage = false;
    
    /// Coverage tool (Devel::Cover)
    string coverageTool = "cover";
    
    /// Coverage output directory
    string coverageDir = "cover_db";
    
    /// Run tests in parallel
    bool parallel = false;
    
    /// Number of parallel jobs (0 = auto)
    int jobs = 0;
    
    /// Prove-specific options
    struct ProveOptions
    {
        bool verbose = false;
        bool lib = true;           // Add 'lib' to @INC
        bool recurse = true;       // Recurse into directories
        bool timer = false;        // Show timing
        bool color = true;         // Colored output
        string[] includes;         // Additional @INC directories
        string formatter = "TAP";  // Output formatter
    }
    
    ProveOptions prove;
}

/// Formatting/Linting configuration
struct FormatConfig
{
    /// Formatter/linter to use
    PerlFormatter formatter = PerlFormatter.Auto;
    
    /// Auto-format code
    bool autoFormat = false;
    
    /// PerlTidy configuration file
    string perltidyrc = ".perltidyrc";
    
    /// PerlCritic configuration file
    string perlcriticrc = ".perlcriticrc";
    
    /// PerlCritic severity (1=brutal, 5=gentle)
    int criticSeverity = 5;
    
    /// Fail on PerlCritic violations
    bool failOnCritic = false;
    
    /// PerlCritic-specific options
    struct CriticOptions
    {
        int severity = 5;          // 1 (brutal) to 5 (gentle)
        string[] include;          // Include specific policies
        string[] exclude;          // Exclude specific policies
        string theme;              // Policy theme
        bool verbose = false;      // Verbose output
        bool color = true;         // Colored output
    }
    
    CriticOptions critic;
}

/// CPAN configuration
struct CPANConfig
{
    /// Use local::lib for user installations
    bool useLocalLib = false;
    
    /// local::lib directory
    string localLibDir;
    
    /// Mirror list
    string[] mirrors;
    
    /// Install to specific directory
    string installBase;
    
    /// Skip dependencies
    bool noDeps = false;
}

/// Documentation configuration
struct DocConfig
{
    /// Documentation generator
    PerlDocGenerator generator = PerlDocGenerator.Auto;
    
    /// Output directory
    string outputDir = "doc";
    
    /// Generate man pages
    bool generateMan = false;
    
    /// Man page section
    int manSection = 3;
}

/// Perl-specific build configuration
struct PerlConfig
{
    /// Build mode
    PerlBuildMode mode = PerlBuildMode.Script;
    
    /// Perl version requirement
    PerlVersion perlVersion;
    
    /// Package manager
    PerlPackageManager packageManager = PerlPackageManager.Auto;
    
    /// Formatting configuration
    FormatConfig format;
    
    /// Testing configuration
    PerlTestConfig test;
    
    /// CPAN configuration
    CPANConfig cpan;
    
    /// Documentation configuration
    DocConfig documentation;
    
    /// Build tool
    PerlBuildTool buildTool = PerlBuildTool.Auto;
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Module dependencies
    CPANModule[] modules;
    
    /// Include directories for @INC
    string[] includeDirs;
    
    /// Environment variables for build
    string[string] env;
    
    /// Additional Perl flags
    string[] perlFlags;
    
    /// Warnings enabled
    bool warnings = true;
    
    /// Strict mode enabled
    bool strict = true;
    
    /// Parse from JSON
    static PerlConfig fromJSON(JSONValue json)
    {
        PerlConfig config;
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower)
            {
                case "script": config.mode = PerlBuildMode.Script; break;
                case "module": config.mode = PerlBuildMode.Module; break;
                case "application": case "app": config.mode = PerlBuildMode.Application; break;
                case "cpan": config.mode = PerlBuildMode.CPAN; break;
                default: config.mode = PerlBuildMode.Script; break;
            }
        }
        
        // Perl version
        if ("perlVersion" in json)
        {
            auto v = json["perlVersion"];
            if (v.type == JSONType.string)
            {
                auto parts = v.str.split(".");
                if (parts.length >= 1) config.perlVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.perlVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.perlVersion.patch = parts[2].to!int;
            }
            else if (v.type == JSONType.object)
            {
                if ("major" in v) config.perlVersion.major = cast(int)v["major"].integer;
                if ("minor" in v) config.perlVersion.minor = cast(int)v["minor"].integer;
                if ("patch" in v) config.perlVersion.patch = cast(int)v["patch"].integer;
                if ("interpreterPath" in v) config.perlVersion.interpreterPath = v["interpreterPath"].str;
            }
        }
        
        // Package manager
        if ("packageManager" in json)
        {
            string pmStr = json["packageManager"].str;
            switch (pmStr.toLower)
            {
                case "auto": config.packageManager = PerlPackageManager.Auto; break;
                case "cpanm": case "cpanminus": config.packageManager = PerlPackageManager.CPANMinus; break;
                case "cpan": config.packageManager = PerlPackageManager.CPAN; break;
                case "cpm": config.packageManager = PerlPackageManager.CPM; break;
                case "carton": config.packageManager = PerlPackageManager.Carton; break;
                case "none": config.packageManager = PerlPackageManager.None; break;
                default: break;
            }
        }
        
        // Formatting
        if ("format" in json)
        {
            auto f = json["format"];
            if ("autoFormat" in f) config.format.autoFormat = f["autoFormat"].type == JSONType.true_;
            if ("perltidyrc" in f) config.format.perltidyrc = f["perltidyrc"].str;
            if ("perlcriticrc" in f) config.format.perlcriticrc = f["perlcriticrc"].str;
            if ("criticSeverity" in f) config.format.criticSeverity = cast(int)f["criticSeverity"].integer;
            if ("failOnCritic" in f) config.format.failOnCritic = f["failOnCritic"].type == JSONType.true_;
            
            if ("formatter" in f)
            {
                string fmtStr = f["formatter"].str;
                switch (fmtStr.toLower)
                {
                    case "auto": config.format.formatter = PerlFormatter.Auto; break;
                    case "perltidy": config.format.formatter = PerlFormatter.PerlTidy; break;
                    case "perlcritic": config.format.formatter = PerlFormatter.PerlCritic; break;
                    case "both": config.format.formatter = PerlFormatter.Both; break;
                    case "none": config.format.formatter = PerlFormatter.None; break;
                    default: break;
                }
            }
            
            // Critic options
            if ("critic" in f)
            {
                auto c = f["critic"];
                if ("severity" in c) config.format.critic.severity = cast(int)c["severity"].integer;
                if ("verbose" in c) config.format.critic.verbose = c["verbose"].type == JSONType.true_;
                if ("color" in c) config.format.critic.color = c["color"].type == JSONType.true_;
                if ("theme" in c) config.format.critic.theme = c["theme"].str;
                
                if ("include" in c)
                    config.format.critic.include = c["include"].array.map!(e => e.str).array;
                if ("exclude" in c)
                    config.format.critic.exclude = c["exclude"].array.map!(e => e.str).array;
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
            if ("parallel" in t) config.test.parallel = t["parallel"].type == JSONType.true_;
            if ("jobs" in t) config.test.jobs = cast(int)t["jobs"].integer;
            
            if ("testPaths" in t)
                config.test.testPaths = t["testPaths"].array.map!(e => e.str).array;
            
            if ("framework" in t)
            {
                string fwStr = t["framework"].str;
                switch (fwStr.toLower)
                {
                    case "auto": config.test.framework = PerlTestFramework.Auto; break;
                    case "testmore": case "test::more": config.test.framework = PerlTestFramework.TestMore; break;
                    case "test2": config.test.framework = PerlTestFramework.Test2; break;
                    case "testclass": case "test::class": config.test.framework = PerlTestFramework.TestClass; break;
                    case "tapharness": config.test.framework = PerlTestFramework.TAPHarness; break;
                    case "prove": config.test.framework = PerlTestFramework.Prove; break;
                    case "none": config.test.framework = PerlTestFramework.None; break;
                    default: break;
                }
            }
            
            // Prove options
            if ("prove" in t)
            {
                auto p = t["prove"];
                if ("verbose" in p) config.test.prove.verbose = p["verbose"].type == JSONType.true_;
                if ("lib" in p) config.test.prove.lib = p["lib"].type == JSONType.true_;
                if ("recurse" in p) config.test.prove.recurse = p["recurse"].type == JSONType.true_;
                if ("timer" in p) config.test.prove.timer = p["timer"].type == JSONType.true_;
                if ("color" in p) config.test.prove.color = p["color"].type == JSONType.true_;
                if ("formatter" in p) config.test.prove.formatter = p["formatter"].str;
                
                if ("includes" in p)
                    config.test.prove.includes = p["includes"].array.map!(e => e.str).array;
            }
        }
        
        // CPAN configuration
        if ("cpan" in json)
        {
            auto c = json["cpan"];
            if ("useLocalLib" in c) config.cpan.useLocalLib = c["useLocalLib"].type == JSONType.true_;
            if ("localLibDir" in c) config.cpan.localLibDir = c["localLibDir"].str;
            if ("installBase" in c) config.cpan.installBase = c["installBase"].str;
            if ("noDeps" in c) config.cpan.noDeps = c["noDeps"].type == JSONType.true_;
            
            if ("mirrors" in c)
                config.cpan.mirrors = c["mirrors"].array.map!(e => e.str).array;
        }
        
        // Documentation
        if ("documentation" in json)
        {
            auto d = json["documentation"];
            if ("outputDir" in d) config.documentation.outputDir = d["outputDir"].str;
            if ("generateMan" in d) config.documentation.generateMan = d["generateMan"].type == JSONType.true_;
            if ("manSection" in d) config.documentation.manSection = cast(int)d["manSection"].integer;
            
            if ("generator" in d)
            {
                string genStr = d["generator"].str;
                switch (genStr.toLower)
                {
                    case "auto": config.documentation.generator = PerlDocGenerator.Auto; break;
                    case "pod2html": config.documentation.generator = PerlDocGenerator.Pod2HTML; break;
                    case "pod2man": config.documentation.generator = PerlDocGenerator.Pod2Man; break;
                    case "podsimple": config.documentation.generator = PerlDocGenerator.PodSimple; break;
                    case "both": config.documentation.generator = PerlDocGenerator.Both; break;
                    case "none": config.documentation.generator = PerlDocGenerator.None; break;
                    default: break;
                }
            }
        }
        
        // Build tool
        if ("buildTool" in json)
        {
            string btStr = json["buildTool"].str;
            switch (btStr.toLower)
            {
                case "auto": config.buildTool = PerlBuildTool.Auto; break;
                case "modulebuild": case "build.pl": config.buildTool = PerlBuildTool.ModuleBuild; break;
                case "makemaker": case "makefile.pl": config.buildTool = PerlBuildTool.MakeMaker; break;
                case "distzilla": case "dzil": config.buildTool = PerlBuildTool.DistZilla; break;
                case "minilla": config.buildTool = PerlBuildTool.Minilla; break;
                case "none": config.buildTool = PerlBuildTool.None; break;
                default: break;
            }
        }
        
        // Booleans
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        if ("warnings" in json) config.warnings = json["warnings"].type == JSONType.true_;
        if ("strict" in json) config.strict = json["strict"].type == JSONType.true_;
        
        // Arrays
        if ("includeDirs" in json)
            config.includeDirs = json["includeDirs"].array.map!(e => e.str).array;
        if ("perlFlags" in json)
            config.perlFlags = json["perlFlags"].array.map!(e => e.str).array;
        
        // Environment
        if ("env" in json)
        {
            foreach (string key, value; json["env"].object)
            {
                config.env[key] = value.str;
            }
        }
        
        // Modules
        if ("modules" in json)
        {
            foreach (modJson; json["modules"].array)
            {
                CPANModule mod;
                if ("name" in modJson) mod.name = modJson["name"].str;
                if ("version" in modJson) mod.version_ = modJson["version"].str;
                if ("optional" in modJson) mod.optional = modJson["optional"].type == JSONType.true_;
                if ("phase" in modJson) mod.phase = modJson["phase"].str;
                config.modules ~= mod;
            }
        }
        
        return config;
    }
}

/// Perl build result
struct PerlBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Format/lint warnings
    string[] formatWarnings;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
}

