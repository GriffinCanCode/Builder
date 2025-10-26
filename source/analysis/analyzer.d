module analysis.analyzer;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.traits;
import std.meta;
import core.graph;
import config.schema;
import analysis.scanner;
import analysis.resolver;
import utils.logger;

/// Dependency analyzer using D's compile-time metaprogramming
class DependencyAnalyzer
{
    private WorkspaceConfig config;
    private FileScanner scanner;
    private DependencyResolver resolver;
    
    this(WorkspaceConfig config)
    {
        this.config = config;
        this.scanner = new FileScanner();
        this.resolver = new DependencyResolver(config);
    }
    
    /// Analyze dependencies and build graph
    BuildGraph analyze(string targetFilter = "")
    {
        Logger.info("Analyzing dependencies...");
        
        auto graph = new BuildGraph();
        
        // Add all targets to graph
        foreach (ref target; config.targets)
        {
            if (targetFilter.empty || target.name == targetFilter || matchesPattern(target.name, targetFilter))
            {
                graph.addTarget(target);
            }
        }
        
        // Resolve and add dependencies
        foreach (ref target; config.targets)
        {
            if (target.name !in graph.nodes)
                continue;
            
            // Analyze source files for implicit dependencies
            auto implicitDeps = analyzeImplicitDependencies(target);
            
            // Combine explicit and implicit dependencies
            auto allDeps = target.deps ~ implicitDeps;
            
            foreach (dep; allDeps)
            {
                auto resolvedDep = resolver.resolve(dep, target.name);
                
                if (resolvedDep.empty)
                {
                    Logger.warning("Could not resolve dependency: " ~ dep ~ " for " ~ target.name);
                    continue;
                }
                
                // Add to graph if target exists
                if (resolvedDep in graph.nodes)
                {
                    try
                    {
                        graph.addDependency(target.name, resolvedDep);
                    }
                    catch (Exception e)
                    {
                        Logger.error("Dependency error: " ~ e.msg);
                        throw e;
                    }
                }
            }
        }
        
        Logger.success("Dependency analysis complete");
        return graph;
    }
    
    /// Analyze source files for implicit dependencies using compile-time analysis
    private string[] analyzeImplicitDependencies(ref Target target)
    {
        string[] deps;
        
        // Use compile-time dispatch based on language
        final switch (target.language)
        {
            case TargetLanguage.D:
                deps = analyzeDDependencies(target);
                break;
            case TargetLanguage.Python:
                deps = analyzePythonDependencies(target);
                break;
            case TargetLanguage.JavaScript:
            case TargetLanguage.TypeScript:
                deps = analyzeJavaScriptDependencies(target);
                break;
            case TargetLanguage.Go:
                deps = analyzeGoDependencies(target);
                break;
            case TargetLanguage.Rust:
                deps = analyzeRustDependencies(target);
                break;
            case TargetLanguage.Cpp:
            case TargetLanguage.C:
                deps = analyzeCppDependencies(target);
                break;
            case TargetLanguage.Java:
                deps = analyzeJavaDependencies(target);
                break;
            case TargetLanguage.Generic:
                deps = [];
                break;
        }
        
        return deps;
    }
    
    /// Analyze D source files for imports
    private string[] analyzeDDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto importRegex = regex(`^\s*import\s+([\w.]+)`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, importRegex);
            
            // Map imports to targets
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.D);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Analyze Python imports
    private string[] analyzePythonDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto importRegex = regex(`^\s*(?:import|from)\s+([\w.]+)`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, importRegex);
            
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.Python);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Analyze JavaScript/TypeScript imports
    private string[] analyzeJavaScriptDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto importRegex = regex(`^\s*(?:import|require)\s*\(?['"]([^'"]+)['"]`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, importRegex);
            
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.JavaScript);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Analyze Go imports
    private string[] analyzeGoDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto importRegex = regex(`^\s*import\s+"([^"]+)"`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, importRegex);
            
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.Go);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Analyze Rust dependencies
    private string[] analyzeRustDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto useRegex = regex(`^\s*use\s+([\w:]+)`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, useRegex);
            
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.Rust);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Analyze C/C++ includes
    private string[] analyzeCppDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto includeRegex = regex(`^\s*#include\s+["<]([^">]+)[">]`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, includeRegex);
            
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.Cpp);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Analyze Java imports
    private string[] analyzeJavaDependencies(ref Target target)
    {
        import std.regex;
        
        string[] deps;
        auto importRegex = regex(`^\s*import\s+([\w.]+)`, "m");
        
        foreach (source; target.sources)
        {
            auto imports = scanner.scanImports(source, importRegex);
            
            foreach (imp; imports)
            {
                auto dep = resolver.resolveImport(imp, TargetLanguage.Java);
                if (!dep.empty && !deps.canFind(dep))
                    deps ~= dep;
            }
        }
        
        return deps;
    }
    
    /// Check if target name matches pattern
    private bool matchesPattern(string name, string pattern)
    {
        import std.string : indexOf;
        
        // Simple pattern matching for now
        if (pattern.endsWith("..."))
        {
            auto prefix = pattern[0 .. $ - 3];
            return name.indexOf(prefix) == 0;
        }
        
        return name == pattern;
    }
}

/// Compile-time dependency analysis helpers
template AnalyzeDependencies(alias T)
{
    // Use D's compile-time introspection to analyze dependencies
    static if (is(T == struct) || is(T == class))
    {
        alias Members = __traits(allMembers, T);
        
        // Extract import information at compile time
        enum string[] Imports = extractImports!T;
    }
}

/// Extract imports from a type at compile-time
template extractImports(alias T)
{
    string[] extractImports()
    {
        string[] imports;
        
        static if (is(T == struct) || is(T == class))
        {
            foreach (member; __traits(allMembers, T))
            {
                // Get the module of each member's type
                static if (__traits(compiles, __traits(getMember, T, member)))
                {
                    alias MemberType = typeof(__traits(getMember, T, member));
                    static if (!is(MemberType == void))
                    {
                        enum moduleName = moduleName!MemberType;
                        if (!imports.canFind(moduleName))
                            imports ~= moduleName;
                    }
                }
            }
        }
        
        return imports;
    }
}

