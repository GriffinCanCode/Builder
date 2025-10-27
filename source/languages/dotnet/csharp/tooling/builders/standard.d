module languages.dotnet.csharp.tooling.builders.standard;

import std.stdio;
import std.file;
import std.path;
import std.range;
import std.algorithm;
import languages.dotnet.csharp.tooling.builders.base;
import languages.dotnet.csharp.tooling.detection;
import languages.dotnet.csharp.managers.dotnet;
import languages.dotnet.csharp.core.config;
import analysis.targets.spec;
import config.schema.schema;
import utils.files.hash;
import utils.logging.logger;

/// Standard builder using dotnet build
class StandardBuilder : CSharpBuilder
{
    override BuildResult build(
        in string[] sources,
        in CSharpConfig config,
        in Target target,
        in WorkspaceConfig workspaceConfig
    )
    {
        BuildResult result;
        
        Logger.info("Building with standard builder");
        
        // Use dotnet build
        if (!DotNetOps.build(workspaceConfig.root, config))
        {
            result.error = "Build failed";
            return result;
        }
        
        // Find outputs
        auto outputDir = config.outputPath.empty ? 
            buildPath(workspaceConfig.options.outputDir, config.configuration) : 
            config.outputPath;
        
        if (exists(outputDir) && isDir(outputDir))
        {
            // Find DLL or EXE
            foreach (entry; dirEntries(outputDir, SpanMode.shallow))
            {
                if (entry.name.endsWith(".dll") || entry.name.endsWith(".exe"))
                {
                    result.outputs ~= entry.name;
                }
            }
        }
        
        if (result.outputs.length > 0)
        {
            result.success = true;
            result.outputHash = FastHash.hashFile(result.outputs[0]);
        }
        else
        {
            result.error = "No outputs found";
        }
        
        return result;
    }
    
    override bool isAvailable()
    {
        return DotNetToolDetection.isDotNetAvailable();
    }
    
    override string name()
    {
        return "Standard Builder";
    }
}

