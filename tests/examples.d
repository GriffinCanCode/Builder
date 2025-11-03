module tests.examples;

import std.stdio;
import std.algorithm;
import std.array;
import std.range;
import tests.harness;
import tests.bench.utils;

/// Example: Using the benchmark harness
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Benchmark comparison");
    
    // Compare two sorting implementations
    auto data = iota(1000).array;
    
    Benchmark.compare(
        "std.algorithm.sort",
        { auto d = data.dup; d.sort; },
        "manual bubble sort",
        { 
            auto d = data.dup;
            foreach (i; 0 .. d.length)
                foreach (j; i + 1 .. d.length)
                    if (d[i] > d[j])
                    {
                        auto tmp = d[i];
                        d[i] = d[j];
                        d[j] = tmp;
                    }
        },
        iterations: 10
    );
}

/// Example: Using property-based testing
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Property-based testing");
    
    // Property: reversing twice returns original
    bool reverseTwiceIsIdentity(int[] arr) {
        auto reversed = arr.dup.reverse.array;
        auto restored = reversed.reverse.array;
        return arr == restored;
    }
    
    Assert.isTrue(Property.check(&reverseTwiceIsIdentity, 100));
    
    writeln("\x1b[32m  ✓ Property holds for 100 random samples\x1b[0m");
}

/// Example: Performance assertions
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Performance assertions");
    
    import core.time : msecs;
    
    // Assert operation completes quickly
    PerfAssert.completesWithin(
        { auto result = iota(1000).map!(x => x * x).array; },
        100.msecs,
        "Squaring 1000 numbers"
    );
    
    writeln("\x1b[32m  ✓ Performance assertion passed\x1b[0m");
}

/// Example: Statistical benchmarking
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Statistical benchmarking");
    
    // Run benchmark with multiple samples for statistical analysis
    auto stats = Benchmark.runStats(
        "array allocation",
        { auto arr = new int[1000]; },
        iterations: 1000,
        samples: 20
    );
    
    Benchmark.printStats(stats);
}

/// Example: Testing with fixtures
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Using test fixtures");
    
    import tests.fixtures;
    
    auto tempDir = scoped(new TempDir("example-test"));
    
    // Create test files
    tempDir.createFile("config.json", `{"key": "value"}`);
    tempDir.createDir("subdir");
    tempDir.createFile("subdir/data.txt", "test data");
    
    // Verify
    Assert.isTrue(tempDir.hasFile("config.json"));
    Assert.isTrue(tempDir.hasFile("subdir/data.txt"));
    
    auto content = tempDir.readFile("config.json");
    Assert.isTrue(content.canFind("key"));
    
    writeln("\x1b[32m  ✓ Fixture example completed\x1b[0m");
    
    // Automatic cleanup on scope exit
}

/// Example: Using mocks for testing
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Using mock objects");
    
    import tests.mocks;
    import infrastructure.config.schema;
    
    // Create mock language handler
    auto handler = new MockLanguageHandler(true);
    
    // Create dummy target
    Target target;
    target.name = "test";
    target.type = TargetType.Executable;
    
    // Configure mock
    handler.shouldSucceed = true;
    handler.outputHash = "mock-hash-12345";
    
    // Test
    WorkspaceConfig wsConfig;
    auto result = handler.build(target, wsConfig);
    
    Assert.isTrue(result.isOk);
    Assert.isTrue(handler.buildCalled);
    
    writeln("\x1b[32m  ✓ Mock testing example completed\x1b[0m");
}

/// Example: Testing with custom assertions
unittest
{
    writeln("\x1b[36m[EXAMPLE]\x1b[0m Custom assertions");
    
    auto numbers = [1, 2, 3, 4, 5];
    
    // Various assertion types
    Assert.notEmpty(numbers);
    Assert.equal(numbers.length, 5);
    Assert.contains(numbers, 3);
    Assert.isTrue(numbers.all!(x => x > 0));
    
    // Exception testing
    void throwTest() { throw new Exception("test"); }
    Assert.throws!Exception(throwTest());
    
    writeln("\x1b[32m  ✓ Assertion examples completed\x1b[0m");
}


