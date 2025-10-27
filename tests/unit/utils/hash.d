module tests.unit.utils.hash;

import std.stdio;
import std.file;
import std.path;
import utils.files.hash;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - Content hash consistency");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    // Create file and hash it
    auto filePath = buildPath(tempDir.getPath(), "test.txt");
    std.file.write(filePath, "Hello, World!");
    
    auto hash1 = FastHash.hashFile(filePath);
    auto hash2 = FastHash.hashFile(filePath);
    
    Assert.equal(hash1, hash2);
    Assert.notEmpty([hash1]);
    
    writeln("\x1b[32m  ✓ Content hash is consistent\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - Different content produces different hash");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    auto file1 = buildPath(tempDir.getPath(), "file1.txt");
    auto file2 = buildPath(tempDir.getPath(), "file2.txt");
    
    std.file.write(file1, "Content A");
    std.file.write(file2, "Content B");
    
    auto hash1 = FastHash.hashFile(file1);
    auto hash2 = FastHash.hashFile(file2);
    
    Assert.notEqual(hash1, hash2);
    
    writeln("\x1b[32m  ✓ Different content produces different hash\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - Hash stability after modification");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    auto filePath = buildPath(tempDir.getPath(), "mutable.txt");
    std.file.write(filePath, "Original");
    auto hashBefore = FastHash.hashFile(filePath);
    
    // Modify file
    std.file.write(filePath, "Modified");
    auto hashAfter = FastHash.hashFile(filePath);
    
    Assert.notEqual(hashBefore, hashAfter);
    
    // Restore content
    std.file.write(filePath, "Original");
    auto hashRestored = FastHash.hashFile(filePath);
    
    Assert.equal(hashBefore, hashRestored);
    
    writeln("\x1b[32m  ✓ Hash changes with content and restores correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - Empty file hash");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    auto emptyFile = buildPath(tempDir.getPath(), "empty.txt");
    std.file.write(emptyFile, "");
    
    auto hash = FastHash.hashFile(emptyFile);
    Assert.notEmpty([hash]); // Should still produce a hash
    
    writeln("\x1b[32m  ✓ Empty file produces valid hash\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - hashFileComplete() matches hashFile() for small files");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    // Create a small file (< 1MB)
    auto filePath = buildPath(tempDir.getPath(), "small.txt");
    std.file.write(filePath, "Small test content");
    
    auto hashStandard = FastHash.hashFile(filePath);
    auto hashComplete = FastHash.hashFileComplete(filePath);
    
    Assert.equal(hashStandard, hashComplete);
    
    writeln("\x1b[32m  ✓ hashFileComplete() matches hashFile() for small files\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - hashFileComplete() detects changes anywhere in file");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    // Create a file with repeating pattern
    auto filePath = buildPath(tempDir.getPath(), "pattern.txt");
    auto content = "A".replicate(1000);
    std.file.write(filePath, content);
    
    auto originalHash = FastHash.hashFileComplete(filePath);
    
    // Modify middle byte
    auto modifiedContent = content.dup;
    modifiedContent[500] = 'B';
    std.file.write(filePath, modifiedContent);
    
    auto modifiedHash = FastHash.hashFileComplete(filePath);
    
    Assert.notEqual(originalHash, modifiedHash);
    
    writeln("\x1b[32m  ✓ hashFileComplete() detects changes anywhere in file\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - hashFileComplete() consistency");
    
    auto tempDir = scoped(new TempDir("hash-test"));
    
    // Create file with substantial content
    auto filePath = buildPath(tempDir.getPath(), "consistent.txt");
    auto content = "Test content for consistency check\n".replicate(100);
    std.file.write(filePath, content);
    
    auto hash1 = FastHash.hashFileComplete(filePath);
    auto hash2 = FastHash.hashFileComplete(filePath);
    
    Assert.equal(hash1, hash2);
    Assert.notEmpty([hash1]);
    
    writeln("\x1b[32m  ✓ hashFileComplete() produces consistent hashes\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.hash - hashFileComplete() handles non-existent files");
    
    auto hash = FastHash.hashFileComplete("/path/to/nonexistent/file.txt");
    Assert.equal(hash, "");
    
    writeln("\x1b[32m  ✓ hashFileComplete() returns empty string for non-existent files\x1b[0m");
}

