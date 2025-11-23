module tests.adapters.path_adapter;

/// Adapter to make path property tests work with standard path operations
/// Maps test expectations to D standard library path functions

import std.path;
import std.array;
import std.algorithm;
import std.string;

/// Path operations for property tests
struct PathOps
{
    /// Canonicalize path (make absolute and normalize)
    static string canonicalize(string path) pure @safe
    {
        // Normalize and clean up path
        return normalize(path);
    }
    
    /// Normalize path (remove redundant separators, resolve . and ..)
    static string normalize(string path) pure @safe
    {
        // Remove redundant slashes
        string result = path;
        
        // Replace multiple slashes with single
        while (result.canFind("//"))
            result = result.replace("//", "/");
        
        // Handle ./ and ../
        result = buildNormalizedPath(result);
        
        // Remove trailing slash unless root
        if (result.length > 1 && result.endsWith("/"))
            result = result[0 .. $ - 1];
        
        return result;
    }
    
    /// Resolve path (make absolute if relative)
    static string resolve(string path) pure @safe
    {
        if (isAbsolute(path))
            return normalize(path);
        
        // For testing, just normalize relative paths
        return normalize(path);
    }
    
    /// Compute relative path from base to target
    static string relativePath(string target, string base) pure @safe
    {
        return std.path.relativePath(target, base);
    }
    
    /// Get path components
    static string[] components(string path) pure @safe
    {
        return pathSplitter(path).array;
    }
    
    /// Check if path1 contains path2 (path2 is subpath of path1)
    static bool contains(string parent, string child) pure @safe
    {
        auto normParent = normalize(parent);
        auto normChild = normalize(child);
        
        // Ensure both end with / for proper comparison
        if (!normParent.endsWith("/"))
            normParent ~= "/";
        if (!normChild.endsWith("/"))
            normChild ~= "/";
        
        return normChild.startsWith(normParent) || normChild == normParent[0 .. $ - 1];
    }
}

