module languages.compiled.rust.tooling.builders.rustc;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.rust.tooling.builders.base;
import languages.compiled.rust.core.config;
import languages.compiled.rust.managers.toolchain;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Direct rustc builder - compiles without cargo
class RustcBuilder : RustBuilder
{
    RustCompileResult build(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        RustCompileResult result;
        
        if (sources.empty)
        {
            result.error = "No source files provided";
            return result;
        }
        
        Logger.debug_("Building Rust with rustc: " ~ sources.join(", "));
        
        // Build command based on mode
        final switch (config.mode)
        {
            case RustBuildMode.Compile:
                return compileTarget(sources, config, target, workspace);
            case RustBuildMode.Check:
                return checkTarget(sources, config, target, workspace);
            case RustBuildMode.Test:
                return testTarget(sources, config, target, workspace);
            case RustBuildMode.Doc:
                result.error = "Documentation generation requires cargo";
                return result;
            case RustBuildMode.Bench:
                result.error = "Benchmarks require cargo";
                return result;
            case RustBuildMode.Example:
                result.error = "Examples require cargo";
                return result;
            case RustBuildMode.Custom:
                return compileCustom(sources, config, target, workspace);
        }
    }
    
    bool isAvailable()
    {
        return Rustc.isAvailable();
    }
    
    string name() const
    {
        return "rustc";
    }
    
    string getVersion()
    {
        return Rustc.getVersion();
    }
    
    bool supportsFeature(string feature)
    {
        return feature == "compile" || feature == "check";
    }
    
    private RustCompileResult compileTarget(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        RustCompileResult result;
        
        // Determine output path
        string outputPath;
        if (!target.outputPath.empty)
            outputPath = buildPath(workspace.options.outputDir, target.outputPath);
        else
        {
            auto name = target.name.split(":")[$ - 1];
            outputPath = buildPath(workspace.options.outputDir, name);
        }
        
        // Create output directory
        string outputDir = dirName(outputPath);
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build rustc command
        string[] cmd = ["rustc"];
        
        // Entry point
        if (!config.entry.empty)
            cmd ~= [config.entry];
        else
            cmd ~= [sources[0]];
        
        // Output
        cmd ~= ["-o", outputPath];
        
        // Crate type
        cmd ~= ["--crate-type", crateTypeToString(config.crateType)];
        
        // Edition
        cmd ~= ["--edition", editionToString(config.edition)];
        
        // Optimization level
        if (config.release)
            cmd ~= ["-C", "opt-level=" ~ optLevelToString(config.optLevel)];
        else
            cmd ~= ["-C", "opt-level=0"];
        
        // Debug info
        if (config.debugInfo)
            cmd ~= ["-C", "debuginfo=2"];
        
        // LTO
        if (config.lto != LtoMode.Off)
            cmd ~= ["-C", "lto=" ~ ltoModeToString(config.lto)];
        
        // Codegen units
        if (config.codegen == Codegen.Single)
            cmd ~= ["-C", "codegen-units=1"];
        else if (config.codegen == Codegen.Custom)
            cmd ~= ["-C", "codegen-units=" ~ config.codegenUnits.to!string];
        
        // Target triple
        if (!config.target.empty)
            cmd ~= ["--target", config.target];
        
        // Add library paths for additional sources
        if (sources.length > 1)
        {
            foreach (source; sources[1 .. $])
            {
                string dir = dirName(source);
                cmd ~= ["-L", dir];
            }
        }
        
        // Add rustc flags
        cmd ~= config.rustcFlags;
        
        Logger.debug_("Rustc command: " ~ cmd.join(" "));
        
        // Set environment variables
        string[string] env = null;
        if (!config.env.empty)
            env = config.env.dup;
        
        // Execute compilation
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.error = "Rustc compilation failed:\n" ~ res.output;
            return result;
        }
        
        // Parse warnings
        parseRustcOutput(res.output, result);
        
        result.success = true;
        result.outputs = [outputPath];
        
        if (exists(outputPath))
            result.outputHash = FastHash.hashFile(outputPath);
        else
            result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult checkTarget(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        RustCompileResult result;
        
        // Build rustc command for checking
        string[] cmd = ["rustc"];
        
        // Entry point
        if (!config.entry.empty)
            cmd ~= [config.entry];
        else
            cmd ~= [sources[0]];
        
        // Check only (no code generation)
        cmd ~= ["--emit", "metadata"];
        cmd ~= ["--crate-type", "lib"];
        cmd ~= ["--edition", editionToString(config.edition)];
        
        // Target triple
        if (!config.target.empty)
            cmd ~= ["--target", config.target];
        
        // Add library paths
        if (sources.length > 1)
        {
            foreach (source; sources[1 .. $])
            {
                string dir = dirName(source);
                cmd ~= ["-L", dir];
            }
        }
        
        cmd ~= config.rustcFlags;
        
        Logger.debug_("Rustc check: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Rustc check failed:\n" ~ res.output;
            return result;
        }
        
        parseRustcOutput(res.output, result);
        
        result.success = true;
        result.outputHash = FastHash.hashString(res.output);
        
        return result;
    }
    
    private RustCompileResult testTarget(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        RustCompileResult result;
        
        // Build test binary
        string testBinary = buildPath(workspace.options.outputDir, "test-" ~ baseName(sources[0], ".rs"));
        
        string[] cmd = ["rustc"];
        
        if (!config.entry.empty)
            cmd ~= [config.entry];
        else
            cmd ~= [sources[0]];
        
        cmd ~= ["-o", testBinary];
        cmd ~= ["--test"];
        cmd ~= ["--edition", editionToString(config.edition)];
        
        if (!config.target.empty)
            cmd ~= ["--target", config.target];
        
        cmd ~= config.rustcFlags;
        
        Logger.debug_("Rustc test compile: " ~ cmd.join(" "));
        
        auto compileRes = execute(cmd);
        
        if (compileRes.status != 0)
        {
            result.error = "Test compilation failed:\n" ~ compileRes.output;
            return result;
        }
        
        // Run test binary
        Logger.debug_("Running tests: " ~ testBinary);
        
        string[] testCmd = [testBinary] ~ config.testFlags;
        auto testRes = execute(testCmd);
        
        if (testRes.status != 0)
        {
            result.error = "Tests failed:\n" ~ testRes.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashString(testRes.output);
        
        // Clean up test binary
        if (exists(testBinary))
            remove(testBinary);
        
        return result;
    }
    
    private RustCompileResult compileCustom(
        in string[] sources,
        in RustConfig config,
        in Target target,
        in WorkspaceConfig workspace
    )
    {
        RustCompileResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(sources);
        return result;
    }
    
    private void parseRustcOutput(string output, ref RustCompileResult result)
    {
        foreach (line; output.split("\n"))
        {
            if (line.canFind("warning:"))
            {
                result.hadWarnings = true;
                result.warnings ~= line;
            }
        }
    }
    
    private string crateTypeToString(CrateType type)
    {
        final switch (type)
        {
            case CrateType.Bin: return "bin";
            case CrateType.Lib: return "lib";
            case CrateType.Rlib: return "rlib";
            case CrateType.Dylib: return "dylib";
            case CrateType.Cdylib: return "cdylib";
            case CrateType.Staticlib: return "staticlib";
            case CrateType.ProcMacro: return "proc-macro";
        }
    }
    
    private string editionToString(RustEdition edition)
    {
        final switch (edition)
        {
            case RustEdition.Edition2015: return "2015";
            case RustEdition.Edition2018: return "2018";
            case RustEdition.Edition2021: return "2021";
            case RustEdition.Edition2024: return "2024";
        }
    }
    
    private string optLevelToString(OptLevel level)
    {
        final switch (level)
        {
            case OptLevel.O0: return "0";
            case OptLevel.O1: return "1";
            case OptLevel.O2: return "2";
            case OptLevel.O3: return "3";
            case OptLevel.Os: return "s";
            case OptLevel.Oz: return "z";
        }
    }
    
    private string ltoModeToString(LtoMode mode)
    {
        final switch (mode)
        {
            case LtoMode.Off: return "off";
            case LtoMode.Thin: return "thin";
            case LtoMode.Fat: return "fat";
        }
    }
}


