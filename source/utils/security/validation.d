module utils.security.validation;

import std.path;
import std.file;
import std.string;
import std.algorithm;
import std.array;
import std.regex;

@safe:

/// Security utilities for validating and sanitizing file paths and arguments
/// Protects against command injection and path traversal attacks
struct SecurityValidator
{
    /// Validates that a file path is safe to use with external commands
    /// Returns: true if path is safe, false otherwise
    @safe
    static bool isPathSafe(string path) nothrow
    {
        if (path.empty)
            return false;
        
        try
        {
            // Check for null bytes (can be used to bypass checks)
            if (path.canFind('\0'))
                return false;
            
            // Check for shell metacharacters that could enable injection
            // Even in array form, paths with certain characters can be problematic
            const string dangerousChars = ";|&$`<>(){}[]!*?'\"\\";
            foreach (char c; dangerousChars)
            {
                if (path.canFind(c))
                    return false;
            }
            
            // Check for problematic escape sequences
            if (path.canFind("\n") || path.canFind("\r") || path.canFind("\t"))
                return false;
            
            // Validate path structure (no path traversal attempts)
            if (!isPathTraversalSafe(path))
                return false;
            
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Validates that a path doesn't contain path traversal sequences
    @safe
    static bool isPathTraversalSafe(string path) nothrow
    {
        try
        {
            // Check for common path traversal patterns
            if (path.canFind("../") || path.canFind("..\\"))
                return false;
            
            // Check for absolute path to sensitive locations (on Unix)
            version(Posix)
            {
                const string[] sensitivePaths = ["/etc/", "/proc/", "/sys/", "/dev/"];
                foreach (sensPath; sensitivePaths)
                {
                    if (path.startsWith(sensPath))
                        return false;
                }
            }
            
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Validates that a file path exists and is within allowed directory
    /// baseDir: The base directory that the path must be within
    @trusted // File system operations
    static bool isPathWithinBase(string path, string baseDir)
    {
        try
        {
            if (!exists(path))
                return false;
            
            // Normalize both paths to compare
            auto normalPath = buildNormalizedPath(absolutePath(path));
            auto normalBase = buildNormalizedPath(absolutePath(baseDir));
            
            // Check if path starts with base directory
            return normalPath.startsWith(normalBase);
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Validates and sanitizes a command argument
    /// Returns: Sanitized argument, or empty string if unsafe
    @safe
    static string sanitizeArgument(string arg) nothrow
    {
        try
        {
            // If argument contains dangerous characters, reject it
            if (!isArgumentSafe(arg))
                return "";
            
            return arg;
        }
        catch (Exception)
        {
            return "";
        }
    }
    
    /// Check if a command argument is safe
    @safe
    static bool isArgumentSafe(string arg) nothrow
    {
        try
        {
            // Empty arguments are allowed
            if (arg.empty)
                return true;
            
            // Check for null bytes
            if (arg.canFind('\0'))
                return false;
            
            // Check for command injection patterns
            if (arg.canFind(";") || arg.canFind("|") || 
                arg.canFind("&&") || arg.canFind("||") ||
                arg.canFind("`") || arg.canFind("$"))
                return false;
            
            // Check for quote escaping attempts
            if (arg.canFind("'\"") || arg.canFind("\"'"))
                return false;
            
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Escape a file path for safe use in shell commands (when executeShell is unavoidable)
    /// This is a last resort - prefer using execute() with array form
    @trusted // String operations
    static string escapeShellPath(string path)
    {
        version(Windows)
        {
            // On Windows, wrap in quotes and escape internal quotes
            return `"` ~ path.replace(`"`, `""`) ~ `"`;
        }
        else
        {
            // On Unix, escape special characters with backslash
            return path
                .replace(`\`, `\\`)
                .replace(`"`, `\"`)
                .replace(`'`, `\'`)
                .replace(` `, `\ `)
                .replace(`$`, `\$`)
                .replace("`", "\\`");
        }
    }
    
    /// Validates a list of file paths for safety
    /// Returns: true if all paths are safe
    @safe
    static bool arePathsSafe(string[] paths) nothrow
    {
        try
        {
            foreach (path; paths)
            {
                if (!isPathSafe(path))
                    return false;
            }
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Validates that a file extension is in an allowed list
    @safe
    static bool hasAllowedExtension(string path, string[] allowedExtensions) nothrow
    {
        try
        {
            auto ext = extension(path).toLower();
            return allowedExtensions.canFind(ext);
        }
        catch (Exception)
        {
            return false;
        }
    }
}

/// Safe execute wrapper that validates paths before execution
@trusted // Process execution
struct SafeExecute
{
    import std.process;
    
    /// Execute command with path validation
    /// Validates all arguments that look like file paths before execution
    static auto execute(string[] cmd, string[string] env = null, 
                       Config config = Config.none, size_t maxOutput = size_t.max,
                       string workDir = null)
    {
        // Validate command arguments that might be paths
        foreach (arg; cmd)
        {
            // If it looks like a file path (contains path separators), validate it
            if (arg.canFind('/') || arg.canFind('\\'))
            {
                if (!SecurityValidator.isPathSafe(arg))
                {
                    throw new Exception("Unsafe path detected in command: " ~ arg);
                }
            }
        }
        
        // Execute using safe array form
        return std.process.execute(cmd, env, config, maxOutput, workDir);
    }
}

// Unit tests
@safe unittest
{
    // Test path safety validation
    assert(SecurityValidator.isPathSafe("src/main.cpp"));
    assert(SecurityValidator.isPathSafe("output/app.exe"));
    assert(!SecurityValidator.isPathSafe("file; rm -rf /"));
    assert(!SecurityValidator.isPathSafe("file | cat /etc/passwd"));
    assert(!SecurityValidator.isPathSafe("file && malicious"));
    assert(!SecurityValidator.isPathSafe("file`whoami`"));
    assert(!SecurityValidator.isPathSafe("file$var"));
    
    // Test path traversal detection
    assert(SecurityValidator.isPathTraversalSafe("src/main.cpp"));
    assert(!SecurityValidator.isPathTraversalSafe("../../../etc/passwd"));
    assert(!SecurityValidator.isPathTraversalSafe("..\\..\\windows\\system32"));
    
    // Test argument safety
    assert(SecurityValidator.isArgumentSafe("-O2"));
    assert(SecurityValidator.isArgumentSafe("--flag"));
    assert(!SecurityValidator.isArgumentSafe("; rm -rf /"));
    assert(!SecurityValidator.isArgumentSafe("| cat /etc/passwd"));
    
    // Test batch validation
    assert(SecurityValidator.arePathsSafe(["src/a.cpp", "src/b.cpp"]));
    assert(!SecurityValidator.arePathsSafe(["src/a.cpp", "bad; rm"]));
}

