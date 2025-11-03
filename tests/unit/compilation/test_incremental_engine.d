module tests.unit.compilation.test_incremental_engine;

import std.file;
import std.path;
import std.algorithm;
import std.conv;
import compilation.incremental.engine;
import caching.incremental.dependency;
import caching.actions.action;
import testframework.execution.executor;
import testframework.assertions.asserts;
import errors;

/// Test incremental engine rebuild determination
class TestIncrementalEngineRebuildSet : TestCase
{
    private string testCacheDir;
    private DependencyCache depCache;
    private ActionCache actionCache;
    private IncrementalEngine engine;
    private string testDir;
    
    this()
    {
        super("Incremental Engine Rebuild Set Determination");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-inc-engine-" ~ randomUUID().to!string);
        testDir = buildPath(tempDir(), "test-sources-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
        mkdirRecurse(testDir);
        
        depCache = new DependencyCache(buildPath(testCacheDir, "deps"));
        actionCache = new ActionCache(buildPath(testCacheDir, "actions"));
        engine = new IncrementalEngine(depCache, actionCache);
        
        // Create test files
        std.file.write(buildPath(testDir, "main.cpp"), "// main");
        std.file.write(buildPath(testDir, "utils.cpp"), "// utils");
        std.file.write(buildPath(testDir, "header.h"), "// header");
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
        auto mainPath = buildPath(testDir, "main.cpp");
        auto utilsPath = buildPath(testDir, "utils.cpp");
        auto headerPath = buildPath(testDir, "header.h");
        
        // Record that main.cpp depends on header.h
        depCache.recordDependencies(mainPath, [headerPath]);
        
        auto sources = [mainPath, utilsPath];
        auto changedFiles = [headerPath];
        
        // Determine rebuild set
        auto result = engine.determineRebuildSet(
            sources,
            changedFiles,
            (file) {
                ActionId id;
                id.targetId = "test";
                id.type = ActionType.Compile;
                id.subId = baseName(file);
                id.inputHash = "test-hash";
                return id;
            },
            (file) {
                string[string] meta;
                meta["test"] = "true";
                return meta;
            }
        );
        
        // main.cpp should need recompilation (depends on header.h)
        assertTrue(result.filesToCompile.canFind(mainPath),
                  "main.cpp should need recompilation");
        
        // utils.cpp should not (no dependency on header.h)
        // Though it might still compile due to action cache miss
        assertTrue(result.totalFiles == 2, "Should track 2 total files");
    }
}

/// Test incremental compilation recording
class TestIncrementalEngineRecording : TestCase
{
    private string testCacheDir;
    private DependencyCache depCache;
    private ActionCache actionCache;
    private IncrementalEngine engine;
    private string testDir;
    
    this()
    {
        super("Incremental Engine Compilation Recording");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-inc-record-" ~ randomUUID().to!string);
        testDir = buildPath(tempDir(), "test-sources-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
        mkdirRecurse(testDir);
        
        depCache = new DependencyCache(buildPath(testCacheDir, "deps"));
        actionCache = new ActionCache(buildPath(testCacheDir, "actions"));
        engine = new IncrementalEngine(depCache, actionCache);
        
        // Create test files
        std.file.write(buildPath(testDir, "main.cpp"), "// main");
        std.file.write(buildPath(testDir, "header.h"), "// header");
        std.file.write(buildPath(testDir, "main.o"), "fake object");
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
        auto mainPath = buildPath(testDir, "main.cpp");
        auto headerPath = buildPath(testDir, "header.h");
        auto objPath = buildPath(testDir, "main.o");
        
        ActionId actionId;
        actionId.targetId = "test";
        actionId.type = ActionType.Compile;
        actionId.subId = "main.cpp";
        actionId.inputHash = "test-hash";
        
        string[string] metadata;
        metadata["compiler"] = "g++";
        
        // Record compilation
        engine.recordCompilation(
            mainPath,
            [headerPath],
            actionId,
            [objPath],
            metadata
        );
        
        // Verify dependency cache updated
        auto depResult = depCache.getDependencies(mainPath);
        assertTrue(depResult.isOk, "Dependencies should be recorded");
        
        auto deps = depResult.unwrap();
        assertTrue(deps.dependencies.canFind(headerPath),
                  "Should record header dependency");
        
        // Verify action cache updated
        assertTrue(actionCache.isCached(actionId, [mainPath], metadata),
                  "Action should be cached");
    }
}

/// Test incremental compilation strategies
class TestIncrementalStrategies : TestCase
{
    private string testCacheDir;
    private string testDir;
    
    this()
    {
        super("Incremental Compilation Strategies");
    }
    
    override void setup()
    {
        testCacheDir = buildPath(tempDir(), "test-inc-strat-" ~ randomUUID().to!string);
        testDir = buildPath(tempDir(), "test-sources-" ~ randomUUID().to!string);
        mkdirRecurse(testCacheDir);
        mkdirRecurse(testDir);
        
        std.file.write(buildPath(testDir, "file1.cpp"), "// file1");
        std.file.write(buildPath(testDir, "file2.cpp"), "// file2");
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
        auto depCache = new DependencyCache(buildPath(testCacheDir, "deps"));
        auto actionCache = new ActionCache(buildPath(testCacheDir, "actions"));
        
        auto file1 = buildPath(testDir, "file1.cpp");
        auto file2 = buildPath(testDir, "file2.cpp");
        auto sources = [file1, file2];
        
        // Test Full strategy
        {
            auto engine = new IncrementalEngine(
                depCache, actionCache, CompilationStrategy.Full
            );
            
            auto result = engine.determineRebuildSet(
                sources, [],
                (file) { ActionId id; return id; },
                (file) { string[string] m; return m; }
            );
            
            assertEqual(result.strategy, CompilationStrategy.Full, 
                       "Should use Full strategy");
            assertEqual(result.filesToCompile.length, 2, 
                       "Should compile all files with Full strategy");
        }
        
        // Test Incremental strategy
        {
            auto engine = new IncrementalEngine(
                depCache, actionCache, CompilationStrategy.Incremental
            );
            
            auto result = engine.determineRebuildSet(
                sources, [],
                (file) { ActionId id; return id; },
                (file) { string[string] m; return m; }
            );
            
            assertEqual(result.strategy, CompilationStrategy.Incremental,
                       "Should use Incremental strategy");
        }
    }
}

/// Test suite for incremental engine
class IncrementalEngineTestSuite : TestSuite
{
    this()
    {
        super("Incremental Compilation Engine");
        
        addTest(new TestIncrementalEngineRebuildSet());
        addTest(new TestIncrementalEngineRecording());
        addTest(new TestIncrementalStrategies());
    }
}

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

