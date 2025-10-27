module analysis.scanning.scanner;

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
                // Check both capture groups (for "from X import" and "import X")
                for (size_t i = 1; i < match.length; i++)
                {
                    auto importName = match[i].strip();
                    if (!importName.empty && !imports.canFind(importName))
                        imports ~= importName;
                }
            }
        }
        catch (Exception e)
        {
            // File read error, log for debugging
            import utils.logging.logger : Logger;
            Logger.debugLog("Failed to scan file for imports: " ~ path ~ ": " ~ e.msg);
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
        import utils.files.hash;
        
        if (!exists(path))
            return true;
        
        auto currentHash = FastHash.hashMetadata(path);
        return currentHash != lastHash;
    }
}

