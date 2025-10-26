module languages.dotnet.fsharp.tooling.builders.fable;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.datetime.stopwatch;
import languages.dotnet.fsharp.tooling.builders.base;
import languages.dotnet.fsharp.core.config;
import analysis.targets.types;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Builder for Fable (F# to JavaScript/TypeScript)
class FableBuilder : FSharpBuilder
{
    FSharpBuildResult build(string[] sources, FSharpConfig config, Target target, WorkspaceConfig workspaceConfig)
    {
        FSharpBuildResult result;
        auto sw = StopWatch(AutoStart.yes);
        
        if (!isAvailable())
        {
            result.error = "Fable is not installed. Run: npm install -g fable-compiler";
            return result;
        }
        
        auto outputDir = buildPath(workspaceConfig.options.outputDir, config.fable.outDir);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build command
        string[] cmd = ["dotnet", "fable"];
        
        // Find .fsproj file
        auto fsprojFile = sources.find!(s => s.endsWith(".fsproj"));
        if (!fsprojFile.empty)
            cmd ~= [fsprojFile.front];
        
        // Output directory
        cmd ~= ["--outDir", config.fable.outDir];
        
        // Module system
        cmd ~= ["--lang", config.fable.language];
        
        // TypeScript output
        if (config.fable.typescript)
            cmd ~= ["--typescript"];
        
        // Source maps
        if (config.fable.sourceMaps)
            cmd ~= ["--sourceMaps"];
        
        // Optimization
        if (config.fable.optimize)
            cmd ~= ["--optimize"];
        
        // Defines
        foreach (define; config.fable.defines)
            cmd ~= ["--define", define];
        
        // Watch mode
        if (config.fable.watch)
            cmd ~= ["--watch"];
        
        // Run after compilation
        if (!config.fable.runAfter.empty)
            cmd ~= ["--run", config.fable.runAfter];
        
        // Execute Fable
        auto res = execute(cmd);
        
        sw.stop();
        result.buildTime = sw.peek().total!"msecs";
        
        if (res.status != 0)
        {
            result.error = "Fable compilation failed: " ~ res.output;
            return result;
        }
        
        // Find generated files
        string[] outputs;
        auto ext = config.fable.typescript ? ".ts" : ".js";
        
        try
        {
            foreach (entry; dirEntries(outputDir, SpanMode.depth))
            {
                if (entry.name.endsWith(ext))
                    outputs ~= entry.name;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to enumerate output files: " ~ e.msg);
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(sources);
        
        Logger.info("Fable compilation successful");
        
        return result;
    }
    
    FSharpBuildMode getMode()
    {
        return FSharpBuildMode.Fable;
    }
    
    bool isAvailable()
    {
        auto res = execute(["dotnet", "fable", "--version"]);
        return res.status == 0;
    }
}

