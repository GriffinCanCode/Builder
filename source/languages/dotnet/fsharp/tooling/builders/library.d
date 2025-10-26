module languages.dotnet.fsharp.tooling.builders.library;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.datetime.stopwatch;
import languages.dotnet.fsharp.tooling.builders.base;
import languages.dotnet.fsharp.core.config;
import languages.dotnet.fsharp.managers.dotnet;
import analysis.targets.types;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Builder for F# libraries (DLL)
class LibraryBuilder : FSharpBuilder
{
    FSharpBuildResult build(string[] sources, FSharpConfig config, Target target, WorkspaceConfig workspaceConfig)
    {
        FSharpBuildResult result;
        auto sw = StopWatch(AutoStart.yes);
        
        // Check for .fsproj file
        auto fsprojFile = sources.find!(s => s.endsWith(".fsproj"));
        
        if (!fsprojFile.empty)
        {
            // Use dotnet build
            result = buildWithDotnet(fsprojFile.front, config, target, workspaceConfig);
        }
        else
        {
            // Use direct fsc compilation
            result = buildWithFSC(sources, config, target, workspaceConfig);
        }
        
        sw.stop();
        result.buildTime = sw.peek().total!"msecs";
        
        return result;
    }
    
    FSharpBuildMode getMode()
    {
        return FSharpBuildMode.Library;
    }
    
    bool isAvailable()
    {
        return DotnetOps.isAvailable();
    }
    
    private FSharpBuildResult buildWithDotnet(string projectFile, FSharpConfig config, Target target, WorkspaceConfig workspaceConfig)
    {
        FSharpBuildResult result;
        
        auto outputDir = workspaceConfig.options.outputDir;
        if (!config.dotnet.outputDir.empty)
            outputDir = config.dotnet.outputDir;
        
        bool success = DotnetOps.build(
            projectFile,
            config.dotnet.configuration,
            config.dotnet.framework.identifier,
            outputDir
        );
        
        if (!success)
        {
            result.error = "dotnet build failed";
            return result;
        }
        
        // Find output DLL
        auto projectName = baseName(projectFile, ".fsproj");
        auto outputPath = buildPath(outputDir, projectName ~ ".dll");
        
        if (exists(outputPath))
        {
            result.success = true;
            result.outputs = [outputPath];
            result.outputHash = FastHash.hashFile(outputPath);
        }
        else
        {
            result.error = "Output file not found: " ~ outputPath;
        }
        
        return result;
    }
    
    private FSharpBuildResult buildWithFSC(string[] sources, FSharpConfig config, Target target, WorkspaceConfig workspaceConfig)
    {
        FSharpBuildResult result;
        
        auto outputDir = workspaceConfig.options.outputDir;
        auto outputName = target.name.split(":")[$ - 1];
        auto outputPath = buildPath(outputDir, outputName ~ ".dll");
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        string[] cmd = ["fsc", "--target:library", "--out:" ~ outputPath];
        
        // Add optimization flags
        if (config.optimize)
            cmd ~= ["--optimize+"];
        
        // Add debug info
        if (config.debug_)
            cmd ~= ["--debug+", "--debug:full"];
        
        // Add compiler flags
        cmd ~= config.compilerFlags;
        
        // Add source files
        cmd ~= sources.filter!(s => s.endsWith(".fs") || s.endsWith(".fsi")).array;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "fsc compilation failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = [outputPath];
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
}

