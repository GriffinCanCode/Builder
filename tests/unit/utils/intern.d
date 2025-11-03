module tests.unit.utils.intern;

import std.stdio;
import std.algorithm;
import std.conv;
import std.range;
import infrastructure.utils.memory.intern;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Basic interning and equality");
    
    auto pool = new StringPool();
    
    auto s1 = pool.intern("hello");
    auto s2 = pool.intern("hello");
    auto s3 = pool.intern("world");
    
    // Same string should have pointer equality
    Assert.equal(s1, s2, "Interned strings should be equal");
    Assert.notEqual(s1, s3, "Different strings should not be equal");
    Assert.equal(s1.toString(), "hello");
    Assert.equal(s3.toString(), "world");
    
    writeln("\x1b[32m  ✓ Basic interning works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Deduplication statistics");
    
    auto pool = new StringPool();
    
    // Intern many duplicates (simulates build system with many file paths)
    foreach (i; 0 .. 100)
    {
        pool.intern("/usr/local/bin");
        pool.intern("/usr/local/lib");
        pool.intern("/usr/local/include");
    }
    
    auto stats = pool.getStats();
    
    Assert.equal(stats.totalInterns, 300);
    Assert.equal(stats.uniqueStrings, 3);
    Assert.isTrue(stats.deduplicationRate >= 99.0, "Should have >=99% deduplication");
    Assert.isTrue(stats.savedBytes > 0, "Should save memory");
    
    writeln("\x1b[32m  ✓ Deduplication statistics work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Hash function and AA keys");
    
    auto pool = new StringPool();
    
    auto s1 = pool.intern("test");
    auto s2 = pool.intern("test");
    auto s3 = pool.intern("other");
    
    // Interned strings should have same hash
    Assert.equal(s1.toHash(), s2.toHash());
    Assert.notEqual(s1.toHash(), s3.toHash());
    
    // Can be used as associative array keys
    int[Intern] map;
    map[s1] = 42;
    map[s3] = 99;
    
    Assert.equal(map[s2], 42, "Should find via interned pointer");
    Assert.equal(map[s3], 99);
    Assert.equal(map.length, 2);
    
    writeln("\x1b[32m  ✓ Hash function and AA keys work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Comparison operators");
    
    auto pool = new StringPool();
    
    auto apple = pool.intern("apple");
    auto banana = pool.intern("banana");
    auto apple2 = pool.intern("apple");
    
    Assert.equal(apple, apple2);
    Assert.notEqual(apple, banana);
    Assert.isTrue(apple < banana, "apple < banana");
    Assert.isFalse(apple > banana, "apple not > banana");
    Assert.isTrue(banana > apple, "banana > apple");
    
    // Test sorting
    Intern[] fruits = [banana, apple];
    fruits.sort();
    Assert.equal(fruits[0], apple);
    Assert.equal(fruits[1], banana);
    
    writeln("\x1b[32m  ✓ Comparison operators work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Empty strings");
    
    auto pool = new StringPool();
    
    auto empty1 = pool.intern("");
    auto empty2 = pool.intern("");
    auto nonempty = pool.intern("x");
    
    Assert.equal(empty1, empty2);
    Assert.isTrue(empty1.empty);
    Assert.equal(empty1.length, 0);
    Assert.isFalse(nonempty.empty);
    Assert.equal(nonempty.length, 1);
    
    writeln("\x1b[32m  ✓ Empty string handling works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Large scale deduplication");
    
    auto pool = new StringPool();
    
    // Simulate realistic build system scenario
    string[] commonPaths = [
        "/usr/local/bin",
        "/usr/local/lib",
        "/usr/local/include",
        "/home/user/project/src",
        "/home/user/project/build",
        "node_modules/package/index.js",
        "node_modules/package/lib/utils.js",
        "src/main.d",
        "src/utils.d",
        "build/output.o"
    ];
    
    // Each path used 50 times (typical for large build)
    foreach (i; 0 .. 50)
    {
        foreach (path; commonPaths)
        {
            pool.intern(path);
        }
    }
    
    auto stats = pool.getStats();
    
    Assert.equal(stats.uniqueStrings, 10, "Should have 10 unique paths");
    Assert.equal(stats.totalInterns, 500, "Should have 500 total interns");
    Assert.isTrue(stats.deduplicationRate >= 98.0, "Should have >=98% deduplication");
    
    // Estimate memory saved
    immutable avgPathLength = 30;
    immutable estimatedSaved = (500 - 10) * (avgPathLength + 16);  // string overhead
    Assert.isTrue(stats.savedBytes > 0);
    
    writeln("\x1b[32m  ✓ Large scale deduplication works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Domain-specific pools");
    
    DomainPools pools = DomainPools(0);
    
    // Intern paths, targets, and imports separately
    auto path1 = pools.internPath("/usr/local/bin");
    auto path2 = pools.internPath("/usr/local/bin");
    auto path3 = pools.internPath("/usr/local/lib");
    
    auto target1 = pools.internTarget("mylib");
    auto target2 = pools.internTarget("mylib");
    auto target3 = pools.internTarget("myapp");
    
    auto import1 = pools.internImport("std.stdio");
    auto import2 = pools.internImport("std.stdio");
    auto import3 = pools.internImport("std.algorithm");
    
    // Check deduplication within each domain
    Assert.equal(path1, path2);
    Assert.equal(target1, target2);
    Assert.equal(import1, import2);
    
    // Check combined statistics
    auto stats = pools.getCombinedStats();
    Assert.equal(stats.totalInterns, 9);
    Assert.equal(stats.uniqueStrings, 6);  // 2 paths + 2 targets + 2 imports
    Assert.isTrue(stats.deduplicationRate > 30.0);
    
    writeln("\x1b[32m  ✓ Domain-specific pools work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Thread safety");
    
    import std.parallelism : parallel;
    import std.range : iota;
    
    auto pool = new StringPool();
    
    // Intern same strings from multiple threads
    foreach (_; parallel(iota(100)))
    {
        auto s1 = pool.intern("concurrent");
        auto s2 = pool.intern("test");
        auto s3 = pool.intern("safety");
        auto s4 = pool.intern("concurrent");
        
        // Verify equality within thread
        Assert.equal(s1, s4);
    }
    
    auto stats = pool.getStats();
    
    // Should have exactly 3 unique strings despite concurrent access
    Assert.equal(stats.uniqueStrings, 3);
    Assert.equal(stats.totalInterns, 400);  // 100 threads * 4 interns each
    Assert.isTrue(stats.deduplicationRate > 99.0);
    
    writeln("\x1b[32m  ✓ Thread safety works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Performance: O(1) equality");
    
    import std.datetime.stopwatch : StopWatch, AutoStart;
    
    auto pool = new StringPool();
    
    auto s1 = pool.intern("a" ~ "b".repeat(1000).join);  // Long string
    auto s2 = pool.intern("a" ~ "b".repeat(1000).join);
    
    // Measure pointer equality (should be O(1))
    StopWatch sw = StopWatch(AutoStart.yes);
    foreach (i; 0 .. 100_000)
    {
        auto equal = (s1 == s2);
        assert(equal);
    }
    sw.stop();
    
    immutable pointerTime = sw.peek().total!"usecs";
    
    // Compare with string equality (O(n))
    string str1 = s1.toString();
    string str2 = s2.toString();
    
    sw.reset();
    sw.start();
    foreach (i; 0 .. 100_000)
    {
        auto equal = (str1 == str2);
        assert(equal);
    }
    sw.stop();
    
    immutable stringTime = sw.peek().total!"usecs";
    
    writeln("  Pointer comparison: ", pointerTime, " μs");
    writeln("  String comparison: ", stringTime, " μs");
    writeln("  Speedup: ", cast(double)stringTime / pointerTime, "x");
    
    // Pointer equality should be significantly faster
    Assert.isTrue(pointerTime < stringTime, "Pointer equality should be faster");
    
    writeln("\x1b[32m  ✓ O(1) equality comparison works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Clear functionality");
    
    auto pool = new StringPool();
    
    pool.intern("test1");
    pool.intern("test2");
    pool.intern("test3");
    
    Assert.equal(pool.size(), 3);
    
    pool.clear();
    
    Assert.equal(pool.size(), 0);
    
    // Can still intern after clear
    auto s = pool.intern("new");
    Assert.equal(s.toString(), "new");
    Assert.equal(pool.size(), 1);
    
    writeln("\x1b[32m  ✓ Clear functionality works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.intern - Memory footprint simulation");
    
    auto pool = new StringPool();
    
    // Simulate a large project with many targets
    immutable targetCount = 1000;
    immutable avgReferencesPerTarget = 20;  // Each target referenced 20 times
    
    foreach (i; 0 .. targetCount)
    {
        string targetName = "target_" ~ i.to!string;
        foreach (_; 0 .. avgReferencesPerTarget)
        {
            pool.intern(targetName);
        }
    }
    
    auto stats = pool.getStats();
    
    Assert.equal(stats.uniqueStrings, targetCount);
    Assert.equal(stats.totalInterns, targetCount * avgReferencesPerTarget);
    
    // Calculate savings
    immutable avgTargetNameLength = 12;  // "target_XXX"
    immutable stringOverhead = 16;  // length + ptr
    immutable withoutIntern = stats.totalInterns * (avgTargetNameLength + stringOverhead);
    immutable withIntern = stats.uniqueStrings * (avgTargetNameLength + stringOverhead);
    immutable savedPercentage = (1.0 - cast(double)withIntern / withoutIntern) * 100.0;
    
    writeln("  Without interning: ~", withoutIntern / 1024, " KB");
    writeln("  With interning: ~", withIntern / 1024, " KB");
    writeln("  Saved: ~", savedPercentage, "%");
    
    Assert.isTrue(savedPercentage > 90.0, "Should save >90% memory");
    
    writeln("\x1b[32m  ✓ Memory footprint simulation shows significant savings\x1b[0m");
}

