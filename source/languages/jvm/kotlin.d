module languages.jvm.kotlin;

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

/// Kotlin build handler
class KotlinHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Kotlin target: " ~ target.name);
        
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
            outputs ~= buildPath(config.options.outputDir, name ~ ".jar");
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
        
        // Compile with kotlinc
        auto cmd = ["kotlinc"];
        
        // Add include runtime for executable
        cmd ~= ["-include-runtime"];
        
        // Add classpath if dependencies exist
        if (!target.deps.empty)
            cmd ~= ["-classpath", buildClasspath(target, config)];
        
        // Add flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        // Specify output
        cmd ~= ["-d", outputPath];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "kotlinc failed: " ~ res.output;
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
        
        // Compile as library (no runtime)
        auto cmd = ["kotlinc"];
        
        // Add classpath if dependencies exist
        if (!target.deps.empty)
            cmd ~= ["-classpath", buildClasspath(target, config)];
        
        // Add flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        // Specify output
        cmd ~= ["-d", outputPath];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "kotlinc failed: " ~ res.output;
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
        
        // Build and run with kotlin test runner
        auto tempJar = buildPath(config.options.outputDir, ".kotlin-test.jar");
        
        auto buildCmd = ["kotlinc", "-include-runtime"];
        buildCmd ~= target.sources;
        buildCmd ~= ["-d", tempJar];
        
        auto buildRes = execute(buildCmd);
        
        if (buildRes.status != 0)
        {
            result.error = "Test compilation failed: " ~ buildRes.output;
            return result;
        }
        
        // Run tests
        auto runCmd = ["kotlin", "-classpath", tempJar, "TestKt"];
        auto runRes = execute(runCmd);
        
        if (runRes.status != 0)
        {
            result.error = "Tests failed: " ~ runRes.output;
            return result;
        }
        
        // Clean up
        if (exists(tempJar))
            remove(tempJar);
        
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
        auto spec = getLanguageSpec(TargetLanguage.Kotlin);
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
    
    private string buildClasspath(Target target, WorkspaceConfig config)
    {
        string[] paths;
        
        foreach (dep; target.deps)
        {
            auto depTarget = config.findTarget(dep);
            if (depTarget !is null)
            {
                auto depOutputs = getOutputs(*depTarget, config);
                paths ~= depOutputs;
            }
        }
        
        version(Windows)
            return paths.join(";");
        else
            return paths.join(":");
    }
}

