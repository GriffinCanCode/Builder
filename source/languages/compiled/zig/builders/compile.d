module languages.compiled.zig.builders.compile;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import languages.compiled.zig.core.config;
import languages.compiled.zig.tooling.tools;
import languages.compiled.zig.builders.base;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Builder using direct zig compile commands
class CompileBuilder : ZigBuilder
{
    ZigCompileResult build(
        string[] sources,
        ZigConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ZigCompileResult result;
        
        if (sources.empty)
        {
            result.error = "No source files specified";
            return result;
        }
        
        // Determine entry point
        string entryPoint = config.entry.empty ? sources[0] : config.entry;
        
        if (!exists(entryPoint))
        {
            result.error = "Entry point not found: " ~ entryPoint;
            return result;
        }
        
        // Build based on mode
        final switch (config.mode)
        {
            case ZigBuildMode.Compile:
                result = compileTarget(sources, config, target, workspace);
                break;
            case ZigBuildMode.Test:
                result = runTests(sources, config, target, workspace);
                break;
            case ZigBuildMode.Run:
                result = buildAndRun(sources, config, target, workspace);
                break;
            case ZigBuildMode.Check:
                result = checkOnly(sources, config);
                break;
            case ZigBuildMode.TranslateC:
                result.error = "translate-c not yet implemented in compile builder";
                return result;
            case ZigBuildMode.BuildScript:
                result.error = "Use BuildZigBuilder for build.zig projects";
                return result;
            case ZigBuildMode.Custom:
                result = compileTarget(sources, config, target, workspace);
                break;
        }
        
        return result;
    }
    
    bool isAvailable()
    {
        return ZigTools.isZigAvailable();
    }
    
    string name() const
    {
        return "compile";
    }
    
    string getVersion()
    {
        return ZigTools.getZigVersion();
    }
    
    bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "compile":
            case "test":
            case "run":
            case "check":
            case "cross-compile":
                return true;
            default:
                return false;
        }
    }
    
    /// Compile target directly
    private ZigCompileResult compileTarget(
        string[] sources,
        ZigConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ZigCompileResult result;
        
        // Determine output path
        string outputPath = getOutputPath(config, target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build command based on output type
        string[] cmd;
        
        final switch (config.outputType)
        {
            case OutputType.Exe:
                cmd = ["zig", "build-exe"];
                break;
            case OutputType.Lib:
                cmd = ["zig", "build-lib"];
                break;
            case OutputType.Dylib:
                cmd = ["zig", "build-lib", "-dynamic"];
                break;
            case OutputType.Obj:
                cmd = ["zig", "build-obj"];
                break;
        }
        
        // Add entry point
        cmd ~= config.entry.empty ? sources[0] : config.entry;
        
        // Add other sources as packages
        foreach (i, source; sources[1 .. $])
        {
            string modName = baseName(source, extension(source));
            cmd ~= ["--mod", modName ~ ":" ~ source];
        }
        
        // Add packages/dependencies
        foreach (pkg; config.packages)
        {
            if (!pkg.path.empty && exists(pkg.path))
            {
                cmd ~= ["--mod", pkg.name ~ ":" ~ pkg.path];
            }
        }
        
        // Add optimization mode
        final switch (config.optimize)
        {
            case OptMode.Debug:
                cmd ~= "-ODebug";
                break;
            case OptMode.ReleaseSafe:
                cmd ~= "-OReleaseSafe";
                break;
            case OptMode.ReleaseFast:
                cmd ~= "-OReleaseFast";
                break;
            case OptMode.ReleaseSmall:
                cmd ~= "-OReleaseSmall";
                break;
        }
        
        // Add target for cross-compilation
        if (config.target.isCross())
        {
            cmd ~= "-target";
            cmd ~= config.target.toTargetFlag();
        }
        
        // Add CPU features
        if (config.target.cpuFeatures == CpuFeature.Native)
        {
            cmd ~= "-mcpu=native";
        }
        else if (config.target.cpuFeatures == CpuFeature.Custom && !config.target.customFeatures.empty)
        {
            cmd ~= "-mcpu=" ~ config.target.customFeatures;
        }
        
        // Add C include directories
        foreach (inc; config.cIncludeDirs)
        {
            cmd ~= "-I" ~ inc;
        }
        
        // Add C library directories
        foreach (lib; config.cLibDirs)
        {
            cmd ~= "-L" ~ lib;
        }
        
        // Add C libraries
        foreach (lib; config.cLibs)
        {
            cmd ~= "-l" ~ lib;
        }
        
        // Add system libraries
        foreach (lib; config.sysLibs)
        {
            cmd ~= "-l" ~ lib;
        }
        
        // Add C flags
        cmd ~= config.cflags.map!(f => "-cflags " ~ f).array;
        
        // Add link mode
        if (config.linkMode == LinkMode.Static)
        {
            cmd ~= "-static";
        }
        
        // Add strip mode
        final switch (config.strip)
        {
            case StripMode.None:
                break;
            case StripMode.Debug:
                cmd ~= "-fstrip";
                break;
            case StripMode.All:
                cmd ~= "-fstrip";
                break;
        }
        
        // Add PIC/PIE
        if (config.pic)
            cmd ~= "-fPIC";
        if (config.pie)
            cmd ~= "-fPIE";
        
        // Add LTO
        if (config.lto)
            cmd ~= "-flto";
        
        // Add single-threaded
        if (config.singleThreaded)
            cmd ~= "-fsingle-threaded";
        
        // Add stack check
        if (!config.stackCheck)
            cmd ~= "-fno-stack-check";
        
        // Add red zone
        if (!config.redZone)
            cmd ~= "-mred-zone";
        
        // Add code model
        if (config.codeModel != CodeModel.Default)
        {
            final switch (config.codeModel)
            {
                case CodeModel.Default: break;
                case CodeModel.Tiny: cmd ~= "-mcmodel=tiny"; break;
                case CodeModel.Small: cmd ~= "-mcmodel=small"; break;
                case CodeModel.Kernel: cmd ~= "-mcmodel=kernel"; break;
                case CodeModel.Medium: cmd ~= "-mcmodel=medium"; break;
                case CodeModel.Large: cmd ~= "-mcmodel=large"; break;
            }
        }
        
        // Add output path
        cmd ~= ["-femit-bin=" ~ outputPath];
        
        // Add cache directory
        if (!config.cache.cacheDir.empty)
        {
            cmd ~= "--cache-dir";
            cmd ~= config.cache.cacheDir;
        }
        
        // Add global cache option
        if (!config.cache.globalCache)
        {
            cmd ~= "--global-cache-dir";
            cmd ~= buildPath(workspace.root, ".zig-cache");
        }
        
        // Add verbose
        if (config.verbose)
            cmd ~= "--verbose";
        
        // Add time report
        if (config.timeReport)
            cmd ~= "--verbose-link";
        
        // Add color
        if (!config.color)
            cmd ~= "-fno-color";
        
        // Add LLVM options
        if (!config.llvmVerifyModule)
            cmd ~= "-fno-llvm-module-verification";
        if (!config.llvmIrVerify)
            cmd ~= "-fno-llvm-ir-verification";
        
        // Add target flags
        cmd ~= target.flags;
        
        Logger.info("Compiling with zig: " ~ cmd.join(" "));
        
        // Prepare environment
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Add custom environment variables
        foreach (key, value; config.env)
            env[key] = value;
        
        // Execute compilation
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.error = "Compilation failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        // Parse warnings
        foreach (line; res.output.lineSplitter)
        {
            if (line.canFind("warning:"))
            {
                result.warnings ~= line.strip;
                result.hadWarnings = true;
            }
        }
        
        return result;
    }
    
    /// Run tests
    private ZigCompileResult runTests(
        string[] sources,
        ZigConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        ZigCompileResult result;
        
        foreach (source; sources)
        {
            if (!exists(source))
                continue;
            
            string[] cmd = ["zig", "test"];
            
            // Add optimization
            final switch (config.optimize)
            {
                case OptMode.Debug: cmd ~= "-ODebug"; break;
                case OptMode.ReleaseSafe: cmd ~= "-OReleaseSafe"; break;
                case OptMode.ReleaseFast: cmd ~= "-OReleaseFast"; break;
                case OptMode.ReleaseSmall: cmd ~= "-OReleaseSmall"; break;
            }
            
            // Add target
            if (config.target.isCross())
            {
                cmd ~= "-target";
                cmd ~= config.target.toTargetFlag();
            }
            
            // Add test filter
            if (!config.test.filter.empty)
            {
                cmd ~= "--test-filter";
                cmd ~= config.test.filter;
            }
            
            // Add test skip filter
            if (!config.test.skipFilter.empty)
            {
                cmd ~= "--test-name-prefix";
                cmd ~= config.test.skipFilter;
            }
            
            // Add target flags
            cmd ~= target.flags;
            
            // Add source
            cmd ~= source;
            
            Logger.info("Running tests: " ~ cmd.join(" "));
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Tests failed in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    /// Build and run
    private ZigCompileResult buildAndRun(
        string[] sources,
        ZigConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        // First compile
        auto compileResult = compileTarget(sources, config, target, workspace);
        if (!compileResult.success)
            return compileResult;
        
        // Then run
        if (!compileResult.outputs.empty)
        {
            string exe = compileResult.outputs[0];
            Logger.info("Running: " ~ exe);
            
            auto res = execute([exe]);
            if (res.status != 0)
            {
                compileResult.error = "Execution failed: " ~ res.output;
                compileResult.success = false;
            }
        }
        
        return compileResult;
    }
    
    /// Check only (no code generation)
    private ZigCompileResult checkOnly(string[] sources, ZigConfig config)
    {
        ZigCompileResult result;
        
        foreach (source; sources)
        {
            if (!exists(source))
                continue;
            
            string[] cmd = ["zig", "ast-check", source];
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Check failed in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(sources);
        
        return result;
    }
    
    /// Get output path
    private string getOutputPath(ZigConfig config, Target target, WorkspaceConfig workspace)
    {
        if (!config.outputName.empty)
        {
            return buildPath(config.outputDir, config.outputName);
        }
        
        if (!target.outputPath.empty)
        {
            return buildPath(workspace.options.outputDir, target.outputPath);
        }
        
        auto name = target.name.split(":")[$ - 1];
        
        // Add extension based on platform
        version(Windows)
        {
            if (config.outputType == OutputType.Exe)
                name ~= ".exe";
        }
        
        return buildPath(config.outputDir, name);
    }
}


