module utils.glob;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import std.range;
import std.parallelism;
import core.sync.mutex;

/// Result of glob matching
struct GlobResult
{
    string[] matches;
    string[] excluded;
}

/// Glob pattern matcher with support for **, *, ?, negation
class GlobMatcher
{
    /// Match files against glob patterns
    static string[] match(string[] patterns, string baseDir)
    {
        auto result = matchWithExclusions(patterns, baseDir);
        return result.matches;
    }
    
    /// Match with separate tracking of exclusions
    static GlobResult matchWithExclusions(string[] patterns, string baseDir)
    {
        GlobResult result;
        bool[string] matchSet;  // Use AA for deduplication
        bool[string] excludeSet;
        
        foreach (pattern; patterns)
        {
            bool isNegation = pattern.startsWith("!");
            string cleanPattern = isNegation ? pattern[1 .. $] : pattern;
            
            auto matched = matchSingle(cleanPattern, baseDir);
            
            if (isNegation)
            {
                foreach (file; matched)
                    excludeSet[file] = true;
            }
            else
            {
                foreach (file; matched)
                    matchSet[file] = true;
            }
        }
        
        // Apply exclusions
        foreach (file; matchSet.byKey)
        {
            if (file !in excludeSet)
                result.matches ~= file;
        }
        
        result.excluded = excludeSet.keys.array;
        return result;
    }
    
    /// Match a single glob pattern
    private static string[] matchSingle(string pattern, string baseDir)
    {
        string fullPattern = buildPath(baseDir, pattern);
        
        // Direct file reference (no wildcards)
        if (!pattern.canFind("*") && !pattern.canFind("?") && !pattern.canFind("["))
        {
            if (exists(fullPattern) && isFile(fullPattern))
                return [fullPattern];
            return [];
        }
        
        // Contains ** - recursive glob
        if (pattern.canFind("**"))
        {
            return matchRecursive(pattern, baseDir);
        }
        
        // Shallow glob
        return matchShallow(pattern, baseDir);
    }
    
    /// Match recursive glob pattern (contains **)
    private static string[] matchRecursive(string pattern, string baseDir)
    {
        string[] files;
        
        // Split pattern on **
        auto parts = pattern.split("**");
        
        if (parts.length == 1)
        {
            // No ** found after split (shouldn't happen)
            return matchShallow(pattern, baseDir);
        }
        
        string prefix = parts[0].stripRight("/").stripRight("\\");
        string suffix = parts.length > 1 ? parts[1].stripLeft("/").stripLeft("\\") : "";
        
        // Start directory
        string startDir = prefix.empty ? baseDir : buildPath(baseDir, prefix);
        
        if (!exists(startDir) || !isDir(startDir))
            return [];
        
        // If suffix contains path separators, match against full relative path
        // Otherwise, match against just the filename
        bool matchFullPath = suffix.canFind("/") || suffix.canFind("\\");
        
        // Compile suffix pattern to regex
        auto suffixRegex = suffix.empty ? regex(".*") : globToRegex(suffix);
        
        // Recursively walk directory tree
        try
        {
            foreach (entry; dirEntries(startDir, SpanMode.depth, false))
            {
                if (entry.isFile)
                {
                    string matchPath;
                    
                    if (matchFullPath)
                    {
                        // Match against full relative path
                        matchPath = relativePath(entry.name, startDir);
                    }
                    else
                    {
                        // Match against just the filename
                        matchPath = baseName(entry.name);
                    }
                    
                    if (suffix.empty || matchFirst(matchPath, suffixRegex))
                    {
                        files ~= entry.name;
                    }
                }
            }
        }
        catch (Exception e)
        {
            // Ignore permission errors, etc.
        }
        
        return files;
    }
    
    /// Match shallow glob pattern (no **)
    private static string[] matchShallow(string pattern, string baseDir)
    {
        string[] files;
        
        string fullPattern = buildPath(baseDir, pattern);
        string dir = dirName(fullPattern);
        string filePattern = baseName(fullPattern);
        
        if (!exists(dir) || !isDir(dir))
            return [];
        
        auto patternRegex = globToRegex(filePattern);
        
        try
        {
            foreach (entry; dirEntries(dir, SpanMode.shallow, false))
            {
                if (entry.isFile && matchFirst(entry.name.baseName, patternRegex))
                {
                    files ~= entry.name;
                }
            }
        }
        catch (Exception e)
        {
            // Ignore errors
        }
        
        return files;
    }
    
    /// Convert glob pattern to regex
    private static Regex!char globToRegex(string pattern)
    {
        string regexPattern = "^";
        size_t i = 0;
        
        while (i < pattern.length)
        {
            char c = pattern[i];
            
            switch (c)
            {
                case '*':
                    // * matches anything except path separators
                    regexPattern ~= `[^/\\]*`;
                    break;
                    
                case '?':
                    // ? matches single character except path separators
                    regexPattern ~= `[^/\\]`;
                    break;
                    
                case '[':
                    // Character class - pass through
                    size_t j = i + 1;
                    while (j < pattern.length && pattern[j] != ']')
                        j++;
                    if (j < pattern.length)
                    {
                        regexPattern ~= pattern[i .. j + 1];
                        i = j;
                    }
                    else
                    {
                        // Unclosed bracket - treat as literal
                        regexPattern ~= `\[`;
                    }
                    break;
                    
                case '.':
                case '+':
                case '^':
                case '$':
                case '(':
                case ')':
                case '{':
                case '}':
                case '|':
                    // Escape regex special characters
                    regexPattern ~= `\` ~ c;
                    break;
                    
                case '/':
                case '\\':
                    // Path separators - match both
                    regexPattern ~= `[/\\]`;
                    break;
                    
                default:
                    regexPattern ~= c;
                    break;
            }
            
            i++;
        }
        
        regexPattern ~= "$";
        return regex(regexPattern);
    }
}

/// Convenience function for matching globs
string[] glob(string[] patterns, string baseDir = ".")
{
    return GlobMatcher.match(patterns, baseDir);
}

/// Convenience function for single pattern
string[] glob(string pattern, string baseDir = ".")
{
    return GlobMatcher.match([pattern], baseDir);
}

unittest
{
    import std.stdio : writeln;
    
    writeln("Testing glob patterns...");
    
    // Test regex conversion
    auto re1 = GlobMatcher.globToRegex("*.py");
    assert(matchFirst("test.py", re1));
    assert(!matchFirst("test.txt", re1));
    assert(!matchFirst("dir/test.py", re1));
    
    auto re2 = GlobMatcher.globToRegex("test?.py");
    assert(matchFirst("test1.py", re2));
    assert(!matchFirst("test.py", re2));
    assert(!matchFirst("test12.py", re2));
    
    writeln("Glob pattern tests passed!");
}

