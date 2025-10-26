module languages.compiled.cpp.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.conv;
import languages.base.base;
import languages.compiled.cpp.core.config;
import languages.compiled.cpp.tooling.toolchain;
import languages.compiled.cpp.analysis.analysis;
import languages.compiled.cpp.tooling.tools;
import languages.compiled.cpp.builders;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// C++ build handler with comprehensive feature support
class CppHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building C++ target: " ~ target.name);
        
        // Parse C++ configuration
        CppConfig cppConfig = parseCppConfig(target);
        
        // Detect and enhance configuration
        enhanceConfigFromProject(cppConfig, target, config);
        
        // Run static analysis if requested
        if (cppConfig.analyzer != StaticAnalyzer.None)
        {
            auto analysisResult = runStaticAnalysis(target, cppConfig);
            if (analysisResult.hadIssues)
            {
                Logger.warning("Static analysis found issues:");
                foreach (issue; analysisResult.issues[0 .. min(10, $)])
                {
                    Logger.warning("  " ~ issue);
                }
                if (analysisResult.issues.length > 10)
                {
                    Logger.warning("  ... and " ~ (analysisResult.issues.length - 10).to!string ~ " more issues");
                }
            }
        }
        
        // Run code formatter if requested
        if (cppConfig.format)
        {
            formatCode(target.sources, cppConfig);
        }
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, cppConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, cppConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, cppConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, cppConfig);
                break;
        }
        
        // Run with sanitizers if requested and successful
        if (result.success && !cppConfig.sanitizers.empty && !result.outputs.empty)
        {
            auto sanitizerResult = runWithSanitizers(result.outputs[0], cppConfig);
            if (sanitizerResult.hadIssues)
            {
                Logger.warning("Sanitizer detected issues:");
                foreach (issue; sanitizerResult.issues)
                {
                    Logger.warning("  " ~ issue);
                }
            }
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        CppConfig cppConfig = parseCppConfig(target);
        
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Add platform-specific extension
            string ext = "";
            if (cppConfig.outputType == OutputType.Executable)
            {
                version(Windows)
                {
                    ext = ".exe";
                }
            }
            else if (cppConfig.outputType == OutputType.SharedLib)
            {
                version(Windows)
                {
                    ext = ".dll";
                }
                else version(OSX)
                {
                    ext = ".dylib";
                }
                else
                {
                    ext = ".so";
                }
            }
            else if (cppConfig.outputType == OutputType.StaticLib)
            {
                version(Windows)
                {
                    ext = ".lib";
                }
                else
                {
                    ext = ".a";
                }
            }
            
            outputs ~= buildPath(config.options.outputDir, name ~ ext);
        }
        
        return outputs;
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
    
    private LanguageBuildResult buildExecutable(
        Target target,
        WorkspaceConfig config,
        CppConfig cppConfig
    )
    {
        LanguageBuildResult result;
        
        // Ensure output type is executable
        cppConfig.outputType = OutputType.Executable;
        
        // Build with selected builder
        auto buildResult = compileTarget(target, config, cppConfig);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        Target target,
        WorkspaceConfig config,
        CppConfig cppConfig
    )
    {
        LanguageBuildResult result;
        
        // Check if header-only library
        bool isHeaderOnly = target.sources.all!(s => 
            s.endsWith(".h") || s.endsWith(".hpp") || s.endsWith(".hxx")
        );
        
        if (isHeaderOnly || cppConfig.outputType == OutputType.HeaderOnly)
        {
            Logger.info("Header-only library detected");
            result.success = true;
            result.outputs = target.sources;
            result.outputHash = FastHash.hashStrings(target.sources);
            return result;
        }
        
        // Set library output type if not specified
        if (cppConfig.outputType == OutputType.Executable)
        {
            cppConfig.outputType = OutputType.StaticLib;
        }
        
        // Build
        auto buildResult = compileTarget(target, config, cppConfig);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        Target target,
        WorkspaceConfig config,
        CppConfig cppConfig
    )
    {
        LanguageBuildResult result;
        
        // Build test executable
        cppConfig.outputType = OutputType.Executable;
        auto buildResult = compileTarget(target, config, cppConfig);
        
        if (!buildResult.success)
        {
            result.error = buildResult.error;
            return result;
        }
        
        // Run the test executable
        if (!buildResult.outputs.empty)
        {
            string testExe = buildResult.outputs[0];
            
            Logger.info("Running tests: " ~ testExe);
            
            auto res = execute([testExe]);
            
            if (res.status != 0)
            {
                result.error = "Tests failed: " ~ res.output;
                return result;
            }
            
            Logger.info("Tests passed");
        }
        
        result.success = true;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        Target target,
        WorkspaceConfig config,
        CppConfig cppConfig
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    private CppCompileResult compileTarget(
        Target target,
        WorkspaceConfig config,
        CppConfig cppConfig
    )
    {
        // Create builder based on configuration
        auto builder = CppBuilderFactory.create(cppConfig);
        
        if (!builder.isAvailable())
        {
            CppCompileResult result;
            result.error = "C++ builder '" ~ builder.name() ~ "' is not available. " ~
                          "Please install a C++ compiler (GCC, Clang, or MSVC).";
            return result;
        }
        
        Logger.debug_("Using C++ builder: " ~ builder.name() ~ " (" ~ builder.getVersion() ~ ")");
        
        // Optimize with precompiled headers if beneficial
        if (cppConfig.pch.strategy == PchStrategy.Auto && target.sources.length > 5)
        {
            auto pchHeaders = PchOptimizer.suggestPchHeaders(target.sources, cppConfig.includeDirs);
            if (!pchHeaders.empty)
            {
                double benefit = PchOptimizer.estimatePchBenefit(target.sources, pchHeaders);
                if (benefit > 30.0)
                {
                    Logger.info("PCH would benefit ~" ~ benefit.to!string[0 .. min(5, $)] ~ "% of includes");
                    // TODO: Enable PCH
                }
            }
        }
        
        // Compile
        auto compileResult = builder.build(target.sources, cppConfig, target, config);
        
        if (!compileResult.success)
        {
            return compileResult;
        }
        
        // Report warnings
        if (compileResult.hadWarnings && !compileResult.warnings.empty)
        {
            Logger.warning("Compilation warnings:");
            foreach (warn; compileResult.warnings[0 .. min(5, $)])
            {
                Logger.warning("  " ~ warn);
            }
            if (compileResult.warnings.length > 5)
            {
                Logger.warning("  ... and " ~ (compileResult.warnings.length - 5).to!string ~ " more warnings");
            }
        }
        
        return compileResult;
    }
    
    private CppConfig parseCppConfig(Target target)
    {
        CppConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("cpp" in target.langConfig)
            configKey = "cpp";
        else if ("cppConfig" in target.langConfig)
            configKey = "cppConfig";
        else if ("c++" in target.langConfig)
            configKey = "c++";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = CppConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse C++ config, using defaults: " ~ e.msg);
            }
        }
        
        // Apply target flags to compiler flags
        if (!target.flags.empty)
        {
            config.compilerFlags ~= target.flags;
        }
        
        return config;
    }
    
    private void enhanceConfigFromProject(
        ref CppConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Auto-detect build system
        if (config.buildSystem == BuildSystem.Auto)
        {
            auto detected = BuildSystemDetector.detect(sourceDir);
            if (detected != BuildSystem.None)
            {
                Logger.debug_("Detected build system: " ~ detected.to!string);
                config.buildSystem = detected;
            }
        }
        
        // Auto-detect entry point
        if (config.entry.empty && !target.sources.empty)
        {
            // Look for main.cpp, main.cc, or similar
            foreach (source; target.sources)
            {
                string basename = baseName(source, extension(source));
                if (basename == "main" || basename == "app")
                {
                    config.entry = source;
                    break;
                }
            }
            
            // Fallback to first source
            if (config.entry.empty)
                config.entry = target.sources[0];
        }
        
        // Add include directories from target
        if (!target.includes.empty)
        {
            config.includeDirs ~= target.includes;
        }
    }
    
    private AnalysisResult runStaticAnalysis(Target target, CppConfig config)
    {
        final switch (config.analyzer)
        {
            case StaticAnalyzer.None:
                return AnalysisResult();
            case StaticAnalyzer.ClangTidy:
                return ClangTidy.analyze(target.sources, config);
            case StaticAnalyzer.CppCheck:
                return CppCheck.analyze(target.sources, config);
            case StaticAnalyzer.PVSStudio:
            case StaticAnalyzer.Coverity:
                Logger.warning("Analyzer not yet implemented: " ~ config.analyzer.to!string);
                return AnalysisResult();
        }
    }
    
    private void formatCode(string[] sources, CppConfig config)
    {
        if (ClangFormat.isAvailable())
        {
            ClangFormat.format(sources, config.formatStyle, true);
        }
        else
        {
            Logger.warning("clang-format not available, skipping formatting");
        }
    }
    
    private SanitizerResult runWithSanitizers(string executable, CppConfig config)
    {
        if (config.sanitizers.empty)
        {
            return SanitizerResult();
        }
        
        return SanitizerRunner.run(executable, config.sanitizers);
    }
}

/// C handler (reuses CppHandler with C-specific settings)
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

