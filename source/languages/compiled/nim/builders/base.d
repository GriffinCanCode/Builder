module languages.compiled.nim.builders.base;

import std.algorithm;
import std.range;
import std.string;
import languages.compiled.nim.core.config;
import infrastructure.config.schema.schema;
import infrastructure.analysis.targets.types;
import engine.caching.actions.action : ActionCache;

/// Base interface for Nim builders
interface NimBuilder
{
    /// Build Nim project
    NimCompileResult build(
        in string[] sources,
        in NimConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get builder version
    string getVersion();
    
    /// Supports specific features
    bool supportsFeature(string feature);
    
    /// Set action cache for incremental builds
    void setActionCache(ActionCache cache);
}

/// Factory for creating Nim builders
class NimBuilderFactory
{
    /// Create builder based on type with optional action cache
    static NimBuilder create(NimBuilderType builderType, NimConfig config, ActionCache cache = null)
    {
        import languages.compiled.nim.builders.nimble;
        import languages.compiled.nim.builders.compile;
        import languages.compiled.nim.builders.check;
        import languages.compiled.nim.builders.doc;
        import languages.compiled.nim.builders.js;
        
        NimBuilder builder;
        
        final switch (builderType)
        {
            case NimBuilderType.Auto:
                builder = createAuto(config);
                break;
            case NimBuilderType.Nimble:
                builder = new NimbleBuilder();
                break;
            case NimBuilderType.Compile:
                builder = new CompileBuilder();
                break;
            case NimBuilderType.Check:
                builder = new CheckBuilder();
                break;
            case NimBuilderType.Doc:
                builder = new DocBuilder();
                break;
            case NimBuilderType.Js:
                builder = new JsBuilder();
                break;
        }
        
        if (cache !is null)
            builder.setActionCache(cache);
        
        return builder;
    }
    
    /// Create builder from string name with optional action cache
    static NimBuilder createFromName(string name, NimConfig config, ActionCache cache = null)
    {
        import languages.compiled.nim.builders.nimble;
        import languages.compiled.nim.builders.compile;
        import languages.compiled.nim.builders.check;
        import languages.compiled.nim.builders.doc;
        import languages.compiled.nim.builders.js;
        
        NimBuilder builder;
        
        switch (name.toLower)
        {
            case "auto":
                builder = createAuto(config);
                break;
            case "nimble":
                builder = new NimbleBuilder();
                break;
            case "compile":
            case "nim":
                builder = new CompileBuilder();
                break;
            case "check":
                builder = new CheckBuilder();
                break;
            case "doc":
                builder = new DocBuilder();
                break;
            case "js":
            case "javascript":
                builder = new JsBuilder();
                break;
            default:
                builder = createAuto(config);
                break;
        }
        
        if (cache !is null)
            builder.setActionCache(cache);
        
        return builder;
    }
    
    /// Auto-detect best available builder
    static NimBuilder createAuto(NimConfig config)
    {
        import languages.compiled.nim.builders.nimble;
        import languages.compiled.nim.builders.compile;
        import languages.compiled.nim.builders.check;
        import languages.compiled.nim.builders.doc;
        import languages.compiled.nim.builders.js;
        import languages.compiled.nim.analysis.nimble : NimbleParser;
        
        // JavaScript backend uses JS builder
        if (config.backend == NimBackend.Js)
        {
            auto jsBuilder = new JsBuilder();
            if (jsBuilder.isAvailable())
                return jsBuilder;
        }
        
        // Check mode uses check builder
        if (config.mode == NimBuildMode.Check)
        {
            auto checkBuilder = new CheckBuilder();
            if (checkBuilder.isAvailable())
                return checkBuilder;
        }
        
        // Doc mode uses doc builder
        if (config.mode == NimBuildMode.Doc)
        {
            auto docBuilder = new DocBuilder();
            if (docBuilder.isAvailable())
                return docBuilder;
        }
        
        // If nimble file exists or nimble config enabled, prefer Nimble builder
        if (config.nimble.enabled)
        {
            string nimbleFile = config.nimble.nimbleFile;
            if (nimbleFile.empty)
                nimbleFile = NimbleParser.findNimbleFile(".");
            
            if (!nimbleFile.empty)
            {
                auto nimbleBuilder = new NimbleBuilder();
                if (nimbleBuilder.isAvailable())
                    return nimbleBuilder;
            }
        }
        
        // Default to direct compilation
        auto compileBuilder = new CompileBuilder();
        if (compileBuilder.isAvailable())
            return compileBuilder;
        
        // Fallback to compile builder (will fail gracefully)
        return new CompileBuilder();
    }
}

