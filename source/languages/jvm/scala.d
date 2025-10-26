module languages.jvm.scala;

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

/// Scala build handler
class ScalaHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Scala target: " ~ target.name);
        
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
        
        // Create temp directory for class files
        auto tempDir = buildPath(outputDir, ".scala-build");
        if (!exists(tempDir))
            mkdirRecurse(tempDir);
        
        // Compile with scalac
        auto compileCmd = ["scalac", "-d", tempDir];
        
        // Add classpath for dependencies
        if (!target.deps.empty)
            compileCmd ~= ["-classpath", buildClasspath(target, config)];
        
        // Add flags
        compileCmd ~= target.flags;
        
        // Add sources
        compileCmd ~= target.sources;
        
        auto compileRes = execute(compileCmd);
        
        if (compileRes.status != 0)
        {
            result.error = "scalac failed: " ~ compileRes.output;
            return result;
        }
        
        // Package into JAR
        auto jarCmd = ["jar", "cf", outputPath, "-C", tempDir, "."];
        auto jarRes = execute(jarCmd);
        
        if (jarRes.status != 0)
        {
            result.error = "jar creation failed: " ~ jarRes.output;
            return result;
        }
        
        // Clean up
        rmdirRecurse(tempDir);
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        return buildExecutable(target, config);
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Run with ScalaTest
        auto cmd = ["scala", "-cp", "scalatest.jar"];
        cmd ~= ["org.scalatest.run"];
        
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
        auto spec = getLanguageSpec(TargetLanguage.Scala);
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

