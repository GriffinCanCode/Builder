module analysis.scanner;

import std.stdio;
import std.file;
import std.algorithm;
import std.array;
import std.regex;
import std.string;

/// Fast file scanner for dependency analysis
class FileScanner
{
    /// Scan a file for imports using a regex pattern
    string[] scanImports(string path, Regex!char pattern)
    {
        if (!exists(path) || !isFile(path))
            return [];
        
        string[] imports;
        
        try
        {
            auto content = readText(path);
            
            foreach (match; matchAll(content, pattern))
            {
                if (match.length > 1)
                {
                    auto importName = match[1].strip();
                    if (!importName.empty && !imports.canFind(importName))
                        imports ~= importName;
                }
            }
        }
        catch (Exception e)
        {
            // File read error, skip
        }
        
        return imports;
    }
    
    /// Scan multiple files in parallel
    string[][string] scanImportsParallel(string[] paths, Regex!char pattern)
    {
        import std.parallelism;
        
        string[][string] results;
        
        foreach (path; parallel(paths))
        {
            auto imports = scanImports(path, pattern);
            synchronized
            {
                results[path] = imports;
            }
        }
        
        return results;
    }
    
    /// Check if file has changed since last scan
    bool hasChanged(string path, string lastHash)
    {
        import utils.hash;
        
        if (!exists(path))
            return true;
        
        auto currentHash = FastHash.hashMetadata(path);
        return currentHash != lastHash;
    }
}

