module languages.jvm.java.core.handler;

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
import languages.jvm.java.core.config;

/// Java build handler
class JavaHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Java target: " ~ target.name);
        
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
        
        // Compile with javac
        auto cmd = ["javac"];
        
        // Add classpath if dependencies exist
        if (!target.deps.empty)
            cmd ~= ["-classpath", buildClasspath(target, config)];
        
        // Add flags
        cmd ~= target.flags;
        
        // Specify output directory
        cmd ~= ["-d", outputDir];
        
        // Add sources
        cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = "javac failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputs = outputs;
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        return buildExecutable(target, config);
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // First compile the tests
        result = buildExecutable(target, config);
        if (!result.success)
            return result;
        
        // Run with junit if available
        auto cmd = ["java", "-classpath", buildClasspath(target, config)];
        cmd ~= target.flags;
        
        auto res = execute(cmd);
        
        result.success = res.status == 0;
        if (!result.success)
            result.error = "Tests failed: " ~ res.output;
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        if (target.commands.empty)
        {
            result.error = "Custom target requires commands";
            return result;
        }
        
        foreach (cmd; target.commands)
        {
            auto res = executeShell(cmd);
            if (res.status != 0)
            {
                result.error = "Command failed: " ~ cmd ~ "\n" ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = getOutputs(target, config);
        
        return result;
    }
    
    private string buildClasspath(Target target, WorkspaceConfig config)
    {
        string[] classpaths;
        
        // Add dependency outputs
        foreach (dep; target.deps)
        {
            // This is simplified - in practice would resolve from build graph
            classpaths ~= buildPath(config.options.outputDir, dep ~ ".jar");
        }
        
        version (Windows)
            return classpaths.join(";");
        else
            return classpaths.join(":");
    }
}

