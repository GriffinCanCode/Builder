module tests.unit.config.parse_cache;

import std.stdio;
import std.file;
import std.path;
import std.conv;
import infrastructure.config.caching.parse;
import infrastructure.config.caching.storage;
import infrastructure.config.workspace.ast;
import infrastructure.config.parsing.lexer;
import infrastructure.config.interpretation.dsl;

/// Test parse cache functionality
void testParseCache()
{
    writeln("Testing parse cache...");
    
    testBasicCaching();
    testCacheInvalidation();
    testTwoTierValidation();
    testLRUEviction();
    testSerialization();
    testConcurrentAccess();
    
    writeln("✓ All parse cache tests passed");
}

/// Test basic cache hit/miss behavior
void testBasicCaching()
{
    writeln("  Testing basic caching...");
    
    // Create temporary test file
    auto testDir = buildPath(tempDir(), "builder-test-" ~ randomUUID().toString());
    mkdirRecurse(testDir);
    scope(exit) rmdirRecurse(testDir);
    
    auto testFile = buildPath(testDir, "test.build");
    auto content = `target("app") { type: executable; sources: ["main.py"]; }`;
    write(testFile, content);
    
    // Create cache
    auto cacheDir = buildPath(testDir, "cache");
    auto cache = new ParseCache(false, cacheDir, 10);
    
    // First access - cache miss
    auto ast1 = cache.get(testFile);
    assert(ast1 is null, "First access should be cache miss");
    
    // Parse and cache
    auto lexResult = lex(content, testFile);
    assert(lexResult.isOk, "Lex should succeed");
    auto parser = DSLParser(lexResult.unwrap(), testFile);
    auto parseResult = parser.parse();
    assert(parseResult.isOk, "Parse should succeed");
    
    cache.put(testFile, parseResult.unwrap());
    
    // Second access - cache hit
    auto ast2 = cache.get(testFile);
    assert(ast2 !is null, "Second access should be cache hit");
    assert(ast2.targets.length == 1, "Cached AST should have 1 target");
    assert(ast2.targets[0].name == "app", "Cached target name should match");
    
    // Verify statistics
    auto stats = cache.getStats();
    assert(stats.hits == 1, "Should have 1 cache hit");
    assert(stats.misses == 1, "Should have 1 cache miss");
    assert(stats.hitRate > 49.0 && stats.hitRate < 51.0, "Hit rate should be ~50%");
    
    writeln("    ✓ Basic caching works");
}

/// Test cache invalidation on file changes
void testCacheInvalidation()
{
    writeln("  Testing cache invalidation...");
    
    auto testDir = buildPath(tempDir(), "builder-test-" ~ randomUUID().toString());
    mkdirRecurse(testDir);
    scope(exit) rmdirRecurse(testDir);
    
    auto testFile = buildPath(testDir, "test.build");
    auto content1 = `target("app") { type: executable; sources: ["main.py"]; }`;
    write(testFile, content1);
    
    auto cacheDir = buildPath(testDir, "cache");
    auto cache = new ParseCache(false, cacheDir, 10);
    
    // Parse and cache
    auto lexResult1 = lex(content1, testFile);
    auto parser1 = DSLParser(lexResult1.unwrap(), testFile);
    cache.put(testFile, parser1.parse().unwrap());
    
    // Verify cache hit
    auto ast1 = cache.get(testFile);
    assert(ast1 !is null, "Should get cache hit");
    
    // Modify file
    import core.thread : Thread;
    import core.time : msecs;
    Thread.sleep(10.msecs); // Ensure mtime changes
    auto content2 = `target("app2") { type: library; sources: ["lib.py"]; }`;
    write(testFile, content2);
    
    // Cache should be invalidated
    auto ast2 = cache.get(testFile);
    assert(ast2 is null, "Cache should be invalidated after file change");
    
    writeln("    ✓ Cache invalidation works");
}

/// Test two-tier validation (metadata vs content hash)
void testTwoTierValidation()
{
    writeln("  Testing two-tier validation...");
    
    auto testDir = buildPath(tempDir(), "builder-test-" ~ randomUUID().toString());
    mkdirRecurse(testDir);
    scope(exit) rmdirRecurse(testDir);
    
    auto testFile = buildPath(testDir, "test.build");
    auto content = `target("app") { type: executable; sources: ["main.py"]; }`;
    write(testFile, content);
    
    auto cacheDir = buildPath(testDir, "cache");
    auto cache = new ParseCache(false, cacheDir, 10);
    
    // Parse and cache
    auto lexResult = lex(content, testFile);
    auto parser = DSLParser(lexResult.unwrap(), testFile);
    cache.put(testFile, parser.parse().unwrap());
    
    // First hit - metadata unchanged (fast path)
    auto ast1 = cache.get(testFile);
    assert(ast1 !is null, "Should get cache hit");
    
    auto stats1 = cache.getStats();
    assert(stats1.metadataHits == 1, "Should use fast path (metadata)");
    assert(stats1.contentHashes == 0, "Should not compute content hash");
    
    writeln("    ✓ Two-tier validation works");
}

/// Test LRU eviction
void testLRUEviction()
{
    writeln("  Testing LRU eviction...");
    
    auto testDir = buildPath(tempDir(), "builder-test-" ~ randomUUID().toString());
    mkdirRecurse(testDir);
    scope(exit) rmdirRecurse(testDir);
    
    auto cacheDir = buildPath(testDir, "cache");
    auto cache = new ParseCache(false, cacheDir, 3); // Small cache for testing
    
    // Create and cache 5 files
    foreach (i; 0 .. 5)
    {
        auto testFile = buildPath(testDir, "test" ~ i.to!string ~ ".build");
        auto content = `target("app` ~ i.to!string ~ `") { type: executable; sources: ["main.py"]; }`;
        write(testFile, content);
        
        auto lexResult = lex(content, testFile);
        auto parser = DSLParser(lexResult.unwrap(), testFile);
        cache.put(testFile, parser.parse().unwrap());
    }
    
    // Cache should have evicted oldest entries
    auto stats = cache.getStats();
    assert(stats.totalEntries <= 3, "Cache should not exceed max entries");
    
    writeln("    ✓ LRU eviction works");
}

/// Test AST serialization
void testSerialization()
{
    writeln("  Testing AST serialization...");
    
    // Create test AST
    BuildFile original;
    original.filePath = "test.build";
    
    TargetDecl target;
    target.name = "app";
    target.line = 1;
    target.column = 1;
    
    Field field1;
    field1.name = "type";
    field1.line = 2;
    field1.column = 5;
    field1.value = ExpressionValue.fromIdentifier("executable", 2, 11);
    
    Field field2;
    field2.name = "sources";
    field2.line = 3;
    field2.column = 5;
    field2.value = ExpressionValue.fromArray([
        ExpressionValue.fromString("main.py", 3, 15)
    ], 3, 14);
    
    target.fields ~= field1;
    target.fields ~= field2;
    original.targets ~= target;
    
    // Serialize and deserialize
    auto serialized = ASTStorage.serialize(original);
    auto deserialized = ASTStorage.deserialize(serialized);
    
    // Verify
    assert(deserialized.filePath == original.filePath, "File path should match");
    assert(deserialized.targets.length == 1, "Should have 1 target");
    assert(deserialized.targets[0].name == "app", "Target name should match");
    assert(deserialized.targets[0].fields.length == 2, "Should have 2 fields");
    assert(deserialized.targets[0].fields[0].name == "type", "First field name should match");
    assert(deserialized.targets[0].fields[1].name == "sources", "Second field name should match");
    
    writeln("    ✓ AST serialization works");
}

/// Test concurrent cache access
void testConcurrentAccess()
{
    writeln("  Testing concurrent access...");
    
    auto testDir = buildPath(tempDir(), "builder-test-" ~ randomUUID().toString());
    mkdirRecurse(testDir);
    scope(exit) rmdirRecurse(testDir);
    
    auto cacheDir = buildPath(testDir, "cache");
    auto cache = new ParseCache(false, cacheDir, 100);
    
    // Create test files
    auto testFiles = new string[10];
    foreach (i; 0 .. 10)
    {
        testFiles[i] = buildPath(testDir, "test" ~ i.to!string ~ ".build");
        auto content = `target("app` ~ i.to!string ~ `") { type: executable; sources: ["main.py"]; }`;
        write(testFiles[i], content);
    }
    
    // Concurrent access from multiple threads
    import std.parallelism : parallel;
    import std.range : iota;
    
    foreach (i; parallel(iota(10)))
    {
        auto testFile = testFiles[i];
        auto content = readText(testFile);
        
        // Try to get from cache
        auto cached = cache.get(testFile);
        
        if (cached is null)
        {
            // Parse and cache
            auto lexResult = lex(content, testFile);
            if (lexResult.isOk)
            {
                auto parser = DSLParser(lexResult.unwrap(), testFile);
                auto parseResult = parser.parse();
                if (parseResult.isOk)
                {
                    cache.put(testFile, parseResult.unwrap());
                }
            }
        }
    }
    
    // Verify all files were cached
    auto stats = cache.getStats();
    assert(stats.totalEntries == 10, "All files should be cached");
    
    writeln("    ✓ Concurrent access works");
}

/// Helper to generate random UUID
private string randomUUID()
{
    import std.uuid : randomUUID;
    return randomUUID().toString();
}

