module languages.compiled.nim.builders.base;

import std.algorithm;
import std.range;
import std.string;
import languages.compiled.nim.core.config;
import config.schema.schema;
import analysis.targets.types;

/// Base interface for Nim builders
interface NimBuilder
{
    /// Build Nim project
    NimCompileResult build(
        string[] sources,
        NimConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get builder version
    string getVersion();
    
    /// Supports specific features
    bool supportsFeature(string feature);
}

/// Factory for creating Nim builders
class NimBuilderFactory
{
    /// Create builder based on type
    static NimBuilder create(NimBuilderType builderType, NimConfig config)
    {
        import languages.compiled.nim.builders.nimble;
        import languages.compiled.nim.builders.compile;
        import languages.compiled.nim.builders.check;
        import languages.compiled.nim.builders.doc;
        import languages.compiled.nim.builders.js;
        
        final switch (builderType)
        {
            case NimBuilderType.Auto:
                return createAuto(config);
            case NimBuilderType.Nimble:
                return new NimbleBuilder();
            case NimBuilderType.Compile:
                return new CompileBuilder();
            case NimBuilderType.Check:
                return new CheckBuilder();
            case NimBuilderType.Doc:
                return new DocBuilder();
            case NimBuilderType.Js:
                return new JsBuilder();
        }
    }
    
    /// Create builder from string name
    static NimBuilder createFromName(string name, NimConfig config)
    {
        import languages.compiled.nim.builders.nimble;
        import languages.compiled.nim.builders.compile;
        import languages.compiled.nim.builders.check;
        import languages.compiled.nim.builders.doc;
        import languages.compiled.nim.builders.js;
        
        switch (name.toLower)
        {
            case "auto":
                return createAuto(config);
            case "nimble":
                return new NimbleBuilder();
            case "compile":
            case "nim":
                return new CompileBuilder();
            case "check":
                return new CheckBuilder();
            case "doc":
                return new DocBuilder();
            case "js":
            case "javascript":
                return new JsBuilder();
            default:
                return createAuto(config);
        }
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

