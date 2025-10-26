module languages.scripting.python;

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
import utils.python.pycheck;
import utils.python.pywrap;

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
    
    override Import[] analyzeImports(string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Python);
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
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Batch validate Python syntax using AST parser (single process)
        auto validationResult = PyValidator.validate(target.sources);
        
        if (!validationResult.success)
        {
            result.error = validationResult.firstError();
            return result;
        }
        
        // Create smart executable wrapper
        auto outputs = getOutputs(target, config);
        if (!outputs.empty && !target.sources.empty)
        {
            auto outputPath = outputs[0];
            auto mainFile = target.sources[0];
            
            // Get entry point metadata from validation
            auto mainFileResult = validationResult.files[0];
            
            WrapperConfig wrapperConfig;
            wrapperConfig.mainFile = mainFile;
            wrapperConfig.outputPath = outputPath;
            wrapperConfig.projectRoot = config.root.empty ? "." : config.root;
            wrapperConfig.hasMain = mainFileResult.hasMain;
            wrapperConfig.hasMainGuard = mainFileResult.hasMainGuard;
            wrapperConfig.isExecutable = mainFileResult.isExecutable;
            
            PyWrapperGenerator.generate(wrapperConfig);
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        // Batch validate Python syntax using AST parser (single process)
        auto validationResult = PyValidator.validate(target.sources);
        
        if (!validationResult.success)
        {
            result.error = validationResult.firstError();
            return result;
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

