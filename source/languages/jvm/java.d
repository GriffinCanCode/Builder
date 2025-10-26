module languages.jvm.java;

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
        
        // Create temporary directory for .class files
        auto tempDir = buildPath(outputDir, ".java-build");
        if (!exists(tempDir))
            mkdirRecurse(tempDir);
        
        // Compile Java sources
        auto compileCmd = ["javac", "-d", tempDir];
        
        // Add classpath if dependencies exist
        if (!target.deps.empty)
            compileCmd ~= ["-cp", buildClasspath(target, config)];
        
        // Add flags
        compileCmd ~= target.flags;
        
        // Add sources
        compileCmd ~= target.sources;
        
        auto compileRes = execute(compileCmd);
        
        if (compileRes.status != 0)
        {
            result.error = "javac failed: " ~ compileRes.output;
            return result;
        }
        
        // Find main class
        auto mainClass = findMainClass(target);
        
        // Create JAR
        auto jarCmd = ["jar", "cfe", outputPath, mainClass, "-C", tempDir, "."];
        auto jarRes = execute(jarCmd);
        
        if (jarRes.status != 0)
        {
            result.error = "jar creation failed: " ~ jarRes.output;
            return result;
        }
        
        // Clean up temp directory
        rmdirRecurse(tempDir);
        
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
        
        // Create temporary directory for .class files
        auto tempDir = buildPath(outputDir, ".java-build");
        if (!exists(tempDir))
            mkdirRecurse(tempDir);
        
        // Compile Java sources
        auto compileCmd = ["javac", "-d", tempDir];
        
        // Add classpath if dependencies exist
        if (!target.deps.empty)
            compileCmd ~= ["-cp", buildClasspath(target, config)];
        
        // Add flags
        compileCmd ~= target.flags;
        
        // Add sources
        compileCmd ~= target.sources;
        
        auto compileRes = execute(compileCmd);
        
        if (compileRes.status != 0)
        {
            result.error = "javac failed: " ~ compileRes.output;
            return result;
        }
        
        // Create JAR (library, no main class)
        auto jarCmd = ["jar", "cf", outputPath, "-C", tempDir, "."];
        auto jarRes = execute(jarCmd);
        
        if (jarRes.status != 0)
        {
            result.error = "jar creation failed: " ~ jarRes.output;
            return result;
        }
        
        // Clean up temp directory
        rmdirRecurse(tempDir);
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFile(outputPath);
        
        return result;
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Run JUnit tests if available
        auto cmd = ["java", "-jar", "junit-platform-console-standalone.jar"];
        cmd ~= ["--class-path", buildClasspath(target, config)];
        cmd ~= ["--scan-class-path"];
        
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
        auto spec = getLanguageSpec(TargetLanguage.Java);
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
    
    private string findMainClass(Target target)
    {
        // Try to find main class from sources
        foreach (source; target.sources)
        {
            if (!exists(source))
                continue;
            
            try
            {
                auto content = readText(source);
                
                // Look for "public static void main"
                if (content.canFind("public static void main"))
                {
                    // Extract package and class name
                    import std.regex;
                    
                    auto packageMatch = matchFirst(content, regex(`^\s*package\s+([\w.]+)`));
                    auto classMatch = matchFirst(content, regex(`^\s*public\s+class\s+(\w+)`, "m"));
                    
                    if (!classMatch.empty)
                    {
                        auto className = classMatch[1];
                        
                        if (!packageMatch.empty)
                            return packageMatch[1] ~ "." ~ className;
                        else
                            return className;
                    }
                }
            }
            catch (Exception e)
            {
                continue;
            }
        }
        
        // Fallback: use target name
        return target.name.split(":")[$ - 1];
    }
}

