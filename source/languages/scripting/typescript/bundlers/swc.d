module languages.scripting.typescript.bundlers.swc;

import languages.scripting.typescript.bundlers.base;
import languages.scripting.typescript.config;
import languages.scripting.typescript.checker;
import config.schema.schema;
import std.process;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.json;
import utils.files.hash;
import utils.logging.logger;

/// SWC - ultra-fast Rust-based TypeScript compiler
class SWCBundler : TSBundler
{
    TSCompileResult compile(
        string[] sources,
        TSConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        TSCompileResult result;
        
        if (!isAvailable())
        {
            result.error = "SWC compiler not found. Install: npm install -g @swc/cli @swc/core";
            return result;
        }
        
        // Type check first if needed (SWC doesn't type check)
        if (config.mode != TSBuildMode.Check && TypeChecker.isTSCAvailable())
        {
            auto checkResult = TypeChecker.check(sources, config, workspace.root);
            if (!checkResult.success)
            {
                Logger.warning("Type checking failed, but continuing with SWC compilation");
                result.hadTypeErrors = true;
                result.typeErrors = checkResult.errors;
            }
        }
        
        // Determine output directory
        string outputDir = config.outDir.empty ? workspace.options.outputDir : config.outDir;
        mkdirRecurse(outputDir);
        
        // Compile each source file
        string[] outputs;
        
        foreach (source; sources)
        {
            string output = compileSingle(source, config, outputDir, workspace.root);
            if (output.empty)
            {
                result.error = "Failed to compile: " ~ source;
                return result;
            }
            outputs ~= output;
        }
        
        result.success = true;
        result.outputs = outputs;
        result.outputHash = FastHash.hashFiles(outputs);
        
        // Note: SWC doesn't generate declaration files
        // For libraries, recommend using tsc with --emitDeclarationOnly
        if (config.declaration && config.mode == TSBuildMode.Library)
        {
            result.declarations = generateDeclarationsWithTSC(sources, config, outputDir, workspace.root);
        }
        
        return result;
    }
    
    bool isAvailable()
    {
        auto res = execute(["swc", "--version"]);
        return res.status == 0;
    }
    
    string name() const
    {
        return "swc";
    }
    
    string getVersion()
    {
        auto res = execute(["swc", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    bool supportsTypeCheck()
    {
        return false; // SWC is transpile-only
    }
    
    private string compileSingle(string source, TSConfig config, string outputDir, string workspaceRoot)
    {
        import std.uuid : randomUUID;
        
        // Build output path
        string baseName = source.baseName.stripExtension;
        string outputFile = buildPath(outputDir, baseName ~ ".js");
        
        // Create SWC config file (temporary)
        string configFile = buildPath(outputDir, ".swcrc." ~ randomUUID().toString[0..8]);
        scope(exit) {
            if (exists(configFile))
                remove(configFile);
        }
        
        JSONValue swcConfig = buildSWCConfig(config);
        std.file.write(configFile, swcConfig.toJSON());
        
        // Build swc command
        string[] cmd = [
            "swc",
            source,
            "-o", outputFile,
            "--config-file", configFile
        ];
        
        if (config.sourceMap)
        {
            cmd ~= "--source-maps";
            cmd ~= config.inlineSourceMap ? "inline" : "true";
        }
        
        Logger.debug_("Compiling with SWC: " ~ cmd.join(" "));
        
        // Execute swc
        auto res = execute(cmd, null, Config.none, size_t.max, workspaceRoot);
        
        if (res.status != 0)
        {
            Logger.error("SWC compilation failed for " ~ source ~ ": " ~ res.output);
            return "";
        }
        
        return outputFile;
    }
    
    private JSONValue buildSWCConfig(TSConfig config)
    {
        JSONValue swcConfig = parseJSON("{}");
        
        // JsC target
        JSONValue jsc = parseJSON("{}");
        
        // Parser
        JSONValue parser = parseJSON("{}");
        parser["syntax"] = "typescript";
        parser["tsx"] = (config.jsx != TSXMode.Preserve);
        parser["decorators"] = config.experimentalDecorators;
        parser["dynamicImport"] = true;
        
        jsc["parser"] = parser;
        
        // Target
        jsc["target"] = targetToString(config.target);
        
        // Transform
        JSONValue transform = parseJSON("{}");
        
        if (config.jsx != TSXMode.Preserve)
        {
            JSONValue react = parseJSON("{}");
            react["runtime"] = (config.jsx == TSXMode.ReactJSX || config.jsx == TSXMode.ReactJSXDev) ? "automatic" : "classic";
            react["pragma"] = config.jsxFactory;
            react["pragmaFrag"] = config.jsxFragmentFactory;
            if (!config.jsxImportSource.empty)
                react["importSource"] = config.jsxImportSource;
            react["development"] = (config.jsx == TSXMode.ReactJSXDev);
            
            transform["react"] = react;
        }
        
        if (config.experimentalDecorators)
        {
            JSONValue decorator = parseJSON("{}");
            decorator["legacy"] = true;
            transform["legacyDecorator"] = decorator;
        }
        
        jsc["transform"] = transform;
        
        // Keep class names (useful for debugging)
        jsc["keepClassNames"] = !config.minify;
        
        // Minify
        if (config.minify)
        {
            JSONValue minify = parseJSON("{}");
            minify["compress"] = true;
            minify["mangle"] = true;
            jsc["minify"] = minify;
        }
        
        swcConfig["jsc"] = jsc;
        
        // Module
        JSONValue moduleConfig = parseJSON("{}");
        moduleConfig["type"] = moduleTypeToString(config.moduleFormat);
        if (config.strict)
            moduleConfig["strict"] = true;
        swcConfig["module"] = moduleConfig;
        
        // Source maps
        if (config.sourceMap)
        {
            if (config.inlineSourceMap)
                swcConfig["sourceMaps"] = "inline";
            else
                swcConfig["sourceMaps"] = true;
        }
        
        return swcConfig;
    }
    
    private string[] generateDeclarationsWithTSC(string[] sources, TSConfig config, string outputDir, string workspaceRoot)
    {
        if (!TypeChecker.isTSCAvailable())
        {
            Logger.warning("tsc not available, cannot generate declaration files");
            return [];
        }
        
        // Use tsc with --emitDeclarationOnly
        string[] cmd = [
            "tsc",
            "--emitDeclarationOnly",
            "--outDir", outputDir,
            "--declaration"
        ];
        
        if (config.declarationMap)
            cmd ~= "--declarationMap";
        
        cmd ~= sources;
        
        Logger.debug_("Generating declarations with tsc: " ~ cmd.join(" "));
        
        auto res = execute(cmd, null, Config.none, size_t.max, workspaceRoot);
        
        if (res.status != 0)
        {
            Logger.warning("Failed to generate declaration files: " ~ res.output);
            return [];
        }
        
        // Collect declaration files
        string[] declarations;
        foreach (source; sources)
        {
            string baseName = source.baseName.stripExtension;
            string declFile = buildPath(outputDir, baseName ~ ".d.ts");
            if (exists(declFile))
                declarations ~= declFile;
        }
        
        return declarations;
    }
    
    private static string targetToString(TSTarget target)
    {
        final switch (target)
        {
            case TSTarget.ES3: return "es3";
            case TSTarget.ES5: return "es5";
            case TSTarget.ES6: case TSTarget.ES2015: return "es2015";
            case TSTarget.ES2016: return "es2016";
            case TSTarget.ES2017: return "es2017";
            case TSTarget.ES2018: return "es2018";
            case TSTarget.ES2019: return "es2019";
            case TSTarget.ES2020: return "es2020";
            case TSTarget.ES2021: return "es2021";
            case TSTarget.ES2022: return "es2022";
            case TSTarget.ES2023: return "es2023";
            case TSTarget.ESNext: return "esnext";
        }
    }
    
    private static string moduleTypeToString(TSModuleFormat moduleFormat)
    {
        final switch (moduleFormat)
        {
            case TSModuleFormat.CommonJS: return "commonjs";
            case TSModuleFormat.ESM: case TSModuleFormat.ES2015: return "es6";
            case TSModuleFormat.UMD: return "umd";
            case TSModuleFormat.AMD: return "amd";
            case TSModuleFormat.System: return "systemjs";
            case TSModuleFormat.ES2020: return "es6";
            case TSModuleFormat.ESNext: return "es6";
            case TSModuleFormat.Node16: return "nodenext";
            case TSModuleFormat.NodeNext: return "nodenext";
        }
    }
}

