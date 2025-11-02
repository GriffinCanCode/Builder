module languages.scripting.go.core.handler;

import std.stdio;
import std.process : Config, environment;
import utils.security : execute;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import languages.base.base;
import languages.base.mixins;
import languages.scripting.go.core.config;
import languages.scripting.go.managers.modules;
import languages.scripting.go.tooling.tools;
import languages.scripting.go.builders;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import core.caching.action : ActionId, ActionType;

/// Go build handler - modular and extensible with action-level caching
class GoHandler : BaseLanguageHandler
{
    mixin CachingHandlerMixin!"go";
    mixin ConfigParsingMixin!(GoConfig, "parseGoConfig", ["go", "goConfig"]);
    mixin SimpleBuildOrchestrationMixin!(GoConfig, "parseGoConfig");
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config) @system
    {
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            
            version(Windows)
            {
                if (target.type == TargetType.Executable)
                    name ~= ".exe";
            }
            
            outputs ~= buildPath(config.options.outputDir, name);
        }
        
        return outputs;
    }
    
    private void enhanceConfigFromProject(
        ref GoConfig config,
        const Target target,
        const WorkspaceConfig workspace
    ) @system
    {
        if (target.sources.empty)
            return;
        
        string sourceDir = dirName(target.sources[0]);
        
        auto goModPath = ModuleAnalyzer.findGoMod(sourceDir);
        if (!goModPath.empty && config.modMode == GoModMode.Auto)
        {
            config.modMode = GoModMode.On;
            Logger.debugLog("Detected go.mod at: " ~ goModPath);
            
            auto mod = ModuleAnalyzer.parseGoMod(goModPath);
            if (mod.isValid())
            {
                Logger.debugLog("Module path: " ~ mod.path);
                Logger.debugLog("Go version: " ~ mod.goVersion);
                
                if (config.modPath.empty)
                    config.modPath = mod.path;
            }
        }
        
        auto goWorkPath = ModuleAnalyzer.findGoWork(sourceDir);
        if (!goWorkPath.empty)
        {
            Logger.debugLog("Detected go.work at: " ~ goWorkPath);
            
            auto ws = ModuleAnalyzer.parseGoWork(goWorkPath);
            if (ws.isValid())
                Logger.debugLog("Workspace modules: " ~ ws.use.join(", "));
        }
        
        if (!config.cgo.enabled)
        {
            foreach (source; target.sources)
            {
                if (exists(source) && hasCGoCode(source))
                {
                    Logger.debugLog("Detected CGO code in: " ~ source);
                    config.cgo.enabled = true;
                    break;
                }
            }
        }
    }
    
    private LanguageBuildResult buildExecutable(
        const Target target,
        const WorkspaceConfig config,
        GoConfig goConfig
    ) @system
    {
        LanguageBuildResult result;
        
        if (target.sources.length == 0)
        {
            result.error = "No source files specified for target " ~ target.name;
            return result;
        }
        
        auto builder = GoBuilderFactory.createAuto(goConfig, getCache());
        
        if (!builder.isAvailable())
        {
            result.error = "Go compiler not available. Install from: https://golang.org/dl/";
            return result;
        }
        
        Logger.debugLog("Using builder: " ~ builder.name() ~ " (" ~ builder.getVersion() ~ ")");
        
        auto buildResult = builder.build(target.sources, goConfig, target, config);
        
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        if (!buildResult.toolWarnings.empty)
        {
            Logger.info("Build completed with warnings from tools:");
            foreach (warning; buildResult.toolWarnings)
                Logger.warning("  " ~ warning);
        }
        
        return result;
    }
    
    private LanguageBuildResult buildLibrary(
        const Target target,
        const WorkspaceConfig config,
        GoConfig goConfig
    ) @system
    {
        goConfig.mode = GoBuildMode.Library;
        
        auto builder = GoBuilderFactory.createAuto(goConfig, getCache());
        
        if (!builder.isAvailable())
        {
            LanguageBuildResult result;
            result.error = "Go compiler not available";
            return result;
        }
        
        Logger.debugLog("Building Go library/package");
        
        auto buildResult = builder.build(target.sources, goConfig, target, config);
        
        LanguageBuildResult result;
        result.success = buildResult.success;
        result.error = buildResult.error;
        result.outputs = buildResult.outputs;
        result.outputHash = buildResult.outputHash;
        
        return result;
    }
    
    private LanguageBuildResult runTests(
        const Target target,
        const WorkspaceConfig config,
        GoConfig goConfig
    ) @system
    {
        LanguageBuildResult result;
        
        if (!GoTools.isGoAvailable())
        {
            result.error = "Go not available for running tests";
            return result;
        }
        
        string workDir = config.root;
        if (!target.sources.empty)
            workDir = dirName(target.sources[0]);
        
        string[] cmd = ["go", "test"];
        
        cmd ~= goConfig.test.toFlags();
        
        auto allTags = goConfig.buildTags ~ goConfig.constraints.tags;
        if (!allTags.empty)
        {
            cmd ~= "-tags";
            cmd ~= allTags.join(",");
        }
        
        cmd ~= target.flags;
        
        if (target.sources.empty)
            cmd ~= "./...";
        else
            cmd ~= target.sources;
        
        Logger.info("Running Go tests: " ~ cmd.join(" "));
        
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        if (goConfig.cgo.enabled)
        {
            foreach (key, value; goConfig.cgo.toEnv())
                env[key] = value;
        }
        
        if (goConfig.cross.isCross())
        {
            foreach (key, value; goConfig.cross.toEnv())
                env[key] = value;
        }
        
        auto res = execute(cmd, env, Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            result.error = "Go tests failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        if (goConfig.test.coverage && !goConfig.test.coverProfile.empty)
        {
            auto coverPath = buildPath(workDir, goConfig.test.coverProfile);
            if (exists(coverPath))
                result.outputs ~= coverPath;
        }
        
        return result;
    }
    
    private bool hasCGoCode(string filePath) @system
    {
        try
        {
            auto content = readText(filePath);
            
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
    
    override Import[] analyzeImports(in string[] sources) @system
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
