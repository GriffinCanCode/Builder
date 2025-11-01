module analysis.resolution.resolver;

import std.stdio;
import std.algorithm;
import std.array;
import std.string;
import std.path;
import std.conv;
import config.schema.schema;
import analysis.targets.types;
import errors;

/// Resolves import statements to build targets
class DependencyResolver
{
    private WorkspaceConfig config;
    private string[string] importCache;
    private ImportIndex index;
    
    this(WorkspaceConfig config)
    {
        this.config = config;
        this.index = new ImportIndex(config);
        buildImportCache();
    }
    
    /// Resolve a dependency reference to a target name
    string resolve(string dep, string fromTarget)
    {
        // Absolute reference: //path/to:target
        if (dep.startsWith("//"))
            return dep;
        
        // Relative reference: :target (same package)
        if (dep.startsWith(":"))
        {
            auto parts = fromTarget.split(":");
            if (parts.length > 0)
                return parts[0] ~ dep;
        }
        
        // Package-relative: //path/to:target
        return dep;
    }
    
    /// Resolve a dependency reference to a TargetId (type-safe version)
    Result!(TargetId, BuildError) resolveToId(string dep, TargetId fromTarget)
    {
        import errors : ParseError;
        
        // Absolute reference: //path/to:target or workspace//path:target
        if (dep.indexOf("//") >= 0 || dep.indexOf(":") >= 0)
        {
            return TargetId.parse(dep);
        }
        
        // Relative reference: :target (same package)
        if (dep.startsWith(":"))
        {
            auto newName = dep[1 .. $];  // Remove leading ":"
            auto resolved = TargetId(fromTarget.workspace, fromTarget.path, newName);
            return Result!(TargetId, BuildError).ok(resolved);
        }
        
        // Simple name - same workspace and path
        auto resolved = TargetId(fromTarget.workspace, fromTarget.path, dep);
        return Result!(TargetId, BuildError).ok(resolved);
    }
    
    /// Resolve an import statement to a target
    string resolveImport(string importName, TargetLanguage language)
    {
        // Check cache first
        string cacheKey = language.to!string ~ ":" ~ importName;
        if (cacheKey in importCache)
            return importCache[cacheKey];
        
        // Language-specific resolution
        string target;
        
        final switch (language)
        {
            case TargetLanguage.D:
                target = resolveDImport(importName);
                break;
            case TargetLanguage.Python:
                target = resolvePythonImport(importName);
                break;
            case TargetLanguage.JavaScript:
            case TargetLanguage.TypeScript:
                target = resolveJSImport(importName);
                break;
            case TargetLanguage.Go:
                target = resolveGoImport(importName);
                break;
            case TargetLanguage.Rust:
                target = resolveRustImport(importName);
                break;
            case TargetLanguage.Cpp:
            case TargetLanguage.C:
                target = resolveCppImport(importName);
                break;
            case TargetLanguage.Java:
                target = resolveJavaImport(importName);
                break;
            case TargetLanguage.Kotlin:
            case TargetLanguage.Scala:
                target = resolveJavaImport(importName);  // Use Java resolution for JVM languages
                break;
            case TargetLanguage.CSharp:
            case TargetLanguage.FSharp:
            case TargetLanguage.Swift:
                target = "";  // TODO: Implement .NET language resolution
                break;
            case TargetLanguage.Zig:
            case TargetLanguage.Nim:
                target = resolveCppImport(importName);  // Use C++ resolution for compiled languages
                break;
            case TargetLanguage.Ruby:
            case TargetLanguage.Perl:
            case TargetLanguage.PHP:
            case TargetLanguage.Elixir:
            case TargetLanguage.Lua:
            case TargetLanguage.R:
            case TargetLanguage.OCaml:
            case TargetLanguage.Haskell:
            case TargetLanguage.Elm:
                target = "";  // TODO: Implement scripting language resolution
                break;
            case TargetLanguage.CSS:
                target = "";  // CSS has no imports to resolve
                break;
            case TargetLanguage.Protobuf:
                target = "";  // Protobuf imports handled by compiler
                break;
            case TargetLanguage.Generic:
                target = "";
                break;
        }
        
        if (!target.empty)
            importCache[cacheKey] = target;
        
        return target;
    }
    
    private void buildImportCache()
    {
        // Pre-build cache of known imports to targets
        foreach (ref target; config.targets)
        {
            // Map target sources to import paths
            // This is language-specific
        }
    }
    
    private string resolveDImport(string importName)
    {
        // Convert D module name to potential target
        // e.g., "core.graph" -> "//source/core:graph"
        
        auto parts = importName.split(".");
        if (parts.length > 1)
        {
            string path = parts[0 .. $ - 1].join("/");
            string name = parts[$ - 1];
            
            // Look for matching target
            foreach (ref target; config.targets)
            {
                if (target.name.canFind(path) && target.name.canFind(name))
                    return target.name;
            }
        }
        
        return "";
    }
    
    private string resolvePythonImport(string importName)
    {
        // Convert Python import to target
        // e.g., "mypackage.module" -> "//python/mypackage:module"
        
        auto parts = importName.split(".");
        
        foreach (ref target; config.targets)
        {
            // Check if any source file matches
            foreach (source; target.sources)
            {
                if (source.canFind(importName.replace(".", "/")))
                    return target.name;
            }
        }
        
        return "";
    }
    
    private string resolveJSImport(string importName)
    {
        // Convert JS/TS import to target
        
        // Skip external packages
        if (!importName.startsWith(".") && !importName.startsWith("/"))
            return "";
        
        foreach (ref target; config.targets)
        {
            foreach (source; target.sources)
            {
                if (source.canFind(importName))
                    return target.name;
            }
        }
        
        return "";
    }
    
    private string resolveGoImport(string importName)
    {
        // Convert Go import to target
        
        foreach (ref target; config.targets)
        {
            if (target.name.canFind(importName))
                return target.name;
        }
        
        return "";
    }
    
    private string resolveRustImport(string importName)
    {
        // Convert Rust use statement to target
        
        auto parts = importName.split("::");
        
        foreach (ref target; config.targets)
        {
            if (parts.length > 0 && target.name.canFind(parts[0]))
                return target.name;
        }
        
        return "";
    }
    
    private string resolveCppImport(string importName)
    {
        // Convert C/C++ include to target
        
        foreach (ref target; config.targets)
        {
            foreach (source; target.sources)
            {
                if (source.endsWith(importName))
                    return target.name;
            }
        }
        
        return "";
    }
    
    private string resolveJavaImport(string importName)
    {
        // Convert Java import to target
        
        auto parts = importName.split(".");
        
        foreach (ref target; config.targets)
        {
            foreach (source; target.sources)
            {
                if (source.canFind(importName.replace(".", "/")))
                    return target.name;
            }
        }
        
        return "";
    }
    
    /// Resolve typed Import to Dependency
    Dependency resolveTypedImport(Import imp, TargetLanguage language)
    {
        if (imp.isExternal)
            return Dependency("", DependencyKind.Direct, []); // External, not tracked
        
        auto targetName = resolveImport(imp.moduleName, language);
        
        if (targetName.empty)
            return Dependency("", DependencyKind.Implicit, [imp.moduleName]);
        
        return Dependency.direct(targetName, imp.moduleName);
    }
}

/// Fast import-to-target lookup index
class ImportIndex
{
    private string[string] moduleToTarget;
    private WorkspaceConfig config;
    
    this(WorkspaceConfig config)
    {
        this.config = config;
        buildIndex();
    }
    
    /// Build the index from workspace configuration
    private void buildIndex()
    {
        foreach (ref target; config.targets)
        {
            // Map each source file to this target
            foreach (source; target.sources)
            {
                auto normalized = source.buildNormalizedPath;
                moduleToTarget[normalized] = target.name;
                
                // Also index by base name without extension
                auto baseName = source.baseName.stripExtension;
                if (baseName !in moduleToTarget)
                    moduleToTarget[baseName] = target.name;
            }
        }
    }
    
    /// Look up target by module name (O(1) average case)
    string lookup(string moduleName) const
    {
        if (auto target = moduleName in moduleToTarget)
            return *target;
        
        // Try normalized path
        auto normalized = moduleName.buildNormalizedPath;
        if (auto target = normalized in moduleToTarget)
            return *target;
        
        return "";
    }
    
    /// Get all indexed modules
    string[] allModules() const
    {
        return moduleToTarget.keys;
    }
}

