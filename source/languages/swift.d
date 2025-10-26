module languages.swift;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base;
import config.schema;
import analysis.types;
import analysis.spec;
import utils.hash;
import utils.logger;

/// Swift build handler
class SwiftHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Swift target: " ~ target.name);
        
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
            outputs ~= buildPath(config.options.outputDir, name);
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
        
        // Build with swiftc
        auto cmd = ["swiftc", "-o", outputPath];
        
        // Add framework paths if on macOS
        version(OSX)
        {
            cmd ~= ["-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"];
        }
        
        // Add optimization flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "swiftc failed: " ~ res.output;
            return result;
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
        
        // Build as dynamic library
        auto cmd = ["swiftc", "-emit-library", "-o", outputPath];
        
        // Add framework paths if on macOS
        version(OSX)
        {
            cmd ~= ["-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"];
        }
        
        // Add flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "swiftc failed: " ~ res.output;
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
        
        // Build test executable
        auto tempExe = buildPath(config.options.outputDir, ".swift-test");
        
        auto buildCmd = ["swiftc", "-o", tempExe];
        
        version(OSX)
        {
            buildCmd ~= ["-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"];
        }
        
        buildCmd ~= target.sources;
        
        auto buildRes = execute(buildCmd);
        
        if (buildRes.status != 0)
        {
            result.error = "Test compilation failed: " ~ buildRes.output;
            return result;
        }
        
        // Run tests
        auto runRes = execute([tempExe]);
        
        if (runRes.status != 0)
        {
            result.error = "Tests failed: " ~ runRes.output;
            return result;
        }
        
        // Clean up
        if (exists(tempExe))
            remove(tempExe);
        
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
        auto spec = getLanguageSpec(TargetLanguage.Swift);
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
}

