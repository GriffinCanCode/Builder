module tests.unit.caching.test_incremental;

import std.file;
import std.path;
import std.algorithm;
import std.conv;
import caching.incremental.dependency;
import caching.incremental.storage;
import testframework.execution.executor;
import testframework.assertions.asserts;
import errors;

/// Test dependency cache basic operations
class TestDependencyCacheBasic : TestCase
{
    private string testCacheDir;
    private DependencyCache cache;
    
    this()
    {
        super("DependencyCache Basic Operations");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-dep-cache-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
        cache = new DependencyCache(testCacheDir);
    }
    
    override void teardown()
    {
        if (exists(testCacheDir))
            rmdirRecurse(testCacheDir);
    }
    
    override void run()
    {
        // Test recording dependencies
        cache.recordDependencies("main.cpp", ["header.h", "utils.h"]);
        
        auto result = cache.getDependencies("main.cpp");
        assertTrue(result.isOk, "Should retrieve dependencies");
        
        auto deps = result.unwrap();
        assertEqual(deps.sourceFile, "main.cpp", "Source file should match");
        assertEqual(deps.dependencies.length, 2, "Should have 2 dependencies");
        assertTrue(deps.dependencies.canFind("header.h"), "Should include header.h");
        assertTrue(deps.dependencies.canFind("utils.h"), "Should include utils.h");
    }
}

/// Test dependency change analysis
class TestDependencyChangeAnalysis : TestCase
{
    private string testCacheDir;
    private DependencyCache cache;
    private string testDir;
    
    this()
    {
        super("Dependency Change Analysis");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-dep-analysis-" ~ randomUUID().to!string);
        testDir = buildPath(tempDir(), "test-sources-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
        mkdirRecurse(testDir);
        
        // Create test files
        std.file.write(buildPath(testDir, "main.cpp"), "// main");
        std.file.write(buildPath(testDir, "header.h"), "// header");
        std.file.write(buildPath(testDir, "utils.h"), "// utils");
        
        cache = new DependencyCache(testCacheDir);
        
        // Record dependencies
        auto mainPath = buildPath(testDir, "main.cpp");
        auto headerPath = buildPath(testDir, "header.h");
        auto utilsPath = buildPath(testDir, "utils.h");
        
        cache.recordDependencies(mainPath, [headerPath, utilsPath]);
    }
    
    override void teardown()
    {
        if (exists(testCacheDir))
            rmdirRecurse(testCacheDir);
        if (exists(testDir))
            rmdirRecurse(testDir);
    }
    
    override void run()
    {
        auto headerPath = buildPath(testDir, "header.h");
        auto mainPath = buildPath(testDir, "main.cpp");
        
        // Analyze changes when header.h changes
        auto changes = cache.analyzeChanges([headerPath]);
        
        assertTrue(changes.filesToRebuild.length > 0, "Should have files to rebuild");
        assertTrue(changes.filesToRebuild.canFind(mainPath), 
                  "main.cpp should need rebuild when header.h changes");
        assertTrue(changes.changedDependencies.canFind(headerPath),
                  "header.h should be in changed dependencies");
    }
}

/// Test dependency cache persistence
class TestDependencyCachePersistence : TestCase
{
    private string testCacheDir;
    
    this()
    {
        super("Dependency Cache Persistence");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-dep-persist-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
    }
    
    override void teardown()
    {
        if (exists(testCacheDir))
            rmdirRecurse(testCacheDir);
    }
    
    override void run()
    {
        // Create cache and record dependencies
        {
            auto cache = new DependencyCache(testCacheDir);
            cache.recordDependencies("file1.cpp", ["dep1.h", "dep2.h"]);
            cache.recordDependencies("file2.cpp", ["dep3.h"]);
            cache.flush();
        }
        
        // Load cache in new instance
        {
            auto cache = new DependencyCache(testCacheDir);
            
            auto result1 = cache.getDependencies("file1.cpp");
            assertTrue(result1.isOk, "Should load file1.cpp dependencies");
            assertEqual(result1.unwrap().dependencies.length, 2, "Should have 2 deps");
            
            auto result2 = cache.getDependencies("file2.cpp");
            assertTrue(result2.isOk, "Should load file2.cpp dependencies");
            assertEqual(result2.unwrap().dependencies.length, 1, "Should have 1 dep");
        }
    }
}

/// Test dependency invalidation
class TestDependencyInvalidation : TestCase
{
    private string testCacheDir;
    private DependencyCache cache;
    
    this()
    {
        super("Dependency Invalidation");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-dep-invalid-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
        cache = new DependencyCache(testCacheDir);
    }
    
    override void teardown()
    {
        if (exists(testCacheDir))
            rmdirRecurse(testCacheDir);
    }
    
    override void run()
    {
        // Record dependencies
        cache.recordDependencies("main.cpp", ["header.h"]);
        
        auto before = cache.getDependencies("main.cpp");
        assertTrue(before.isOk, "Should have dependencies before invalidation");
        
        // Invalidate
        cache.invalidate(["main.cpp"]);
        
        auto after = cache.getDependencies("main.cpp");
        assertTrue(after.isErr, "Should not have dependencies after invalidation");
    }
}

/// Test suite for incremental compilation
class IncrementalCompilationTestSuite : TestSuite
{
    this()
    {
        super("Incremental Compilation");
        
        addTest(new TestDependencyCacheBasic());
        addTest(new TestDependencyChangeAnalysis());
        addTest(new TestDependencyCachePersistence());
        addTest(new TestDependencyInvalidation());
    }
}

// Helper to generate random UUID
private string randomUUID()
{
    import std.random;
    import std.format;
    
    return format("%08x-%04x-%04x-%04x-%012x",
                 uniform!uint(),
                 uniform!ushort(),
                 uniform!ushort(),
                 uniform!ushort(),
                 uniform!ulong() & 0xFFFF_FFFF_FFFF);
}

