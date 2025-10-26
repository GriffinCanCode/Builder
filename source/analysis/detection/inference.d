module analysis.detection.inference;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import config.schema.schema;
import analysis.detection.detector;
import analysis.targets.types;
import utils.logging.logger;

/// Zero-config target inference
/// Automatically generates build targets from project structure
class TargetInference
{
    private string workspaceRoot;
    
    this(string root)
    {
        this.workspaceRoot = root;
    }
    
    /// Infer targets from project structure
    /// Returns array of targets that can be used directly without Builderfile
    Target[] inferTargets()
    {
        Logger.info("No Builderfile found - inferring targets from project structure...");
        
        // Run project detector
        auto detector = new ProjectDetector(workspaceRoot);
        auto metadata = detector.detect();
        
        if (metadata.languages.empty)
        {
            Logger.warning("No supported languages detected in workspace");
            return [];
        }
        
        Logger.success(format("Detected %d language(s):", metadata.languages.length));
        foreach (lang; metadata.languages)
        {
            string frameworkInfo = lang.framework != ProjectFramework.None ?
                format(" [%s]", lang.framework) : "";
            Logger.info(format("  • %s (%d files, %.0f%% confidence)%s",
                lang.language,
                lang.sourceFiles.length,
                lang.confidence * 100,
                frameworkInfo
            ));
        }
        
        // Generate targets for each detected language
        Target[] targets;
        foreach (langInfo; metadata.languages)
        {
            auto target = inferTargetFromLanguage(langInfo, metadata);
            if (target.sources.length > 0)
            {
                targets ~= target;
            }
        }
        
        Logger.success(format("Inferred %d target(s)", targets.length));
        
        return targets;
    }
    
    /// Infer a single target from language info
    private Target inferTargetFromLanguage(LanguageInfo langInfo, ProjectMetadata metadata)
    {
        Target target;
        
        // Generate target name from language and project
        target.name = format("//:auto-%s", langInfo.language.to!string.toLower);
        target.language = langInfo.language;
        target.sources = langInfo.sourceFiles;
        
        // Infer target type
        target.type = inferTargetType(langInfo);
        
        // Add language-specific configuration
        target.langConfig = inferLanguageConfig(langInfo);
        
        return target;
    }
    
    /// Infer target type from language info
    private TargetType inferTargetType(LanguageInfo langInfo)
    {
        // Check for test files
        if (langInfo.sourceFiles.any!(f => 
            f.canFind("test") || f.canFind("spec") || f.startsWith("test_")))
        {
            return TargetType.Test;
        }
        
        // Check for main/entry files (likely executable)
        immutable mainFiles = ["main", "app", "index", "cli", "server"];
        bool hasMainFile = langInfo.sourceFiles.any!(f => 
            mainFiles.canFind(baseName(stripExtension(f)).toLower)
        );
        
        if (hasMainFile)
        {
            return TargetType.Executable;
        }
        
        // Check framework hints
        final switch (langInfo.framework)
        {
            case ProjectFramework.Django:
            case ProjectFramework.Flask:
            case ProjectFramework.FastAPI:
            case ProjectFramework.Rails:
            case ProjectFramework.Sinatra:
            case ProjectFramework.Express:
            case ProjectFramework.Gin:
            case ProjectFramework.Echo:
            case ProjectFramework.Fiber:
            case ProjectFramework.Actix:
            case ProjectFramework.Rocket:
            case ProjectFramework.Axum:
            case ProjectFramework.Spring:
            case ProjectFramework.Quarkus:
            case ProjectFramework.AspNetCore:
            case ProjectFramework.Laravel:
            case ProjectFramework.Symfony:
            case ProjectFramework.Phoenix:
            case ProjectFramework.PhoenixLiveView:
                return TargetType.Executable;  // Web apps are executables
            
            case ProjectFramework.React:
            case ProjectFramework.Vue:
            case ProjectFramework.Angular:
            case ProjectFramework.Svelte:
            case ProjectFramework.NextJS:
            case ProjectFramework.ViteReact:
            case ProjectFramework.ViteVue:
                return TargetType.Custom;  // Frontend needs bundling
            
            case ProjectFramework.None:
                break;
        }
        
        // Default to library if no clear indicators
        return TargetType.Library;
    }
    
    /// Infer language-specific configuration
    private string[string] inferLanguageConfig(LanguageInfo langInfo)
    {
        string[string] config;
        
        final switch (langInfo.language)
        {
            case TargetLanguage.Python:
                return inferPythonConfig(langInfo);
            
            case TargetLanguage.JavaScript:
                return inferJavaScriptConfig(langInfo);
            
            case TargetLanguage.TypeScript:
                return inferTypeScriptConfig(langInfo);
            
            case TargetLanguage.Go:
                return inferGoConfig(langInfo);
            
            case TargetLanguage.Rust:
                return inferRustConfig(langInfo);
            
            case TargetLanguage.Java:
                return inferJavaConfig(langInfo);
            
            case TargetLanguage.Cpp:
            case TargetLanguage.C:
                return inferCppConfig(langInfo);
            
            case TargetLanguage.D:
            case TargetLanguage.Kotlin:
            case TargetLanguage.CSharp:
            case TargetLanguage.FSharp:
            case TargetLanguage.Zig:
            case TargetLanguage.Swift:
            case TargetLanguage.Ruby:
            case TargetLanguage.Elixir:
            case TargetLanguage.PHP:
            case TargetLanguage.Scala:
            case TargetLanguage.Nim:
            case TargetLanguage.Lua:
            case TargetLanguage.R:
            case TargetLanguage.CSS:
            case TargetLanguage.Generic:
                return config;
        }
    }
    
    /// Infer Python configuration
    private string[string] inferPythonConfig(LanguageInfo langInfo)
    {
        import std.json;
        
        JSONValue config = JSONValue.emptyObject;
        
        // Check for requirements.txt
        bool hasRequirements = langInfo.manifestFiles.any!(f => 
            baseName(f) == "requirements.txt"
        );
        
        if (hasRequirements)
        {
            config["requirements"] = "requirements.txt";
            config["virtualenv"] = true;
        }
        
        // Framework-specific config
        if (langInfo.framework == ProjectFramework.Django)
        {
            config["mode"] = "module";
        }
        else
        {
            config["mode"] = "script";
        }
        
        string[string] result;
        if (config.object.length > 0)
        {
            result["python"] = config.toString();
        }
        return result;
    }
    
    /// Infer JavaScript configuration
    private string[string] inferJavaScriptConfig(LanguageInfo langInfo)
    {
        import std.json;
        
        JSONValue config = JSONValue.emptyObject;
        
        // Framework-specific config
        final switch (langInfo.framework)
        {
            case ProjectFramework.React:
            case ProjectFramework.ViteReact:
                config["mode"] = "bundle";
                config["bundler"] = langInfo.framework == ProjectFramework.ViteReact ? "vite" : "esbuild";
                config["jsx"] = true;
                break;
            
            case ProjectFramework.Vue:
            case ProjectFramework.ViteVue:
                config["mode"] = "bundle";
                config["bundler"] = langInfo.framework == ProjectFramework.ViteVue ? "vite" : "esbuild";
                break;
            
            case ProjectFramework.NextJS:
                config["mode"] = "nextjs";
                break;
            
            case ProjectFramework.None:
            case ProjectFramework.Angular:
            case ProjectFramework.Svelte:
            case ProjectFramework.Django:
            case ProjectFramework.Flask:
            case ProjectFramework.FastAPI:
            case ProjectFramework.Express:
            case ProjectFramework.Gin:
            case ProjectFramework.Echo:
            case ProjectFramework.Fiber:
            case ProjectFramework.Actix:
            case ProjectFramework.Rocket:
            case ProjectFramework.Axum:
            case ProjectFramework.Rails:
            case ProjectFramework.Sinatra:
            case ProjectFramework.Phoenix:
            case ProjectFramework.PhoenixLiveView:
            case ProjectFramework.Laravel:
            case ProjectFramework.Symfony:
            case ProjectFramework.Spring:
            case ProjectFramework.Quarkus:
            case ProjectFramework.AspNetCore:
                config["mode"] = "execute";
                break;
        }
        
        string[string] result;
        if (config.object.length > 0)
        {
            result["javascript"] = config.toString();
        }
        return result;
    }
    
    /// Infer TypeScript configuration
    private string[string] inferTypeScriptConfig(LanguageInfo langInfo)
    {
        auto jsConfig = inferJavaScriptConfig(langInfo);
        
        // Rename key from javascript to typescript
        string[string] result;
        if ("javascript" in jsConfig)
        {
            result["typescript"] = jsConfig["javascript"];
        }
        
        return result;
    }
    
    /// Infer Go configuration
    private string[string] inferGoConfig(LanguageInfo langInfo)
    {
        import std.json;
        
        JSONValue config = JSONValue.emptyObject;
        config["modMode"] = "on";
        config["runFmt"] = true;
        config["runVet"] = true;
        
        string[string] result;
        result["go"] = config.toString();
        return result;
    }
    
    /// Infer Rust configuration
    private string[string] inferRustConfig(LanguageInfo langInfo)
    {
        import std.json;
        
        JSONValue config = JSONValue.emptyObject;
        
        // Check for Cargo.toml
        bool hasCargo = langInfo.manifestFiles.any!(f => 
            baseName(f) == "Cargo.toml"
        );
        
        if (hasCargo)
        {
            config["mode"] = "cargo";
            config["profile"] = "release";
        }
        else
        {
            config["mode"] = "compile";
        }
        
        string[string] result;
        result["rust"] = config.toString();
        return result;
    }
    
    /// Infer Java configuration
    private string[string] inferJavaConfig(LanguageInfo langInfo)
    {
        import std.json;
        
        JSONValue config = JSONValue.emptyObject;
        config["buildTool"] = "Auto";  // Auto-detect Maven/Gradle
        
        string[string] result;
        result["java"] = config.toString();
        return result;
    }
    
    /// Infer C/C++ configuration
    private string[string] inferCppConfig(LanguageInfo langInfo)
    {
        import std.json;
        
        JSONValue config = JSONValue.emptyObject;
        config["buildSystem"] = "Auto";  // Auto-detect CMake/Make
        config["compiler"] = "Auto";
        config["standard"] = langInfo.language == TargetLanguage.Cpp ? "c++17" : "c11";
        
        string[string] result;
        result[langInfo.language == TargetLanguage.Cpp ? "cpp" : "c"] = config.toString();
        return result;
    }
}