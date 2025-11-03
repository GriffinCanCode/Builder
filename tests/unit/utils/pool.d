module tests.unit.utils.pool;

import std.stdio;
import std.algorithm;
import std.range;
import std.conv;
import core.time;
import core.thread;
import infrastructure.utils.concurrency.pool;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Basic parallel map with function");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    int square(int x) { return x * x; }
    
    auto input = [1, 2, 3, 4, 5];
    auto results = pool.map(input, &square);
    
    Assert.equal(results, [1, 4, 9, 16, 25]);
    
    writeln("\x1b[32m  ✓ Basic parallel map works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Parallel map with delegate");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    int multiplier = 10;
    auto results = pool.map([1, 2, 3, 4], (int x) => x * multiplier);
    
    Assert.equal(results, [10, 20, 30, 40]);
    
    writeln("\x1b[32m  ✓ Parallel map with delegate works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Empty input array");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    int[] emptyInput;
    auto results = pool.map(emptyInput, (int x) => x * 2);
    
    Assert.equal(results.length, 0);
    
    writeln("\x1b[32m  ✓ Empty input array is handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Single item input");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    auto results = pool.map([42], (int x) => x * 2);
    
    Assert.equal(results, [84]);
    
    writeln("\x1b[32m  ✓ Single item input is handled correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Large array processing");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    auto input = iota(0, 1000).array;
    auto results = pool.map(input, (int x) => x * x);
    
    // Verify all results are correct
    foreach (i, val; results)
    {
        Assert.equal(val, i * i);
    }
    
    writeln("\x1b[32m  ✓ Large array processing works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - String operations");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    auto input = ["hello", "world", "builder", "test"];
    auto results = pool.map(input, (string s) => s.length);
    
    Assert.equal(results, [5, 5, 7, 4]);
    
    writeln("\x1b[32m  ✓ String operations work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Type conversion");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    auto input = [1, 2, 3, 4, 5];
    auto results = pool.map(input, (int x) => x.to!string);
    
    Assert.equal(results, ["1", "2", "3", "4", "5"]);
    
    writeln("\x1b[32m  ✓ Type conversion works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Parallel forEach");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    shared int sum = 0;
    auto input = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    
    pool.forEach(input, (int x) {
        import core.atomic;
        atomicOp!"+="(sum, x);
    });
    
    Assert.equal(sum, 55); // Sum of 1..10
    
    writeln("\x1b[32m  ✓ Parallel forEach works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Shutdown idempotency");
    
    auto pool = new ThreadPool(2);
    
    pool.shutdown();
    pool.shutdown(); // Should be safe to call multiple times
    
    writeln("\x1b[32m  ✓ Shutdown is idempotent\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Multiple operations on same pool");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    // First operation
    auto results1 = pool.map([1, 2, 3], (int x) => x * 2);
    Assert.equal(results1, [2, 4, 6]);
    
    // Second operation
    auto results2 = pool.map([4, 5, 6], (int x) => x * 3);
    Assert.equal(results2, [12, 15, 18]);
    
    // Third operation
    auto results3 = pool.map([7, 8], (int x) => x + 10);
    Assert.equal(results3, [17, 18]);
    
    writeln("\x1b[32m  ✓ Multiple operations on same pool work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Worker count defaults to CPU count");
    
    auto pool = new ThreadPool(0); // 0 = auto-detect
    scope(exit) pool.shutdown();
    
    // Should successfully create pool with auto-detected worker count
    auto results = pool.map([1, 2, 3], (int x) => x * 2);
    Assert.equal(results, [2, 4, 6]);
    
    writeln("\x1b[32m  ✓ Auto-detect worker count works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Complex struct operations");
    
    struct Point { int x, y; }
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    auto input = [Point(1, 2), Point(3, 4), Point(5, 6)];
    auto results = pool.map(input, (Point p) => p.x + p.y);
    
    Assert.equal(results, [3, 7, 11]);
    
    writeln("\x1b[32m  ✓ Complex struct operations work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Nested data structures");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    auto input = [[1, 2], [3, 4], [5, 6]];
    auto results = pool.map(input, (int[] arr) {
        int sum = 0;
        foreach (val; arr) sum += val;
        return sum;
    });
    
    Assert.equal(results, [3, 7, 11]);
    
    writeln("\x1b[32m  ✓ Nested data structures work correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Order preservation");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    // Even with parallel execution, order should be preserved
    auto input = iota(0, 100).array;
    auto results = pool.map(input, (int x) => x);
    
    Assert.equal(results, input);
    
    writeln("\x1b[32m  ✓ Result order is preserved\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m utils.pool - Heavy computation workload");
    
    auto pool = new ThreadPool(4);
    scope(exit) pool.shutdown();
    
    // Simulate heavy computation
    int heavyCompute(int n)
    {
        int result = 0;
        foreach (i; 0 .. 1000)
            result += i;
        return result + n;
    }
    
    auto input = iota(0, 20).array;
    auto results = pool.map(input, &heavyCompute);
    
    // Verify results
    Assert.equal(results.length, 20);
    foreach (i, val; results)
    {
        Assert.equal(val, heavyCompute(cast(int)i));
    }
    
    writeln("\x1b[32m  ✓ Heavy computation workload is handled correctly\x1b[0m");
}

