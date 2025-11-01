module languages.compiled.ocaml.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;

/// OCaml compiler selection
enum OCamlCompiler
{
    /// Auto-detect (prefer dune if exists, then ocamlopt, then ocamlc)
    Auto,
    /// Use dune build system
    Dune,
    /// Use ocamlopt (native compiler)
    OCamlOpt,
    /// Use ocamlc (bytecode compiler)
    OCamlC,
    /// Use ocamlbuild
    OCamlBuild
}

/// Optimization level
enum OptLevel
{
    /// No optimization
    None,
    /// Level 1 optimizations
    O1,
    /// Level 2 optimizations
    O2,
    /// Level 3 optimizations (aggressive)
    O3
}

/// Output type
enum OCamlOutputType
{
    /// Executable
    Executable,
    /// Library (static)
    Library,
    /// Bytecode executable
    Bytecode,
    /// Native code
    Native
}

/// Build profile for dune
enum DuneProfile
{
    /// Development profile
    Dev,
    /// Release profile
    Release
}

/// OCaml configuration
struct OCamlConfig
{
    /// Compiler to use
    OCamlCompiler compiler = OCamlCompiler.Auto;
    
    /// Optimization level
    OptLevel optimize = OptLevel.O2;
    
    /// Output type
    OCamlOutputType outputType = OCamlOutputType.Executable;
    
    /// Entry point file (.ml file)
    string entry;
    
    /// Output directory
    string outputDir = "_build";
    
    /// Output name
    string outputName;
    
    /// Include directories
    string[] includeDirs;
    
    /// Library directories
    string[] libDirs;
    
    /// Libraries to link
    string[] libs;
    
    /// Compiler flags
    string[] compilerFlags;
    
    /// Linker flags
    string[] linkerFlags;
    
    /// Package manager (opam) integration
    bool useOpam = true;
    
    /// Install dependencies before building
    bool installDeps = false;
    
    /// Dune-specific options
    DuneProfile duneProfile = DuneProfile.Release;
    string[] duneTargets;
    bool duneWatch = false;
    
    /// Enable warnings
    bool warnings = true;
    
    /// Treat warnings as errors
    bool warningsAsErrors = false;
    
    /// Enable debug info
    bool debugInfo = false;
    
    /// Generate documentation
    bool genDocs = false;
    
    /// Run formatter (ocamlformat)
    bool runFormat = false;
    
    /// Verbose output
    bool verbose = false;
    
    /// Parse from JSON
    static OCamlConfig fromJSON(JSONValue json)
    {
        OCamlConfig config;
        
        // Compiler selection
        if ("compiler" in json)
        {
            string compilerStr = json["compiler"].str.toLower;
            switch (compilerStr)
            {
                case "auto": config.compiler = OCamlCompiler.Auto; break;
                case "dune": config.compiler = OCamlCompiler.Dune; break;
                case "ocamlopt": case "opt": config.compiler = OCamlCompiler.OCamlOpt; break;
                case "ocamlc": case "bytecode": config.compiler = OCamlCompiler.OCamlC; break;
                case "ocamlbuild": case "build": config.compiler = OCamlCompiler.OCamlBuild; break;
                default: config.compiler = OCamlCompiler.Auto; break;
            }
        }
        
        // Optimization level
        if ("optimize" in json || "optimization" in json)
        {
            string key = "optimize" in json ? "optimize" : "optimization";
            auto optValue = json[key];
            if (optValue.type == JSONType.string)
            {
                string optStr = optValue.str.toLower;
                switch (optStr)
                {
                    case "none": case "0": config.optimize = OptLevel.None; break;
                    case "1": case "o1": config.optimize = OptLevel.O1; break;
                    case "2": case "o2": config.optimize = OptLevel.O2; break;
                    case "3": case "o3": config.optimize = OptLevel.O3; break;
                    default: config.optimize = OptLevel.O2; break;
                }
            }
            else if (optValue.type == JSONType.integer)
            {
                int level = cast(int)optValue.integer;
                switch (level)
                {
                    case 0: config.optimize = OptLevel.None; break;
                    case 1: config.optimize = OptLevel.O1; break;
                    case 2: config.optimize = OptLevel.O2; break;
                    case 3: config.optimize = OptLevel.O3; break;
                    default: config.optimize = OptLevel.O2; break;
                }
            }
        }
        
        // Output type
        if ("outputType" in json || "output_type" in json)
        {
            string key = "outputType" in json ? "outputType" : "output_type";
            string typeStr = json[key].str.toLower;
            switch (typeStr)
            {
                case "executable": case "exe": config.outputType = OCamlOutputType.Executable; break;
                case "library": case "lib": config.outputType = OCamlOutputType.Library; break;
                case "bytecode": case "byte": config.outputType = OCamlOutputType.Bytecode; break;
                case "native": config.outputType = OCamlOutputType.Native; break;
                default: config.outputType = OCamlOutputType.Executable; break;
            }
        }
        
        // Dune profile
        if ("duneProfile" in json || "dune_profile" in json || "profile" in json)
        {
            string key = "duneProfile" in json ? "duneProfile" : 
                        ("dune_profile" in json ? "dune_profile" : "profile");
            string profileStr = json[key].str.toLower;
            config.duneProfile = profileStr == "dev" ? DuneProfile.Dev : DuneProfile.Release;
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
        
        // Boolean fields
        if ("useOpam" in json || "use_opam" in json)
        {
            string key = "useOpam" in json ? "useOpam" : "use_opam";
            config.useOpam = json[key].type == JSONType.true_;
        }
        if ("installDeps" in json || "install_deps" in json)
        {
            string key = "installDeps" in json ? "installDeps" : "install_deps";
            config.installDeps = json[key].type == JSONType.true_;
        }
        if ("duneWatch" in json || "dune_watch" in json || "watch" in json)
        {
            string key = "duneWatch" in json ? "duneWatch" : 
                        ("dune_watch" in json ? "dune_watch" : "watch");
            config.duneWatch = json[key].type == JSONType.true_;
        }
        if ("warnings" in json) config.warnings = json["warnings"].type == JSONType.true_;
        if ("warningsAsErrors" in json || "warnings_as_errors" in json)
        {
            string key = "warningsAsErrors" in json ? "warningsAsErrors" : "warnings_as_errors";
            config.warningsAsErrors = json[key].type == JSONType.true_;
        }
        if ("debugInfo" in json || "debug_info" in json || "debug" in json)
        {
            string key = "debugInfo" in json ? "debugInfo" : 
                        ("debug_info" in json ? "debug_info" : "debug");
            config.debugInfo = json[key].type == JSONType.true_;
        }
        if ("genDocs" in json || "gen_docs" in json || "docs" in json)
        {
            string key = "genDocs" in json ? "genDocs" : 
                        ("gen_docs" in json ? "gen_docs" : "docs");
            config.genDocs = json[key].type == JSONType.true_;
        }
        if ("runFormat" in json || "run_format" in json || "format" in json)
        {
            string key = "runFormat" in json ? "runFormat" : 
                        ("run_format" in json ? "run_format" : "format");
            config.runFormat = json[key].type == JSONType.true_;
        }
        if ("verbose" in json) config.verbose = json["verbose"].type == JSONType.true_;
        
        // Array fields
        if ("includeDirs" in json || "include_dirs" in json || "includes" in json)
        {
            string key = "includeDirs" in json ? "includeDirs" : 
                        ("include_dirs" in json ? "include_dirs" : "includes");
            config.includeDirs = json[key].array.map!(e => e.str).array;
        }
        if ("libDirs" in json || "lib_dirs" in json)
        {
            string key = "libDirs" in json ? "libDirs" : "lib_dirs";
            config.libDirs = json[key].array.map!(e => e.str).array;
        }
        if ("libs" in json || "libraries" in json)
        {
            string key = "libs" in json ? "libs" : "libraries";
            config.libs = json[key].array.map!(e => e.str).array;
        }
        if ("compilerFlags" in json || "compiler_flags" in json || "flags" in json)
        {
            string key = "compilerFlags" in json ? "compilerFlags" : 
                        ("compiler_flags" in json ? "compiler_flags" : "flags");
            config.compilerFlags = json[key].array.map!(e => e.str).array;
        }
        if ("linkerFlags" in json || "linker_flags" in json || "ldflags" in json)
        {
            string key = "linkerFlags" in json ? "linkerFlags" : 
                        ("linker_flags" in json ? "linker_flags" : "ldflags");
            config.linkerFlags = json[key].array.map!(e => e.str).array;
        }
        if ("duneTargets" in json || "dune_targets" in json || "targets" in json)
        {
            string key = "duneTargets" in json ? "duneTargets" : 
                        ("dune_targets" in json ? "dune_targets" : "targets");
            config.duneTargets = json[key].array.map!(e => e.str).array;
        }
        
        return config;
    }
}

/// OCaml compilation result
struct OCamlCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string[] artifacts;
    string outputHash;
    bool hadWarnings;
    string[] warnings;
}


