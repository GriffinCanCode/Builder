module languages.dotnet.csharp.tooling.builders.aot;

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

/// Native AOT builder
class AOTBuilder : CSharpBuilder
{
    override BuildResult build(
        in string[] sources,
        in CSharpConfig config,
        in Target target,
        in WorkspaceConfig workspaceConfig
    )
    {
        BuildResult result;
        
        Logger.info("Building with Native AOT builder");
        
        // Enable AOT in config
        auto mutableConfig = cast(CSharpConfig)config;
        mutableConfig.aot.enabled = true;
        mutableConfig.publish.nativeAot = true;
        
        // Use dotnet publish with AOT
        if (!DotNetOps.publish(workspaceConfig.root, mutableConfig))
        {
            result.error = "Native AOT build failed";
            return result;
        }
        
        // Find native executable
        auto outputDir = config.outputPath.empty ? 
            buildPath(workspaceConfig.options.outputDir, config.configuration, "publish") : 
            config.outputPath;
        
        if (exists(outputDir) && isDir(outputDir))
        {
            // Find native executable (no .dll extension)
            foreach (entry; dirEntries(outputDir, SpanMode.shallow))
            {
                auto name = baseName(entry.name);
                if (entry.isFile && !name.endsWith(".dll") && !name.endsWith(".pdb") && 
                    !name.endsWith(".json") && !name.endsWith(".xml"))
                {
                    result.outputs ~= entry.name;
                    break;
                }
            }
        }
        
        if (result.outputs.length > 0)
        {
            result.success = true;
            result.outputHash = FastHash.hashFile(result.outputs[0]);
            
            Logger.info("Native AOT build succeeded, output: " ~ result.outputs[0]);
        }
        else
        {
            result.error = "No native executable found";
        }
        
        return result;
    }
    
    override bool isAvailable()
    {
        // Native AOT requires .NET 7+ and appropriate SDK
        if (!DotNetToolDetection.isDotNetAvailable())
            return false;
        
        import languages.dotnet.csharp.tooling.info;
        auto version_ = DotNetInfo.getVersion();
        
        // Very simple version check - just check for 7, 8, or 9
        if (version_.length > 0)
        {
            auto major = version_[0];
            return major >= '7';
        }
        
        return false;
    }
    
    override string name()
    {
        return "Native AOT Builder";
    }
}

