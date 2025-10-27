module languages.web.javascript.core.handler;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.conv : to;
import languages.base.base;
import languages.web.javascript.bundlers;
import languages.web.javascript.core.config;
import languages.web.shared_.utils;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import utils.process.checker : isCommandAvailable;
// SECURITY: Use secure execute with automatic path validation
import utils.security : execute;
import std.process : Config;

/// JavaScript/TypeScript build handler with bundler support
class JavaScriptHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debugLog("Building JavaScript target: " ~ target.name);
        
        // Parse JavaScript configuration
        JSConfig jsConfig = parseJSConfig(target);
        
        // Detect TypeScript
        bool isTypeScript = target.sources.any!(s => s.endsWith(".ts") || s.endsWith(".tsx"));
        if (isTypeScript && target.language != TargetLanguage.TypeScript)
        {
            Logger.debugLog("Detected TypeScript sources");
        }
        
        // Detect JSX/React
        bool hasJSX = target.sources.any!(s => s.endsWith(".jsx") || s.endsWith(".tsx"));
        if (hasJSX && !jsConfig.jsx)
        {
            Logger.debugLog("Detected JSX sources, enabling JSX support");
            jsConfig.jsx = true;
        }
        
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, jsConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, jsConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, jsConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, jsConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        JSConfig jsConfig = parseJSConfig(target);
        
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            string ext = ".js";
            
            // Adjust extension based on format
            if (jsConfig.format == OutputFormat.ESM)
                ext = ".mjs";
            
            outputs ~= buildPath(config.options.outputDir, name ~ ext);
            
            if (jsConfig.sourcemap)
            {
                outputs ~= buildPath(config.options.outputDir, name ~ ext ~ ".map");
            }
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(in Target target, in WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
        // Check for empty sources
        if (target.sources.length == 0)
        {
            result.success = false;
            result.error = "No source files specified for target " ~ target.name;
            return result;
        }
        
        // Auto-detect mode if not specified
        if (jsConfig.mode == JSBuildMode.Node && jsConfig.bundler == BundlerType.Auto)
        {
            // Check if package.json exists to determine if bundling is needed
            string packageJsonPath = buildPath(dirName(target.sources[0]), "package.json");
            if (exists(packageJsonPath))
            {
                jsConfig.mode = detectModeFromPackageJson(packageJsonPath);
            }
        }
        
        // For Node.js scripts without bundling, just validate
        if (jsConfig.mode == JSBuildMode.Node && jsConfig.bundler == BundlerType.None)
        {
            return validateOnly(target, config);
        }
        
        // Use bundler
        return bundleTarget(target, config, jsConfig);
    }
    
    private LanguageBuildResult buildLibrary(in Target target, in WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
        // Check for empty sources
        if (target.sources.length == 0)
        {
            result.success = false;
            result.error = "No source files specified for target " ~ target.name;
            return result;
        }
        
        // Libraries should use library mode (but respect explicit "none" bundler)
        if (jsConfig.mode == JSBuildMode.Node)
        {
            jsConfig.mode = JSBuildMode.Library;
        }
        
        // Prefer rollup for libraries when bundler is auto
        // But if user explicitly set bundler to "none", respect that
        if (jsConfig.bundler == BundlerType.Auto)
        {
            jsConfig.bundler = BundlerType.Rollup;
        }
        else if (jsConfig.bundler == BundlerType.None)
        {
            // For libraries with bundler "none", just validate and copy sources
            return validateOnly(target, config);
        }
        
        return bundleTarget(target, config, jsConfig);
    }
    
    private LanguageBuildResult runTests(in Target target, in WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
        // Check for empty sources
        if (target.sources.length == 0)
        {
            result.success = false;
            result.error = "No source files specified for target " ~ target.name;
            return result;
        }
        
        // Run tests with configured test runner
        string[] cmd;
        
        // Try to detect test framework from package.json
        string packageJsonPath = findPackageJson(target.sources);
        if (exists(packageJsonPath))
        {
            auto testCmd = detectTestCommand(packageJsonPath);
            if (!testCmd.empty)
            {
                cmd = testCmd;
            }
        }
        
        // Fallback test commands
        if (cmd.empty)
        {
            // Try common test runners
            if (isCommandAvailable("jest"))
                cmd = ["jest"];
            else if (isCommandAvailable("mocha"))
                cmd = ["mocha"];
            else if (isCommandAvailable("vitest"))
                cmd = ["vitest", "run"];
            else
                cmd = ["npm", "test"];
        }
        
        Logger.debugLog("Running tests: " ~ cmd.join(" "));
        
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
    
    private LanguageBuildResult buildCustom(in Target target, in WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Bundle target using configured bundler
    private LanguageBuildResult bundleTarget(in Target target, in WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
        // Install dependencies first if requested (before checking bundler availability)
        if (jsConfig.installDeps)
        {
            languages.web.shared_.utils.installDependencies(target.sources, jsConfig.packageManager);
        }
        
        // Create bundler
        auto bundler = BundlerFactory.create(jsConfig.bundler, jsConfig);
        
        if (!bundler.isAvailable())
        {
            result.error = "Bundler '" ~ bundler.name() ~ "' is not available. " ~
                          "Please install it or set bundler to 'auto' for fallback.";
            return result;
        }
        
        Logger.debugLog("Using bundler: " ~ bundler.name() ~ " (" ~ bundler.getVersion() ~ ")");
        
        // Bundle
        auto bundleResult = bundler.bundle(target.sources, jsConfig, target, config);
        
        if (!bundleResult.success)
        {
            result.error = bundleResult.error;
            return result;
        }
        
        result.success = true;
        result.outputs = bundleResult.outputs;
        result.outputHash = bundleResult.outputHash;
        
        return result;
    }
    
    /// Validate JavaScript syntax without bundling
    private LanguageBuildResult validateOnly(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        foreach (source; target.sources)
        {
            // For TypeScript files, use tsc if available
            if (source.endsWith(".ts") || source.endsWith(".tsx"))
            {
                if (isCommandAvailable("tsc"))
                {
                    auto cmd = ["tsc", "--noEmit", source];
                    auto res = execute(cmd);
                    
                    if (res.status != 0)
                    {
                        result.error = "TypeScript validation failed: " ~ res.output;
                        return result;
                    }
                }
                else
                {
                    Logger.warning("TypeScript file found but tsc not available");
                }
            }
            else
            {
                // Validate JavaScript with Node.js
                auto cmd = ["node", "--check", source];
                auto res = execute(cmd);
                
                if (res.status != 0)
                {
                    result.error = "JavaScript validation failed in " ~ source ~ ": " ~ res.output;
                    return result;
                }
            }
        }
        
        result.success = true;
        result.outputs = target.sources.dup;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Parse JavaScript configuration from target
    private JSConfig parseJSConfig(in Target target)
    {
        JSConfig config;
        
        // Try language-specific keys (javascript, jsConfig for backward compat)
        string configKey = "";
        if ("javascript" in target.langConfig)
            configKey = "javascript";
        else if ("jsConfig" in target.langConfig)
            configKey = "jsConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = JSConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse JavaScript config, using defaults: " ~ e.msg);
            }
        }
        
        // Auto-detect entry point if not specified
        if (config.entry.empty && !target.sources.empty)
        {
            config.entry = target.sources[0];
        }
        
        return config;
    }
    
    /// Detect build mode from package.json
    private JSBuildMode detectModeFromPackageJson(string packageJsonPath)
    {
        try
        {
            auto content = readText(packageJsonPath);
            auto json = parseJSON(content);
            
            // Check for browser field
            if ("browser" in json)
                return JSBuildMode.Bundle;
            
            // Check for module field (ESM library)
            if ("module" in json)
                return JSBuildMode.Library;
            
            // Check for dependencies that suggest bundling
            if ("dependencies" in json)
            {
                auto deps = json["dependencies"].object;
                if ("react" in deps || "vue" in deps || "svelte" in deps)
                    return JSBuildMode.Bundle;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse package.json: " ~ e.msg);
        }
        
        return JSBuildMode.Node;
    }
    
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.JavaScript);
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
