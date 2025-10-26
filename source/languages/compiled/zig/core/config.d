module languages.compiled.zig.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Zig build modes - aligned with zig build-* commands
enum ZigBuildMode
{
    /// Standard compilation
    Compile,
    /// Build and test
    Test,
    /// Run after building
    Run,
    /// Build using build.zig
    BuildScript,
    /// Check only (no code generation)
    Check,
    /// Translate C code
    TranslateC,
    /// Custom build
    Custom
}

/// Builder selection
enum ZigBuilderType
{
    /// Auto-detect (prefer build.zig if exists)
    Auto,
    /// Use build.zig build system
    BuildZig,
    /// Direct zig compile invocation
    Compile
}

/// Optimization modes - Zig's optimization levels
enum OptMode
{
    /// Debug mode (no optimization)
    Debug,
    /// Release with safety checks
    ReleaseSafe,
    /// Release optimized
    ReleaseFast,
    /// Release optimized for size
    ReleaseSmall
}

/// Output types
enum OutputType
{
    /// Executable
    Exe,
    /// Static library
    Lib,
    /// Dynamic library
    Dylib,
    /// Object file
    Obj
}

/// Target CPU features
enum CpuFeature
{
    /// Baseline CPU features
    Baseline,
    /// Native CPU features
    Native,
    /// Custom feature set
    Custom
}

/// Link mode
enum LinkMode
{
    /// Dynamic linking
    Dynamic,
    /// Static linking
    Static
}

/// Strip mode
enum StripMode
{
    /// No stripping
    None,
    /// Strip debug info
    Debug,
    /// Strip all symbols
    All
}

/// Code model for position-independent code
enum CodeModel
{
    /// Default
    Default,
    /// Tiny
    Tiny,
    /// Small
    Small,
    /// Kernel
    Kernel,
    /// Medium
    Medium,
    /// Large
    Large
}

/// Cross-compilation target configuration
struct CrossTarget
{
    /// Target triple (e.g., x86_64-linux-gnu)
    string triple;
    
    /// CPU architecture
    string cpu;
    
    /// Operating system
    string os;
    
    /// ABI
    string abi;
    
    /// CPU features
    CpuFeature cpuFeatures = CpuFeature.Baseline;
    
    /// Custom CPU feature string
    string customFeatures;
    
    /// Check if cross-compilation is enabled
    bool isCross() const pure nothrow
    {
        return !triple.empty || !cpu.empty || !os.empty || !abi.empty;
    }
    
    /// Generate target flag for zig
    string toTargetFlag() const
    {
        if (!triple.empty)
            return triple;
        
        string[] parts;
        if (!cpu.empty) parts ~= cpu;
        if (!os.empty) parts ~= os;
        if (!abi.empty) parts ~= abi;
        
        return parts.join("-");
    }
}

/// Package dependency
struct ZigPackage
{
    /// Package name
    string name;
    
    /// Package path (for local packages)
    string path;
    
    /// Package URL (for remote packages)
    string url;
    
    /// Package hash
    string hash;
}

/// Test configuration
struct TestConfig
{
    /// Test name filter
    string filter;
    
    /// Skip filter
    string skipFilter;
    
    /// Run tests with filter
    bool verbose = false;
    
    /// Generate coverage
    bool coverage = false;
    
    /// Coverage output directory
    string coverageDir = "zig-out/coverage";
}

/// Build.zig configuration
struct BuildZigConfig
{
    /// Path to build.zig
    string path = "build.zig";
    
    /// Build steps to execute
    string[] steps;
    
    /// Build options as key-value pairs
    string[string] options;
    
    /// Prefix for install
    string prefix;
    
    /// System library integration prefix
    string sysroot;
    
    /// Use system linker
    bool useSystemLinker = false;
}

/// Cache configuration
struct ZigCacheConfig
{
    /// Enable global cache
    bool globalCache = true;
    
    /// Cache directory override
    string cacheDir;
    
    /// Enable incremental compilation
    bool incremental = true;
}

/// Zig-specific build configuration
struct ZigConfig
{
    /// Build mode
    ZigBuildMode mode = ZigBuildMode.Compile;
    
    /// Builder selection
    ZigBuilderType builder = ZigBuilderType.Auto;
    
    /// Optimization mode
    OptMode optimize = OptMode.ReleaseFast;
    
    /// Output type
    OutputType outputType = OutputType.Exe;
    
    /// Cross-compilation target
    CrossTarget target;
    
    /// Link mode
    LinkMode linkMode = LinkMode.Static;
    
    /// Strip debug symbols
    StripMode strip = StripMode.None;
    
    /// Code model
    CodeModel codeModel = CodeModel.Default;
    
    /// Entry point file
    string entry;
    
    /// Output directory
    string outputDir = "zig-out";
    
    /// Output name
    string outputName;
    
    /// Enable C++ interop
    bool cppInterop = false;
    
    /// C include directories
    string[] cIncludeDirs;
    
    /// C library directories
    string[] cLibDirs;
    
    /// C libraries to link
    string[] cLibs;
    
    /// Link system libraries
    string[] sysLibs;
    
    /// C flags
    string[] cflags;
    
    /// Link flags
    string[] ldflags;
    
    /// Packages (dependencies)
    ZigPackage[] packages;
    
    /// Enable single-threaded mode
    bool singleThreaded = false;
    
    /// Enable stack overflow protection
    bool stackCheck = true;
    
    /// Enable red zone
    bool redZone = true;
    
    /// Enable PIC (position independent code)
    bool pic = false;
    
    /// Enable PIE (position independent executable)
    bool pie = false;
    
    /// Enable LTO (link time optimization)
    bool lto = false;
    
    /// Enable LLVM module verification
    bool llvmVerifyModule = true;
    
    /// Enable LLVM IR verification
    bool llvmIrVerify = true;
    
    /// Maximum memory for compilation (bytes)
    ulong maxMemory = 0; // 0 = unlimited
    
    /// Number of threads for compilation
    size_t threads = 0; // 0 = auto
    
    /// Verbose output
    bool verbose = false;
    
    /// Time report
    bool timeReport = false;
    
    /// Enable color diagnostics
    bool color = true;
    
    /// Build.zig configuration
    BuildZigConfig buildZig;
    
    /// Test configuration
    TestConfig test;
    
    /// Cache configuration
    ZigCacheConfig cache;
    
    /// Tooling options
    bool runFmt = false;
    bool runCheck = false;
    
    /// Format options
    bool fmtCheck = false; // Check only, don't modify
    string fmtExclude; // Glob pattern to exclude
    
    /// Environment variables
    string[string] env;
    
    /// Parse from JSON
    static ZigConfig fromJSON(JSONValue json)
    {
        ZigConfig config;
        
        // Mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str.toLower;
            switch (modeStr)
            {
                case "compile": config.mode = ZigBuildMode.Compile; break;
                case "test": config.mode = ZigBuildMode.Test; break;
                case "run": config.mode = ZigBuildMode.Run; break;
                case "build": case "build-script": config.mode = ZigBuildMode.BuildScript; break;
                case "check": config.mode = ZigBuildMode.Check; break;
                case "translate-c": config.mode = ZigBuildMode.TranslateC; break;
                case "custom": config.mode = ZigBuildMode.Custom; break;
                default: config.mode = ZigBuildMode.Compile; break;
            }
        }
        
        // Builder
        if ("builder" in json)
        {
            string builderStr = json["builder"].str.toLower;
            switch (builderStr)
            {
                case "auto": config.builder = ZigBuilderType.Auto; break;
                case "build-zig": case "build": config.builder = ZigBuilderType.BuildZig; break;
                case "compile": config.builder = ZigBuilderType.Compile; break;
                default: config.builder = ZigBuilderType.Auto; break;
            }
        }
        
        // Optimization
        if ("optimize" in json)
        {
            string optStr = json["optimize"].str.toLower;
            switch (optStr)
            {
                case "debug": case "debug-mode": config.optimize = OptMode.Debug; break;
                case "release-safe": case "safe": config.optimize = OptMode.ReleaseSafe; break;
                case "release-fast": case "fast": config.optimize = OptMode.ReleaseFast; break;
                case "release-small": case "small": case "size": config.optimize = OptMode.ReleaseSmall; break;
                default: config.optimize = OptMode.ReleaseFast; break;
            }
        }
        
        // Output type
        if ("outputType" in json || "output_type" in json)
        {
            string key = "outputType" in json ? "outputType" : "output_type";
            string typeStr = json[key].str.toLower;
            switch (typeStr)
            {
                case "exe": case "executable": config.outputType = OutputType.Exe; break;
                case "lib": case "library": config.outputType = OutputType.Lib; break;
                case "dylib": case "dynamic": config.outputType = OutputType.Dylib; break;
                case "obj": case "object": config.outputType = OutputType.Obj; break;
                default: config.outputType = OutputType.Exe; break;
            }
        }
        
        // Link mode
        if ("linkMode" in json || "link_mode" in json)
        {
            string key = "linkMode" in json ? "linkMode" : "link_mode";
            string linkStr = json[key].str.toLower;
            config.linkMode = linkStr == "dynamic" ? LinkMode.Dynamic : LinkMode.Static;
        }
        
        // Strip mode
        if ("strip" in json)
        {
            auto stripValue = json["strip"];
            if (stripValue.type == JSONType.true_)
                config.strip = StripMode.All;
            else if (stripValue.type == JSONType.false_)
                config.strip = StripMode.None;
            else if (stripValue.type == JSONType.string)
            {
                string stripStr = stripValue.str.toLower;
                switch (stripStr)
                {
                    case "none": config.strip = StripMode.None; break;
                    case "debug": config.strip = StripMode.Debug; break;
                    case "all": case "true": config.strip = StripMode.All; break;
                    default: config.strip = StripMode.None; break;
                }
            }
        }
        
        // Code model
        if ("codeModel" in json || "code_model" in json)
        {
            string key = "codeModel" in json ? "codeModel" : "code_model";
            string modelStr = json[key].str.toLower;
            switch (modelStr)
            {
                case "default": config.codeModel = CodeModel.Default; break;
                case "tiny": config.codeModel = CodeModel.Tiny; break;
                case "small": config.codeModel = CodeModel.Small; break;
                case "kernel": config.codeModel = CodeModel.Kernel; break;
                case "medium": config.codeModel = CodeModel.Medium; break;
                case "large": config.codeModel = CodeModel.Large; break;
                default: config.codeModel = CodeModel.Default; break;
            }
        }
        
        // Cross-compilation target
        if ("target" in json)
        {
            auto targetObj = json["target"];
            if (targetObj.type == JSONType.string)
            {
                config.target.triple = targetObj.str;
            }
            else if (targetObj.type == JSONType.object)
            {
                if ("triple" in targetObj) config.target.triple = targetObj["triple"].str;
                if ("cpu" in targetObj) config.target.cpu = targetObj["cpu"].str;
                if ("os" in targetObj) config.target.os = targetObj["os"].str;
                if ("abi" in targetObj) config.target.abi = targetObj["abi"].str;
                
                if ("cpuFeatures" in targetObj || "cpu_features" in targetObj)
                {
                    string key = "cpuFeatures" in targetObj ? "cpuFeatures" : "cpu_features";
                    string featStr = targetObj[key].str.toLower;
                    switch (featStr)
                    {
                        case "baseline": config.target.cpuFeatures = CpuFeature.Baseline; break;
                        case "native": config.target.cpuFeatures = CpuFeature.Native; break;
                        case "custom": config.target.cpuFeatures = CpuFeature.Custom; break;
                        default: config.target.cpuFeatures = CpuFeature.Baseline; break;
                    }
                }
                
                if ("customFeatures" in targetObj || "custom_features" in targetObj)
                {
                    string key = "customFeatures" in targetObj ? "customFeatures" : "custom_features";
                    config.target.customFeatures = targetObj[key].str;
                }
            }
        }
        
        // String fields
        if ("entry" in json) config.entry = json["entry"].str;
        if ("outputDir" in json || "output_dir" in json)
        {
            string key = "outputDir" in json ? "outputDir" : "output_dir";
            config.outputDir = json[key].str;
        }
        if ("outputName" in json || "output_name" in json)
        {
            string key = "outputName" in json ? "outputName" : "output_name";
            config.outputName = json[key].str;
        }
        if ("fmtExclude" in json || "fmt_exclude" in json)
        {
            string key = "fmtExclude" in json ? "fmtExclude" : "fmt_exclude";
            config.fmtExclude = json[key].str;
        }
        
        // Numeric fields
        if ("maxMemory" in json || "max_memory" in json)
        {
            string key = "maxMemory" in json ? "maxMemory" : "max_memory";
            config.maxMemory = json[key].integer.to!ulong;
        }
        if ("threads" in json) config.threads = json["threads"].integer.to!size_t;
        
        // Boolean fields
        if ("cppInterop" in json || "cpp_interop" in json)
        {
            string key = "cppInterop" in json ? "cppInterop" : "cpp_interop";
            config.cppInterop = json[key].type == JSONType.true_;
        }
        if ("singleThreaded" in json || "single_threaded" in json)
        {
            string key = "singleThreaded" in json ? "singleThreaded" : "single_threaded";
            config.singleThreaded = json[key].type == JSONType.true_;
        }
        if ("stackCheck" in json || "stack_check" in json)
        {
            string key = "stackCheck" in json ? "stackCheck" : "stack_check";
            config.stackCheck = json[key].type == JSONType.true_;
        }
        if ("redZone" in json || "red_zone" in json)
        {
            string key = "redZone" in json ? "redZone" : "red_zone";
            config.redZone = json[key].type == JSONType.true_;
        }
        if ("pic" in json) config.pic = json["pic"].type == JSONType.true_;
        if ("pie" in json) config.pie = json["pie"].type == JSONType.true_;
        if ("lto" in json) config.lto = json["lto"].type == JSONType.true_;
        if ("llvmVerifyModule" in json || "llvm_verify_module" in json)
        {
            string key = "llvmVerifyModule" in json ? "llvmVerifyModule" : "llvm_verify_module";
            config.llvmVerifyModule = json[key].type == JSONType.true_;
        }
        if ("llvmIrVerify" in json || "llvm_ir_verify" in json)
        {
            string key = "llvmIrVerify" in json ? "llvmIrVerify" : "llvm_ir_verify";
            config.llvmIrVerify = json[key].type == JSONType.true_;
        }
        if ("verbose" in json) config.verbose = json["verbose"].type == JSONType.true_;
        if ("timeReport" in json || "time_report" in json)
        {
            string key = "timeReport" in json ? "timeReport" : "time_report";
            config.timeReport = json[key].type == JSONType.true_;
        }
        if ("color" in json) config.color = json["color"].type == JSONType.true_;
        if ("runFmt" in json || "run_fmt" in json)
        {
            string key = "runFmt" in json ? "runFmt" : "run_fmt";
            config.runFmt = json[key].type == JSONType.true_;
        }
        if ("runCheck" in json || "run_check" in json)
        {
            string key = "runCheck" in json ? "runCheck" : "run_check";
            config.runCheck = json[key].type == JSONType.true_;
        }
        if ("fmtCheck" in json || "fmt_check" in json)
        {
            string key = "fmtCheck" in json ? "fmtCheck" : "fmt_check";
            config.fmtCheck = json[key].type == JSONType.true_;
        }
        
        // Array fields
        if ("cIncludeDirs" in json || "c_include_dirs" in json || "includes" in json)
        {
            string key = "cIncludeDirs" in json ? "cIncludeDirs" : 
                        ("c_include_dirs" in json ? "c_include_dirs" : "includes");
            config.cIncludeDirs = json[key].array.map!(e => e.str).array;
        }
        if ("cLibDirs" in json || "c_lib_dirs" in json || "lib_dirs" in json)
        {
            string key = "cLibDirs" in json ? "cLibDirs" : 
                        ("c_lib_dirs" in json ? "c_lib_dirs" : "lib_dirs");
            config.cLibDirs = json[key].array.map!(e => e.str).array;
        }
        if ("cLibs" in json || "c_libs" in json || "libs" in json)
        {
            string key = "cLibs" in json ? "cLibs" : 
                        ("c_libs" in json ? "c_libs" : "libs");
            config.cLibs = json[key].array.map!(e => e.str).array;
        }
        if ("sysLibs" in json || "sys_libs" in json || "system_libs" in json)
        {
            string key = "sysLibs" in json ? "sysLibs" : 
                        ("sys_libs" in json ? "sys_libs" : "system_libs");
            config.sysLibs = json[key].array.map!(e => e.str).array;
        }
        if ("cflags" in json)
            config.cflags = json["cflags"].array.map!(e => e.str).array;
        if ("ldflags" in json)
            config.ldflags = json["ldflags"].array.map!(e => e.str).array;
        
        // Build.zig configuration
        if ("buildZig" in json || "build_zig" in json)
        {
            string key = "buildZig" in json ? "buildZig" : "build_zig";
            auto bz = json[key];
            if ("path" in bz) config.buildZig.path = bz["path"].str;
            if ("steps" in bz)
                config.buildZig.steps = bz["steps"].array.map!(e => e.str).array;
            if ("prefix" in bz) config.buildZig.prefix = bz["prefix"].str;
            if ("sysroot" in bz) config.buildZig.sysroot = bz["sysroot"].str;
            if ("useSystemLinker" in bz || "use_system_linker" in bz)
            {
                string lkey = "useSystemLinker" in bz ? "useSystemLinker" : "use_system_linker";
                config.buildZig.useSystemLinker = bz[lkey].type == JSONType.true_;
            }
            if ("options" in bz)
            {
                foreach (string okey, value; bz["options"].object)
                {
                    config.buildZig.options[okey] = value.str;
                }
            }
        }
        
        // Test configuration
        if ("test" in json)
        {
            auto test = json["test"];
            if ("filter" in test) config.test.filter = test["filter"].str;
            if ("skipFilter" in test || "skip_filter" in test)
            {
                string key = "skipFilter" in test ? "skipFilter" : "skip_filter";
                config.test.skipFilter = test[key].str;
            }
            if ("verbose" in test) config.test.verbose = test["verbose"].type == JSONType.true_;
            if ("coverage" in test) config.test.coverage = test["coverage"].type == JSONType.true_;
            if ("coverageDir" in test || "coverage_dir" in test)
            {
                string key = "coverageDir" in test ? "coverageDir" : "coverage_dir";
                config.test.coverageDir = test[key].str;
            }
        }
        
        // Cache configuration
        if ("cache" in json)
        {
            auto cache = json["cache"];
            if ("globalCache" in cache || "global_cache" in cache)
            {
                string key = "globalCache" in cache ? "globalCache" : "global_cache";
                config.cache.globalCache = cache[key].type == JSONType.true_;
            }
            if ("cacheDir" in cache || "cache_dir" in cache)
            {
                string key = "cacheDir" in cache ? "cacheDir" : "cache_dir";
                config.cache.cacheDir = cache[key].str;
            }
            if ("incremental" in cache)
                config.cache.incremental = cache["incremental"].type == JSONType.true_;
        }
        
        // Packages
        if ("packages" in json)
        {
            foreach (pkg; json["packages"].array)
            {
                ZigPackage package_;
                if ("name" in pkg) package_.name = pkg["name"].str;
                if ("path" in pkg) package_.path = pkg["path"].str;
                if ("url" in pkg) package_.url = pkg["url"].str;
                if ("hash" in pkg) package_.hash = pkg["hash"].str;
                config.packages ~= package_;
            }
        }
        
        // Environment variables
        if ("env" in json)
        {
            foreach (string ekey, value; json["env"].object)
            {
                config.env[ekey] = value.str;
            }
        }
        
        return config;
    }
}

/// Zig compilation result
struct ZigCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string[] artifacts; // Additional artifacts (libs, docs, etc.)
    string outputHash;
    bool hadWarnings;
    string[] warnings;
    string[] toolOutput; // Output from fmt, check, etc.
}


