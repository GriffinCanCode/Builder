module languages.dynamic.spec;

import std.json;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import infrastructure.errors;

/// Language specification loaded from declarative config
/// Enables zero-code language addition via TOML/JSON specs
struct LanguageSpec
{
    /// Language metadata
    struct Metadata
    {
        string name;                    // Language identifier (e.g. "crystal")
        string display;                 // Display name (e.g. "Crystal")
        string category;                // compiled/scripting/jvm/dotnet/web
        string[] extensions;            // File extensions [".cr"]
        string[] aliases;               // Name aliases ["cr"]
    }
    
    /// Detection patterns for language identification
    struct Detection
    {
        string[] shebang;              // Shebang patterns to match
        string[] manifestFiles;        // Project files (e.g. "shard.yml")
        string versionCmd;             // Command to check version
    }
    
    /// Build configuration with command templates
    struct Build
    {
        string compiler;                // Compiler/runtime command
        string compileCmd;              // Template: "crystal build {{sources}} -o {{output}} {{flags}}"
        string testCmd;                 // Template for running tests
        string formatCmd;               // Template for code formatting
        string lintCmd;                 // Template for linting
        string checkCmd;                // Template for type checking
        string[string] env;             // Environment variables
        bool incremental;               // Supports incremental compilation
        bool caching;                   // Supports build caching
    }
    
    /// Dependency analysis configuration
    struct Dependencies
    {
        string pattern;                 // Regex pattern for imports
        string resolver;                // How to resolve (module_path, package, etc.)
        string manifest;                // Dependency manifest file
        string installCmd;              // Command to install dependencies
    }
    
    Metadata metadata;
    Detection detection;
    Build build;
    Dependencies deps;
    
    /// Load spec from JSON file
    static Result!(LanguageSpec, BuildError) fromJSON(string jsonPath) @system
    {
        try
        {
            auto content = readText(jsonPath);
            auto json = parseJSON(content);
            
            LanguageSpec spec;
            
            // Parse metadata
            if ("language" in json)
            {
                auto lang = json["language"];
                spec.metadata.name = lang["name"].str;
                spec.metadata.display = lang.get("display", json["language"]["name"]).str;
                spec.metadata.category = lang.get("category", JSONValue("scripting")).str;
                
                if ("extensions" in lang)
                {
                    foreach (ext; lang["extensions"].array)
                        spec.metadata.extensions ~= ext.str;
                }
                
                if ("aliases" in lang)
                {
                    foreach (alias_; lang["aliases"].array)
                        spec.metadata.aliases ~= alias_.str;
                }
            }
            
            // Parse detection
            if ("detection" in json)
            {
                auto det = json["detection"];
                if ("shebang" in det)
                {
                    foreach (sheb; det["shebang"].array)
                        spec.detection.shebang ~= sheb.str;
                }
                if ("files" in det)
                {
                    foreach (file; det["files"].array)
                        spec.detection.manifestFiles ~= file.str;
                }
                if ("version_cmd" in det)
                    spec.detection.versionCmd = det["version_cmd"].str;
            }
            
            // Parse build
            if ("build" in json)
            {
                auto bld = json["build"];
                spec.build.compiler = bld.get("compiler", JSONValue("")).str;
                spec.build.compileCmd = bld.get("compile_cmd", JSONValue("")).str;
                spec.build.testCmd = bld.get("test_cmd", JSONValue("")).str;
                spec.build.formatCmd = bld.get("format_cmd", JSONValue("")).str;
                spec.build.lintCmd = bld.get("lint_cmd", JSONValue("")).str;
                spec.build.checkCmd = bld.get("check_cmd", JSONValue("")).str;
                spec.build.incremental = bld.get("incremental", JSONValue(false)).boolean;
                spec.build.caching = bld.get("caching", JSONValue(true)).boolean;
                
                if ("env" in bld)
                {
                    foreach (key, value; bld["env"].object)
                        spec.build.env[key] = value.str;
                }
            }
            
            // Parse dependencies
            if ("dependencies" in json)
            {
                auto dep = json["dependencies"];
                spec.deps.pattern = dep.get("pattern", JSONValue("")).str;
                spec.deps.resolver = dep.get("resolver", JSONValue("module_path")).str;
                spec.deps.manifest = dep.get("manifest", JSONValue("")).str;
                spec.deps.installCmd = dep.get("install_cmd", JSONValue("")).str;
            }
            
            return Ok!(LanguageSpec, BuildError)(spec);
        }
        catch (Exception e)
        {
            auto error = new ParseError(jsonPath, "Failed to parse language spec: " ~ e.msg, ErrorCode.ParseFailed);
            return Err!(LanguageSpec, BuildError)(error);
        }
    }
    
    /// Expand command template with variables
    string expandTemplate(string template_, string[string] vars) const pure @safe
    {
        string result = template_;
        foreach (key, value; vars)
        {
            result = result.replace("{{" ~ key ~ "}}", value);
        }
        return result;
    }
    
    /// Check if compiler is available on system
    bool isAvailable() const @system
    {
        import infrastructure.utils.process : isCommandAvailable;
        return !build.compiler.empty && isCommandAvailable(build.compiler);
    }
}

/// Registry for dynamically loaded language specs
final class SpecRegistry
{
    private LanguageSpec[string] specs;
    private string specsDir;
    
    this(string specsDir = "")
    {
        import std.process : environment;
        
        if (specsDir.empty)
        {
            // Default to Builder installation directory
            this.specsDir = buildPath(environment.get("HOME", "."), ".builder", "specs");
        }
        else
        {
            this.specsDir = specsDir;
        }
    }
    
    /// Discover and load all spec files from directory
    Result!(size_t, BuildError) loadAll() @system
    {
        if (!exists(specsDir) || !isDir(specsDir))
            return Ok!(size_t, BuildError)(0);
        
        size_t loaded = 0;
        
        try
        {
            foreach (entry; dirEntries(specsDir, "*.json", SpanMode.shallow))
            {
                if (!entry.isFile)
                    continue;
                
                auto specResult = LanguageSpec.fromJSON(entry.name);
                if (specResult.isOk)
                {
                    auto spec = specResult.unwrap();
                    specs[spec.metadata.name] = spec;
                    loaded++;
                }
            }
        }
        catch (Exception e)
        {
            auto error = new BuildFailureError("spec-registry", "Failed to load specs: " ~ e.msg, ErrorCode.SystemError);
            return Err!(size_t, BuildError)(error);
        }
        
        return Ok!(size_t, BuildError)(loaded);
    }
    
    /// Get spec by language name
    LanguageSpec* get(string langName) @system
    {
        if (auto spec = langName in specs)
            return spec;
        return null;
    }
    
    /// Check if spec exists
    bool has(string langName) const pure nothrow @safe
    {
        return (langName in specs) !is null;
    }
    
    /// Get all registered spec names
    string[] languages() const @system
    {
        return specs.keys;
    }
}

