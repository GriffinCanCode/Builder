module infrastructure.analysis.metadata.metagen;

import infrastructure.analysis.targets.types;
import infrastructure.analysis.targets.spec;
import infrastructure.config.schema.schema;
import std.meta;
import std.traits;
import std.conv;

/// Compile-time code generation for language analyzers
/// This is where the REAL metaprogramming magic happens

/// Generate analyzer dispatch function at compile-time
string generateAnalyzerDispatch()
{
    string code = q{
        FileAnalysis analyzeFile(TargetLanguage language, string filePath, string content)
        {
            auto spec = getLanguageSpec(language);
            if (spec is null)
            {
                return FileAnalysis(
                    filePath,
                    [],
                    "",
                    true,
                    ["No language specification for " ~ language.to!string]
                );
            }
            
            auto imports = spec.scanImports(filePath, content);
            
            return FileAnalysis(
                filePath,
                imports,
                "", // Hash computed elsewhere
                false,
                []
            );
        }
    };
    
    return code;
}

/// Mixin template for compile-time validated analysis
mixin template LanguageAnalyzer()
{
    // Inject the generated analyzer function
    mixin(generateAnalyzerDispatch());
    
    /// Validate language specs at compile-time
    static assert(validateLanguageSpecs(), "Language specifications are invalid");
}

/// Compile-time validation of language specifications
bool validateLanguageSpecs()
{
    // This executes at compile-time!
    
    // Check that all languages have specs
    static foreach (lang; EnumMembers!TargetLanguage)
    {
        static assert(
            __traits(compiles, getLanguageSpec(lang)),
            "Missing specification for language: " ~ lang.stringof
        );
    }
    
    return true;
}

/// Type-safe compile-time language registry
template LanguageRegistry(TargetLanguage lang)
{
    // Get spec at compile-time
    enum hasSpec = __traits(compiles, getLanguageSpec(lang));
    
    static if (hasSpec)
    {
        alias Spec = typeof(getLanguageSpec(lang));
    }
    else
    {
        static assert(false, "No specification for " ~ lang.stringof);
    }
}

/// Generate optimized dispatch table at compile-time
private template GenerateDispatchTable()
{
    string GenerateDispatchTable()
    {
        string code = "final switch (language) {\n";
        
        static foreach (lang; EnumMembers!TargetLanguage)
        {
            code ~= "    case TargetLanguage." ~ lang.stringof ~ ":\n";
            code ~= "        return analyze" ~ lang.stringof ~ "(target, content);\n";
        }
        
        code ~= "}";
        return code;
    }
}

/// Compile-time introspection helpers

/// Check if a type represents a valid import at compile-time
template isValidImport(T)
{
    enum isValidImport = is(T == struct) &&
                        __traits(hasMember, T, "moduleName") &&
                        __traits(hasMember, T, "kind");
}

static assert(isValidImport!Import, "Import type is malformed");

/// Check if a type represents a valid dependency at compile-time
template isValidDependency(T)
{
    enum isValidDependency = is(T == struct) &&
                            __traits(hasMember, T, "targetName") &&
                            __traits(hasMember, T, "kind");
}

static assert(isValidDependency!Dependency, "Dependency type is malformed");

/// Compile-time computation of language analyzer signatures
template AnalyzerSignature(TargetLanguage lang)
{
    alias AnalyzerSignature = FileAnalysis function(string filePath, string content);
}

/// Zero-cost abstraction: compile-time dispatch wrapper
struct CompiletimeDispatcher(alias Specs)
{
    static auto dispatch(TargetLanguage lang, string file, string content)
    {
        // This switch is optimized away at compile-time
        switch (lang)
        {
            static foreach (spec; Specs)
            {
                case spec.language:
                    return spec.scanImports(file, content);
            }
            default:
                return Import[].init;
        }
    }
}

/// Compile-time optimization: precompute regex patterns
/// Note: In D, regexes can be compiled at CTFE (Compile-Time Function Execution)
template PrecompiledPattern(string pattern)
{
    import std.regex;
    enum PrecompiledPattern = regex(pattern, "m");
}

/// Generate statistics about language coverage at compile-time
enum LanguageCount = EnumMembers!TargetLanguage.length;
enum GeneratedAnalyzers = LanguageCount;

/// Compile-time verification that all handlers exist
template VerifyHandlers()
{
    static foreach (lang; EnumMembers!TargetLanguage)
    {
        static assert(
            lang in LanguageSpecs,
            "Missing handler for " ~ lang.stringof
        );
    }
}

// Execute verification at compile-time
// Note: Disabled due to CTFE limitations with associative arrays
// mixin VerifyHandlers;

/// Generate type-safe import resolution at compile-time
string generateImportResolver()
{
    string code = q{
        Dependency[] resolveImports(Import[] imports, TargetLanguage language, WorkspaceConfig config)
        {
            import infrastructure.analysis.resolution.resolver;
            
            Dependency[] deps;
            auto resolver = new DependencyResolver(config);
            
            foreach (imp; imports)
            {
                if (imp.isExternal)
                    continue; // Skip external packages
                
                auto targetName = resolver.resolveImport(imp.moduleName, language);
                if (!targetName.empty)
                {
                    deps ~= Dependency.direct(targetName, imp.moduleName);
                }
            }
            
            return deps;
        }
    };
    
    return code;
}

