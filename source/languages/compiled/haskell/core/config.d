module languages.compiled.haskell.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// Haskell build tool
enum HaskellBuildTool
{
    /// Auto-detect (prefer Stack if stack.yaml exists, else Cabal)
    Auto,
    /// Use GHC directly
    GHC,
    /// Use Cabal
    Cabal,
    /// Use Stack
    Stack
}

/// Haskell build mode
enum HaskellBuildMode
{
    /// Compile to executable
    Compile,
    /// Compile library
    Library,
    /// Run tests
    Test,
    /// Generate documentation
    Doc,
    /// Run REPL
    REPL,
    /// Custom build
    Custom
}

/// GHC optimization level
enum GHCOptLevel
{
    /// No optimization
    O0,
    /// Basic optimization
    O1,
    /// Full optimization (default)
    O2
}

/// Haskell language standard
enum HaskellStandard
{
    /// Haskell 98
    Haskell98,
    /// Haskell 2010 (default)
    Haskell2010
}

/// Haskell-specific configuration
struct HaskellConfig
{
    /// Build tool selection
    HaskellBuildTool buildTool = HaskellBuildTool.Auto;
    
    /// Build mode
    HaskellBuildMode mode = HaskellBuildMode.Compile;
    
    /// Optimization level
    GHCOptLevel optLevel = GHCOptLevel.O2;
    
    /// Language standard
    HaskellStandard standard = HaskellStandard.Haskell2010;
    
    /// Main module (e.g., "Main")
    string mainModule;
    
    /// Entry point file (e.g., "Main.hs")
    string entry;
    
    /// Output directory
    string outputDir;
    
    /// Package name (for Cabal/Stack)
    string packageName;
    
    /// Cabal file path
    string cabalFile;
    
    /// Stack file path
    string stackFile;
    
    /// GHC version constraint
    string ghcVersion;
    
    /// Enable profiling
    bool profiling = false;
    
    /// Enable coverage
    bool coverage = false;
    
    /// Enable warnings
    bool warnings = true;
    
    /// Treat warnings as errors
    bool werror = false;
    
    /// Enable parallel build
    bool parallel = true;
    
    /// Number of parallel jobs (0 = auto)
    size_t jobs = 0;
    
    /// Enable documentation generation
    bool haddock = false;
    
    /// GHC language extensions
    string[] extensions;
    
    /// GHC options
    string[] ghcOptions;
    
    /// Additional packages to depend on
    string[] packages;
    
    /// Include directories
    string[] includeDirs;
    
    /// Library directories
    string[] libDirs;
    
    /// Enable threaded runtime
    bool threaded = false;
    
    /// Enable static linking
    bool static_ = false;
    
    /// Enable dynamic linking
    bool dynamic = false;
    
    /// Run HLint (linter)
    bool hlint = false;
    
    /// Run Ormolu (formatter)
    bool ormolu = false;
    
    /// Run Fourmolu (alternative formatter)
    bool fourmolu = false;
    
    /// Custom GHC flags
    string[] customFlags;
    
    /// Environment variables
    string[string] env;
    
    /// Benchmark options
    string[] benchOptions;
    
    /// Test options
    string[] testOptions;
    
    /// Stack resolver (e.g., "lts-21.22")
    string resolver;
    
    /// Cabal constraint solver options
    bool cabalFreeze = false;
    
    /// Parse from JSON
    static HaskellConfig fromJSON(JSONValue json)
    {
        HaskellConfig config;
        
        // Build tool
        if ("buildTool" in json || "build_tool" in json)
        {
            string key = "buildTool" in json ? "buildTool" : "build_tool";
            string toolStr = json[key].str.toLower;
            switch (toolStr)
            {
                case "auto": config.buildTool = HaskellBuildTool.Auto; break;
                case "ghc": config.buildTool = HaskellBuildTool.GHC; break;
                case "cabal": config.buildTool = HaskellBuildTool.Cabal; break;
                case "stack": config.buildTool = HaskellBuildTool.Stack; break;
                default: config.buildTool = HaskellBuildTool.Auto; break;
            }
        }
        
        // Build mode
        if ("mode" in json)
        {
            string modeStr = json["mode"].str.toLower;
            switch (modeStr)
            {
                case "compile": config.mode = HaskellBuildMode.Compile; break;
                case "library": case "lib": config.mode = HaskellBuildMode.Library; break;
                case "test": config.mode = HaskellBuildMode.Test; break;
                case "doc": config.mode = HaskellBuildMode.Doc; break;
                case "repl": config.mode = HaskellBuildMode.REPL; break;
                case "custom": config.mode = HaskellBuildMode.Custom; break;
                default: config.mode = HaskellBuildMode.Compile; break;
            }
        }
        
        // Optimization level
        if ("optLevel" in json || "opt_level" in json)
        {
            string key = "optLevel" in json ? "optLevel" : "opt_level";
            string optStr = json[key].str.toLower;
            switch (optStr)
            {
                case "0": case "o0": config.optLevel = GHCOptLevel.O0; break;
                case "1": case "o1": config.optLevel = GHCOptLevel.O1; break;
                case "2": case "o2": config.optLevel = GHCOptLevel.O2; break;
                default: config.optLevel = GHCOptLevel.O2; break;
            }
        }
        
        // Language standard
        if ("standard" in json)
        {
            string stdStr = json["standard"].str.toLower;
            switch (stdStr)
            {
                case "haskell98": case "98": config.standard = HaskellStandard.Haskell98; break;
                case "haskell2010": case "2010": config.standard = HaskellStandard.Haskell2010; break;
                default: config.standard = HaskellStandard.Haskell2010; break;
            }
        }
        
        // String fields
        if ("mainModule" in json || "main_module" in json)
        {
            string key = "mainModule" in json ? "mainModule" : "main_module";
            config.mainModule = json[key].str;
        }
        if ("entry" in json) config.entry = json["entry"].str;
        if ("outputDir" in json || "output_dir" in json)
        {
            string key = "outputDir" in json ? "outputDir" : "output_dir";
            config.outputDir = json[key].str;
        }
        if ("packageName" in json || "package_name" in json)
        {
            string key = "packageName" in json ? "packageName" : "package_name";
            config.packageName = json[key].str;
        }
        if ("cabalFile" in json || "cabal_file" in json)
        {
            string key = "cabalFile" in json ? "cabalFile" : "cabal_file";
            config.cabalFile = json[key].str;
        }
        if ("stackFile" in json || "stack_file" in json)
        {
            string key = "stackFile" in json ? "stackFile" : "stack_file";
            config.stackFile = json[key].str;
        }
        if ("ghcVersion" in json || "ghc_version" in json)
        {
            string key = "ghcVersion" in json ? "ghcVersion" : "ghc_version";
            config.ghcVersion = json[key].str;
        }
        if ("resolver" in json) config.resolver = json["resolver"].str;
        
        // Numeric fields
        if ("jobs" in json) config.jobs = json["jobs"].integer.to!size_t;
        
        // Boolean fields
        if ("profiling" in json) config.profiling = json["profiling"].type == JSONType.true_;
        if ("coverage" in json) config.coverage = json["coverage"].type == JSONType.true_;
        if ("warnings" in json) config.warnings = json["warnings"].type == JSONType.true_;
        if ("werror" in json) config.werror = json["werror"].type == JSONType.true_;
        if ("parallel" in json) config.parallel = json["parallel"].type == JSONType.true_;
        if ("haddock" in json) config.haddock = json["haddock"].type == JSONType.true_;
        if ("threaded" in json) config.threaded = json["threaded"].type == JSONType.true_;
        if ("static" in json) config.static_ = json["static"].type == JSONType.true_;
        if ("dynamic" in json) config.dynamic = json["dynamic"].type == JSONType.true_;
        if ("hlint" in json) config.hlint = json["hlint"].type == JSONType.true_;
        if ("ormolu" in json) config.ormolu = json["ormolu"].type == JSONType.true_;
        if ("fourmolu" in json) config.fourmolu = json["fourmolu"].type == JSONType.true_;
        if ("cabalFreeze" in json || "cabal_freeze" in json)
        {
            string key = "cabalFreeze" in json ? "cabalFreeze" : "cabal_freeze";
            config.cabalFreeze = json[key].type == JSONType.true_;
        }
        
        // Array fields
        if ("extensions" in json)
            config.extensions = json["extensions"].array.map!(e => e.str).array;
        if ("ghcOptions" in json || "ghc_options" in json)
        {
            string key = "ghcOptions" in json ? "ghcOptions" : "ghc_options";
            config.ghcOptions = json[key].array.map!(e => e.str).array;
        }
        if ("packages" in json)
            config.packages = json["packages"].array.map!(e => e.str).array;
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
        if ("customFlags" in json || "custom_flags" in json)
        {
            string key = "customFlags" in json ? "customFlags" : "custom_flags";
            config.customFlags = json[key].array.map!(e => e.str).array;
        }
        if ("benchOptions" in json || "bench_options" in json)
        {
            string key = "benchOptions" in json ? "benchOptions" : "bench_options";
            config.benchOptions = json[key].array.map!(e => e.str).array;
        }
        if ("testOptions" in json || "test_options" in json)
        {
            string key = "testOptions" in json ? "testOptions" : "test_options";
            config.testOptions = json[key].array.map!(e => e.str).array;
        }
        
        // Map fields
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

/// Haskell compilation result
struct HaskellCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    bool hadWarnings;
    string[] warnings;
    bool hadHLintIssues;
    string[] hlintIssues;
}

