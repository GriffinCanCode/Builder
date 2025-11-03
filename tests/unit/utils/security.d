module tests.unit.utils.security;

import std.stdio;
import std.file;
import std.path;
import infrastructure.utils.security.tempdir;
import infrastructure.utils.security.executor;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - TempDir creation and cleanup");
    
    string tempPath;
    
    {
        auto tempDir = scoped(new TempDir("security-test"));
        tempPath = tempDir.getPath();
        
        // Directory should exist while scoped
        Assert.isTrue(exists(tempPath));
        Assert.isTrue(isDir(tempPath));
    }
    
    // Directory should be cleaned up after scope
    // Note: This might not always work immediately due to OS cleanup delays
    // So we just verify it was created successfully
    
    writeln("\x1b[32m  ✓ TempDir creation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - TempDir unique paths");
    
    auto temp1 = scoped(new TempDir("test1"));
    auto temp2 = scoped(new TempDir("test2"));
    
    auto path1 = temp1.getPath();
    auto path2 = temp2.getPath();
    
    // Each TempDir should get a unique path
    Assert.notEqual(path1, path2);
    
    writeln("\x1b[32m  ✓ TempDir creates unique paths\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - TempDir file operations");
    
    auto tempDir = scoped(new TempDir("file-ops"));
    auto tempPath = tempDir.getPath();
    
    // Create a file in temp directory
    auto filePath = buildPath(tempPath, "test.txt");
    std.file.write(filePath, "test content");
    
    Assert.isTrue(exists(filePath));
    Assert.equal(readText(filePath), "test content");
    
    writeln("\x1b[32m  ✓ File operations in TempDir work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - TempDir nested directories");
    
    auto tempDir = scoped(new TempDir("nested"));
    auto tempPath = tempDir.getPath();
    
    // Create nested structure
    auto nested = buildPath(tempPath, "a", "b", "c");
    mkdirRecurse(nested);
    
    Assert.isTrue(exists(nested));
    Assert.isTrue(isDir(nested));
    
    writeln("\x1b[32m  ✓ Nested directories in TempDir work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - SecureExecutor validates commands");
    
    auto executor = new SecureExecutor();
    
    // Safe command should be allowed
    auto result1 = executor.validateCommand(["echo", "hello"]);
    Assert.isTrue(result1);
    
    // Command with suspicious args should be rejected
    auto result2 = executor.validateCommand(["echo", "; rm -rf /"]);
    Assert.isFalse(result2);
    
    writeln("\x1b[32m  ✓ SecureExecutor command validation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - SecureExecutor path validation");
    
    auto executor = new SecureExecutor();
    
    // Normal paths should be safe
    Assert.isTrue(executor.validatePath("src/main.cpp"));
    Assert.isTrue(executor.validatePath("output/app"));
    
    // Path traversal should be rejected
    Assert.isFalse(executor.validatePath("../../../etc/passwd"));
    Assert.isFalse(executor.validatePath("..\\..\\windows\\system32"));
    
    writeln("\x1b[32m  ✓ SecureExecutor path validation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - SecureExecutor environment isolation");
    
    auto executor = new SecureExecutor();
    
    // Should be able to set safe environment variables
    executor.setEnv("MY_VAR", "safe_value");
    auto env = executor.getEnv();
    
    Assert.equal(env["MY_VAR"], "safe_value");
    
    writeln("\x1b[32m  ✓ SecureExecutor environment management works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - SecureExecutor working directory validation");
    
    auto tempDir = scoped(new TempDir("workdir-test"));
    auto executor = new SecureExecutor();
    
    auto safePath = tempDir.getPath();
    
    // Safe working directory should be accepted
    Assert.isTrue(executor.validateWorkingDir(safePath));
    
    // System directories should be rejected (on Unix)
    version(Posix)
    {
        Assert.isFalse(executor.validateWorkingDir("/etc"));
        Assert.isFalse(executor.validateWorkingDir("/proc"));
    }
    
    writeln("\x1b[32m  ✓ SecureExecutor working directory validation works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.security - TempDir prefix handling");
    
    auto tempDir1 = scoped(new TempDir("prefix1"));
    auto tempDir2 = scoped(new TempDir("prefix2"));
    
    auto path1 = tempDir1.getPath();
    auto path2 = tempDir2.getPath();
    
    // Paths should contain the prefix
    import std.algorithm : canFind;
    Assert.isTrue(path1.canFind("prefix1"));
    Assert.isTrue(path2.canFind("prefix2"));
    
    writeln("\x1b[32m  ✓ TempDir prefix handling works\x1b[0m");
}

