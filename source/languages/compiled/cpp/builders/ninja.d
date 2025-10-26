module languages.compiled.cpp.builders.ninja;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.cpp.core.config;
import languages.compiled.cpp.tooling.toolchain;
import languages.compiled.cpp.builders.base;
import config.schema.schema;
import analysis.targets.types;
import utils.files.hash;
import utils.logging.logger;

/// Ninja-based builder
class NinjaBuilder : BaseCppBuilder
{
    this(CppConfig config)
    {
        super(config);
    }
    
    override CppCompileResult build(
        string[] sources,
        CppConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        CppCompileResult result;
        
        if (!isAvailable())
        {
            result.error = "Ninja is not available";
            return result;
        }
        
        Logger.debug_("Building with Ninja");
        
        // Find build.ninja
        string ninjaFile = findNinjaFile(sources);
        if (ninjaFile.empty)
        {
            result.error = "build.ninja not found";
            return result;
        }
        
        string projectDir = dirName(ninjaFile);
        
        // Build with Ninja
        auto buildResult = buildNinja(projectDir, config, target);
        if (!buildResult.success)
        {
            result.error = "Ninja build failed: " ~ buildResult.error;
            return result;
        }
        
        // Find output files
        string outputFile = findNinjaOutput(projectDir, target, workspace);
        if (outputFile.empty || !exists(outputFile))
        {
            result.error = "Ninja output file not found";
            return result;
        }
        
        result.success = true;
        result.outputs = [outputFile];
        result.outputHash = FastHash.hashFile(outputFile);
        result.warnings = buildResult.warnings;
        result.hadWarnings = buildResult.hadWarnings;
        
        return result;
    }
    
    override bool isAvailable()
    {
        return Toolchain.isAvailable("ninja");
    }
    
    override string name() const
    {
        return "Ninja";
    }
    
    override string getVersion()
    {
        auto res = execute(["ninja", "--version"]);
        if (res.status == 0)
        {
            return "Ninja " ~ res.output.strip;
        }
        return "unknown";
    }
    
    private string findNinjaFile(string[] sources)
    {
        if (sources.empty)
            return "";
        
        string dir = dirName(sources[0]);
        
        // Search for build.ninja
        while (dir != "/" && dir.length > 1)
        {
            string ninjaPath = buildPath(dir, "build.ninja");
            if (exists(ninjaPath))
                return ninjaPath;
            
            dir = dirName(dir);
        }
        
        return "";
    }
    
    private CppCompileResult buildNinja(string projectDir, CppConfig config, Target target)
    {
        CppCompileResult result;
        
        string[] cmd = ["ninja"];
        
        // Parallel jobs
        if (config.jobs > 0)
        {
            cmd ~= ["-j", config.jobs.to!string];
        }
        
        // Verbose
        if (config.verbose)
        {
            cmd ~= ["-v"];
        }
        
        Logger.info("Building with Ninja...");
        Logger.debug_("Command: " ~ cmd.join(" "));
        
        // Execute in project directory
        auto res = execute(cmd, null, Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            result.error = res.output;
            return result;
        }
        
        // Parse warnings
        foreach (line; res.output.split("\n"))
        {
            if (line.canFind("warning:") || line.canFind("Warning:"))
            {
                result.hadWarnings = true;
                result.warnings ~= line;
            }
        }
        
        result.success = true;
        return result;
    }
    
    private string findNinjaOutput(string projectDir, Target target, WorkspaceConfig workspace)
    {
        string[] searchDirs = [
            projectDir,
            buildPath(projectDir, "bin"),
            buildPath(projectDir, "build"),
            buildPath(projectDir, "out")
        ];
        
        string targetName = target.name.split(":")[$ - 1];
        
        foreach (dir; searchDirs)
        {
            if (!exists(dir))
                continue;
            
            foreach (entry; dirEntries(dir, SpanMode.shallow))
            {
                if (entry.isFile && baseName(entry.name).canFind(targetName))
                {
                    return entry.name;
                }
            }
        }
        
        return "";
    }
}

