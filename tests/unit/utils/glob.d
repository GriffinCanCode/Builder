module tests.unit.utils.glob;

import std.stdio;
import std.path;
import std.file;
import std.algorithm;
import std.array;
import utils.files.glob;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.glob - Basic pattern matching");
    
    auto tempDir = scoped(new TempDir("glob-test"));
    
    // Create test files
    tempDir.createFile("file1.py", "# Python");
    tempDir.createFile("file2.py", "# Python");
    tempDir.createFile("file1.js", "// JS");
    tempDir.createDir("src");
    tempDir.createFile("src/main.py", "# Main");
    tempDir.createFile("src/util.py", "# Util");
    
    // Test simple glob
    auto pyFiles = glob("*.py", tempDir.getPath());
    Assert.equal(pyFiles.length, 2);
    Assert.isTrue(pyFiles.any!(f => f.baseName == "file1.py"));
    Assert.isTrue(pyFiles.any!(f => f.baseName == "file2.py"));
    
    writeln("\x1b[32m  ✓ Basic pattern matching works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.glob - Recursive glob");
    
    auto tempDir = scoped(new TempDir("glob-test"));
    
    tempDir.createFile("root.py", "");
    tempDir.createDir("src");
    tempDir.createFile("src/a.py", "");
    tempDir.createDir("src/sub");
    tempDir.createFile("src/sub/b.py", "");
    
    // Test recursive glob
    auto allPy = glob("**/*.py", tempDir.getPath());
    Assert.equal(allPy.length, 3);
    
    writeln("\x1b[32m  ✓ Recursive glob works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.glob - Negation patterns");
    
    auto tempDir = scoped(new TempDir("glob-test"));
    
    tempDir.createFile("keep.py", "");
    tempDir.createDir("exclude");
    tempDir.createFile("exclude/remove.py", "");
    
    // Test negation
    auto filtered = glob(["**/*.py", "!exclude/**"], tempDir.getPath());
    Assert.equal(filtered.length, 1);
    Assert.isTrue(filtered[0].baseName == "keep.py");
    
    writeln("\x1b[32m  ✓ Negation patterns work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.glob - Wildcard characters");
    
    auto tempDir = scoped(new TempDir("glob-test"));
    
    tempDir.createFile("file1.py", "");
    tempDir.createFile("file2.py", "");
    tempDir.createFile("file10.py", "");
    
    // Test ? wildcard
    auto singleChar = glob("file?.py", tempDir.getPath());
    Assert.equal(singleChar.length, 2); // file1.py and file2.py, not file10.py
    
    writeln("\x1b[32m  ✓ Wildcard characters work\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.glob - Empty results");
    
    auto tempDir = scoped(new TempDir("glob-test"));
    
    // Test no matches
    auto noMatch = glob("*.nonexistent", tempDir.getPath());
    Assert.isEmpty(noMatch);
    
    writeln("\x1b[32m  ✓ Empty results handled correctly\x1b[0m");
}

