module languages.compiled.nim.builders.compile;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.nim.builders.base;
import languages.compiled.nim.core.config;
import languages.compiled.nim.tooling.tools;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Direct Nim compiler builder - for direct nim c/cpp/js invocations
class CompileBuilder : NimBuilder
{
    NimCompileResult build(
        string[] sources,
        NimConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        NimCompileResult result;
        
        // Ensure we have a source to compile
        if (sources.empty && config.entry.empty)
        {
            result.error = "No source files specified";
            return result;
        }
        
        string entryPoint = config.entry.empty ? sources[0] : config.entry;
        
        // Determine output path
        string outputPath = determineOutputPath(entryPoint, config, target, workspace);
        string outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build command based on backend
        string[] cmd = buildCompileCommand(entryPoint, outputPath, config);
        
        // Log the command
        if (config.verbose || config.listCmd)
        {
            Logger.info("Nim compile command: " ~ cmd.join(" "));
        }
        
        // Set environment variables
        string[string] env = environment.toAA();
        foreach (key, value; config.env)
        {
            env[key] = value;
        }
        
        // Execute compilation
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.error = "Nim compilation failed: " ~ res.output;
            return result;
        }
        
        // Parse warnings and hints from output
        parseCompilerOutput(res.output, result);
        
        // Verify output exists
        if (!exists(outputPath))
        {
            result.error = "Compilation succeeded but output file not found: " ~ outputPath;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        // Collect additional artifacts (nimcache, etc.)
        collectArtifacts(config, result);
        
        return result;
    }
    
    bool isAvailable()
    {
        return NimTools.isNimAvailable();
    }
    
    string name() const
    {
        return "nim-compile";
    }
    
    string getVersion()
    {
        return NimTools.getNimVersion();
    }
    
    bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "compile":
            case "c-backend":
            case "cpp-backend":
            case "objc-backend":
            case "cross-compile":
            case "optimization":
                return true;
            default:
                return false;
        }
    }
    
    private string determineOutputPath(
        string entryPoint,
        NimConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        // Use explicit output if specified
        if (!config.output.empty)
        {
            if (config.outputDir.empty)
                return buildPath(workspace.options.outputDir, config.output);
            else
                return buildPath(config.outputDir, config.output);
        }
        
        // Use target output path
        if (!target.outputPath.empty)
        {
            return buildPath(workspace.options.outputDir, target.outputPath);
        }
        
        // Generate from entry point
        string baseName = stripExtension(baseName(entryPoint));
        string outputDir = config.outputDir.empty ? workspace.options.outputDir : config.outputDir;
        
        // Add platform-specific extension
        string extension = "";
        if (config.appType == AppType.Console || config.appType == AppType.Gui)
        {
            version(Windows)
                extension = ".exe";
        }
        else if (config.appType == AppType.DynamicLib)
        {
            version(Windows)
                extension = ".dll";
            else version(OSX)
                extension = ".dylib";
            else
                extension = ".so";
        }
        else if (config.appType == AppType.StaticLib)
        {
            version(Windows)
                extension = ".lib";
            else
                extension = ".a";
        }
        
        return buildPath(outputDir, baseName ~ extension);
    }
    
    private string[] buildCompileCommand(string entryPoint, string outputPath, NimConfig config)
    {
        string[] cmd = ["nim"];
        
        // Backend selection
        final switch (config.backend)
        {
            case NimBackend.C:
                cmd ~= "c";
                break;
            case NimBackend.Cpp:
                cmd ~= "cpp";
                break;
            case NimBackend.Js:
                cmd ~= "js";
                break;
            case NimBackend.ObjC:
                cmd ~= "objc";
                break;
        }
        
        // Output specification
        cmd ~= "--out:" ~ outputPath;
        
        // Nimcache directory
        if (!config.nimCache.empty)
            cmd ~= "--nimcache:" ~ config.nimCache;
        
        // Optimization
        if (config.release)
        {
            cmd ~= "-d:release";
        }
        else
        {
            final switch (config.optimize)
            {
                case OptLevel.None:
                    cmd ~= "--opt:none";
                    break;
                case OptLevel.Speed:
                    cmd ~= "--opt:speed";
                    break;
                case OptLevel.Size:
                    cmd ~= "--opt:size";
                    break;
            }
        }
        
        // Danger mode (disables all checks)
        if (config.danger)
            cmd ~= "-d:danger";
        
        // GC strategy
        if (config.gc != GcStrategy.Orc) // Orc is default in modern Nim
        {
            string gcName = config.gc.to!string.toLower;
            cmd ~= "--gc:" ~ gcName;
        }
        
        // Application type
        final switch (config.appType)
        {
            case AppType.Console:
                cmd ~= "--app:console";
                break;
            case AppType.Gui:
                cmd ~= "--app:gui";
                break;
            case AppType.StaticLib:
                cmd ~= "--app:staticlib";
                break;
            case AppType.DynamicLib:
                cmd ~= "--app:lib";
                break;
        }
        
        // Debug and runtime checks
        if (config.debugInfo)
            cmd ~= "--debugger:native";
        
        if (!config.checks)
            cmd ~= "--checks:off";
        
        if (!config.assertions)
            cmd ~= "--assertions:off";
        
        if (config.lineTrace)
            cmd ~= "--lineTrace:on";
        
        if (config.stackTrace)
            cmd ~= "--stackTrace:on";
        else
            cmd ~= "--stackTrace:off";
        
        if (config.profiler)
            cmd ~= "--profiler:on";
        
        // Cross-compilation
        if (config.target.isCross())
            cmd ~= config.target.toFlags();
        
        // Threading
        if (config.threads.enabled)
            cmd ~= "--threads:on";
        
        // Defines
        foreach (define; config.defines)
            cmd ~= "-d:" ~ define;
        
        foreach (undef; config.undefines)
            cmd ~= "-u:" ~ undef;
        
        // Paths
        if (config.path.clearPaths)
            cmd ~= "--clearNimblePath";
        
        foreach (path; config.path.paths)
            cmd ~= "--path:" ~ path;
        
        foreach (nimblePath; config.path.nimblePaths)
            cmd ~= "--nimblePath:" ~ nimblePath;
        
        // C compiler options (for C/C++ backends)
        if (config.backend == NimBackend.C || config.backend == NimBackend.Cpp)
        {
            if (!config.cCompiler.empty && config.backend == NimBackend.C)
                cmd ~= "--cc:" ~ config.cCompiler;
            
            if (!config.cppCompiler.empty && config.backend == NimBackend.Cpp)
                cmd ~= "--cc:" ~ config.cppCompiler;
            
            foreach (incDir; config.includeDirs)
                cmd ~= "--cincludes:" ~ incDir;
            
            foreach (libDir; config.libDirs)
                cmd ~= "--clibdir:" ~ libDir;
            
            foreach (lib; config.libs)
                cmd ~= "--lib:" ~ lib;
            
            foreach (cflag; config.passCFlags)
                cmd ~= "--passC:" ~ cflag;
            
            foreach (lflag; config.passLFlags)
                cmd ~= "--passL:" ~ lflag;
        }
        
        // Hints and warnings
        foreach (hint; config.hints.enable)
            cmd ~= "--hint:" ~ hint ~ ":on";
        
        foreach (hint; config.hints.disable)
            cmd ~= "--hint:" ~ hint ~ ":off";
        
        foreach (warn; config.hints.enableWarnings)
            cmd ~= "--warning:" ~ warn ~ ":on";
        
        foreach (warn; config.hints.disableWarnings)
            cmd ~= "--warning:" ~ warn ~ ":off";
        
        if (config.hints.warningsAsErrors)
            cmd ~= "--warningAsError";
        
        if (config.hints.hintsAsErrors)
            cmd ~= "--hintAsError";
        
        // Experimental features
        if (config.experimental.enabled)
        {
            foreach (feature; config.experimental.features)
                cmd ~= "--experimental:" ~ feature;
        }
        
        // Additional compiler flags
        cmd ~= config.compilerFlags;
        
        // Verbose output
        if (config.verbose)
            cmd ~= "--verbose";
        
        // Force rebuild
        if (config.forceBuild)
            cmd ~= "--forceBuild";
        
        // Parallel build
        if (config.parallel && config.parallelJobs > 0)
            cmd ~= "--parallelBuild:" ~ config.parallelJobs.to!string;
        else if (config.parallel)
            cmd ~= "--parallelBuild:0"; // Auto
        
        // List commands
        if (config.listCmd)
            cmd ~= "--listCmd";
        
        // Colors
        if (!config.colors)
            cmd ~= "--colors:off";
        
        // Nim stdlib override
        if (!config.nimStdlib.empty)
            cmd ~= "--lib:" ~ config.nimStdlib;
        
        // Entry point source file
        cmd ~= entryPoint;
        
        return cmd;
    }
    
    private void parseCompilerOutput(string output, ref NimCompileResult result)
    {
        import std.regex;
        
        // Parse warnings
        auto warningRegex = regex(`Warning:.*$", "m`);
        foreach (match; matchAll(output, warningRegex))
        {
            result.warnings ~= match.hit;
            result.hadWarnings = true;
        }
        
        // Parse hints
        auto hintRegex = regex(`Hint:.*$", "m`);
        foreach (match; matchAll(output, hintRegex))
        {
            result.hints ~= match.hit;
        }
    }
    
    private void collectArtifacts(NimConfig config, ref NimCompileResult result)
    {
        // Add nimcache directory as artifact (contains generated C code)
        if (!config.nimCache.empty && exists(config.nimCache))
        {
            result.artifacts ~= config.nimCache;
        }
    }
}

