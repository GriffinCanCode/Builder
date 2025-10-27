module languages.compiled.zig.builders.build;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.string;
import languages.compiled.zig.core.config;
import languages.compiled.zig.analysis.builder;
import languages.compiled.zig.tooling.tools;
import languages.compiled.zig.builders.base;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Builder using build.zig build system
class BuildZigBuilder : ZigBuilder
{
    ZigCompileResult build(
        const string[] sources,
        ZigConfig config,
        const Target target,
        const WorkspaceConfig workspace
    )
    {
        ZigCompileResult result;
        
        // Determine working directory
        string workDir = workspace.root;
        if (!sources.empty)
            workDir = dirName(sources[0]);
        
        // Find build.zig
        string buildZigPath = config.buildZig.path;
        if (buildZigPath.empty || !exists(buildPath(workDir, buildZigPath)))
        {
            buildZigPath = BuildZigParser.findBuildZig(workDir);
            if (buildZigPath.empty)
            {
                result.error = "build.zig not found in project";
                return result;
            }
            workDir = dirName(buildZigPath);
        }
        
        Logger.debug_("Using build.zig at: " ~ buildZigPath);
        
        // Parse build.zig to get project info
        auto project = BuildZigParser.parseBuildZig(buildZigPath);
        if (!project.name.empty)
        {
            Logger.debug_("Building project: " ~ project.name ~ 
                         (project.version_.empty ? "" : " v" ~ project.version_));
        }
        
        // Build command
        string[] cmd = ["zig", "build"];
        
        // Add build steps
        if (!config.buildZig.steps.empty)
        {
            cmd ~= config.buildZig.steps;
        }
        
        // Add optimization mode
        final switch (config.optimize)
        {
            case OptMode.Debug:
                cmd ~= "-Doptimize=Debug";
                break;
            case OptMode.ReleaseSafe:
                cmd ~= "-Doptimize=ReleaseSafe";
                break;
            case OptMode.ReleaseFast:
                cmd ~= "-Doptimize=ReleaseFast";
                break;
            case OptMode.ReleaseSmall:
                cmd ~= "-Doptimize=ReleaseSmall";
                break;
        }
        
        // Add target if specified
        if (config.target.isCross())
        {
            cmd ~= "-Dtarget=" ~ config.target.toTargetFlag();
        }
        
        // Add CPU features
        if (config.target.cpuFeatures == CpuFeature.Native)
        {
            cmd ~= "-Dcpu=native";
        }
        else if (config.target.cpuFeatures == CpuFeature.Custom && !config.target.customFeatures.empty)
        {
            cmd ~= "-Dcpu=" ~ config.target.customFeatures;
        }
        
        // Add prefix for install
        if (!config.buildZig.prefix.empty)
        {
            cmd ~= "--prefix";
            cmd ~= config.buildZig.prefix;
        }
        else if (!config.outputDir.empty)
        {
            cmd ~= "--prefix";
            cmd ~= config.outputDir;
        }
        
        // Add custom build options
        foreach (key, value; config.buildZig.options)
        {
            cmd ~= "-D" ~ key ~ "=" ~ value;
        }
        
        // Add system library integration
        if (!config.buildZig.sysroot.empty)
        {
            cmd ~= "--sysroot";
            cmd ~= config.buildZig.sysroot;
        }
        
        // Add linker option
        if (config.buildZig.useSystemLinker)
        {
            cmd ~= "--system";
        }
        
        // Add verbose flag
        if (config.verbose)
        {
            cmd ~= "--verbose";
        }
        
        // Add target flags if specified
        cmd ~= target.flags;
        
        Logger.info("Building with zig build: " ~ cmd.join(" "));
        
        // Prepare environment
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Add custom environment variables
        foreach (key, value; config.env)
            env[key] = value;
        
        // Execute build
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "zig build failed: " ~ res.output;
            return result;
        }
        
        // Determine outputs
        string outputDir = config.buildZig.prefix.empty ? 
                          buildPath(workDir, config.outputDir) :
                          config.buildZig.prefix;
        
        string[] outputs = collectOutputs(outputDir, target);
        
        if (outputs.empty)
        {
            // Try common output locations
            outputs = findDefaultOutputs(workDir, config, target);
        }
        
        result.success = true;
        result.outputs = outputs;
        
        // Hash outputs
        if (!outputs.empty && exists(outputs[0]))
            result.outputHash = FastHash.hashFile(outputs[0]);
        else
            result.outputHash = FastHash.hashStrings(sources);
        
        // Parse warnings from output
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
    
    bool isAvailable()
    {
        return ZigTools.isZigAvailable();
    }
    
    string name() const
    {
        return "build-zig";
    }
    
    string getVersion()
    {
        return ZigTools.getZigVersion();
    }
    
    bool supportsFeature(string feature)
    {
        switch (feature)
        {
            case "build-script":
            case "dependencies":
            case "modules":
            case "tests":
            case "install":
                return true;
            default:
                return false;
        }
    }
    
    /// Collect outputs from build directory
    private string[] collectOutputs(string outputDir, const Target target)
    {
        string[] outputs;
        
        if (!exists(outputDir))
            return outputs;
        
        // Look in bin/ subdirectory
        string binDir = buildPath(outputDir, "bin");
        if (exists(binDir) && isDir(binDir))
        {
            foreach (entry; dirEntries(binDir, SpanMode.shallow))
            {
                if (entry.isFile)
                {
                    outputs ~= entry.name;
                }
            }
        }
        
        // Look in lib/ subdirectory for libraries
        if (target.type == TargetType.Library)
        {
            string libDir = buildPath(outputDir, "lib");
            if (exists(libDir) && isDir(libDir))
            {
                foreach (entry; dirEntries(libDir, SpanMode.shallow))
                {
                    if (entry.isFile)
                    {
                        outputs ~= entry.name;
                    }
                }
            }
        }
        
        return outputs;
    }
    
    /// Find default output locations
    private string[] findDefaultOutputs(string workDir, ZigConfig config, const Target target)
    {
        string[] outputs;
        
        // Common output locations
        string[] searchDirs = [
            buildPath(workDir, "zig-out", "bin"),
            buildPath(workDir, "zig-out", "lib"),
            buildPath(workDir, config.outputDir, "bin"),
            buildPath(workDir, config.outputDir, "lib"),
        ];
        
        foreach (dir; searchDirs)
        {
            if (exists(dir) && isDir(dir))
            {
                foreach (entry; dirEntries(dir, SpanMode.shallow))
                {
                    if (entry.isFile)
                    {
                        // Filter by target type
                        bool isLibrary = entry.name.endsWith(".a") || 
                                        entry.name.endsWith(".so") ||
                                        entry.name.endsWith(".dylib");
                        
                        if (target.type == TargetType.Library && isLibrary)
                        {
                            outputs ~= entry.name;
                        }
                        else if (target.type == TargetType.Executable && !isLibrary)
                        {
                            outputs ~= entry.name;
                        }
                    }
                }
                
                if (!outputs.empty)
                    break;
            }
        }
        
        return outputs;
    }
}


