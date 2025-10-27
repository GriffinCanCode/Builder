module languages.web.typescript.core.handler;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import std.string;
import languages.base.base;
import languages.web.typescript.core.config;
import languages.web.typescript.tooling.checker;
import languages.web.typescript.tooling.bundlers;
import languages.web.shared_.utils;
import config.schema.schema;
import analysis.targets.types;
import analysis.targets.spec;
import utils.files.hash;
import utils.logging.logger;
import utils.process.checker : isCommandAvailable;

/// TypeScript build handler - separate from JavaScript with type-first approach
class TypeScriptHandler : BaseLanguageHandler
{
    protected override LanguageBuildResult buildImpl(in Target target, in WorkspaceConfig config)
    {
        LanguageBuildResult result;
        
        Logger.debugLog("Building TypeScript target: " ~ target.name);
        
        // Parse TypeScript configuration
        TSConfig tsConfig = parseTSConfig(target);
        
        // Detect JSX/TSX
        bool hasTSX = target.sources.any!(s => s.endsWith(".tsx"));
        if (hasTSX && tsConfig.jsx == TSXMode.React)
        {
            Logger.debugLog("Detected TSX sources");
        }
        
        final switch (target.type)
        {
            case TargetType.Executable:
                result = buildExecutable(target, config, tsConfig);
                break;
            case TargetType.Library:
                result = buildLibrary(target, config, tsConfig);
                break;
            case TargetType.Test:
                result = runTests(target, config, tsConfig);
                break;
            case TargetType.Custom:
                result = buildCustom(target, config, tsConfig);
                break;
        }
        
        return result;
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        TSConfig tsConfig = parseTSConfig(target);
        
        string[] outputs;
        
        if (!target.outputPath.empty)
        {
            outputs ~= buildPath(config.options.outputDir, target.outputPath);
        }
        else
        {
            auto name = target.name.split(":")[$ - 1];
            string ext = ".js";
            
            // Adjust extension based on module format
            if (tsConfig.moduleFormat == TSModuleFormat.ESM)
                ext = ".mjs";
            
            outputs ~= buildPath(config.options.outputDir, name ~ ext);
            
            if (tsConfig.sourceMap)
            {
                outputs ~= buildPath(config.options.outputDir, name ~ ext ~ ".map");
            }
            
            if (tsConfig.declaration)
            {
                outputs ~= buildPath(config.options.outputDir, name ~ ".d.ts");
                if (tsConfig.declarationMap)
                    outputs ~= buildPath(config.options.outputDir, name ~ ".d.ts.map");
            }
        }
        
        return outputs;
    }
    
    private LanguageBuildResult buildExecutable(in Target target, in WorkspaceConfig config, TSConfig tsConfig)
    {
        LanguageBuildResult result;
        
        // For type check only mode
        if (tsConfig.mode == TSBuildMode.Check)
        {
            return typeCheckOnly(target, config, tsConfig);
        }
        
        // Install dependencies if requested
        if (tsConfig.installDeps)
        {
            languages.web.shared_.utils.installDependencies(target.sources, tsConfig.packageManager);
        }
        
        // Compile/bundle with selected compiler
        return compileTarget(target, config, tsConfig);
    }
    
    private LanguageBuildResult buildLibrary(in Target target, in WorkspaceConfig config, TSConfig tsConfig)
    {
        // Libraries should use library mode
        if (tsConfig.mode != TSBuildMode.Library)
        {
            tsConfig.mode = TSBuildMode.Library;
        }
        
        // Libraries should generate declarations
        if (!tsConfig.declaration)
        {
            Logger.warning("Library target should generate declarations, enabling");
            tsConfig.declaration = true;
        }
        
        // Prefer tsc for libraries (best declaration generation)
        if (tsConfig.compiler == TSCompiler.Auto)
        {
            tsConfig.compiler = TSCompiler.TSC;
        }
        
        return compileTarget(target, config, tsConfig);
    }
    
    private LanguageBuildResult runTests(in Target target, in WorkspaceConfig config, TSConfig tsConfig)
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
            // Try common TypeScript test runners
            if (isCommandAvailable("vitest"))
                cmd = ["vitest", "run"];
            else if (isCommandAvailable("jest"))
                cmd = ["jest"];
            else if (isCommandAvailable("ts-node"))
                cmd = ["ts-node", target.sources[0]];
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
    
    private LanguageBuildResult buildCustom(in Target target, in WorkspaceConfig config, TSConfig tsConfig)
    {
        LanguageBuildResult result;
        result.success = true;
        result.outputHash = FastHash.hashStrings(target.sources);
        return result;
    }
    
    /// Compile/bundle target using configured compiler
    private LanguageBuildResult compileTarget(in Target target, in WorkspaceConfig config, TSConfig tsConfig)
    {
        LanguageBuildResult result;
        
        // Create compiler/bundler
        auto bundler = TSBundlerFactory.create(tsConfig.compiler, tsConfig);
        
        if (!bundler.isAvailable())
        {
            result.error = "TypeScript compiler '" ~ bundler.name() ~ "' is not available. " ~
                          "Install it or set compiler to 'auto' for fallback.";
            return result;
        }
        
        Logger.debugLog("Using TypeScript compiler: " ~ bundler.name() ~ " (" ~ bundler.getVersion() ~ ")");
        
        // Compile
        auto compileResult = bundler.compile(target.sources, tsConfig, target, config);
        
        if (!compileResult.success)
        {
            result.error = compileResult.error;
            return result;
        }
        
        // Report type errors even if compilation succeeded
        if (compileResult.hadTypeErrors)
        {
            Logger.warning("Type errors detected (but compilation continued):");
            foreach (err; compileResult.typeErrors)
            {
                Logger.warning("  " ~ err);
            }
        }
        
        result.success = true;
        result.outputs = compileResult.outputs ~ compileResult.declarations;
        result.outputHash = compileResult.outputHash;
        
        return result;
    }
    
    /// Type check without compilation
    private LanguageBuildResult typeCheckOnly(in Target target, in WorkspaceConfig config, TSConfig tsConfig)
    {
        LanguageBuildResult result;
        
        auto checkResult = TypeChecker.check(target.sources, tsConfig, config.root);
        
        if (!checkResult.success)
        {
            result.error = "Type check failed:\n" ~ checkResult.errors.join("\n");
            return result;
        }
        
        if (checkResult.hasWarnings)
        {
            Logger.warning("Type check warnings:");
            foreach (warn; checkResult.warnings)
            {
                Logger.warning("  " ~ warn);
            }
        }
        
        result.success = true;
        result.outputs = target.sources.dup;
        result.outputHash = FastHash.hashStrings(target.sources);
        
        return result;
    }
    
    /// Parse TypeScript configuration from target
    private TSConfig parseTSConfig(in Target target)
    {
        TSConfig config;
        
        // Try language-specific keys
        string configKey = "";
        if ("typescript" in target.langConfig)
            configKey = "typescript";
        else if ("tsConfig" in target.langConfig)
            configKey = "tsConfig";
        
        if (!configKey.empty)
        {
            try
            {
                auto json = parseJSON(target.langConfig[configKey]);
                config = TSConfig.fromJSON(json);
            }
            catch (Exception e)
            {
                Logger.warning("Failed to parse TypeScript config, using defaults: " ~ e.msg);
            }
        }
        
        // Try to load from tsconfig.json if specified
        if (!config.tsconfig.empty && exists(config.tsconfig))
        {
            auto fileConfig = TypeChecker.loadFromTSConfig(config.tsconfig);
            // Merge file config with explicit config (explicit takes precedence)
            config = mergeTSConfigs(fileConfig, config);
        }
        else
        {
            // Look for tsconfig.json in project directory
            string tsconfigPath = findTSConfig(target.sources);
            if (!tsconfigPath.empty)
            {
                auto fileConfig = TypeChecker.loadFromTSConfig(tsconfigPath);
                config = mergeTSConfigs(fileConfig, config);
                config.tsconfig = tsconfigPath;
            }
        }
        
        // Auto-detect entry point if not specified
        if (config.entry.empty && !target.sources.empty)
        {
            config.entry = target.sources[0];
        }
        
        return config;
    }
    
    /// Merge two TSConfig structs (second takes precedence)
    private TSConfig mergeTSConfigs(TSConfig base, TSConfig override_)
    {
        // For now, just return override if it has values, else base
        // This is simplified; could be more sophisticated
        TSConfig result = base;
        
        if (override_.mode != TSBuildMode.Compile) result.mode = override_.mode;
        if (override_.compiler != TSCompiler.Auto) result.compiler = override_.compiler;
        if (!override_.entry.empty) result.entry = override_.entry;
        if (!override_.outDir.empty) result.outDir = override_.outDir;
        if (override_.target != TSTarget.ES2020) result.target = override_.target;
        if (override_.moduleFormat != TSModuleFormat.CommonJS) result.moduleFormat = override_.moduleFormat;
        if (override_.declaration) result.declaration = true;
        if (override_.sourceMap) result.sourceMap = true;
        if (override_.strict) result.strict = true;
        
        return result;
    }
    
    /// Find tsconfig.json in source tree
    private string findTSConfig(const(string[]) sources)
    {
        if (sources.empty)
            return "";
        
        string dir = dirName(sources[0]);
        
        while (dir != "/" && dir.length > 1)
        {
            string tsconfigPath = buildPath(dir, "tsconfig.json");
            if (exists(tsconfigPath))
                return tsconfigPath;
            
            dir = dirName(dir);
        }
        
        return "";
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        auto spec = getLanguageSpec(TargetLanguage.TypeScript);
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

