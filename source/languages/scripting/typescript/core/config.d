module languages.scripting.typescript.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;

/// TypeScript build modes
enum TSBuildMode
{
    /// Type check only - no emit
    Check,
    /// Compile to JavaScript
    Compile,
    /// Bundle with dependencies
    Bundle,
    /// Library with declaration files
    Library
}

/// TypeScript compiler selection
enum TSCompiler
{
    /// Auto-detect best available
    Auto,
    /// Official TypeScript compiler (tsc)
    TSC,
    /// SWC - ultra-fast Rust-based compiler
    SWC,
    /// esbuild - optimized for TypeScript
    ESBuild,
    /// No compilation (type check only)
    None
}

/// Module format for output
enum TSModuleFormat
{
    /// CommonJS
    CommonJS,
    /// ES Modules
    ESM,
    /// UMD (Universal Module Definition)
    UMD,
    /// AMD (Asynchronous Module Definition)
    AMD,
    /// System.js format
    System,
    /// ES2015
    ES2015,
    /// ES2020
    ES2020,
    /// ESNext
    ESNext,
    /// Node16
    Node16,
    /// NodeNext
    NodeNext
}

/// Module resolution strategy
enum TSModuleResolution
{
    /// Classic resolution
    Classic,
    /// Node.js resolution
    Node,
    /// Node16 resolution
    Node16,
    /// NodeNext resolution
    NodeNext,
    /// Bundler resolution
    Bundler
}

/// JSX compilation mode
enum TSXMode
{
    /// Preserve JSX
    Preserve,
    /// React JSX transform
    React,
    /// React JSX (development)
    ReactJSX,
    /// React JSX (development)
    ReactJSXDev,
    /// React Native
    ReactNative
}

/// Target ECMAScript version
enum TSTarget
{
    ES3,
    ES5,
    ES6,
    ES2015,
    ES2016,
    ES2017,
    ES2018,
    ES2019,
    ES2020,
    ES2021,
    ES2022,
    ES2023,
    ESNext
}

/// TypeScript-specific configuration
struct TSConfig
{
    /// Build mode
    TSBuildMode mode = TSBuildMode.Compile;
    
    /// Compiler selection
    TSCompiler compiler = TSCompiler.Auto;
    
    /// Entry point
    string entry;
    
    /// Output directory
    string outDir;
    
    /// Root directory
    string rootDir;
    
    /// Target ECMAScript version
    TSTarget target = TSTarget.ES2020;
    
    /// Module format
    TSModuleFormat moduleFormat = TSModuleFormat.CommonJS;
    
    /// Module resolution strategy
    TSModuleResolution moduleResolution = TSModuleResolution.Node;
    
    /// Generate declaration files (.d.ts)
    bool declaration = false;
    
    /// Generate declaration maps
    bool declarationMap = false;
    
    /// Generate source maps
    bool sourceMap = false;
    
    /// Inline source maps
    bool inlineSourceMap = false;
    
    /// Inline sources in source maps
    bool inlineSources = false;
    
    /// Enable strict type checking
    bool strict = true;
    
    /// Enable all strict mode options
    bool alwaysStrict = false;
    
    /// Strict null checks
    bool strictNullChecks = false;
    
    /// Strict function types
    bool strictFunctionTypes = false;
    
    /// Strict bind/call/apply
    bool strictBindCallApply = false;
    
    /// Strict property initialization
    bool strictPropertyInitialization = false;
    
    /// No implicit any
    bool noImplicitAny = false;
    
    /// No implicit this
    bool noImplicitThis = false;
    
    /// No implicit returns
    bool noImplicitReturns = false;
    
    /// No fallthrough cases in switch
    bool noFallthroughCasesInSwitch = false;
    
    /// No unused locals
    bool noUnusedLocals = false;
    
    /// No unused parameters
    bool noUnusedParameters = false;
    
    /// Skip lib check
    bool skipLibCheck = true;
    
    /// Allow JS files
    bool allowJs = false;
    
    /// Check JS files
    bool checkJs = false;
    
    /// ES module interop
    bool esModuleInterop = true;
    
    /// Allow synthetic default imports
    bool allowSyntheticDefaultImports = false;
    
    /// Force consistent casing in file names
    bool forceConsistentCasingInFileNames = true;
    
    /// Resolve JSON modules
    bool resolveJsonModule = false;
    
    /// Isolated modules
    bool isolatedModules = false;
    
    /// Preserve const enums
    bool preserveConstEnums = false;
    
    /// Remove comments
    bool removeComments = false;
    
    /// No emit
    bool noEmit = false;
    
    /// No emit on error
    bool noEmitOnError = false;
    
    /// Import helpers
    bool importHelpers = false;
    
    /// Down level iteration
    bool downlevelIteration = false;
    
    /// Emit decorator metadata
    bool emitDecoratorMetadata = false;
    
    /// Experimental decorators
    bool experimentalDecorators = false;
    
    /// JSX mode
    TSXMode jsx = TSXMode.React;
    
    /// JSX factory function
    string jsxFactory = "React.createElement";
    
    /// JSX fragment factory
    string jsxFragmentFactory = "React.Fragment";
    
    /// JSX import source
    string jsxImportSource;
    
    /// Minify output
    bool minify = false;
    
    /// Bundler-specific: external packages
    string[] external;
    
    /// Custom tsconfig.json path
    string tsconfig;
    
    /// Package manager
    string packageManager = "npm";
    
    /// Auto-install dependencies
    bool installDeps = false;
    
    /// Additional compiler options (passed directly)
    string[string] customOptions;
    
    /// Type roots
    string[] typeRoots;
    
    /// Types to include
    string[] types;
    
    /// Base URL for module resolution
    string baseUrl;
    
    /// Path mappings
    string[string] paths;
    
    /// Parse from JSON
    static TSConfig fromJSON(JSONValue json)
    {
        TSConfig config;
        
        if ("mode" in json)
        {
            string modeStr = json["mode"].str;
            switch (modeStr)
            {
                case "check": config.mode = TSBuildMode.Check; break;
                case "compile": config.mode = TSBuildMode.Compile; break;
                case "bundle": config.mode = TSBuildMode.Bundle; break;
                case "library": config.mode = TSBuildMode.Library; break;
                default: config.mode = TSBuildMode.Compile; break;
            }
        }
        
        if ("compiler" in json)
        {
            string compilerStr = json["compiler"].str;
            switch (compilerStr)
            {
                case "auto": config.compiler = TSCompiler.Auto; break;
                case "tsc": config.compiler = TSCompiler.TSC; break;
                case "swc": config.compiler = TSCompiler.SWC; break;
                case "esbuild": config.compiler = TSCompiler.ESBuild; break;
                case "none": config.compiler = TSCompiler.None; break;
                default: config.compiler = TSCompiler.Auto; break;
            }
        }
        
        if ("entry" in json) config.entry = json["entry"].str;
        if ("outDir" in json) config.outDir = json["outDir"].str;
        if ("rootDir" in json) config.rootDir = json["rootDir"].str;
        if ("tsconfig" in json) config.tsconfig = json["tsconfig"].str;
        if ("packageManager" in json) config.packageManager = json["packageManager"].str;
        if ("jsxFactory" in json) config.jsxFactory = json["jsxFactory"].str;
        if ("jsxFragmentFactory" in json) config.jsxFragmentFactory = json["jsxFragmentFactory"].str;
        if ("jsxImportSource" in json) config.jsxImportSource = json["jsxImportSource"].str;
        if ("baseUrl" in json) config.baseUrl = json["baseUrl"].str;
        
        // Boolean flags
        if ("declaration" in json) config.declaration = json["declaration"].type == JSONType.true_;
        if ("declarationMap" in json) config.declarationMap = json["declarationMap"].type == JSONType.true_;
        if ("sourceMap" in json) config.sourceMap = json["sourceMap"].type == JSONType.true_;
        if ("inlineSourceMap" in json) config.inlineSourceMap = json["inlineSourceMap"].type == JSONType.true_;
        if ("inlineSources" in json) config.inlineSources = json["inlineSources"].type == JSONType.true_;
        if ("strict" in json) config.strict = json["strict"].type == JSONType.true_;
        if ("alwaysStrict" in json) config.alwaysStrict = json["alwaysStrict"].type == JSONType.true_;
        if ("strictNullChecks" in json) config.strictNullChecks = json["strictNullChecks"].type == JSONType.true_;
        if ("strictFunctionTypes" in json) config.strictFunctionTypes = json["strictFunctionTypes"].type == JSONType.true_;
        if ("strictBindCallApply" in json) config.strictBindCallApply = json["strictBindCallApply"].type == JSONType.true_;
        if ("strictPropertyInitialization" in json) config.strictPropertyInitialization = json["strictPropertyInitialization"].type == JSONType.true_;
        if ("noImplicitAny" in json) config.noImplicitAny = json["noImplicitAny"].type == JSONType.true_;
        if ("noImplicitThis" in json) config.noImplicitThis = json["noImplicitThis"].type == JSONType.true_;
        if ("noImplicitReturns" in json) config.noImplicitReturns = json["noImplicitReturns"].type == JSONType.true_;
        if ("noFallthroughCasesInSwitch" in json) config.noFallthroughCasesInSwitch = json["noFallthroughCasesInSwitch"].type == JSONType.true_;
        if ("noUnusedLocals" in json) config.noUnusedLocals = json["noUnusedLocals"].type == JSONType.true_;
        if ("noUnusedParameters" in json) config.noUnusedParameters = json["noUnusedParameters"].type == JSONType.true_;
        if ("skipLibCheck" in json) config.skipLibCheck = json["skipLibCheck"].type == JSONType.true_;
        if ("allowJs" in json) config.allowJs = json["allowJs"].type == JSONType.true_;
        if ("checkJs" in json) config.checkJs = json["checkJs"].type == JSONType.true_;
        if ("esModuleInterop" in json) config.esModuleInterop = json["esModuleInterop"].type == JSONType.true_;
        if ("allowSyntheticDefaultImports" in json) config.allowSyntheticDefaultImports = json["allowSyntheticDefaultImports"].type == JSONType.true_;
        if ("forceConsistentCasingInFileNames" in json) config.forceConsistentCasingInFileNames = json["forceConsistentCasingInFileNames"].type == JSONType.true_;
        if ("resolveJsonModule" in json) config.resolveJsonModule = json["resolveJsonModule"].type == JSONType.true_;
        if ("isolatedModules" in json) config.isolatedModules = json["isolatedModules"].type == JSONType.true_;
        if ("preserveConstEnums" in json) config.preserveConstEnums = json["preserveConstEnums"].type == JSONType.true_;
        if ("removeComments" in json) config.removeComments = json["removeComments"].type == JSONType.true_;
        if ("noEmit" in json) config.noEmit = json["noEmit"].type == JSONType.true_;
        if ("noEmitOnError" in json) config.noEmitOnError = json["noEmitOnError"].type == JSONType.true_;
        if ("importHelpers" in json) config.importHelpers = json["importHelpers"].type == JSONType.true_;
        if ("downlevelIteration" in json) config.downlevelIteration = json["downlevelIteration"].type == JSONType.true_;
        if ("emitDecoratorMetadata" in json) config.emitDecoratorMetadata = json["emitDecoratorMetadata"].type == JSONType.true_;
        if ("experimentalDecorators" in json) config.experimentalDecorators = json["experimentalDecorators"].type == JSONType.true_;
        if ("minify" in json) config.minify = json["minify"].type == JSONType.true_;
        if ("installDeps" in json) config.installDeps = json["installDeps"].type == JSONType.true_;
        
        // Enums
        if ("target" in json)
        {
            string targetStr = json["target"].str;
            switch (targetStr.toLower())
            {
                case "es3": config.target = TSTarget.ES3; break;
                case "es5": config.target = TSTarget.ES5; break;
                case "es6": case "es2015": config.target = TSTarget.ES2015; break;
                case "es2016": config.target = TSTarget.ES2016; break;
                case "es2017": config.target = TSTarget.ES2017; break;
                case "es2018": config.target = TSTarget.ES2018; break;
                case "es2019": config.target = TSTarget.ES2019; break;
                case "es2020": config.target = TSTarget.ES2020; break;
                case "es2021": config.target = TSTarget.ES2021; break;
                case "es2022": config.target = TSTarget.ES2022; break;
                case "es2023": config.target = TSTarget.ES2023; break;
                case "esnext": config.target = TSTarget.ESNext; break;
                default: config.target = TSTarget.ES2020; break;
            }
        }
        
        if ("module" in json)
        {
            string moduleStr = json["module"].str;
            switch (moduleStr.toLower())
            {
                case "commonjs": config.moduleFormat = TSModuleFormat.CommonJS; break;
                case "esm": case "es6": case "es2015": config.moduleFormat = TSModuleFormat.ESM; break;
                case "umd": config.moduleFormat = TSModuleFormat.UMD; break;
                case "amd": config.moduleFormat = TSModuleFormat.AMD; break;
                case "system": config.moduleFormat = TSModuleFormat.System; break;
                case "es2020": config.moduleFormat = TSModuleFormat.ES2020; break;
                case "esnext": config.moduleFormat = TSModuleFormat.ESNext; break;
                case "node16": config.moduleFormat = TSModuleFormat.Node16; break;
                case "nodenext": config.moduleFormat = TSModuleFormat.NodeNext; break;
                default: config.moduleFormat = TSModuleFormat.CommonJS; break;
            }
        }
        
        if ("moduleResolution" in json)
        {
            string resStr = json["moduleResolution"].str;
            switch (resStr.toLower())
            {
                case "classic": config.moduleResolution = TSModuleResolution.Classic; break;
                case "node": config.moduleResolution = TSModuleResolution.Node; break;
                case "node16": config.moduleResolution = TSModuleResolution.Node16; break;
                case "nodenext": config.moduleResolution = TSModuleResolution.NodeNext; break;
                case "bundler": config.moduleResolution = TSModuleResolution.Bundler; break;
                default: config.moduleResolution = TSModuleResolution.Node; break;
            }
        }
        
        if ("jsx" in json)
        {
            string jsxStr = json["jsx"].str;
            switch (jsxStr.toLower())
            {
                case "preserve": config.jsx = TSXMode.Preserve; break;
                case "react": config.jsx = TSXMode.React; break;
                case "react-jsx": config.jsx = TSXMode.ReactJSX; break;
                case "react-jsxdev": config.jsx = TSXMode.ReactJSXDev; break;
                case "react-native": config.jsx = TSXMode.ReactNative; break;
                default: config.jsx = TSXMode.React; break;
            }
        }
        
        // Arrays
        if ("external" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.external = json["external"].array.map!(e => e.str).array;
        }
        
        if ("typeRoots" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.typeRoots = json["typeRoots"].array.map!(e => e.str).array;
        }
        
        if ("types" in json)
        {
            import std.algorithm : map;
            import std.array : array;
            config.types = json["types"].array.map!(e => e.str).array;
        }
        
        // Maps
        if ("customOptions" in json)
        {
            foreach (string key, value; json["customOptions"].object)
            {
                config.customOptions[key] = value.str;
            }
        }
        
        if ("paths" in json)
        {
            foreach (string key, value; json["paths"].object)
            {
                import std.json : toJSON;
                config.paths[key] = value.toJSON();
            }
        }
        
        return config;
    }
}

/// TypeScript compilation result
struct TSCompileResult
{
    bool success;
    string error;
    string[] outputs;
    string[] declarations; // .d.ts files
    string outputHash;
    bool hadTypeErrors;
    string[] typeErrors;
}

