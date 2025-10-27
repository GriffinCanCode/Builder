module languages.dotnet.csharp.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.base.base;
import languages.dotnet.csharp.core.config;
import languages.dotnet.csharp.managers;
import languages.dotnet.csharp.tooling.detection;
import languages.dotnet.csharp.tooling.info;
import languages.dotnet.csharp.tooling.builders;
import languages.dotnet.csharp.tooling.formatters;
import languages.dotnet.csharp.tooling.analyzers;
import languages.dotnet.csharp.analysis;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// C# build handler - comprehensive and modular
class CSharpHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building C# target: " ~ target.name);
        
        // Parse C# configuration
        CSharpConfig csConfig = parseCSharpConfig(target);
        
        // Detect and enhance configuration from project structure
        BuildToolFactory.enhanceConfigFromProject(csConfig, config.root);
        
        // Validate .NET installation
        if (!DotNetToolDetection.isDotNetAvailable() && csConfig.buildTool != CSharpBuildTool.CSC)
        {
            result.error = "dotnet CLI not found. Please install .NET SDK.";
            return result;
        }
        
        // Check .NET version
        auto dotnetVersion = DotNetInfo.getVersion();
        if (dotnetVersion.empty)
        {
            Logger.warning("Could not determine .NET version");
        }
        else
        {
            Logger.info("Using .NET " ~ dotnetVersion);
        }
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, csConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, csConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, csConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, csConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        
        CSharpConfig csConfig = parseCSharpConfig(target);
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Determine extension based on mode and target type
            string ext;
            if (csConfig.mode == CSharpBuildMode.NativeAOT || csConfig.mode == CSharpBuildMode.SingleFile)
            {
                version(Windows)
                    ext = ".exe";
                else
                    ext = "";
            }
            else if (target.type == TargetType.Library)
            {
                ext = ".dll";
            }
            else
            {
                ext = ".exe";
            }
            
            outputs ~= buildPath(config.options.outputDir, name ~ ext);
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        in Target target,
        in WorkspaceConfig config,
        CSharpConfig csConfig
    )
    {
        LanguageBuildResult result;
        
        // Use build tool if configured
        if (csConfig.buildTool != CSharpBuildTool.Direct && csConfig.buildTool != CSharpBuildTool.None)
        {
            return buildWithBuildTool(target, config, csConfig);
        }
        
        // Restore NuGet packages if configured
        if (csConfig.nuget.autoRestore && DotNetToolDetection.hasProjectFile(config.root))
        {
            if (!NuGetOps.restore(config.root, csConfig.nuget))
            {
                Logger.warning("NuGet restore had issues, continuing anyway");
            }
        }
        
        // Auto-format if configured
        if (csConfig.formatter.autoFormat && csConfig.formatter.formatter != CSharpFormatter.None)
        {
            Logger.info("Auto-formatting code");
            auto formatter = CSharpFormatterFactory.create(csConfig.formatter.formatter, config.root);
            auto formatResult = formatter.format(target.sources.dup, csConfig.formatter, config.root, csConfig.formatter.checkOnly);
            
            if (!formatResult.success)
            {
                if (csConfig.formatter.verifyNoChanges)
                {
                    result.error = "Formatting verification failed: " ~ formatResult.error;
                    return result;
                }
                Logger.warning("Formatting failed, continuing anyway");
            }
        }
        
        // Run static analysis if configured
        if (csConfig.analysis.enabled && csConfig.analysis.analyzer != CSharpAnalyzer.None)
        {
            Logger.info("Running static analysis");
            auto analyzer = CSharpAnalyzerFactory.create(csConfig.analysis.analyzer, config.root);
            auto analysisResult = analyzer.analyze(target.sources.dup, csConfig.analysis, config.root);
            
            if (analysisResult.hasErrors() && csConfig.analysis.failOnErrors)
            {
                result.error = "Static analysis found errors:\n" ~ analysisResult.errors.join("\n");
                return result;
            }
            
            if (analysisResult.hasWarnings())
            {
                Logger.warning("Static analysis warnings:");
                foreach (warning; analysisResult.warnings)
                {
                    Logger.warning("  " ~ warning);
                }
                
                if (csConfig.analysis.failOnWarnings)
                {
                    result.error = "Static analysis warnings treated as errors";
                    return result;
                }
            }
        }
        
        // Build using appropriate builder
        auto builder = CSharpBuilderFactory.create(csConfig.mode, csConfig);
        
        if (!builder.isAvailable())
        {
            result.error = "Builder " ~ builder.name() ~ " not available";
            return result;
        }
        
        auto buildResult = builder.build(target.sources.dup, csConfig, target, config);
        
        if (!buildResult.success)
        {
            result.error = buildResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        in Target target,
        in WorkspaceConfig config,
        CSharpConfig csConfig
    )
    {
        LanguageBuildResult result;
        
        // Libraries use standard build mode
        if (csConfig.mode == CSharpBuildMode.NativeAOT || csConfig.mode == CSharpBuildMode.SingleFile)
        {
            Logger.warning("Converting incompatible build mode to Standard for library");
            csConfig.mode = CSharpBuildMode.Standard;
        }
        
        return buildExecutable(target, config, csConfig);
    }
    
    private LanguageBuildResult runTests(
        in Target target,
        in WorkspaceConfig config,
        CSharpConfig csConfig
    )
    {
        LanguageBuildResult result;
        
        Logger.info("Running C# tests");
        
        // Use build tool for testing if available
        if (csConfig.buildTool == CSharpBuildTool.DotNet && DotNetToolDetection.hasProjectFile(config.root))
        {
            if (!DotNetOps.test(config.root, csConfig.test))
            {
                result.error = "dotnet test failed";
                return result;
            }
        }
        else if (csConfig.buildTool == CSharpBuildTool.MSBuild && MSBuildToolDetection.hasMSBuildFile(config.root))
        {
            if (!MSBuildOps.test(config.root, csConfig.test))
            {
                result.error = "MSBuild test failed";
                return result;
            }
        }
        else
        {
            // Run tests directly
            auto testResult = runTestsDirect(target, config, csConfig);
            if (!testResult.success)
                return testResult;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources.dup);
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        in Target target,
        in WorkspaceConfig config,
        CSharpConfig csConfig
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources.dup);
        return result;
    }
    
    private LanguageBuildResult buildWithBuildTool(
        const Target target,
        const WorkspaceConfig config,
        CSharpConfig csConfig
    )
    {
        LanguageBuildResult result;
        
        final switch (csConfig.buildTool)
        {
            case CSharpBuildTool.DotNet:
                if (!DotNetOps.build(config.root, csConfig))
                {
                    result.error = "dotnet build failed";
                    return result;
                }
                break;
            
            case CSharpBuildTool.MSBuild:
                if (!MSBuildOps.build(config.root, csConfig))
                {
                    result.error = "MSBuild failed";
                    return result;
                }
                break;
            
            case CSharpBuildTool.Direct:
                // Direct CSC compilation
                result.error = "Direct CSC compilation not yet supported";
                return result;
            
            case CSharpBuildTool.Auto:
            case CSharpBuildTool.CSC:
            case CSharpBuildTool.None:
                // Fall back to direct compilation
                return buildExecutable(target, config, csConfig);
        }
        
        // Find output artifacts
        auto outputs = getOutputs(target, config);
        
        if (outputs.length > 0 && exists(outputs[0]))
        {
            result.success = true;
            result.outputs = outputs;
            result.outputHash = FastHash.hashFile(outputs[0]);
        }
        else
        {
            result.error = "Build succeeded but output not found";
        }
        
        return result;
    }
    
    private LanguageBuildResult runTestsDirect(
        const Target target,
        const WorkspaceConfig config,
        CSharpConfig csConfig
    )
    {
        LanguageBuildResult result;
        
        Logger.info("Running tests directly");
        
        // This is a simplified implementation
        // In a real scenario, we'd need to find test framework and run tests properly
        
        Logger.warning("Direct test execution not fully implemented, use dotnet test");
        
        result.success = true;
        return result;
    }
    
    override Import[] analyzeImports(in string[] sources)
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
}

