module languages.scripting.go.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import languages.base.base;
import languages.scripting.go.core.config;
import languages.scripting.go.managers.modules;
import languages.scripting.go.tooling.tools;
import languages.scripting.go.builders;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// Go build handler - modular and extensible
class GoHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building Go target: " ~ target.name);
        
        // Parse Go configuration
        GoConfig goConfig = parseGoConfig(target);
        
        // Auto-detect configuration from project structure
        enhanceConfigFromProject(goConfig, target, config);
        
        // Build based on target type
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, goConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, goConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, goConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, goConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            // Add platform-specific extension
            version(Windows)
            {
                if (target.type == TargetType.Executable)
                    name ~= ".exe";
            }
            
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(
        Target target,
        WorkspaceConfig config,
        GoConfig goConfig
    )
    {
        LanguageBuildResult result;
        
        // Create appropriate builder
        auto builder = GoBuilderFactory.createAuto(goConfig);
        
        if (!builder.isAvailable())
        {
            result.error = "Go compiler not available. Install from: https://golang.org/dl/";
            return result;
        }
        
        Logger.debug_("Using builder: " ~ builder.name() ~ " (" ~ builder.getVersion() ~ ")");
        
        // Build
        auto buildResult = builder.build(target.sources, goConfig, target, config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        // Report tool warnings
        if (!buildResult.toolWarnings.empty)
        {
            Logger.info("Build completed with warnings from tools:");
            foreach (warning; buildResult.toolWarnings)
            {
                Logger.warning("  " ~ warning);
            }
        }
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        Target target,
        WorkspaceConfig config,
        GoConfig goConfig
    )
    {
        // Libraries in Go are just packages - build them to ensure compilation
        goConfig.mode = GoBuildMode.Library;
        
        auto builder = GoBuilderFactory.createAuto(goConfig);
        
        if (!builder.isAvailable())
        {
            LanguageBuildResult result;
            result.error = "Go compiler not available";
            return result;
        }
        
        Logger.debug_("Building Go library/package");
        
        // For libraries, we typically just want to ensure compilation
        // The actual package will be used by other Go code
        auto buildResult = builder.build(target.sources, goConfig, target, config);
        
        LanguageBuildResult result;
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        Target target,
        WorkspaceConfig config,
        GoConfig goConfig
    )
    {
        LanguageBuildResult result;
        
        if (!GoTools.isGoAvailable())
        {
            result.error = "Go not available for running tests";
            return result;
        }
        
        // Determine working directory
        string workDir = config.root;
        if (!target.sources.empty)
            workDir = dirName(target.sources[0]);
        
        // Build go test command
        string[] cmd = ["go", "test"];
        
        // Add test flags
        cmd ~= goConfig.test.toFlags();
        
        // Add build tags if specified
        auto allTags = goConfig.buildTags ~ goConfig.constraints.tags;
        if (!allTags.empty)
        {
            cmd ~= "-tags";
            cmd ~= allTags.join(",");
        }
        
        // Add target flags
        cmd ~= target.flags;
        
        // Add test packages/files
        if (target.sources.empty)
            cmd ~= "./...";
        else
            cmd ~= target.sources;
        
        Logger.info("Running Go tests: " ~ cmd.join(" "));
        
        // Prepare environment
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Add CGO environment
        if (goConfig.cgo.enabled)
        {
            foreach (key, value; goConfig.cgo.toEnv())
                env[key] = value;
        }
        
        // Add cross-compilation environment
        if (goConfig.cross.isCross())
        {
            foreach (key, value; goConfig.cross.toEnv())
                env[key] = value;
        }
        
        // Execute tests
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Go tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        // If coverage was generated, add it to outputs
        if (goConfig.test.coverage && !goConfig.test.coverProfile.empty)
        {
            auto coverPath = buildPath(workDir, goConfig.test.coverProfile);
            if (exists(coverPath))
                result.outputs ~= coverPath;
        }
        
        return result;
    }
    
    private LanguageBuildResult buildCustom(
        Target target,
        WorkspaceConfig config,
        GoConfig goConfig
    )
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Parse Go configuration from target
    private GoConfig parseGoConfig(Target target)
    {
        GoConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("go" in target.langConfig)
            configKey = "go";
        else if ("goConfig" in target.langConfig)
            configKey = "goConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = GoConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse Go config, using defaults: " ~ e.msg);
            }
        }
        
        return config;
    }
    
    /// Enhance configuration based on project structure
    private void enhanceConfigFromProject(
        ref GoConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        // Check if in a module
        auto goModPath = ModuleAnalyzer.findGoMod(sourceDir);
        if (!goModPath.empty && config.modMode == GoModMode.Auto)
        {
            config.modMode = GoModMode.On;
            Logger.debug_("Detected go.mod at: " ~ goModPath);
            
            // Parse module information
            auto mod = ModuleAnalyzer.parseGoMod(goModPath);
            if (mod.isValid())
            {
                Logger.debug_("Module path: " ~ mod.path);
                Logger.debug_("Go version: " ~ mod.goVersion);
                
                if (config.modPath.empty)
                    config.modPath = mod.path;
            }
        }
        
        // Check if in a workspace
        auto goWorkPath = ModuleAnalyzer.findGoWork(sourceDir);
        if (!goWorkPath.empty)
        {
            Logger.debug_("Detected go.work at: " ~ goWorkPath);
            
            auto ws = ModuleAnalyzer.parseGoWork(goWorkPath);
            if (ws.isValid())
            {
                Logger.debug_("Workspace modules: " ~ ws.use.join(", "));
            }
        }
        
        // Auto-detect CGO usage
        if (!config.cgo.enabled)
        {
            foreach (source; target.sources)
            {
                if (exists(source) && hasCGoCode(source))
                {
                    Logger.debug_("Detected CGO code in: " ~ source);
                    config.cgo.enabled = true;
                    break;
                }
            }
        }
    }
    
    /// Check if source file contains CGO code
    private bool hasCGoCode(string filePath)
    {
        try
        {
            auto content = readText(filePath);
            
            // Look for CGO comments
            if (content.canFind("/*") && content.canFind("import \"C\""))
                return true;
            if (content.canFind("// #cgo "))
                return true;
            if (content.canFind("import \"C\""))
                return true;
                
            return false;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.Go);
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

