module utils.concurrency.simd;

import std.range;
import std.algorithm;
import std.parallelism;
import std.array;
import utils.simd.ops;
import utils.concurrency.pool;

/// SIMD-aware parallel operations
/// Combines task parallelism with data parallelism for maximum throughput
struct SIMDParallel
{
    /// Parallel map with SIMD acceleration for data operations
    /// Use when func performs SIMD-friendly operations (memcpy, hash, compare)
    static R[] mapSIMD(T, R)(T[] items, R delegate(T) func, size_t maxParallelism = 0)
    {
        import std.parallelism : totalCPUs;
        
        if (items.empty)
            return [];
        
        if (items.length == 1)
            return [func(items[0])];
        
        auto workerCount = maxParallelism == 0 ? totalCPUs : maxParallelism;
        auto pool = new ThreadPool(workerCount);
        scope(exit) pool.finish();
        
        return pool.map(items, func);
    }
    
    /// Parallel reduce with SIMD operations
    /// Useful for aggregating hash results, comparing arrays, etc.
    static R reduceSIMD(T, R)(T[] items, R delegate(R, T) reducer, R initial)
    {
        if (items.empty)
            return initial;
        
        // Use D's parallel reduce (already optimized)
        return items.parallel.reduce!((a, b) => reducer(a, b))(initial);
    }
    
    /// Batch hash multiple byte arrays in parallel using SIMD
    /// This leverages both task parallelism and SIMD acceleration
    static string[] hashBatch(const(ubyte[])[] inputs)
    {
        import utils.crypto.blake3;
        
        return mapSIMD(inputs, (input) {
            return Blake3.hashHex(input);
        });
    }
    
    /// Parallel XOR of multiple byte arrays
    static ubyte[][] xorBatch(const(ubyte[])[] array1, const(ubyte[])[] array2)
    {
        import std.algorithm : min;
        
        if (array1.length != array2.length)
            throw new Exception("Arrays must have same length for batch XOR");
        
        return mapSIMD(
            iota(array1.length).array,
            (i) {
                auto len = min(array1[i].length, array2[i].length);
                auto result = new ubyte[len];
                SIMDOps.xor(result, array1[i][0..len], array2[i][0..len]);
                return result;
            }
        );
    }
    
    /// Parallel comparison of byte arrays
    /// Returns indices where arrays differ
    static size_t[] findDifferences(const(ubyte[])[] baseline, const(ubyte[])[] current)
    {
        import std.algorithm : min;
        
        if (baseline.length != current.length)
            return iota(min(baseline.length, current.length), 
                       max(baseline.length, current.length)).array;
        
        size_t[] differences;
        
        // Check each pair in parallel
        auto results = mapSIMD(
            iota(baseline.length).array,
            (i) {
                return SIMDOps.equals(
                    cast(void[])baseline[i],
                    cast(void[])current[i]
                ) ? -1 : cast(long)i;
            }
        );
        
        // Collect indices that differ
        foreach (idx; results) {
            if (idx >= 0)
                differences ~= cast(size_t)idx;
        }
        
        return differences;
    }
}

// Unit tests
unittest
{
    import std.stdio;
    import std.array;
    
    // Test parallel hash
    ubyte[][4] testData;
    foreach (i; 0 .. 4) {
        testData[i] = new ubyte[1024];
        foreach (j, ref b; testData[i])
            b = cast(ubyte)(i * 256 + j);
    }
    
    auto hashes = SIMDParallel.hashBatch(testData[]);
    assert(hashes.length == 4);
    assert(hashes[0] != hashes[1]);  // Different data = different hashes
    
    // Test parallel XOR
    ubyte[][2] arr1;
    ubyte[][2] arr2;
    foreach (i; 0 .. 2) {
        arr1[i] = new ubyte[128];
        arr2[i] = new ubyte[128];
        arr1[i][] = 0xFF;
        arr2[i][] = 0x0F;
    }
    
    auto xorResults = SIMDParallel.xorBatch(arr1[], arr2[]);
    assert(xorResults.length == 2);
    assert(xorResults[0][0] == 0xF0);  // 0xFF ^ 0x0F
    
    writeln("SIMD parallel operations tests passed!");
}

