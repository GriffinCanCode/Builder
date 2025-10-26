module languages.python;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.base;
import config.schema;
import utils.hash;
import utils.logger;

/// Python build handler
class PythonHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Python target: " ~ target.name);
        
        // For Python, we mainly validate and optionally compile to .pyc
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
            // Default output
            auto name = target.name.split(":")[$ - 1];
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Validate Python syntax
        foreach (source; target.sources)
        {
            auto cmd = ["python3", "-m", "py_compile", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Syntax error in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        // Create executable wrapper if needed
        auto outputs = getOutputs(target, config);
        if (!outputs.empty)
        {
            auto outputPath = outputs[0];
            auto outputDir = dirName(outputPath);
            
            if (!exists(outputDir))
                mkdirRecurse(outputDir);
            
            // Create a simple wrapper script
            string wrapper = "#!/usr/bin/env python3\n";
            wrapper ~= "import sys\n";
            wrapper ~= "import os\n";
            wrapper ~= "# Add source directory to path\n";
            wrapper ~= "sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + '/../')\n";
            
            if (!target.sources.empty)
            {
                auto mainFile = baseName(target.sources[0], ".py");
                wrapper ~= "import " ~ mainFile ~ "\n";
                wrapper ~= "if __name__ == '__main__':\n";
                wrapper ~= "    " ~ mainFile ~ ".main()\n";
            }
            
            std.file.write(outputPath, wrapper);
            
            version (Posix)
            {
                import core.sys.posix.sys.stat;
                chmod(outputPath.ptr, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);
            }
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Validate Python syntax
        foreach (source; target.sources)
        {
            auto cmd = ["python3", "-m", "py_compile", source];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Syntax error in " ~ source ~ ": " ~ res.output;
                return result;
            }
        }
        
        result.success = true;
        result.outputs = target.sources;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Run pytest if available
        foreach (source; target.sources)
        {
            auto cmd = ["python3", "-m", "pytest", source, "-v"];
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                result.error = "Tests failed in " ~ source;
                return result;
            }
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
}

