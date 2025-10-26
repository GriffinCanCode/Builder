module languages.dotnet.csharp;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.base.base;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// C# build handler
class CSharpHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building C# target: " ~ target.name);
        
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config);
                break;
            case TargetType.Test:
                result = runTests(target, config);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            if (target.type == TargetType.Library)
                outputs ~= buildPath(config.options.outputDir, name ~ ".dll");
            else
                outputs ~= buildPath(config.options.outputDir, name ~ ".exe");
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        auto outputs = getOutputs(target, config);
        auto outputPath = outputs[0];
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build with dotnet or csc
        auto cmd = detectBuildTool(target);
        
        if (cmd == "dotnet")
        {
            // Use dotnet build
            auto dotnetCmd = ["dotnet", "build", "-o", outputDir];
            dotnetCmd ~= target.flags;
            
            auto res = execute(dotnetCmd);
            
            if (res.status != 0)
            {
                result.error = "dotnet build failed: " ~ res.output;
                return result;
            }
        }
        else
        {
            // Use csc (C# compiler)
            auto cscCmd = ["csc", "-out:" ~ outputPath];
            
            // Add references for dependencies
            foreach (dep; target.deps)
            {
                auto depTarget = config.findTarget(dep);
                if (depTarget !is null)
                {
                    auto depOutputs = getOutputs(*depTarget, config);
                    foreach (depOut; depOutputs)
                        cscCmd ~= ["-reference:" ~ depOut];
                }
            }
            
            // Add flags
            cscCmd ~= target.flags;
            
            // Add sources
            cscCmd ~= target.sources;
            
            auto res = execute(cscCmd);
            
            if (res.status != 0)
            {
                result.error = "csc failed: " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        auto outputs = getOutputs(target, config);
        auto outputPath = outputs[0];
        auto outputDir = dirName(outputPath);
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        // Build with csc
        auto cmd = ["csc", "-target:library", "-out:" ~ outputPath];
        
        // Add references for dependencies
        foreach (dep; target.deps)
        {
            auto depTarget = config.findTarget(dep);
            if (depTarget !is null)
            {
                auto depOutputs = getOutputs(*depTarget, config);
                foreach (depOut; depOutputs)
                    cmd ~= ["-reference:" ~ depOut];
            }
        }
        
        // Add flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "csc failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Run with dotnet test or vstest
        auto cmd = ["dotnet", "test"];
        cmd ~= target.flags;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "Tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.CSharp);
        if (spec is null)
            return [];
        
        Import[] allImports;
        
        foreach (source; sources)
        {
            if (!exists(source) || !isFile(source))
                continue;
            
            try
            {
                auto content = readText(source);
                auto imports = spec.scanImports(source, content);
                allImports ~= imports;
            }
            catch (Exception e)
            {
                Logger.warning("Failed to analyze imports in " ~ source);
            }
        }
        
        return allImports;
    }
    
    private string detectBuildTool(Target target)
    {
        // Check if we're in a dotnet project directory
        auto currentDir = getcwd();
        
        if (exists(buildPath(currentDir, "*.csproj")))
            return "dotnet";
        
        // Otherwise use csc
        return "csc";
    }
}

