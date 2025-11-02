module languages.dotnet.csharp.tooling.builders.publish;

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

/// Publish builder for single-file, R2R, and trimmed builds
class PublishBuilder : CSharpBuilder
{
    import core.caching.actions.action : ActionCache;
    this(ActionCache cache = null) {}
    
    override BuildResult build(
        in string[] sources,
        in CSharpConfig config,
        in Target target,
        in WorkspaceConfig workspaceConfig
    )
    {
        BuildResult result;
        
        Logger.info("Building with publish builder");
        
        // Use dotnet publish
        if (!DotNetOps.publish(workspaceConfig.root, config))
        {
            result.error = "Publish failed";
            return result;
        }
        
        // Find outputs
        auto outputDir = config.outputPath.empty ? 
            buildPath(workspaceConfig.options.outputDir, config.configuration, "publish") : 
            config.outputPath;
        
        if (exists(outputDir) && isDir(outputDir))
        {
            // Find executable
            foreach (entry; dirEntries(outputDir, SpanMode.shallow))
            {
                if (entry.name.endsWith(".exe") || (entry.isFile && !entry.name.endsWith(".dll") && !entry.name.endsWith(".pdb")))
                {
                    result.outputs ~= entry.name;
                    break;
                }
            }
            
            // If no exe, find DLL
            if (result.outputs.length == 0)
            {
                foreach (entry; dirEntries(outputDir, SpanMode.shallow))
                {
                    if (entry.name.endsWith(".dll"))
                    {
                        result.outputs ~= entry.name;
                        break;
                    }
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
        return "Publish Builder";
    }
}

