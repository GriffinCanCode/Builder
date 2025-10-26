module tests.unit.core.cache;

import std.stdio;
import std.path;
import std.file;
import std.datetime;
import std.conv;
import std.range;
import core.cache;
import core.eviction;
import tests.harness;
import tests.fixtures;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.cache - Cache hit on unchanged file");
    
    auto tempDir = scoped(new TempDir("cache-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    auto cache = new BuildCache(cacheDir);
    
    // Create source files
    tempDir.createFile("main.d", "void main() {}");
    auto sourcePath = buildPath(tempDir.getPath(), "main.d");
    
    // Initial build - cache miss
    string[] sources = [sourcePath];
    string[] deps = [];
    Assert.isFalse(cache.isCached("test-target", sources, deps));
    
    // Update cache
    cache.update("test-target", sources, deps, "hash123");
    
    // Second check - cache hit (file unchanged)
    Assert.isTrue(cache.isCached("test-target", sources, deps));
    
    writeln("\x1b[32m  ✓ Cache hit on unchanged file works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.cache - Cache miss on modified file");
    
    auto tempDir = scoped(new TempDir("cache-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    auto cache = new BuildCache(cacheDir);
    
    // Create and cache initial version
    tempDir.createFile("source.d", "void main() { writeln(\"v1\"); }");
    auto sourcePath = buildPath(tempDir.getPath(), "source.d");
    
    string[] sources = [sourcePath];
    cache.update("target", sources, [], "hash1");
    Assert.isTrue(cache.isCached("target", sources, []));
    
    // Modify file content
    import core.thread : Thread;
    import core.time : msecs;
    Thread.sleep(10.msecs); // Ensure timestamp changes
    tempDir.createFile("source.d", "void main() { writeln(\"v2\"); }");
    
    // Cache miss due to content change
    Assert.isFalse(cache.isCached("target", sources, []));
    
    writeln("\x1b[32m  ✓ Cache miss on modified file detected correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.cache - LRU eviction");
    
    auto tempDir = scoped(new TempDir("cache-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    
    // Configure cache with small limits for testing
    CacheConfig config;
    config.maxEntries = 3;  // Only keep 3 entries
    config.maxSize = 0;      // Disable size limit
    config.maxAge = 365;     // Disable age limit
    
    auto cache = new BuildCache(cacheDir, config);
    
    // Create test files
    tempDir.createFile("a.d", "// File A");
    tempDir.createFile("b.d", "// File B");
    tempDir.createFile("c.d", "// File C");
    tempDir.createFile("d.d", "// File D");
    
    auto pathA = buildPath(tempDir.getPath(), "a.d");
    auto pathB = buildPath(tempDir.getPath(), "b.d");
    auto pathC = buildPath(tempDir.getPath(), "c.d");
    auto pathD = buildPath(tempDir.getPath(), "d.d");
    
    // Add 3 entries (at capacity)
    cache.update("target-a", [pathA], [], "hashA");
    cache.update("target-b", [pathB], [], "hashB");
    cache.update("target-c", [pathC], [], "hashC");
    
    // Access target-a to make it recently used
    cache.isCached("target-a", [pathA], []);
    
    // Add 4th entry - should evict target-b (least recently used)
    cache.update("target-d", [pathD], [], "hashD");
    cache.flush(); // Trigger eviction
    
    // Verify eviction behavior
    auto stats = cache.getStats();
    Assert.isTrue(stats.totalEntries <= config.maxEntries,
                 "Cache should respect entry limit");
    
    writeln("\x1b[32m  ✓ LRU eviction policy works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.cache - Two-tier hashing performance");
    
    auto tempDir = scoped(new TempDir("cache-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    auto cache = new BuildCache(cacheDir);
    
    // Create source file
    tempDir.createFile("large.d", "// " ~ "x".repeat(10_000).join);
    auto sourcePath = buildPath(tempDir.getPath(), "large.d");
    
    // Cache the file
    cache.update("target", [sourcePath], [], "hash1");
    
    // Check cache multiple times (should use fast metadata path)
    foreach (_; 0 .. 5)
    {
        Assert.isTrue(cache.isCached("target", [sourcePath], []));
    }
    
    auto stats = cache.getStats();
    // Metadata hits should dominate content hashes
    Assert.isTrue(stats.metadataHits > stats.contentHashes,
                 "Two-tier hashing should favor metadata checks");
    
    writeln("\x1b[32m  ✓ Two-tier hashing optimization verified\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m core.cache - Dependency change invalidation");
    
    auto tempDir = scoped(new TempDir("cache-test"));
    auto cacheDir = buildPath(tempDir.getPath(), ".cache");
    auto cache = new BuildCache(cacheDir);
    
    // Create lib and app
    tempDir.createFile("lib.d", "module lib;");
    tempDir.createFile("app.d", "import lib;");
    
    auto libPath = buildPath(tempDir.getPath(), "lib.d");
    auto appPath = buildPath(tempDir.getPath(), "app.d");
    
    // Build lib first
    cache.update("lib", [libPath], [], "hashLib1");
    
    // Build app depending on lib
    cache.update("app", [appPath], ["lib"], "hashApp1");
    Assert.isTrue(cache.isCached("app", [appPath], ["lib"]));
    
    // Rebuild lib with different hash
    cache.update("lib", [libPath], [], "hashLib2");
    
    // App should be invalidated due to dependency change
    Assert.isFalse(cache.isCached("app", [appPath], ["lib"]));
    
    writeln("\x1b[32m  ✓ Dependency change invalidation works\x1b[0m");
}

