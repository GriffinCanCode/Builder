module languages.compiled.cpp;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base.base;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// C/C++ build handler
class CppHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building C++ target: " ~ target.name);
        
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
        
        // Detect compiler
        auto compiler = detectCompiler(target);
        
        // Build command with includes
        auto cmd = [compiler, "-o", outputPath];
        
        // Add include paths
        foreach (inc; target.includes)
            cmd ~= ["-I", inc];
        
        // Add flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = compiler ~ " build failed: " ~ res.output;
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
        
        // Detect compiler
        auto compiler = detectCompiler(target);
        
        // Build as shared library
        auto cmd = [compiler, "-shared", "-fPIC", "-o", outputPath];
        
        // Add include paths
        foreach (inc; target.includes)
            cmd ~= ["-I", inc];
        
        // Add flags
        cmd ~= target.flags;
        
        // Add sources
        cmd ~= target.sources;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            result.error = compiler ~ " build failed: " ~ res.output;
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
        auto testResult = buildExecutable(target, config);
        if (!testResult.success)
            return testResult;
        
        // Run the test executable
        auto testExe = testResult.outputs[0];
        auto res = execute([testExe]);
        
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
        auto spec = getLanguageSpec(TargetLanguage.Cpp);
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
    
    private string detectCompiler(Target target)
    {
        // Check if C++ or C based on file extensions
        bool isCpp = target.sources.any!(s => 
            s.endsWith(".cpp") || s.endsWith(".cxx") || 
            s.endsWith(".cc") || s.endsWith(".C")
        );
        
        // Prefer clang, fallback to gcc
        if (isCpp)
        {
            return executeShell("which clang++").status == 0 ? "clang++" : "g++";
        }
        else
        {
            return executeShell("which clang").status == 0 ? "clang" : "gcc";
        }
    }
}

/// C build handler (reuses CppHandler)
class CHandler : CppHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        Logger.debug_("Building C target: " ~ target.name);
        return super.buildImpl(target, config);
    }
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.C);
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

