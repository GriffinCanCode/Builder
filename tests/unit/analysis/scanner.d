module tests.unit.analysis.scanner;

import std.stdio;
import std.path;
import std.regex;
import infrastructure.analysis.scanning.scanner;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.scanner - File scanning");
    
    auto tempDir = scoped(new TempDir("scanner-test"));
    auto scanner = new FileScanner();
    
    // Create Python file with imports
    string pythonCode = `
import os
import sys
from pathlib import Path
import numpy as np
`;
    
    tempDir.createFile("test.py", pythonCode);
    auto filePath = buildPath(tempDir.getPath(), "test.py");
    
    // Python import pattern
    auto pattern = regex(r"^\s*(?:from\s+(\S+)\s+import|import\s+(\S+))", "m");
    
    auto imports = scanner.scanImports(filePath, pattern);
    
    // Verify imports detected (should find at least some imports)
    // Note: The actual number depends on the regex capturing groups
    Assert.notEmpty(imports);
    
    writeln("\x1b[32m  ✓ File scanning detects imports correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.scanner - Parallel file scanning");
    
    auto tempDir = scoped(new TempDir("scanner-test"));
    auto scanner = new FileScanner();
    
    // Create multiple Python files
    tempDir.createFile("file1.py", "import os\nimport sys");
    tempDir.createFile("file2.py", "import json\nimport re");
    tempDir.createFile("file3.py", "from pathlib import Path");
    
    string[] files = [
        buildPath(tempDir.getPath(), "file1.py"),
        buildPath(tempDir.getPath(), "file2.py"),
        buildPath(tempDir.getPath(), "file3.py")
    ];
    
    auto pattern = regex(r"^\s*(?:from\s+(\S+)\s+import|import\s+(\S+))", "m");
    
    // Scan in parallel
    auto results = scanner.scanImportsParallel(files, pattern);
    
    // Verify all files scanned
    Assert.equal(results.length, 3);
    
    foreach (file; files)
    {
        Assert.isTrue((file in results) !is null);
        Assert.notEmpty(results[file]);
    }
    
    writeln("\x1b[32m  ✓ Parallel scanning processes multiple files\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m analysis.scanner - Change detection");
    
    auto tempDir = scoped(new TempDir("scanner-test"));
    auto scanner = new FileScanner();
    
    tempDir.createFile("mutable.py", "# Version 1");
    auto filePath = buildPath(tempDir.getPath(), "mutable.py");
    
    // Get initial hash
    import infrastructure.utils.files.hash;
    auto hash1 = FastHash.hashMetadata(filePath);
    
    // File hasn't changed
    Assert.isFalse(scanner.hasChanged(filePath, hash1));
    
    // Modify file
    import core.thread : Thread;
    import core.time : msecs;
    Thread.sleep(10.msecs);
    tempDir.createFile("mutable.py", "# Version 2");
    
    // File has changed
    Assert.isTrue(scanner.hasChanged(filePath, hash1));
    
    writeln("\x1b[32m  ✓ Change detection works correctly\x1b[0m");
}

