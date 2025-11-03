module tests.unit.utils.validation;

import std.stdio;
import std.path;
import std.file;
import infrastructure.utils.security.validation;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Path safety validation");
    
    // Safe paths
    Assert.isTrue(SecurityValidator.isPathSafe("src/main.cpp"));
    Assert.isTrue(SecurityValidator.isPathSafe("output/app.exe"));
    Assert.isTrue(SecurityValidator.isPathSafe("foo/bar/baz.txt"));
    Assert.isTrue(SecurityValidator.isPathSafe("/usr/local/bin/app"));
    
    // Unsafe paths with shell metacharacters
    Assert.isFalse(SecurityValidator.isPathSafe("file; rm -rf /"));
    Assert.isFalse(SecurityValidator.isPathSafe("file | cat /etc/passwd"));
    Assert.isFalse(SecurityValidator.isPathSafe("file && malicious"));
    Assert.isFalse(SecurityValidator.isPathSafe("file || backup"));
    Assert.isFalse(SecurityValidator.isPathSafe("file`whoami`"));
    Assert.isFalse(SecurityValidator.isPathSafe("file$var"));
    Assert.isFalse(SecurityValidator.isPathSafe("file<redirect"));
    Assert.isFalse(SecurityValidator.isPathSafe("file>output"));
    Assert.isFalse(SecurityValidator.isPathSafe("file(subshell)"));
    Assert.isFalse(SecurityValidator.isPathSafe("file{brace}"));
    Assert.isFalse(SecurityValidator.isPathSafe("file[bracket]"));
    
    // Empty path
    Assert.isFalse(SecurityValidator.isPathSafe(""));
    
    // Null byte
    Assert.isFalse(SecurityValidator.isPathSafe("file\0bad"));
    
    // Escape sequences
    Assert.isFalse(SecurityValidator.isPathSafe("file\npath"));
    Assert.isFalse(SecurityValidator.isPathSafe("file\rpath"));
    Assert.isFalse(SecurityValidator.isPathSafe("file\tpath"));
    
    writeln("\x1b[32m  ✓ Path safety validation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Path traversal detection");
    
    // Safe paths
    Assert.isTrue(SecurityValidator.isPathTraversalSafe("src/main.cpp"));
    Assert.isTrue(SecurityValidator.isPathTraversalSafe("foo/bar/baz.txt"));
    Assert.isTrue(SecurityValidator.isPathTraversalSafe("/usr/local/lib/something"));
    
    // Path traversal attempts
    Assert.isFalse(SecurityValidator.isPathTraversalSafe("../../../etc/passwd"));
    Assert.isFalse(SecurityValidator.isPathTraversalSafe("..\\..\\windows\\system32"));
    Assert.isFalse(SecurityValidator.isPathTraversalSafe("foo/../../../etc/shadow"));
    
    version(Posix)
    {
        // Sensitive system paths on Unix
        Assert.isFalse(SecurityValidator.isPathTraversalSafe("/etc/passwd"));
        Assert.isFalse(SecurityValidator.isPathTraversalSafe("/proc/self/mem"));
        Assert.isFalse(SecurityValidator.isPathTraversalSafe("/sys/class/dmi"));
        Assert.isFalse(SecurityValidator.isPathTraversalSafe("/dev/sda"));
    }
    
    writeln("\x1b[32m  ✓ Path traversal detection works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Argument safety validation");
    
    // Safe arguments
    Assert.isTrue(SecurityValidator.isArgumentSafe(""));
    Assert.isTrue(SecurityValidator.isArgumentSafe("-O2"));
    Assert.isTrue(SecurityValidator.isArgumentSafe("--flag"));
    Assert.isTrue(SecurityValidator.isArgumentSafe("-Wall"));
    Assert.isTrue(SecurityValidator.isArgumentSafe("normal-text"));
    
    // Command injection attempts
    Assert.isFalse(SecurityValidator.isArgumentSafe("; rm -rf /"));
    Assert.isFalse(SecurityValidator.isArgumentSafe("| cat /etc/passwd"));
    Assert.isFalse(SecurityValidator.isArgumentSafe("&& malicious"));
    Assert.isFalse(SecurityValidator.isArgumentSafe("|| backup"));
    Assert.isFalse(SecurityValidator.isArgumentSafe("`whoami`"));
    Assert.isFalse(SecurityValidator.isArgumentSafe("$HOME"));
    
    // Quote escaping attempts
    Assert.isFalse(SecurityValidator.isArgumentSafe("'\"escape"));
    Assert.isFalse(SecurityValidator.isArgumentSafe("\"'escape"));
    
    // Null byte
    Assert.isFalse(SecurityValidator.isArgumentSafe("arg\0bad"));
    
    writeln("\x1b[32m  ✓ Argument safety validation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Argument sanitization");
    
    // Safe arguments should pass through
    Assert.equal(SecurityValidator.sanitizeArgument("-O2"), "-O2");
    Assert.equal(SecurityValidator.sanitizeArgument("--flag"), "--flag");
    Assert.equal(SecurityValidator.sanitizeArgument(""), "");
    
    // Unsafe arguments should return empty string
    Assert.equal(SecurityValidator.sanitizeArgument("; rm -rf /"), "");
    Assert.equal(SecurityValidator.sanitizeArgument("| cat /etc/passwd"), "");
    Assert.equal(SecurityValidator.sanitizeArgument("`whoami`"), "");
    
    writeln("\x1b[32m  ✓ Argument sanitization works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Batch path validation");
    
    // All safe
    Assert.isTrue(SecurityValidator.arePathsSafe(["src/a.cpp", "src/b.cpp", "include/header.h"]));
    
    // One unsafe
    Assert.isFalse(SecurityValidator.arePathsSafe(["src/a.cpp", "bad; rm", "src/c.cpp"]));
    
    // Empty array
    Assert.isTrue(SecurityValidator.arePathsSafe([]));
    
    writeln("\x1b[32m  ✓ Batch path validation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Path within base directory validation");
    
    auto tempDir = scoped(new TempDir("validation-test"));
    auto basePath = tempDir.getPath();
    
    // Create subdirectory and file
    auto subDir = buildPath(basePath, "subdir");
    mkdir(subDir);
    auto filePath = buildPath(subDir, "test.txt");
    std.file.write(filePath, "test");
    
    // File within base should be valid
    Assert.isTrue(SecurityValidator.isPathWithinBase(filePath, basePath));
    Assert.isTrue(SecurityValidator.isPathWithinBase(subDir, basePath));
    
    // Non-existent path should be invalid
    Assert.isFalse(SecurityValidator.isPathWithinBase(buildPath(basePath, "nonexistent"), basePath));
    
    // Path outside base (using parent's parent) should be invalid
    Assert.isFalse(SecurityValidator.isPathWithinBase("/etc/passwd", basePath));
    
    writeln("\x1b[32m  ✓ Path within base directory validation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - File extension validation");
    
    string[] allowedExts = [".cpp", ".h", ".hpp", ".cc"];
    
    Assert.isTrue(SecurityValidator.hasAllowedExtension("main.cpp", allowedExts));
    Assert.isTrue(SecurityValidator.hasAllowedExtension("header.h", allowedExts));
    Assert.isTrue(SecurityValidator.hasAllowedExtension("Header.H", allowedExts)); // Case insensitive
    Assert.isTrue(SecurityValidator.hasAllowedExtension("source.cc", allowedExts));
    
    Assert.isFalse(SecurityValidator.hasAllowedExtension("script.py", allowedExts));
    Assert.isFalse(SecurityValidator.hasAllowedExtension("doc.txt", allowedExts));
    Assert.isFalse(SecurityValidator.hasAllowedExtension("noext", allowedExts));
    
    writeln("\x1b[32m  ✓ File extension validation works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.validation - Shell path escaping");
    
    version(Windows)
    {
        Assert.equal(SecurityValidator.escapeShellPath("simple.txt"), `"simple.txt"`);
        Assert.equal(SecurityValidator.escapeShellPath("path with spaces.txt"), `"path with spaces.txt"`);
    }
    else
    {
        Assert.equal(SecurityValidator.escapeShellPath("simple.txt"), "simple.txt");
        Assert.notEmpty([SecurityValidator.escapeShellPath("path with spaces.txt")]);
        Assert.notEmpty([SecurityValidator.escapeShellPath("path$with$vars")]);
    }
    
    writeln("\x1b[32m  ✓ Shell path escaping works correctly\x1b[0m");
}

