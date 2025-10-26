module languages.scripting.php.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// PHP build modes
enum PHPBuildMode
{
    /// Script - single file execution (default)
    Script,
    /// Application - multi-file with autoloading
    Application,
    /// Library - reusable package
    Library,
    /// PHAR - single executable archive
    PHAR,
    /// Package - Composer distributable
    Package,
    /// FrankenPHP - standalone binary with embedded server
    FrankenPHP
}

/// Static analyzer selection
enum PHPAnalyzer
{
    /// Auto-detect from project
    Auto,
    /// PHPStan - most popular, level-based analysis
    PHPStan,
    /// Psalm - security-focused, type inference
    Psalm,
    /// Phan - advanced inference engine
    Phan,
    /// PHP-CS-Fixer in dry-run mode
    PHPCSFixer,
    /// None - skip analysis
    None
}

/// Code formatter selection
enum PHPFormatter
{
    /// Auto-detect from project
    Auto,
    /// PHP-CS-Fixer - modern, configurable (recommended)
    PHPCSFixer,
    /// PHP_CodeSniffer - PSR standards
    PHPCS,
    /// None - skip formatting
    None
}

/// Test framework selection
enum PHPTestFramework
{
    /// Auto-detect from project
    Auto,
    /// PHPUnit - most popular unit testing
    PHPUnit,
    /// Pest - modern, elegant testing
    Pest,
    /// Codeception - full-stack testing
    Codeception,
    /// Behat - behavior-driven development
    Behat,
    /// None - skip tests
    None
}

/// PHAR packager selection
enum PHPPharTool
{
    /// Auto-detect best available
    Auto,
    /// Box - modern PHAR builder (recommended)
    Box,
    /// pharcc - compile PHP to standalone binary
    Pharcc,
    /// Native - built-in Phar class
    Native,
    /// None - skip PHAR creation
    None
}

/// PHP version specification
struct PHPVersion
{
    /// Major version (e.g., 8)
    int major = 8;
    
    /// Minor version (e.g., 3)
    int minor = 3;
    
    /// Patch version (optional)
    int patch = 0;
    
    /// Specific PHP binary path (overrides version)
    string interpreterPath;
    
    /// Convert to string (e.g., "8.3")
    string toString() const
    {
        if (patch == 0)
            return major.to!string ~ "." ~ minor.to!string;
        return major.to!string ~ "." ~ minor.to!string ~ "." ~ patch.to!string;
    }
    
    /// Check if version supports feature
    bool supportsEnums() const pure nothrow
    {
        return (major == 8 && minor >= 1) || major > 8;
    }
    
    bool supportsFibers() const pure nothrow
    {
        return (major == 8 && minor >= 1) || major > 8;
    }
    
    bool supportsReadonly() const pure nothrow
    {
        return (major == 8 && minor >= 1) || major > 8;
    }
    
    bool supportsAttributes() const pure nothrow
    {
        return major >= 8;
    }
    
    bool supportsNamedArguments() const pure nothrow
    {
        return major >= 8;
    }
    
    bool supportsUnionTypes() const pure nothrow
    {
        return major >= 8;
    }
    
    bool supportsMatchExpression() const pure nothrow
    {
        return major >= 8;
    }
}

/// Composer configuration
struct ComposerConfig
{
    /// composer.json path
    string composerJson;
    
    /// Auto-install dependencies
    bool autoInstall = false;
    
    /// Use composer dump-autoload optimization
    bool optimizeAutoloader = true;
    
    /// Generate classmap (faster but larger)
    bool classmap = false;
    
    /// APCu autoloader optimization
    bool apcu = false;
    
    /// Authoritative classmap (no filesystem checks)
    bool authoritative = false;
    
    /// Use composer install with --no-dev
    bool noDev = false;
    
    /// Prefer dist over source
    bool preferDist = true;
    
    /// Composer binary path
    string composerPath = "composer";
}

/// Static analysis configuration
struct AnalysisConfig
{
    /// Enable static analysis
    bool enabled = false;
    
    /// Analyzer to use
    PHPAnalyzer analyzer = PHPAnalyzer.Auto;
    
    /// Analysis level (PHPStan: 0-9, Psalm: 1-8)
    int level = 5;
    
    /// Configuration file path
    string configFile;
    
    /// Treat warnings as errors
    bool strict = false;
    
    /// Ignore error patterns
    string[] ignoreErrors;
    
    /// Paths to analyze (if empty, uses sources)
    string[] paths;
    
    /// Use baseline file (ignore existing errors)
    string baseline;
    
    /// Generate baseline on first run
    bool generateBaseline = false;
    
    /// Memory limit for analysis
    string memoryLimit = "1G";
}

/// Code formatting configuration
struct FormatterConfig
{
    /// Enable auto-formatting
    bool enabled = false;
    
    /// Formatter to use
    PHPFormatter formatter = PHPFormatter.Auto;
    
    /// Configuration file path
    string configFile;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// PSR standard to follow (PSR-1, PSR-2, PSR-12)
    string psrStandard = "PSR-12";
    
    /// Custom rules
    string[] rules;
    
    /// Dry run (show changes without applying)
    bool dryRun = false;
}

/// Testing configuration
struct TestConfig
{
    /// Test framework
    PHPTestFramework framework = PHPTestFramework.Auto;
    
    /// Test directory/files
    string[] testPaths;
    
    /// PHPUnit configuration file
    string configFile;
    
    /// Generate code coverage
    bool coverage = false;
    
    /// Coverage format (html, clover, xml, text)
    string coverageFormat = "html";
    
    /// Coverage output directory
    string coverageDir = "coverage";
    
    /// Minimum coverage percentage
    float minCoverage = 0.0;
    
    /// Fail if below minimum coverage
    bool failUnderCoverage = false;
    
    /// Test groups to run
    string[] groups;
    
    /// Test groups to exclude
    string[] excludeGroups;
    
    /// Stop on first failure
    bool stopOnFailure = false;
    
    /// Verbose output
    bool verbose = false;
}

/// PHAR packaging configuration
struct PHARConfig
{
    /// PHAR packager tool
    PHPPharTool tool = PHPPharTool.Auto;
    
    /// Output PHAR filename
    string outputFile;
    
    /// Entry point (main script)
    string entryPoint;
    
    /// Stub file (bootstrap script)
    string stub;
    
    /// Compression (none, gz, bz2)
    string compression = "gz";
    
    /// Sign PHAR (openssl, sha256, sha512)
    string signature = "sha256";
    
    /// Private key for OpenSSL signing
    string privateKey;
    
    /// Include dev dependencies
    bool includeDev = false;
    
    /// Directories to include
    string[] directories;
    
    /// Files to include
    string[] files;
    
    /// Patterns to exclude
    string[] exclude;
    
    /// Box configuration file
    string boxConfig;
    
    /// Optimize for size
    bool optimize = true;
    
    /// Strip whitespace
    bool strip = true;
}

/// FrankenPHP configuration
struct FrankenPHPConfig
{
    /// Enable FrankenPHP standalone binary
    bool enabled = false;
    
    /// FrankenPHP binary path
    string binaryPath = "frankenphp";
    
    /// Embed PHP files into binary
    bool embed = true;
    
    /// Worker mode (preload application)
    bool worker = false;
    
    /// Number of workers
    int workers = 4;
    
    /// Document root for embedded server
    string docRoot = "public";
    
    /// Server configuration
    string[] serverArgs;
}

/// Opcache configuration
struct OpcacheConfig
{
    /// Enable opcache optimization
    bool enabled = false;
    
    /// Preload script
    string preloadScript;
    
    /// Memory consumption (MB)
    int memory = 128;
    
    /// Max accelerated files
    int maxFiles = 10000;
    
    /// Validate timestamps
    bool validateTimestamps = true;
    
    /// Revalidation frequency (seconds)
    int revalidateFreq = 2;
}

/// PHP-specific build configuration
struct PHPConfig
{
    /// Build mode
    PHPBuildMode mode = PHPBuildMode.Script;
    
    /// PHP version requirement
    PHPVersion phpVersion;
    
    /// Composer configuration
    ComposerConfig composer;
    
    /// Static analysis configuration
    AnalysisConfig analysis;
    
    /// Code formatting configuration
    FormatterConfig formatter;
    
    /// Testing configuration
    TestConfig test;
    
    /// PHAR packaging configuration
    PHARConfig phar;
    
    /// FrankenPHP configuration
    FrankenPHPConfig frankenphp;
    
    /// Opcache configuration
    OpcacheConfig opcache;
    
    /// Enable strict types
    bool strictTypes = false;
    
    /// Validate PSR-4 autoloading
    bool validateAutoload = true;
    
    /// Check namespace consistency
    bool validateNamespaces = true;
    
    /// Optimize class loading
    bool optimizeClassLoading = false;
    
    /// INI settings for build/test
    string[string] iniSettings;
    
    /// Environment variables
    string[string] env;
    
    /// Additional PHP flags
    string[] phpFlags;
    
    /// Include path additions
    string[] includePaths;
    
    /// Parse from JSON
    static PHPConfig fromJSON(JSONValue json)
    {
        PHPConfig config;
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower)
            {
                case "script": config.mode = PHPBuildMode.Script; break;
                case "application": config.mode = PHPBuildMode.Application; break;
                case "library": config.mode = PHPBuildMode.Library; break;
                case "phar": config.mode = PHPBuildMode.PHAR; break;
                case "package": config.mode = PHPBuildMode.Package; break;
                case "frankenphp": config.mode = PHPBuildMode.FrankenPHP; break;
                default: config.mode = PHPBuildMode.Script; break;
            }
        }
        
        // PHP version
        if ("phpVersion" in json)
        {
            auto v = json["phpVersion"];
            if (v.type == JSONType.string)
            {
                auto parts = v.str.split(".");
                if (parts.length >= 1) config.phpVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.phpVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.phpVersion.patch = parts[2].to!int;
            }
            else if (v.type == JSONType.object)
            {
                if ("major" in v) config.phpVersion.major = cast(int)v["major"].integer;
                if ("minor" in v) config.phpVersion.minor = cast(int)v["minor"].integer;
                if ("patch" in v) config.phpVersion.patch = cast(int)v["patch"].integer;
                if ("interpreterPath" in v) config.phpVersion.interpreterPath = v["interpreterPath"].str;
            }
        }
        
        // Composer
        if ("composer" in json)
        {
            auto c = json["composer"];
            if ("composerJson" in c) config.composer.composerJson = c["composerJson"].str;
            if ("autoInstall" in c) config.composer.autoInstall = c["autoInstall"].type == JSONType.true_;
            if ("optimizeAutoloader" in c) config.composer.optimizeAutoloader = c["optimizeAutoloader"].type == JSONType.true_;
            if ("classmap" in c) config.composer.classmap = c["classmap"].type == JSONType.true_;
            if ("apcu" in c) config.composer.apcu = c["apcu"].type == JSONType.true_;
            if ("authoritative" in c) config.composer.authoritative = c["authoritative"].type == JSONType.true_;
            if ("noDev" in c) config.composer.noDev = c["noDev"].type == JSONType.true_;
            if ("preferDist" in c) config.composer.preferDist = c["preferDist"].type == JSONType.true_;
            if ("composerPath" in c) config.composer.composerPath = c["composerPath"].str;
        }
        
        // Analysis
        if ("analysis" in json)
        {
            auto a = json["analysis"];
            if ("enabled" in a) config.analysis.enabled = a["enabled"].type == JSONType.true_;
            if ("level" in a) config.analysis.level = cast(int)a["level"].integer;
            if ("configFile" in a) config.analysis.configFile = a["configFile"].str;
            if ("strict" in a) config.analysis.strict = a["strict"].type == JSONType.true_;
            if ("baseline" in a) config.analysis.baseline = a["baseline"].str;
            if ("generateBaseline" in a) config.analysis.generateBaseline = a["generateBaseline"].type == JSONType.true_;
            if ("memoryLimit" in a) config.analysis.memoryLimit = a["memoryLimit"].str;
            
            if ("analyzer" in a)
            {
                string analyzerStr = a["analyzer"].str;
                switch (analyzerStr.toLower)
                {
                    case "auto": config.analysis.analyzer = PHPAnalyzer.Auto; break;
                    case "phpstan": config.analysis.analyzer = PHPAnalyzer.PHPStan; break;
                    case "psalm": config.analysis.analyzer = PHPAnalyzer.Psalm; break;
                    case "phan": config.analysis.analyzer = PHPAnalyzer.Phan; break;
                    case "php-cs-fixer": config.analysis.analyzer = PHPAnalyzer.PHPCSFixer; break;
                    case "none": config.analysis.analyzer = PHPAnalyzer.None; break;
                    default: break;
                }
            }
            
            if ("ignoreErrors" in a)
                config.analysis.ignoreErrors = a["ignoreErrors"].array.map!(e => e.str).array;
            if ("paths" in a)
                config.analysis.paths = a["paths"].array.map!(e => e.str).array;
        }
        
        // Formatter
        if ("formatter" in json)
        {
            auto f = json["formatter"];
            if ("enabled" in f) config.formatter.enabled = f["enabled"].type == JSONType.true_;
            if ("configFile" in f) config.formatter.configFile = f["configFile"].str;
            if ("checkOnly" in f) config.formatter.checkOnly = f["checkOnly"].type == JSONType.true_;
            if ("psrStandard" in f) config.formatter.psrStandard = f["psrStandard"].str;
            if ("dryRun" in f) config.formatter.dryRun = f["dryRun"].type == JSONType.true_;
            
            if ("formatter" in f)
            {
                string fmtStr = f["formatter"].str;
                switch (fmtStr.toLower)
                {
                    case "auto": config.formatter.formatter = PHPFormatter.Auto; break;
                    case "php-cs-fixer": config.formatter.formatter = PHPFormatter.PHPCSFixer; break;
                    case "phpcs": config.formatter.formatter = PHPFormatter.PHPCS; break;
                    case "none": config.formatter.formatter = PHPFormatter.None; break;
                    default: break;
                }
            }
            
            if ("rules" in f)
                config.formatter.rules = f["rules"].array.map!(e => e.str).array;
        }
        
        // Testing
        if ("test" in json)
        {
            auto t = json["test"];
            if ("configFile" in t) config.test.configFile = t["configFile"].str;
            if ("coverage" in t) config.test.coverage = t["coverage"].type == JSONType.true_;
            if ("coverageFormat" in t) config.test.coverageFormat = t["coverageFormat"].str;
            if ("coverageDir" in t) config.test.coverageDir = t["coverageDir"].str;
            if ("minCoverage" in t) config.test.minCoverage = cast(float)t["minCoverage"].floating;
            if ("failUnderCoverage" in t) config.test.failUnderCoverage = t["failUnderCoverage"].type == JSONType.true_;
            if ("stopOnFailure" in t) config.test.stopOnFailure = t["stopOnFailure"].type == JSONType.true_;
            if ("verbose" in t) config.test.verbose = t["verbose"].type == JSONType.true_;
            
            if ("framework" in t)
            {
                string fwStr = t["framework"].str;
                switch (fwStr.toLower)
                {
                    case "auto": config.test.framework = PHPTestFramework.Auto; break;
                    case "phpunit": config.test.framework = PHPTestFramework.PHPUnit; break;
                    case "pest": config.test.framework = PHPTestFramework.Pest; break;
                    case "codeception": config.test.framework = PHPTestFramework.Codeception; break;
                    case "behat": config.test.framework = PHPTestFramework.Behat; break;
                    case "none": config.test.framework = PHPTestFramework.None; break;
                    default: break;
                }
            }
            
            if ("testPaths" in t)
                config.test.testPaths = t["testPaths"].array.map!(e => e.str).array;
            if ("groups" in t)
                config.test.groups = t["groups"].array.map!(e => e.str).array;
            if ("excludeGroups" in t)
                config.test.excludeGroups = t["excludeGroups"].array.map!(e => e.str).array;
        }
        
        // PHAR
        if ("phar" in json)
        {
            auto p = json["phar"];
            if ("outputFile" in p) config.phar.outputFile = p["outputFile"].str;
            if ("entryPoint" in p) config.phar.entryPoint = p["entryPoint"].str;
            if ("stub" in p) config.phar.stub = p["stub"].str;
            if ("compression" in p) config.phar.compression = p["compression"].str;
            if ("signature" in p) config.phar.signature = p["signature"].str;
            if ("privateKey" in p) config.phar.privateKey = p["privateKey"].str;
            if ("includeDev" in p) config.phar.includeDev = p["includeDev"].type == JSONType.true_;
            if ("boxConfig" in p) config.phar.boxConfig = p["boxConfig"].str;
            if ("optimize" in p) config.phar.optimize = p["optimize"].type == JSONType.true_;
            if ("strip" in p) config.phar.strip = p["strip"].type == JSONType.true_;
            
            if ("tool" in p)
            {
                string toolStr = p["tool"].str;
                switch (toolStr.toLower)
                {
                    case "auto": config.phar.tool = PHPPharTool.Auto; break;
                    case "box": config.phar.tool = PHPPharTool.Box; break;
                    case "pharcc": config.phar.tool = PHPPharTool.Pharcc; break;
                    case "native": config.phar.tool = PHPPharTool.Native; break;
                    case "none": config.phar.tool = PHPPharTool.None; break;
                    default: break;
                }
            }
            
            if ("directories" in p)
                config.phar.directories = p["directories"].array.map!(e => e.str).array;
            if ("files" in p)
                config.phar.files = p["files"].array.map!(e => e.str).array;
            if ("exclude" in p)
                config.phar.exclude = p["exclude"].array.map!(e => e.str).array;
        }
        
        // FrankenPHP
        if ("frankenphp" in json)
        {
            auto fp = json["frankenphp"];
            if ("enabled" in fp) config.frankenphp.enabled = fp["enabled"].type == JSONType.true_;
            if ("binaryPath" in fp) config.frankenphp.binaryPath = fp["binaryPath"].str;
            if ("embed" in fp) config.frankenphp.embed = fp["embed"].type == JSONType.true_;
            if ("worker" in fp) config.frankenphp.worker = fp["worker"].type == JSONType.true_;
            if ("workers" in fp) config.frankenphp.workers = cast(int)fp["workers"].integer;
            if ("docRoot" in fp) config.frankenphp.docRoot = fp["docRoot"].str;
            
            if ("serverArgs" in fp)
                config.frankenphp.serverArgs = fp["serverArgs"].array.map!(e => e.str).array;
        }
        
        // Opcache
        if ("opcache" in json)
        {
            auto o = json["opcache"];
            if ("enabled" in o) config.opcache.enabled = o["enabled"].type == JSONType.true_;
            if ("preloadScript" in o) config.opcache.preloadScript = o["preloadScript"].str;
            if ("memory" in o) config.opcache.memory = cast(int)o["memory"].integer;
            if ("maxFiles" in o) config.opcache.maxFiles = cast(int)o["maxFiles"].integer;
            if ("validateTimestamps" in o) config.opcache.validateTimestamps = o["validateTimestamps"].type == JSONType.true_;
            if ("revalidateFreq" in o) config.opcache.revalidateFreq = cast(int)o["revalidateFreq"].integer;
        }
        
        // Booleans
        if ("strictTypes" in json) config.strictTypes = json["strictTypes"].type == JSONType.true_;
        if ("validateAutoload" in json) config.validateAutoload = json["validateAutoload"].type == JSONType.true_;
        if ("validateNamespaces" in json) config.validateNamespaces = json["validateNamespaces"].type == JSONType.true_;
        if ("optimizeClassLoading" in json) config.optimizeClassLoading = json["optimizeClassLoading"].type == JSONType.true_;
        
        // Arrays
        if ("phpFlags" in json)
            config.phpFlags = json["phpFlags"].array.map!(e => e.str).array;
        if ("includePaths" in json)
            config.includePaths = json["includePaths"].array.map!(e => e.str).array;
        
        // Maps
        if ("iniSettings" in json)
        {
            foreach (string key, value; json["iniSettings"].object)
            {
                config.iniSettings[key] = value.str;
            }
        }
        
        if ("env" in json)
        {
            foreach (string key, value; json["env"].object)
            {
                config.env[key] = value.str;
            }
        }
        
        return config;
    }
}

/// PHP build result
struct PHPBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Analysis warnings
    string[] analysisWarnings;
    bool hadAnalysisErrors;
    
    /// Format issues
    string[] formatIssues;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
}

