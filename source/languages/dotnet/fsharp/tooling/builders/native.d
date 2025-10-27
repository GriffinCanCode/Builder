module languages.dotnet.fsharp.tooling.builders.native;

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

/// Builder for native AOT executables
class NativeBuilder : FSharpBuilder
{
    FSharpBuildResult build(in string[] sources, in FSharpConfig config, in Target target, in WorkspaceConfig workspaceConfig)
    {
        FSharpBuildResult result;
        auto sw = StopWatch(AutoStart.yes);
        
        auto fsprojFile = sources.find!(s => s.endsWith(".fsproj"));
        
        if (fsprojFile.empty)
        {
            result.error = "Native AOT requires .fsproj project file";
            return result;
        }
        
        string outputDir = workspaceConfig.options.outputDir;
        if (!config.dotnet.outputDir.empty)
            outputDir = config.dotnet.outputDir;
        
        // Build with publish for native AOT
        string[] cmd = ["dotnet", "publish", fsprojFile.front];
        
        cmd ~= ["--configuration", config.dotnet.configuration];
        cmd ~= ["--output", outputDir];
        
        if (!config.dotnet.runtime.empty)
            cmd ~= ["--runtime", config.dotnet.runtime];
        
        // Enable native AOT
        cmd ~= ["-p:PublishAot=true"];
        
        // Native AOT specific options
        if (config.native.includeSymbols)
            cmd ~= ["-p:StripSymbols=false"];
        else
            cmd ~= ["-p:StripSymbols=true"];
        
        if (config.native.invariantGlobalization)
            cmd ~= ["-p:InvariantGlobalization=true"];
        
        if (config.native.ilStrip)
            cmd ~= ["-p:IlcOptimizationPreference=" ~ config.native.optimization];
        
        // Execute publish
        auto res = execute(cmd);
        
        sw.stop();
        result.buildTime = sw.peek().total!"msecs";
        
        if (res.status != 0)
        {
            result.error = "Native AOT compilation failed: " ~ res.output;
            return result;
        }
        
        auto projectName = baseName(fsprojFile.front, ".fsproj");
        version(Windows)
            auto outputPath = buildPath(outputDir, projectName ~ ".exe");
        else
            auto outputPath = buildPath(outputDir, projectName);
        
        if (exists(outputPath))
        {
            result.success = true;
            result.outputs = [outputPath];
            result.outputHash = FastHash.hashFile(outputPath);
            
            Logger.info("Native AOT compilation successful");
            Logger.debug_("Output: " ~ outputPath);
        }
        else
        {
            result.error = "Native executable not found: " ~ outputPath;
        }
        
        return result;
    }
    
    FSharpBuildMode getMode()
    {
        return FSharpBuildMode.Native;
    }
    
    bool isAvailable()
    {
        // Check for .NET 7+ which supports native AOT
        auto version_ = DotnetOps.getVersion();
        if (version_.empty)
            return false;
        
        // Parse major version
        try
        {
            import std.conv : to;
            auto parts = version_.split(".");
            if (parts.length > 0)
            {
                auto major = parts[0].to!int;
                return major >= 7;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse .NET version: " ~ e.msg);
        }
        
        return false;
    }
}

