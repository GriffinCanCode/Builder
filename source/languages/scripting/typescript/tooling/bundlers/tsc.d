module languages.scripting.typescript.tooling.bundlers.tsc;

import languages.scripting.typescript.tooling.bundlers.base;
import languages.scripting.typescript.core.config;
import languages.scripting.typescript.tooling.checker;
import config.schema.schema;
import std.process;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import std.conv;
import std.string;
import utils.files.hash;
import utils.logging.logger;

/// Official TypeScript compiler (tsc)
class TSCBundler : TSBundler
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
            result.error = "TypeScript compiler (tsc) not found. Install: npm install -g typescript";
            return result;
        }
        
        // Determine output directory
        string outputDir = config.outDir.empty ? workspace.options.outputDir : config.outDir;
        mkdirRecurse(outputDir);
        
        // Build tsc command
        string[] cmd = ["tsc"];
        
        // Use tsconfig if specified
        if (!config.tsconfig.empty && exists(config.tsconfig))
        {
            cmd ~= ["--project", config.tsconfig];
            
            // Override output directory if specified
            if (!config.outDir.empty)
            {
                cmd ~= ["--outDir", config.outDir];
            }
        }
        else
        {
            // Build inline configuration
            cmd ~= buildCompilerOptions(config, outputDir);
            
            // Add source files
            cmd ~= sources;
        }
        
        Logger.debug_("Compiling with tsc: " ~ cmd.join(" "));
        
        // Execute tsc
        auto res = execute(cmd, null, Config.none, size_t.max, workspace.root);
        
        if (res.status != 0)
        {
            result.error = "TypeScript compilation failed:\n" ~ res.output;
            result.hadTypeErrors = true;
            
            // Parse errors
            TypeCheckResult checkResult;
            parseTypeScriptOutput(res.output, checkResult);
            result.typeErrors = checkResult.errors;
            
            return result;
        }
        
        Logger.debug_("TypeScript compilation successful");
        
        // Collect outputs
        result.outputs = collectOutputs(sources, config, outputDir);
        
        // Collect declaration files if generated
        if (config.declaration)
        {
            result.declarations = collectDeclarations(sources, config, outputDir);
        }
        
        result.success = true;
        result.outputHash = FastHash.hashFiles(result.outputs);
        
        return result;
    }
    
    bool isAvailable()
    {
        return TypeChecker.isTSCAvailable();
    }
    
    string name() const
    {
        return "tsc";
    }
    
    string getVersion()
    {
        return TypeChecker.getTSCVersion();
    }
    
    bool supportsTypeCheck()
    {
        return true;
    }
    
    private string[] buildCompilerOptions(TSConfig config, string outputDir)
    {
        string[] args;
        
        // Output directory
        args ~= ["--outDir", outputDir];
        
        // Target
        args ~= ["--target", targetToString(config.target)];
        
        // Module
        args ~= ["--module", moduleToString(config.moduleFormat)];
        
        // Module resolution
        args ~= ["--moduleResolution", moduleResolutionToString(config.moduleResolution)];
        
        // Declaration files
        if (config.declaration)
        {
            args ~= "--declaration";
            if (config.declarationMap)
                args ~= "--declarationMap";
        }
        
        // Source maps
        if (config.sourceMap)
        {
            args ~= "--sourceMap";
            if (config.inlineSourceMap)
                args ~= "--inlineSourceMap";
            if (config.inlineSources)
                args ~= "--inlineSources";
        }
        
        // Strict options
        if (config.strict) args ~= "--strict";
        if (config.alwaysStrict) args ~= "--alwaysStrict";
        if (config.strictNullChecks) args ~= "--strictNullChecks";
        if (config.strictFunctionTypes) args ~= "--strictFunctionTypes";
        if (config.strictBindCallApply) args ~= "--strictBindCallApply";
        if (config.strictPropertyInitialization) args ~= "--strictPropertyInitialization";
        if (config.noImplicitAny) args ~= "--noImplicitAny";
        if (config.noImplicitThis) args ~= "--noImplicitThis";
        if (config.noImplicitReturns) args ~= "--noImplicitReturns";
        if (config.noFallthroughCasesInSwitch) args ~= "--noFallthroughCasesInSwitch";
        if (config.noUnusedLocals) args ~= "--noUnusedLocals";
        if (config.noUnusedParameters) args ~= "--noUnusedParameters";
        
        // Other options
        if (config.skipLibCheck) args ~= "--skipLibCheck";
        if (config.allowJs) args ~= "--allowJs";
        if (config.checkJs) args ~= "--checkJs";
        if (config.esModuleInterop) args ~= "--esModuleInterop";
        if (config.allowSyntheticDefaultImports) args ~= "--allowSyntheticDefaultImports";
        if (config.forceConsistentCasingInFileNames) args ~= "--forceConsistentCasingInFileNames";
        if (config.resolveJsonModule) args ~= "--resolveJsonModule";
        if (config.isolatedModules) args ~= "--isolatedModules";
        if (config.preserveConstEnums) args ~= "--preserveConstEnums";
        if (config.removeComments) args ~= "--removeComments";
        if (config.importHelpers) args ~= "--importHelpers";
        if (config.downlevelIteration) args ~= "--downlevelIteration";
        if (config.emitDecoratorMetadata) args ~= "--emitDecoratorMetadata";
        if (config.experimentalDecorators) args ~= "--experimentalDecorators";
        if (config.noEmit) args ~= "--noEmit";
        if (config.noEmitOnError) args ~= "--noEmitOnError";
        
        // JSX
        if (config.jsx != TSXMode.React || !config.jsxFactory.empty)
        {
            args ~= ["--jsx", jsxModeToString(config.jsx)];
            if (!config.jsxFactory.empty && config.jsx == TSXMode.React)
                args ~= ["--jsxFactory", config.jsxFactory];
            if (!config.jsxFragmentFactory.empty)
                args ~= ["--jsxFragmentFactory", config.jsxFragmentFactory];
            if (!config.jsxImportSource.empty && 
                (config.jsx == TSXMode.ReactJSX || config.jsx == TSXMode.ReactJSXDev))
                args ~= ["--jsxImportSource", config.jsxImportSource];
        }
        
        // Paths
        if (!config.baseUrl.empty)
            args ~= ["--baseUrl", config.baseUrl];
        
        if (!config.rootDir.empty)
            args ~= ["--rootDir", config.rootDir];
        
        return args;
    }
    
    private string[] collectOutputs(string[] sources, TSConfig config, string outputDir)
    {
        string[] outputs;
        
        foreach (source; sources)
        {
            // Convert .ts/.tsx to .js/.jsx
            string baseName = source.baseName.stripExtension;
            string ext = source.extension;
            
            string outExt = ".js";
            if (ext == ".tsx" && config.jsx == TSXMode.Preserve)
                outExt = ".jsx";
            
            string outputFile = buildPath(outputDir, baseName ~ outExt);
            if (exists(outputFile))
                outputs ~= outputFile;
        }
        
        return outputs;
    }
    
    private string[] collectDeclarations(string[] sources, TSConfig config, string outputDir)
    {
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
    
    private static void parseTypeScriptOutput(string output, ref TypeCheckResult result)
    {
        import std.string : split, strip, indexOf;
        
        auto lines = output.split("\n");
        
        foreach (line; lines)
        {
            auto trimmed = line.strip;
            if (trimmed.empty)
                continue;
            
            if (trimmed.indexOf("error TS") != -1)
            {
                result.errors ~= trimmed;
            }
            else if (trimmed.indexOf("warning TS") != -1)
            {
                result.warnings ~= trimmed;
            }
        }
    }
    
    private static string targetToString(TSTarget target)
    {
        final switch (target)
        {
            case TSTarget.ES3: return "ES3";
            case TSTarget.ES5: return "ES5";
            case TSTarget.ES6: case TSTarget.ES2015: return "ES2015";
            case TSTarget.ES2016: return "ES2016";
            case TSTarget.ES2017: return "ES2017";
            case TSTarget.ES2018: return "ES2018";
            case TSTarget.ES2019: return "ES2019";
            case TSTarget.ES2020: return "ES2020";
            case TSTarget.ES2021: return "ES2021";
            case TSTarget.ES2022: return "ES2022";
            case TSTarget.ES2023: return "ES2023";
            case TSTarget.ESNext: return "ESNext";
        }
    }
    
    private static string moduleToString(TSModuleFormat moduleFormat)
    {
        final switch (moduleFormat)
        {
            case TSModuleFormat.CommonJS: return "CommonJS";
            case TSModuleFormat.ESM: case TSModuleFormat.ES2015: return "ES2015";
            case TSModuleFormat.UMD: return "UMD";
            case TSModuleFormat.AMD: return "AMD";
            case TSModuleFormat.System: return "System";
            case TSModuleFormat.ES2020: return "ES2020";
            case TSModuleFormat.ESNext: return "ESNext";
            case TSModuleFormat.Node16: return "Node16";
            case TSModuleFormat.NodeNext: return "NodeNext";
        }
    }
    
    private static string moduleResolutionToString(TSModuleResolution resolution)
    {
        final switch (resolution)
        {
            case TSModuleResolution.Classic: return "Classic";
            case TSModuleResolution.Node: return "Node";
            case TSModuleResolution.Node16: return "Node16";
            case TSModuleResolution.NodeNext: return "NodeNext";
            case TSModuleResolution.Bundler: return "Bundler";
        }
    }
    
    private static string jsxModeToString(TSXMode mode)
    {
        final switch (mode)
        {
            case TSXMode.Preserve: return "preserve";
            case TSXMode.React: return "react";
            case TSXMode.ReactJSX: return "react-jsx";
            case TSXMode.ReactJSXDev: return "react-jsxdev";
            case TSXMode.ReactNative: return "react-native";
        }
    }
}

