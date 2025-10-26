module languages.compiled.nim.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Nim compilation backends - Nim can compile to multiple targets
enum NimBackend
{
    /// Compile to C (default, fastest)
    C,
    /// Compile to C++ (enables C++ interop)
    Cpp,
    /// Compile to JavaScript (Node.js or browser)
    Js,
    /// Compile to Objective-C (macOS/iOS)
    ObjC
}

/// Nim build modes
enum NimBuildMode
{
    /// Standard compilation
    Compile,
    /// Check syntax and types only (no codegen)
    Check,
    /// Generate documentation
    Doc,
    /// Run after compiling
    Run,
    /// Execute nimble build
    Nimble,
    /// Run tests with testament
    Test,
    /// Custom nim command
    Custom
}

/// Builder strategy selection
enum NimBuilderType
{
    /// Auto-detect based on project structure
    Auto,
    /// Use nimble for package-based projects
    Nimble,
    /// Direct nim compiler invocation
    Compile,
    /// Check-only mode (no compilation)
    Check,
    /// Documentation generation
    Doc,
    /// JavaScript backend
    Js
}

/// Optimization levels
enum OptLevel
{
    /// No optimization (debug)
    None,
    /// Basic optimization
    Speed,
    /// Maximum optimization
    Size
}

/// GC (Garbage Collector) strategies
enum GcStrategy
{
    /// Reference counting with cycle detection (default)
    Refc,
    /// Mark and sweep GC
    MarkAndSweep,
    /// Boehm GC
    Boehm,
    /// Go-like GC
    Go,
    /// No GC (manual memory management)
    None,
    /// Arc - deterministic memory management
    Arc,
    /// Orc - Arc with cycle collection
    Orc
}

/// Target OS for cross-compilation
enum TargetOS
{
    /// Linux
    Linux,
    /// Windows
    Windows,
    /// macOS
    MacOSX,
    /// FreeBSD
    FreeBSD,
    /// OpenBSD
    OpenBSD,
    /// NetBSD
    NetBSD,
    /// Solaris
    Solaris,
    /// Android
    Android,
    /// iOS
    IOS,
    /// Standalone (embedded)
    Standalone,
    /// NimScript
    NimScript,
    /// Any (cross-platform)
    Any
}

/// Target CPU architecture
enum TargetCPU
{
    /// x86 (32-bit)
    I386,
    /// x86-64 (64-bit)
    Amd64,
    /// ARM (32-bit)
    Arm,
    /// ARM64 (64-bit)
    Arm64,
    /// PowerPC
    PowerPC,
    /// PowerPC64
    PowerPC64,
    /// MIPS
    Mips,
    /// MIPS64
    Mips64,
    /// RISC-V
    RiscV,
    /// WebAssembly
    Wasm,
    /// Native (current machine)
    Native
}

/// Application type
enum AppType
{
    /// Console application
    Console,
    /// GUI application
    Gui,
    /// Static library
    StaticLib,
    /// Dynamic library
    DynamicLib
}

/// Cross-compilation target configuration
struct CrossTarget
{
    /// Target OS
    TargetOS os = TargetOS.Any;
    
    /// Target CPU
    TargetCPU cpu = TargetCPU.Native;
    
    /// Check if cross-compilation is enabled
    bool isCross() const pure nothrow
    {
        return os != TargetOS.Any || cpu != TargetCPU.Native;
    }
    
    /// Convert to Nim command-line flags
    string[] toFlags() const
    {
        string[] flags;
        
        if (os != TargetOS.Any)
        {
            flags ~= "--os:" ~ os.to!string.toLower;
        }
        
        if (cpu != TargetCPU.Native)
        {
            flags ~= "--cpu:" ~ cpu.to!string.toLower;
        }
        
        return flags;
    }
}

/// Nimble package configuration
struct NimbleConfig
{
    /// Enable nimble integration
    bool enabled = true;
    
    /// Nimble file path
    string nimbleFile;
    
    /// Install dependencies before building
    bool installDeps = false;
    
    /// Build in development mode
    bool devMode = false;
    
    /// Custom nimble tasks to run
    string[] tasks;
    
    /// Nimble flags
    string[] flags;
}

/// Documentation generation configuration
struct DocConfig
{
    /// Output directory for documentation
    string outputDir = "htmldocs";
    
    /// Documentation format
    string format = "html";
    
    /// Generate index
    bool genIndex = true;
    
    /// Project name for documentation
    string project;
    
    /// Documentation title
    string title;
    
    /// Include source code
    bool includeSource = true;
}

/// Testing configuration
struct TestConfig
{
    /// Testament test suite directory
    string testDir = "tests";
    
    /// Test categories to run
    string[] categories;
    
    /// Test name pattern filter
    string pattern;
    
    /// Generate coverage report
    bool coverage = false;
    
    /// Verbose test output
    bool verbose = false;
    
    /// Parallel test execution
    bool parallel = true;
}

/// Nim path configuration
struct PathConfig
{
    /// Additional Nim module paths
    string[] paths;
    
    /// Clear default paths
    bool clearPaths = false;
    
    /// Nimble package directories
    string[] nimblePaths;
}

/// Hint/warning configuration
struct HintConfig
{
    /// Hints to enable
    string[] enable;
    
    /// Hints to disable
    string[] disable;
    
    /// Warnings to enable
    string[] enableWarnings;
    
    /// Warnings to disable
    string[] disableWarnings;
    
    /// Turn warnings into errors
    bool warningsAsErrors = false;
    
    /// Hints as errors
    bool hintsAsErrors = false;
}

/// Thread configuration
struct ThreadConfig
{
    /// Enable threading support
    bool enabled = false;
    
    /// Thread model (on/off)
    string model = "on";
    
    /// Stack size for threads
    size_t stackSize = 0; // 0 = default
}

/// Experimental features
struct ExperimentalConfig
{
    /// Enable experimental features
    bool enabled = false;
    
    /// Specific experimental features to enable
    string[] features;
}

/// Comprehensive Nim configuration
struct NimConfig
{
    /// Build mode
    NimBuildMode mode = NimBuildMode.Compile;
    
    /// Builder selection
    NimBuilderType builder = NimBuilderType.Auto;
    
    /// Compilation backend
    NimBackend backend = NimBackend.C;
    
    /// Optimization level
    OptLevel optimize = OptLevel.Speed;
    
    /// Garbage collector strategy
    GcStrategy gc = GcStrategy.Orc;
    
    /// Application type
    AppType appType = AppType.Console;
    
    /// Cross-compilation target
    CrossTarget target;
    
    /// Entry point file
    string entry;
    
    /// Output file name
    string output;
    
    /// Output directory
    string outputDir;
    
    /// Generate debug information
    bool debugInfo = false;
    
    /// Enable bounds checking
    bool checks = true;
    
    /// Enable assertions
    bool assertions = true;
    
    /// Enable line tracing
    bool lineTrace = false;
    
    /// Enable stack traces
    bool stackTrace = true;
    
    /// Enable profiler
    bool profiler = false;
    
    /// Compile as release build
    bool release = false;
    
    /// Danger mode (disable all runtime checks)
    bool danger = false;
    
    /// Define symbols
    string[] defines;
    
    /// Undefine symbols
    string[] undefines;
    
    /// Additional compiler flags
    string[] compilerFlags;
    
    /// Linker flags
    string[] linkerFlags;
    
    /// C compiler to use with C backend
    string cCompiler;
    
    /// C++ compiler to use with C++ backend
    string cppCompiler;
    
    /// C/C++ include directories
    string[] includeDirs;
    
    /// C/C++ library directories
    string[] libDirs;
    
    /// C/C++ libraries to link
    string[] libs;
    
    /// Pass through C compiler flags
    string[] passCFlags;
    
    /// Pass through linker flags
    string[] passLFlags;
    
    /// Nimble configuration
    NimbleConfig nimble;
    
    /// Documentation configuration
    DocConfig doc;
    
    /// Test configuration
    TestConfig test;
    
    /// Path configuration
    PathConfig path;
    
    /// Hint/warning configuration
    HintConfig hints;
    
    /// Thread configuration
    ThreadConfig threads;
    
    /// Experimental features
    ExperimentalConfig experimental;
    
    /// Tooling options
    bool runFormat = false;
    bool runCheck = false;
    bool runSuggest = false;
    
    /// Format options
    bool formatCheck = false; // Check only, don't modify
    size_t formatIndent = 2;
    size_t formatMaxLineLen = 80;
    
    /// Verbose output
    bool verbose = false;
    
    /// Force rebuild
    bool forceBuild = false;
    
    /// Parallel build
    bool parallel = false;
    size_t parallelJobs = 0; // 0 = auto
    
    /// List compiler invocations
    bool listCmd = false;
    
    /// Color output
    bool colors = true;
    
    /// Nim standard library override
    string nimStdlib;
    
    /// Nim cache directory
    string nimCache = "nimcache";
    
    /// Environment variables
    string[string] env;
    
    /// Parse from JSON
    static NimConfig fromJSON(JSONValue json)
    {
        NimConfig config;
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str.toLower;
            switch (modeStr)
            {
                case "compile": config.mode = NimBuildMode.Compile; break;
                case "check": config.mode = NimBuildMode.Check; break;
                case "doc": config.mode = NimBuildMode.Doc; break;
                case "run": config.mode = NimBuildMode.Run; break;
                case "nimble": config.mode = NimBuildMode.Nimble; break;
                case "test": config.mode = NimBuildMode.Test; break;
                case "custom": config.mode = NimBuildMode.Custom; break;
                default: config.mode = NimBuildMode.Compile; break;
            }
        }
        
        // Builder
        if ("builder" in json)
        {
            string builderStr = json["builder"].str.toLower;
            switch (builderStr)
            {
                case "auto": config.builder = NimBuilderType.Auto; break;
                case "nimble": config.builder = NimBuilderType.Nimble; break;
                case "compile": config.builder = NimBuilderType.Compile; break;
                case "check": config.builder = NimBuilderType.Check; break;
                case "doc": config.builder = NimBuilderType.Doc; break;
                case "js": config.builder = NimBuilderType.Js; break;
                default: config.builder = NimBuilderType.Auto; break;
            }
        }
        
        // Backend
        if ("backend" in json)
        {
            string backendStr = json["backend"].str.toLower;
            switch (backendStr)
            {
                case "c": config.backend = NimBackend.C; break;
                case "cpp": case "c++": config.backend = NimBackend.Cpp; break;
                case "js": case "javascript": config.backend = NimBackend.Js; break;
                case "objc": case "objective-c": config.backend = NimBackend.ObjC; break;
                default: config.backend = NimBackend.C; break;
            }
        }
        
        // Optimization
        if ("optimize" in json)
        {
            string optStr = json["optimize"].str.toLower;
            switch (optStr)
            {
                case "none": case "debug": config.optimize = OptLevel.None; break;
                case "speed": config.optimize = OptLevel.Speed; break;
                case "size": config.optimize = OptLevel.Size; break;
                default: config.optimize = OptLevel.Speed; break;
            }
        }
        
        // GC strategy
        if ("gc" in json)
        {
            string gcStr = json["gc"].str.toLower;
            switch (gcStr)
            {
                case "refc": config.gc = GcStrategy.Refc; break;
                case "markandsweep": case "ms": config.gc = GcStrategy.MarkAndSweep; break;
                case "boehm": config.gc = GcStrategy.Boehm; break;
                case "go": config.gc = GcStrategy.Go; break;
                case "none": config.gc = GcStrategy.None; break;
                case "arc": config.gc = GcStrategy.Arc; break;
                case "orc": config.gc = GcStrategy.Orc; break;
                default: config.gc = GcStrategy.Orc; break;
            }
        }
        
        // App type
        if ("appType" in json || "app_type" in json)
        {
            string key = "appType" in json ? "appType" : "app_type";
            string appStr = json[key].str.toLower;
            switch (appStr)
            {
                case "console": config.appType = AppType.Console; break;
                case "gui": config.appType = AppType.Gui; break;
                case "staticlib": case "lib": config.appType = AppType.StaticLib; break;
                case "dynamiclib": case "dylib": config.appType = AppType.DynamicLib; break;
                default: config.appType = AppType.Console; break;
            }
        }
        
        // Cross-compilation target
        if ("target" in json)
        {
            auto targetObj = json["target"];
            if (targetObj.type == JSONType.object)
            {
                if ("os" in targetObj)
                {
                    string osStr = targetObj["os"].str.toLower;
                    switch (osStr)
                    {
                        case "linux": config.target.os = TargetOS.Linux; break;
                        case "windows": config.target.os = TargetOS.Windows; break;
                        case "macosx": case "macos": config.target.os = TargetOS.MacOSX; break;
                        case "freebsd": config.target.os = TargetOS.FreeBSD; break;
                        case "openbsd": config.target.os = TargetOS.OpenBSD; break;
                        case "netbsd": config.target.os = TargetOS.NetBSD; break;
                        case "solaris": config.target.os = TargetOS.Solaris; break;
                        case "android": config.target.os = TargetOS.Android; break;
                        case "ios": config.target.os = TargetOS.IOS; break;
                        case "standalone": config.target.os = TargetOS.Standalone; break;
                        case "nimscript": config.target.os = TargetOS.NimScript; break;
                        case "any": config.target.os = TargetOS.Any; break;
                        default: config.target.os = TargetOS.Any; break;
                    }
                }
                
                if ("cpu" in targetObj)
                {
                    string cpuStr = targetObj["cpu"].str.toLower;
                    switch (cpuStr)
                    {
                        case "i386": case "x86": config.target.cpu = TargetCPU.I386; break;
                        case "amd64": case "x86_64": case "x64": config.target.cpu = TargetCPU.Amd64; break;
                        case "arm": config.target.cpu = TargetCPU.Arm; break;
                        case "arm64": case "aarch64": config.target.cpu = TargetCPU.Arm64; break;
                        case "powerpc": case "ppc": config.target.cpu = TargetCPU.PowerPC; break;
                        case "powerpc64": case "ppc64": config.target.cpu = TargetCPU.PowerPC64; break;
                        case "mips": config.target.cpu = TargetCPU.Mips; break;
                        case "mips64": config.target.cpu = TargetCPU.Mips64; break;
                        case "riscv": config.target.cpu = TargetCPU.RiscV; break;
                        case "wasm": case "wasm32": config.target.cpu = TargetCPU.Wasm; break;
                        case "native": config.target.cpu = TargetCPU.Native; break;
                        default: config.target.cpu = TargetCPU.Native; break;
                    }
                }
            }
        }
        
        // String fields
        if ("entry" in json) config.entry = json["entry"].str;
        if ("output" in json) config.output = json["output"].str;
        if ("outputDir" in json || "output_dir" in json)
        {
            string key = "outputDir" in json ? "outputDir" : "output_dir";
            config.outputDir = json[key].str;
        }
        if ("cCompiler" in json || "c_compiler" in json)
        {
            string key = "cCompiler" in json ? "cCompiler" : "c_compiler";
            config.cCompiler = json[key].str;
        }
        if ("cppCompiler" in json || "cpp_compiler" in json)
        {
            string key = "cppCompiler" in json ? "cppCompiler" : "cpp_compiler";
            config.cppCompiler = json[key].str;
        }
        if ("nimStdlib" in json || "nim_stdlib" in json)
        {
            string key = "nimStdlib" in json ? "nimStdlib" : "nim_stdlib";
            config.nimStdlib = json[key].str;
        }
        if ("nimCache" in json || "nim_cache" in json)
        {
            string key = "nimCache" in json ? "nimCache" : "nim_cache";
            config.nimCache = json[key].str;
        }
        
        // Numeric fields
        if ("formatIndent" in json || "format_indent" in json)
        {
            string key = "formatIndent" in json ? "formatIndent" : "format_indent";
            config.formatIndent = json[key].integer.to!size_t;
        }
        if ("formatMaxLineLen" in json || "format_max_line_len" in json)
        {
            string key = "formatMaxLineLen" in json ? "formatMaxLineLen" : "format_max_line_len";
            config.formatMaxLineLen = json[key].integer.to!size_t;
        }
        if ("parallelJobs" in json || "parallel_jobs" in json)
        {
            string key = "parallelJobs" in json ? "parallelJobs" : "parallel_jobs";
            config.parallelJobs = json[key].integer.to!size_t;
        }
        
        // Boolean fields
        if ("debugInfo" in json || "debug_info" in json)
        {
            string key = "debugInfo" in json ? "debugInfo" : "debug_info";
            config.debugInfo = json[key].type == JSONType.true_;
        }
        if ("checks" in json) config.checks = json["checks"].type == JSONType.true_;
        if ("assertions" in json) config.assertions = json["assertions"].type == JSONType.true_;
        if ("lineTrace" in json || "line_trace" in json)
        {
            string key = "lineTrace" in json ? "lineTrace" : "line_trace";
            config.lineTrace = json[key].type == JSONType.true_;
        }
        if ("stackTrace" in json || "stack_trace" in json)
        {
            string key = "stackTrace" in json ? "stackTrace" : "stack_trace";
            config.stackTrace = json[key].type == JSONType.true_;
        }
        if ("profiler" in json) config.profiler = json["profiler"].type == JSONType.true_;
        if ("release" in json) config.release = json["release"].type == JSONType.true_;
        if ("danger" in json) config.danger = json["danger"].type == JSONType.true_;
        if ("runFormat" in json || "run_format" in json)
        {
            string key = "runFormat" in json ? "runFormat" : "run_format";
            config.runFormat = json[key].type == JSONType.true_;
        }
        if ("runCheck" in json || "run_check" in json)
        {
            string key = "runCheck" in json ? "runCheck" : "run_check";
            config.runCheck = json[key].type == JSONType.true_;
        }
        if ("runSuggest" in json || "run_suggest" in json)
        {
            string key = "runSuggest" in json ? "runSuggest" : "run_suggest";
            config.runSuggest = json[key].type == JSONType.true_;
        }
        if ("formatCheck" in json || "format_check" in json)
        {
            string key = "formatCheck" in json ? "formatCheck" : "format_check";
            config.formatCheck = json[key].type == JSONType.true_;
        }
        if ("verbose" in json) config.verbose = json["verbose"].type == JSONType.true_;
        if ("forceBuild" in json || "force_build" in json)
        {
            string key = "forceBuild" in json ? "forceBuild" : "force_build";
            config.forceBuild = json[key].type == JSONType.true_;
        }
        if ("parallel" in json) config.parallel = json["parallel"].type == JSONType.true_;
        if ("listCmd" in json || "list_cmd" in json)
        {
            string key = "listCmd" in json ? "listCmd" : "list_cmd";
            config.listCmd = json[key].type == JSONType.true_;
        }
        if ("colors" in json) config.colors = json["colors"].type == JSONType.true_;
        
        // Array fields
        if ("defines" in json)
            config.defines = json["defines"].array.map!(e => e.str).array;
        if ("undefines" in json)
            config.undefines = json["undefines"].array.map!(e => e.str).array;
        if ("compilerFlags" in json || "compiler_flags" in json)
        {
            string key = "compilerFlags" in json ? "compilerFlags" : "compiler_flags";
            config.compilerFlags = json[key].array.map!(e => e.str).array;
        }
        if ("linkerFlags" in json || "linker_flags" in json)
        {
            string key = "linkerFlags" in json ? "linkerFlags" : "linker_flags";
            config.linkerFlags = json[key].array.map!(e => e.str).array;
        }
        if ("includeDirs" in json || "include_dirs" in json)
        {
            string key = "includeDirs" in json ? "includeDirs" : "include_dirs";
            config.includeDirs = json[key].array.map!(e => e.str).array;
        }
        if ("libDirs" in json || "lib_dirs" in json)
        {
            string key = "libDirs" in json ? "libDirs" : "lib_dirs";
            config.libDirs = json[key].array.map!(e => e.str).array;
        }
        if ("libs" in json)
            config.libs = json["libs"].array.map!(e => e.str).array;
        if ("passCFlags" in json || "pass_c_flags" in json)
        {
            string key = "passCFlags" in json ? "passCFlags" : "pass_c_flags";
            config.passCFlags = json[key].array.map!(e => e.str).array;
        }
        if ("passLFlags" in json || "pass_l_flags" in json)
        {
            string key = "passLFlags" in json ? "passLFlags" : "pass_l_flags";
            config.passLFlags = json[key].array.map!(e => e.str).array;
        }
        
        // Nimble configuration
        if ("nimble" in json)
        {
            auto nimble = json["nimble"];
            if ("enabled" in nimble) config.nimble.enabled = nimble["enabled"].type == JSONType.true_;
            if ("nimbleFile" in nimble || "nimble_file" in nimble)
            {
                string key = "nimbleFile" in nimble ? "nimbleFile" : "nimble_file";
                config.nimble.nimbleFile = nimble[key].str;
            }
            if ("installDeps" in nimble || "install_deps" in nimble)
            {
                string key = "installDeps" in nimble ? "installDeps" : "install_deps";
                config.nimble.installDeps = nimble[key].type == JSONType.true_;
            }
            if ("devMode" in nimble || "dev_mode" in nimble)
            {
                string key = "devMode" in nimble ? "devMode" : "dev_mode";
                config.nimble.devMode = nimble[key].type == JSONType.true_;
            }
            if ("tasks" in nimble)
                config.nimble.tasks = nimble["tasks"].array.map!(e => e.str).array;
            if ("flags" in nimble)
                config.nimble.flags = nimble["flags"].array.map!(e => e.str).array;
        }
        
        // Documentation configuration
        if ("doc" in json)
        {
            auto doc = json["doc"];
            if ("outputDir" in doc || "output_dir" in doc)
            {
                string key = "outputDir" in doc ? "outputDir" : "output_dir";
                config.doc.outputDir = doc[key].str;
            }
            if ("format" in doc) config.doc.format = doc["format"].str;
            if ("genIndex" in doc || "gen_index" in doc)
            {
                string key = "genIndex" in doc ? "genIndex" : "gen_index";
                config.doc.genIndex = doc[key].type == JSONType.true_;
            }
            if ("project" in doc) config.doc.project = doc["project"].str;
            if ("title" in doc) config.doc.title = doc["title"].str;
            if ("includeSource" in doc || "include_source" in doc)
            {
                string key = "includeSource" in doc ? "includeSource" : "include_source";
                config.doc.includeSource = doc[key].type == JSONType.true_;
            }
        }
        
        // Test configuration
        if ("test" in json)
        {
            auto test = json["test"];
            if ("testDir" in test || "test_dir" in test)
            {
                string key = "testDir" in test ? "testDir" : "test_dir";
                config.test.testDir = test[key].str;
            }
            if ("categories" in test)
                config.test.categories = test["categories"].array.map!(e => e.str).array;
            if ("pattern" in test) config.test.pattern = test["pattern"].str;
            if ("coverage" in test) config.test.coverage = test["coverage"].type == JSONType.true_;
            if ("verbose" in test) config.test.verbose = test["verbose"].type == JSONType.true_;
            if ("parallel" in test) config.test.parallel = test["parallel"].type == JSONType.true_;
        }
        
        // Path configuration
        if ("path" in json)
        {
            auto path = json["path"];
            if ("paths" in path)
                config.path.paths = path["paths"].array.map!(e => e.str).array;
            if ("clearPaths" in path || "clear_paths" in path)
            {
                string key = "clearPaths" in path ? "clearPaths" : "clear_paths";
                config.path.clearPaths = path[key].type == JSONType.true_;
            }
            if ("nimblePaths" in path || "nimble_paths" in path)
            {
                string key = "nimblePaths" in path ? "nimblePaths" : "nimble_paths";
                config.path.nimblePaths = path[key].array.map!(e => e.str).array;
            }
        }
        
        // Hint configuration
        if ("hints" in json)
        {
            auto hints = json["hints"];
            if ("enable" in hints)
                config.hints.enable = hints["enable"].array.map!(e => e.str).array;
            if ("disable" in hints)
                config.hints.disable = hints["disable"].array.map!(e => e.str).array;
            if ("enableWarnings" in hints || "enable_warnings" in hints)
            {
                string key = "enableWarnings" in hints ? "enableWarnings" : "enable_warnings";
                config.hints.enableWarnings = hints[key].array.map!(e => e.str).array;
            }
            if ("disableWarnings" in hints || "disable_warnings" in hints)
            {
                string key = "disableWarnings" in hints ? "disableWarnings" : "disable_warnings";
                config.hints.disableWarnings = hints[key].array.map!(e => e.str).array;
            }
            if ("warningsAsErrors" in hints || "warnings_as_errors" in hints)
            {
                string key = "warningsAsErrors" in hints ? "warningsAsErrors" : "warnings_as_errors";
                config.hints.warningsAsErrors = hints[key].type == JSONType.true_;
            }
            if ("hintsAsErrors" in hints || "hints_as_errors" in hints)
            {
                string key = "hintsAsErrors" in hints ? "hintsAsErrors" : "hints_as_errors";
                config.hints.hintsAsErrors = hints[key].type == JSONType.true_;
            }
        }
        
        // Thread configuration
        if ("threads" in json)
        {
            auto threads = json["threads"];
            if ("enabled" in threads) config.threads.enabled = threads["enabled"].type == JSONType.true_;
            if ("model" in threads) config.threads.model = threads["model"].str;
            if ("stackSize" in threads || "stack_size" in threads)
            {
                string key = "stackSize" in threads ? "stackSize" : "stack_size";
                config.threads.stackSize = threads[key].integer.to!size_t;
            }
        }
        
        // Experimental configuration
        if ("experimental" in json)
        {
            auto exp = json["experimental"];
            if ("enabled" in exp) config.experimental.enabled = exp["enabled"].type == JSONType.true_;
            if ("features" in exp)
                config.experimental.features = exp["features"].array.map!(e => e.str).array;
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

/// Nim compilation result
struct NimCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string[] artifacts; // Generated docs, etc.
    string outputHash;
    bool hadWarnings;
    string[] warnings;
    string[] hints;
}

