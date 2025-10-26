module languages.scripting.lua.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Lua build modes
enum LuaBuildMode
{
    /// Script - interpreted execution (default)
    Script,
    /// Bytecode - compiled with luac
    Bytecode,
    /// Library - reusable module/rock
    Library,
    /// Rock - LuaRocks package
    Rock,
    /// Application - multi-file with dependencies
    Application
}

/// Lua runtime/interpreter selection
enum LuaRuntime
{
    /// Auto-detect best available
    Auto,
    /// Standard Lua 5.1
    Lua51,
    /// Standard Lua 5.2
    Lua52,
    /// Standard Lua 5.3
    Lua53,
    /// Standard Lua 5.4 (latest)
    Lua54,
    /// LuaJIT (JIT-compiled, fastest)
    LuaJIT,
    /// System default Lua
    System
}

/// Code formatter selection
enum LuaFormatter
{
    /// Auto-detect best available
    Auto,
    /// StyLua - modern, opinionated formatter (recommended)
    StyLua,
    /// lua-format - configurable formatter
    LuaFormat,
    /// None - skip formatting
    None
}

/// Linter selection  
enum LuaLinter
{
    /// Auto-detect best available
    Auto,
    /// Luacheck - comprehensive static analyzer (recommended)
    Luacheck,
    /// luacheck with LuaJIT extensions
    LuacheckJIT,
    /// Selene - modern static analyzer
    Selene,
    /// None - skip linting
    None
}

/// Test framework selection
enum LuaTestFramework
{
    /// Auto-detect from project
    Auto,
    /// Busted - elegant BDD-style testing (recommended)
    Busted,
    /// LuaUnit - xUnit-style testing
    LuaUnit,
    /// Telescope - flexible test framework
    Telescope,
    /// lua-TestMore - TAP-based testing
    TestMore,
    /// None - skip tests
    None
}

/// Package manager selection
enum LuaPackageManager
{
    /// Auto-detect from project
    Auto,
    /// LuaRocks - standard Lua package manager
    LuaRocks,
    /// None - manual dependency management
    None
}

/// Bytecode optimization level
enum BytecodeOptLevel
{
    /// No optimization (faster compilation, debug info)
    None,
    /// Basic optimization (balanced)
    Basic,
    /// Full optimization (smaller, faster)
    Full
}

/// Lua version specification
struct LuaVersion
{
    /// Major version (e.g., 5)
    int major = 5;
    
    /// Minor version (e.g., 4)
    int minor = 4;
    
    /// Patch version (optional)
    int patch = 0;
    
    /// Specific interpreter path (overrides version)
    string interpreterPath;
    
    /// Convert to string (e.g., "5.4")
    string toString() const
    {
        if (patch == 0)
            return major.to!string ~ "." ~ minor.to!string;
        return major.to!string ~ "." ~ minor.to!string ~ "." ~ patch.to!string;
    }
    
    /// Check version compatibility
    bool supports51() const pure nothrow
    {
        return major == 5 && minor >= 1;
    }
    
    bool supports52() const pure nothrow
    {
        return major == 5 && minor >= 2;
    }
    
    bool supports53() const pure nothrow
    {
        return major == 5 && minor >= 3;
    }
    
    bool supports54() const pure nothrow
    {
        return major == 5 && minor >= 4;
    }
    
    /// Check if bitwise operators are supported
    bool supportsBitwise() const pure nothrow
    {
        return supports53(); // Lua 5.3+ has native bitwise ops
    }
    
    /// Check if goto/labels are supported
    bool supportsGoto() const pure nothrow
    {
        return supports52(); // Lua 5.2+ has goto
    }
    
    /// Check if integer type is supported
    bool supportsIntegers() const pure nothrow
    {
        return supports53(); // Lua 5.3+ has integer subtype
    }
}

/// LuaRocks configuration
struct LuaRocksConfig
{
    /// Enable LuaRocks
    bool enabled = false;
    
    /// rockspec file path
    string rockspecFile;
    
    /// Install dependencies automatically
    bool autoInstall = false;
    
    /// LuaRocks tree (local install directory)
    string tree;
    
    /// Use --local flag (install to user directory)
    bool local = true;
    
    /// Use --tree flag for custom tree
    bool customTree = false;
    
    /// Server URL
    string server = "https://luarocks.org";
    
    /// Additional servers
    string[] additionalServers;
    
    /// Force reinstall
    bool forceInstall = false;
    
    /// Only dependencies (don't build/install main package)
    bool onlyDeps = true;
    
    /// Dependencies to install
    string[] dependencies;
    
    /// Dev dependencies (only for development)
    string[] devDependencies;
}

/// Bytecode compilation configuration
struct BytecodeConfig
{
    /// Enable bytecode compilation
    bool compile = false;
    
    /// Optimization level
    BytecodeOptLevel optLevel = BytecodeOptLevel.Basic;
    
    /// Strip debug information
    bool stripDebug = false;
    
    /// Output bytecode file
    string outputFile;
    
    /// List dependencies in bytecode
    bool listDeps = false;
    
    /// Include source as comments
    bool includeSource = false;
}

/// LuaJIT configuration
struct LuaJITConfig
{
    /// Use LuaJIT instead of standard Lua
    bool enabled = false;
    
    /// LuaJIT binary path
    string jitPath = "luajit";
    
    /// JIT compiler options
    string[] jitOptions;
    
    /// Enable FFI (Foreign Function Interface)
    bool enableFFI = true;
    
    /// Optimization level (0-3)
    int optLevel = 3;
    
    /// Generate bytecode with LuaJIT
    bool bytecode = false;
    
    /// Use -b flag for bytecode generation
    string[] bytecodeFlags;
}

/// Testing configuration
struct LuaTestConfig
{
    /// Test framework
    LuaTestFramework framework = LuaTestFramework.Auto;
    
    /// Test directory/files
    string[] testPaths;
    
    /// Test pattern for discovery
    string pattern = "*_test.lua";
    
    /// Verbose output
    bool verbose = false;
    
    /// Generate coverage
    bool coverage = false;
    
    /// Coverage tool (luacov)
    string coverageTool = "luacov";
    
    /// Coverage output file
    string coverageFile = "luacov.stats.out";
    
    /// Minimum coverage percentage
    float minCoverage = 0.0;
    
    /// Fail if below minimum coverage
    bool failUnderCoverage = false;
    
    /// Output format (tap, junit, default)
    string outputFormat;
    
    /// Busted-specific options
    struct BustedOptions
    {
        /// Tags to include
        string[] tags;
        
        /// Tags to exclude
        string[] excludeTags;
        
        /// Shuffle test order
        bool shuffle = false;
        
        /// Random seed
        int seed = 0;
        
        /// Stop on first failure
        bool failFast = false;
        
        /// Output format (default, TAP, junit, etc.)
        string format = "default";
        
        /// Lazy loading
        bool lazyLoad = false;
    }
    
    BustedOptions busted;
    
    /// LuaUnit-specific options
    struct LuaUnitOptions
    {
        /// Output format (text, tap, junit, nil)
        string output = "text";
        
        /// Verbose level (0-3)
        int verbosity = 1;
        
        /// Quiet mode
        bool quiet = false;
        
        /// XML output file (for junit)
        string xmlOutput;
    }
    
    LuaUnitOptions luaunit;
}

/// Linting/checking configuration
struct LintConfig
{
    /// Enable linting
    bool enabled = false;
    
    /// Linter to use
    LuaLinter linter = LuaLinter.Auto;
    
    /// Configuration file path
    string configFile; // .luacheckrc, selene.toml, etc.
    
    /// Fail on warnings
    bool failOnWarning = false;
    
    /// Luacheck-specific options
    struct LuacheckOptions
    {
        /// Standard library globals
        string std = "lua54"; // lua51, lua52, lua53, lua54, luajit, ngx_lua, love, busted
        
        /// Global variables to allow
        string[] globals;
        
        /// Read-only globals
        string[] readGlobals;
        
        /// Exclude specific warnings/codes
        string[] ignore;
        
        /// Only check specific warnings/codes
        string[] only;
        
        /// Max line length
        int maxLineLength = 120;
        
        /// Max cyclomatic complexity
        int maxComplexity = 0; // 0 = no limit
        
        /// Enable specific warnings
        bool warnUnusedArgs = true;
        bool warnUnusedVars = true;
        bool warnShadowing = false;
        bool warnGlobals = true;
    }
    
    LuacheckOptions luacheck;
    
    /// Selene-specific options
    struct SeleneOptions
    {
        /// Standard library
        string std = "lua54";
        
        /// Display style
        string displayStyle = "rich"; // rich, quiet, json
    }
    
    SeleneOptions selene;
}

/// Formatting configuration
struct FormatConfig
{
    /// Formatter to use
    LuaFormatter formatter = LuaFormatter.Auto;
    
    /// Auto-format code
    bool autoFormat = false;
    
    /// Configuration file path
    string configFile; // stylua.toml, .lua-format, etc.
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// StyLua-specific options
    struct StyLuaOptions
    {
        /// Column width
        int columnWidth = 120;
        
        /// Line endings (Unix, Windows, Auto)
        string lineEndings = "Unix";
        
        /// Indent type (Tabs, Spaces)
        string indentType = "Spaces";
        
        /// Indent width (if using spaces)
        int indentWidth = 4;
        
        /// Quote style (AutoPreferDouble, AutoPreferSingle, ForceDouble, ForceSingle)
        string quoteStyle = "AutoPreferDouble";
        
        /// Call parentheses (Always, NoSingleString, NoSingleTable, None)
        string callParentheses = "Always";
    }
    
    StyLuaOptions stylua;
}

/// Module/package configuration
struct ModuleConfig
{
    /// Module name
    string name;
    
    /// Module version
    string version_;
    
    /// Entry point file
    string entryPoint;
    
    /// Package path additions
    string[] packagePath;
    
    /// C package path additions
    string[] cPackagePath;
    
    /// Module dependencies
    string[] requires;
    
    /// External C libraries
    string[] externalLibs;
}

/// C module build configuration (for rocks with C code)
struct CModuleConfig
{
    /// Enable C module building
    bool enabled = false;
    
    /// C source files
    string[] sources;
    
    /// Include directories
    string[] includes;
    
    /// Libraries to link
    string[] libraries;
    
    /// Library directories
    string[] libDirs;
    
    /// C compiler flags
    string[] cflags;
    
    /// Linker flags
    string[] ldflags;
    
    /// C compiler to use
    string compiler = "gcc";
    
    /// Build as shared library
    bool isShared = true;
}

/// Lua-specific build configuration
struct LuaConfig
{
    /// Build mode
    LuaBuildMode mode = LuaBuildMode.Script;
    
    /// Lua runtime/version
    LuaRuntime runtime = LuaRuntime.Auto;
    
    /// Lua version requirement
    LuaVersion luaVersion;
    
    /// Package manager
    LuaPackageManager packageManager = LuaPackageManager.Auto;
    
    /// LuaRocks configuration
    LuaRocksConfig luarocks;
    
    /// Bytecode configuration
    BytecodeConfig bytecode;
    
    /// LuaJIT configuration
    LuaJITConfig luajit;
    
    /// Testing configuration
    LuaTestConfig test;
    
    /// Linting configuration
    LintConfig lint;
    
    /// Formatting configuration
    FormatConfig format;
    
    /// Module configuration
    ModuleConfig moduleConfig;
    
    /// C module configuration (for rocks with C code)
    CModuleConfig cmodule;
    
    /// Entry point file (main script)
    string entryPoint;
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Lua flags (passed to lua interpreter)
    string[] luaFlags;
    
    /// Environment variables for build/run
    string[string] env;
    
    /// Wrapper script options
    struct WrapperOptions
    {
        /// Create executable wrapper script
        bool create = true;
        
        /// Shebang line
        string shebang = "#!/usr/bin/env lua";
        
        /// Additional setup code
        string[] setupCode;
    }
    
    WrapperOptions wrapper;
    
    /// Parse from JSON
    static LuaConfig fromJSON(JSONValue json)
    {
        LuaConfig config;
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr.toLower)
            {
                case "script": config.mode = LuaBuildMode.Script; break;
                case "bytecode": config.mode = LuaBuildMode.Bytecode; break;
                case "library": config.mode = LuaBuildMode.Library; break;
                case "rock": config.mode = LuaBuildMode.Rock; break;
                case "application": config.mode = LuaBuildMode.Application; break;
                default: config.mode = LuaBuildMode.Script; break;
            }
        }
        
        // Runtime
        if ("runtime" in json)
        {
            string rtStr = json["runtime"].str;
            switch (rtStr.toLower)
            {
                case "auto": config.runtime = LuaRuntime.Auto; break;
                case "lua51": case "5.1": config.runtime = LuaRuntime.Lua51; break;
                case "lua52": case "5.2": config.runtime = LuaRuntime.Lua52; break;
                case "lua53": case "5.3": config.runtime = LuaRuntime.Lua53; break;
                case "lua54": case "5.4": config.runtime = LuaRuntime.Lua54; break;
                case "luajit": config.runtime = LuaRuntime.LuaJIT; break;
                case "system": config.runtime = LuaRuntime.System; break;
                default: config.runtime = LuaRuntime.Auto; break;
            }
        }
        
        // Lua version
        if ("luaVersion" in json)
        {
            auto v = json["luaVersion"];
            if (v.type == JSONType.string)
            {
                auto parts = v.str.split(".");
                if (parts.length >= 1) config.luaVersion.major = parts[0].to!int;
                if (parts.length >= 2) config.luaVersion.minor = parts[1].to!int;
                if (parts.length >= 3) config.luaVersion.patch = parts[2].to!int;
            }
            else if (v.type == JSONType.object)
            {
                if ("major" in v) config.luaVersion.major = cast(int)v["major"].integer;
                if ("minor" in v) config.luaVersion.minor = cast(int)v["minor"].integer;
                if ("patch" in v) config.luaVersion.patch = cast(int)v["patch"].integer;
                if ("interpreterPath" in v) config.luaVersion.interpreterPath = v["interpreterPath"].str;
            }
        }
        
        // Package manager
        if ("packageManager" in json)
        {
            string pmStr = json["packageManager"].str;
            switch (pmStr.toLower)
            {
                case "auto": config.packageManager = LuaPackageManager.Auto; break;
                case "luarocks": config.packageManager = LuaPackageManager.LuaRocks; break;
                case "none": config.packageManager = LuaPackageManager.None; break;
                default: break;
            }
        }
        
        // LuaRocks configuration
        if ("luarocks" in json)
        {
            auto lr = json["luarocks"];
            if ("enabled" in lr) config.luarocks.enabled = lr["enabled"].type == JSONType.true_;
            if ("rockspecFile" in lr) config.luarocks.rockspecFile = lr["rockspecFile"].str;
            if ("autoInstall" in lr) config.luarocks.autoInstall = lr["autoInstall"].type == JSONType.true_;
            if ("tree" in lr) config.luarocks.tree = lr["tree"].str;
            if ("local" in lr) config.luarocks.local = lr["local"].type == JSONType.true_;
            if ("customTree" in lr) config.luarocks.customTree = lr["customTree"].type == JSONType.true_;
            if ("server" in lr) config.luarocks.server = lr["server"].str;
            if ("forceInstall" in lr) config.luarocks.forceInstall = lr["forceInstall"].type == JSONType.true_;
            if ("onlyDeps" in lr) config.luarocks.onlyDeps = lr["onlyDeps"].type == JSONType.true_;
            
            if ("additionalServers" in lr)
                config.luarocks.additionalServers = lr["additionalServers"].array.map!(e => e.str).array;
            if ("dependencies" in lr)
                config.luarocks.dependencies = lr["dependencies"].array.map!(e => e.str).array;
            if ("devDependencies" in lr)
                config.luarocks.devDependencies = lr["devDependencies"].array.map!(e => e.str).array;
        }
        
        // Bytecode configuration
        if ("bytecode" in json)
        {
            auto bc = json["bytecode"];
            if ("compile" in bc) config.bytecode.compile = bc["compile"].type == JSONType.true_;
            if ("stripDebug" in bc) config.bytecode.stripDebug = bc["stripDebug"].type == JSONType.true_;
            if ("outputFile" in bc) config.bytecode.outputFile = bc["outputFile"].str;
            if ("listDeps" in bc) config.bytecode.listDeps = bc["listDeps"].type == JSONType.true_;
            if ("includeSource" in bc) config.bytecode.includeSource = bc["includeSource"].type == JSONType.true_;
            
            if ("optLevel" in bc)
            {
                string optStr = bc["optLevel"].str;
                switch (optStr.toLower)
                {
                    case "none": config.bytecode.optLevel = BytecodeOptLevel.None; break;
                    case "basic": config.bytecode.optLevel = BytecodeOptLevel.Basic; break;
                    case "full": config.bytecode.optLevel = BytecodeOptLevel.Full; break;
                    default: break;
                }
            }
        }
        
        // LuaJIT configuration
        if ("luajit" in json)
        {
            auto lj = json["luajit"];
            if ("enabled" in lj) config.luajit.enabled = lj["enabled"].type == JSONType.true_;
            if ("jitPath" in lj) config.luajit.jitPath = lj["jitPath"].str;
            if ("enableFFI" in lj) config.luajit.enableFFI = lj["enableFFI"].type == JSONType.true_;
            if ("optLevel" in lj) config.luajit.optLevel = cast(int)lj["optLevel"].integer;
            if ("bytecode" in lj) config.luajit.bytecode = lj["bytecode"].type == JSONType.true_;
            
            if ("jitOptions" in lj)
                config.luajit.jitOptions = lj["jitOptions"].array.map!(e => e.str).array;
            if ("bytecodeFlags" in lj)
                config.luajit.bytecodeFlags = lj["bytecodeFlags"].array.map!(e => e.str).array;
        }
        
        // Testing configuration
        if ("test" in json)
        {
            auto t = json["test"];
            if ("verbose" in t) config.test.verbose = t["verbose"].type == JSONType.true_;
            if ("coverage" in t) config.test.coverage = t["coverage"].type == JSONType.true_;
            if ("coverageTool" in t) config.test.coverageTool = t["coverageTool"].str;
            if ("coverageFile" in t) config.test.coverageFile = t["coverageFile"].str;
            if ("minCoverage" in t) config.test.minCoverage = cast(float)t["minCoverage"].floating;
            if ("failUnderCoverage" in t) config.test.failUnderCoverage = t["failUnderCoverage"].type == JSONType.true_;
            if ("pattern" in t) config.test.pattern = t["pattern"].str;
            if ("outputFormat" in t) config.test.outputFormat = t["outputFormat"].str;
            
            if ("framework" in t)
            {
                string fwStr = t["framework"].str;
                switch (fwStr.toLower)
                {
                    case "auto": config.test.framework = LuaTestFramework.Auto; break;
                    case "busted": config.test.framework = LuaTestFramework.Busted; break;
                    case "luaunit": config.test.framework = LuaTestFramework.LuaUnit; break;
                    case "telescope": config.test.framework = LuaTestFramework.Telescope; break;
                    case "testmore": config.test.framework = LuaTestFramework.TestMore; break;
                    case "none": config.test.framework = LuaTestFramework.None; break;
                    default: break;
                }
            }
            
            if ("testPaths" in t)
                config.test.testPaths = t["testPaths"].array.map!(e => e.str).array;
            
            // Busted options
            if ("busted" in t)
            {
                auto b = t["busted"];
                if ("shuffle" in b) config.test.busted.shuffle = b["shuffle"].type == JSONType.true_;
                if ("seed" in b) config.test.busted.seed = cast(int)b["seed"].integer;
                if ("failFast" in b) config.test.busted.failFast = b["failFast"].type == JSONType.true_;
                if ("format" in b) config.test.busted.format = b["format"].str;
                if ("lazy" in b) config.test.busted.lazyLoad = b["lazy"].type == JSONType.true_;
                
                if ("tags" in b)
                    config.test.busted.tags = b["tags"].array.map!(e => e.str).array;
                if ("excludeTags" in b)
                    config.test.busted.excludeTags = b["excludeTags"].array.map!(e => e.str).array;
            }
            
            // LuaUnit options
            if ("luaunit" in t)
            {
                auto lu = t["luaunit"];
                if ("output" in lu) config.test.luaunit.output = lu["output"].str;
                if ("verbosity" in lu) config.test.luaunit.verbosity = cast(int)lu["verbosity"].integer;
                if ("quiet" in lu) config.test.luaunit.quiet = lu["quiet"].type == JSONType.true_;
                if ("xmlOutput" in lu) config.test.luaunit.xmlOutput = lu["xmlOutput"].str;
            }
        }
        
        // Lint configuration
        if ("lint" in json)
        {
            auto l = json["lint"];
            if ("enabled" in l) config.lint.enabled = l["enabled"].type == JSONType.true_;
            if ("configFile" in l) config.lint.configFile = l["configFile"].str;
            if ("failOnWarning" in l) config.lint.failOnWarning = l["failOnWarning"].type == JSONType.true_;
            
            if ("linter" in l)
            {
                string lintStr = l["linter"].str;
                switch (lintStr.toLower)
                {
                    case "auto": config.lint.linter = LuaLinter.Auto; break;
                    case "luacheck": config.lint.linter = LuaLinter.Luacheck; break;
                    case "luacheckjit": config.lint.linter = LuaLinter.LuacheckJIT; break;
                    case "selene": config.lint.linter = LuaLinter.Selene; break;
                    case "none": config.lint.linter = LuaLinter.None; break;
                    default: break;
                }
            }
            
            // Luacheck options
            if ("luacheck" in l)
            {
                auto lc = l["luacheck"];
                if ("std" in lc) config.lint.luacheck.std = lc["std"].str;
                if ("maxLineLength" in lc) config.lint.luacheck.maxLineLength = cast(int)lc["maxLineLength"].integer;
                if ("maxComplexity" in lc) config.lint.luacheck.maxComplexity = cast(int)lc["maxComplexity"].integer;
                if ("warnUnusedArgs" in lc) config.lint.luacheck.warnUnusedArgs = lc["warnUnusedArgs"].type == JSONType.true_;
                if ("warnUnusedVars" in lc) config.lint.luacheck.warnUnusedVars = lc["warnUnusedVars"].type == JSONType.true_;
                if ("warnShadowing" in lc) config.lint.luacheck.warnShadowing = lc["warnShadowing"].type == JSONType.true_;
                if ("warnGlobals" in lc) config.lint.luacheck.warnGlobals = lc["warnGlobals"].type == JSONType.true_;
                
                if ("globals" in lc)
                    config.lint.luacheck.globals = lc["globals"].array.map!(e => e.str).array;
                if ("readGlobals" in lc)
                    config.lint.luacheck.readGlobals = lc["readGlobals"].array.map!(e => e.str).array;
                if ("ignore" in lc)
                    config.lint.luacheck.ignore = lc["ignore"].array.map!(e => e.str).array;
                if ("only" in lc)
                    config.lint.luacheck.only = lc["only"].array.map!(e => e.str).array;
            }
            
            // Selene options
            if ("selene" in l)
            {
                auto s = l["selene"];
                if ("std" in s) config.lint.selene.std = s["std"].str;
                if ("displayStyle" in s) config.lint.selene.displayStyle = s["displayStyle"].str;
            }
        }
        
        // Format configuration
        if ("format" in json)
        {
            auto f = json["format"];
            if ("autoFormat" in f) config.format.autoFormat = f["autoFormat"].type == JSONType.true_;
            if ("configFile" in f) config.format.configFile = f["configFile"].str;
            if ("checkOnly" in f) config.format.checkOnly = f["checkOnly"].type == JSONType.true_;
            
            if ("formatter" in f)
            {
                string fmtStr = f["formatter"].str;
                switch (fmtStr.toLower)
                {
                    case "auto": config.format.formatter = LuaFormatter.Auto; break;
                    case "stylua": config.format.formatter = LuaFormatter.StyLua; break;
                    case "luaformat": case "lua-format": config.format.formatter = LuaFormatter.LuaFormat; break;
                    case "none": config.format.formatter = LuaFormatter.None; break;
                    default: break;
                }
            }
            
            // StyLua options
            if ("stylua" in f)
            {
                auto st = f["stylua"];
                if ("columnWidth" in st) config.format.stylua.columnWidth = cast(int)st["columnWidth"].integer;
                if ("lineEndings" in st) config.format.stylua.lineEndings = st["lineEndings"].str;
                if ("indentType" in st) config.format.stylua.indentType = st["indentType"].str;
                if ("indentWidth" in st) config.format.stylua.indentWidth = cast(int)st["indentWidth"].integer;
                if ("quoteStyle" in st) config.format.stylua.quoteStyle = st["quoteStyle"].str;
                if ("callParentheses" in st) config.format.stylua.callParentheses = st["callParentheses"].str;
            }
        }
        
        // Module configuration
        if ("module" in json)
        {
            auto m = json["module"];
            if ("name" in m) config.moduleConfig.name = m["name"].str;
            if ("version" in m) config.moduleConfig.version_ = m["version"].str;
            if ("entryPoint" in m) config.moduleConfig.entryPoint = m["entryPoint"].str;
            
            if ("packagePath" in m)
                config.moduleConfig.packagePath = m["packagePath"].array.map!(e => e.str).array;
            if ("cPackagePath" in m)
                config.moduleConfig.cPackagePath = m["cPackagePath"].array.map!(e => e.str).array;
            if ("requires" in m)
                config.moduleConfig.requires = m["requires"].array.map!(e => e.str).array;
            if ("externalLibs" in m)
                config.moduleConfig.externalLibs = m["externalLibs"].array.map!(e => e.str).array;
        }
        
        // C module configuration
        if ("cmodule" in json)
        {
            auto cm = json["cmodule"];
            if ("enabled" in cm) config.cmodule.enabled = cm["enabled"].type == JSONType.true_;
            if ("compiler" in cm) config.cmodule.compiler = cm["compiler"].str;
            if ("shared" in cm) config.cmodule.isShared = cm["shared"].type == JSONType.true_;
            
            if ("sources" in cm)
                config.cmodule.sources = cm["sources"].array.map!(e => e.str).array;
            if ("includes" in cm)
                config.cmodule.includes = cm["includes"].array.map!(e => e.str).array;
            if ("libraries" in cm)
                config.cmodule.libraries = cm["libraries"].array.map!(e => e.str).array;
            if ("libDirs" in cm)
                config.cmodule.libDirs = cm["libDirs"].array.map!(e => e.str).array;
            if ("cflags" in cm)
                config.cmodule.cflags = cm["cflags"].array.map!(e => e.str).array;
            if ("ldflags" in cm)
                config.cmodule.ldflags = cm["ldflags"].array.map!(e => e.str).array;
        }
        
        // Simple fields
        if ("entryPoint" in json) config.entryPoint = json["entryPoint"].str;
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        
        if ("luaFlags" in json)
            config.luaFlags = json["luaFlags"].array.map!(e => e.str).array;
        
        // Wrapper options
        if ("wrapper" in json)
        {
            auto w = json["wrapper"];
            if ("create" in w) config.wrapper.create = w["create"].type == JSONType.true_;
            if ("shebang" in w) config.wrapper.shebang = w["shebang"].str;
            
            if ("setupCode" in w)
                config.wrapper.setupCode = w["setupCode"].array.map!(e => e.str).array;
        }
        
        // Environment variables
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

/// Lua build result
struct LuaBuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    
    /// Lint warnings
    string[] lintWarnings;
    bool hadLintErrors;
    
    /// Format issues
    string[] formatIssues;
    
    /// Test results
    bool testsRan;
    int testsPassed;
    int testsFailed;
    float coveragePercent;
    
    /// Rock installation info
    string rockName;
    string rockVersion;
}

