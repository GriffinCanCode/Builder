module languages.scripting.javascript;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import languages.base.base;
import languages.scripting.javascript.bundlers;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;

/// JavaScript/TypeScript build handler with bundler support
class JavaScriptHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(Target target, WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debug_("Building JavaScript target: " ~ target.name);
        
        // Parse JavaScript configuration
        JSConfig jsConfig = parseJSConfig(target);
        
        // Detect TypeScript
        bool isTypeScript = target.sources.any!(s => s.endsWith(".ts") || s.endsWith(".tsx"));
        if (isTypeScript && target.language != TargetLanguage.TypeScript)
        {
            Logger.debug_("Detected TypeScript sources");
        }
        
        // Detect JSX/React
        bool hasJSX = target.sources.any!(s => s.endsWith(".jsx") || s.endsWith(".tsx"));
        if (hasJSX && !jsConfig.jsx)
        {
            Logger.debug_("Detected JSX sources, enabling JSX support");
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
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
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
    
    private LanguageBuildResult buildExecutable(Target target, WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
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
    
    private LanguageBuildResult buildLibrary(Target target, WorkspaceConfig config, JSConfig jsConfig)
    {
        // Libraries should use library mode
        if (jsConfig.mode == JSBuildMode.Node)
        {
            jsConfig.mode = JSBuildMode.Library;
        }
        
        // Prefer rollup for libraries (better tree-shaking)
        if (jsConfig.bundler == BundlerType.Auto)
        {
            jsConfig.bundler = BundlerType.Rollup;
        }
        
        return bundleTarget(target, config, jsConfig);
    }
    
    private LanguageBuildResult runTests(Target target, WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
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
        
        Logger.debug_("Running tests: " ~ cmd.join(" "));
        
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
    
    private LanguageBuildResult buildCustom(Target target, WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Bundle target using configured bundler
    private LanguageBuildResult bundleTarget(Target target, WorkspaceConfig config, JSConfig jsConfig)
    {
        LanguageBuildResult result;
        
        // Create bundler
        auto bundler = BundlerFactory.create(jsConfig.bundler, jsConfig);
        
        if (!bundler.isAvailable())
        {
            result.error = "Bundler '" ~ bundler.name() ~ "' is not available. " ~
                          "Please install it or set bundler to 'auto' for fallback.";
            return result;
        }
        
        Logger.debug_("Using bundler: " ~ bundler.name() ~ " (" ~ bundler.getVersion() ~ ")");
        
        // Install dependencies if requested
        if (jsConfig.installDeps)
        {
            installDependencies(target, jsConfig);
        }
        
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
    private LanguageBuildResult validateOnly(Target target, WorkspaceConfig config)
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
        result.outputs = target.sources;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Parse JavaScript configuration from target
    private JSConfig parseJSConfig(Target target)
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
    
    /// Find package.json in source tree
    private string findPackageJson(string[] sources)
    {
        if (sources.empty)
            return "";
        
        string dir = dirName(sources[0]);
        
        while (dir != "/" && dir.length > 1)
        {
            string packagePath = buildPath(dir, "package.json");
            if (exists(packagePath))
                return packagePath;
            
            dir = dirName(dir);
        }
        
        return "";
    }
    
    /// Detect test command from package.json
    private string[] detectTestCommand(string packageJsonPath)
    {
        try
        {
            auto content = readText(packageJsonPath);
            auto json = parseJSON(content);
            
            if ("scripts" in json && "test" in json["scripts"].object)
            {
                string testScript = json["scripts"]["test"].str;
                if (testScript != "echo \"Error: no test specified\" && exit 1")
                {
                    return ["npm", "test"];
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse package.json: " ~ e.msg);
        }
        
        return [];
    }
    
    /// Install npm dependencies
    private void installDependencies(Target target, JSConfig config)
    {
        string packageJsonPath = findPackageJson(target.sources);
        if (packageJsonPath.empty || !exists(packageJsonPath))
        {
            Logger.warning("No package.json found, skipping dependency installation");
            return;
        }
        
        string packageDir = dirName(packageJsonPath);
        Logger.info("Installing dependencies with " ~ config.packageManager ~ "...");
        
        string[] cmd = [config.packageManager, "install"];
        auto res = execute(cmd, null, std.process.Config.none, size_t.max, packageDir);
        
        if (res.status != 0)
        {
            Logger.warning("Failed to install dependencies: " ~ res.output);
        }
        else
        {
            Logger.info("Dependencies installed successfully");
        }
    }
    
    /// Check if command is available
    private bool isCommandAvailable(string command)
    {
        version(Windows)
        {
            auto res = execute(["where", command]);
        }
        else
        {
            auto res = execute(["which", command]);
        }
        
        return res.status == 0;
    }
    
    override Import[] analyzeImports(string[] sources)
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
