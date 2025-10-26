module languages.scripting.elixir.analysis.dependencies;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import languages.scripting.elixir.core.config;
import utils.logging.logger;

/// Dependency information
struct DependencyInfo
{
    string name;
    string version_;
    string source; // hex, git, path
    string gitUrl;
    string gitRef;
    string path;
    bool optional;
    string[] environments;
    bool runtime;
}

/// Dependency analyzer - extracts and analyzes Elixir dependencies
final class DependencyAnalyzer
{
    // Compile regex patterns once
    private static immutable depsPattern = ctRegex!(r"defp?\s+deps\s+do\s*\[(.*?)\]", "s");
    private static immutable depPattern = ctRegex!(r"\{:(\w+),\s*([^}]+)\}", "g");
    private static immutable versionPattern = ctRegex!(`"([^"]+)"`);
    private static immutable gitPattern = ctRegex!(`git:\s*"([^"]+)"`);
    private static immutable refPattern = ctRegex!(`(?:ref|tag|branch):\s*"([^"]+)"`);
    private static immutable pathPattern = ctRegex!(`path:\s*"([^"]+)"`);
    private static immutable onlyPattern = ctRegex!(r"only:\s*:(\w+)");
    private static immutable envPattern = ctRegex!(r"only:\s*\[(.*?)\]");
    
    /// Analyze dependencies from mix.exs
    static DependencyInfo[] analyzeMixFile(string mixExsPath) @safe
    {
        if (!exists(mixExsPath) || !isFile(mixExsPath))
            return [];
        
        try
        {
            immutable content = readText(mixExsPath);
            
            // Extract deps function
            auto depsMatch = content.matchFirst(depsPattern);
            if (depsMatch.empty)
                return [];
            
            immutable depsDef = depsMatch[1];
            
            // Parse each dependency
            // Format: {:name, "~> version"}
            // Format: {:name, "~> version", [options]}
            // Format: {:name, git: "url"}
            // Format: {:name, path: "path"}
            
            DependencyInfo[] deps;
            deps.reserve(32); // Reasonable initial capacity
            
            foreach (match; depsDef.matchAll(depPattern))
            {
                DependencyInfo dep;
                dep.name = match[1].idup;
                
                immutable depSpec = match[2];
                
                // Parse version string
                auto versionMatch = depSpec.matchFirst(versionPattern);
                if (!versionMatch.empty)
                {
                    dep.version_ = versionMatch[1].idup;
                    dep.source = "hex";
                }
                
                // Parse git source
                auto gitMatch = depSpec.matchFirst(gitPattern);
                if (!gitMatch.empty)
                {
                    dep.gitUrl = gitMatch[1].idup;
                    dep.source = "git";
                    
                    // Parse git ref
                    auto refMatch = depSpec.matchFirst(refPattern);
                    if (!refMatch.empty)
                        dep.gitRef = refMatch[1].idup;
                }
                
                // Parse path source
                auto pathMatch = depSpec.matchFirst(pathPattern);
                if (!pathMatch.empty)
                {
                    dep.path = pathMatch[1].idup;
                    dep.source = "path";
                }
                
                // Parse optional
                dep.optional = depSpec.canFind("optional: true");
                
                // Parse runtime
                dep.runtime = !depSpec.canFind("runtime: false");
                
                // Parse only/env
                auto onlyMatch = depSpec.matchFirst(onlyPattern);
                if (!onlyMatch.empty)
                {
                    dep.environments ~= onlyMatch[1].idup;
                }
                else
                {
                    auto envMatch = depSpec.matchFirst(envPattern);
                    if (!envMatch.empty)
                    {
                        foreach (env; envMatch[1].splitter(','))
                        {
                            immutable envName = env.strip.strip(':');
                            if (!envName.empty)
                                dep.environments ~= envName.idup;
                        }
                    }
                }
                
                deps ~= dep;
            }
            
            return deps;
        }
        catch (Exception e)
        {
            Logger.warning("Failed to analyze dependencies: " ~ e.msg);
            return [];
        }
    }
    
    /// Get dependencies for specific environment
    static DependencyInfo[] getDepsForEnv(scope const(DependencyInfo)[] deps, string env) @safe pure
    {
        return deps
            .filter!(d => d.environments.empty || d.environments.canFind(env))
            .array;
    }
    
    /// Get runtime dependencies only
    static DependencyInfo[] getRuntimeDeps(scope const(DependencyInfo)[] deps) @safe pure nothrow
    {
        return deps.filter!(d => d.runtime).array;
    }
    
    /// Get optional dependencies
    static DependencyInfo[] getOptionalDeps(scope const(DependencyInfo)[] deps) @safe pure nothrow
    {
        return deps.filter!(d => d.optional).array;
    }
    
    /// Build dependency graph (simple version)
    static string[string] buildDependencyGraph(scope const(DependencyInfo)[] deps) @safe pure
    {
        string[string] graph;
        graph.reserve(deps.length);
        
        foreach (ref dep; deps)
        {
            graph[dep.name] = dep.version_.empty ? dep.source : dep.version_;
        }
        
        return graph;
    }
}

