module utils.concurrency.simd;

import std.range;
import std.algorithm;
import std.parallelism;
import std.array;
import utils.simd.ops;
import utils.concurrency.pool;
import core.sync.mutex;

@system:

/// Global thread pool for SIMD operations to avoid repeated allocation
/// Lazily initialized on first use, shared across all mapSIMD calls
private __gshared ThreadPool globalSIMDPool;
private __gshared Mutex globalSIMDPoolMutex;

/// Initialize the global SIMD thread pool (thread-safe)
/// 
/// Safety: This function is @trusted because:
/// 1. Uses mutex to ensure thread-safe initialization
/// 2. Only initializes once (double-checked locking pattern)
/// 3. ThreadPool creation is properly synchronized
@trusted
private ThreadPool getSIMDPool(size_t workerCount = 0) nothrow
{
    import std.parallelism : totalCPUs;
    
    try
    {
        // Fast path: pool already exists
        if (globalSIMDPool !is null)
            return globalSIMDPool;
        
        // Slow path: need to initialize
        if (globalSIMDPoolMutex is null)
            globalSIMDPoolMutex = new Mutex();
        
        synchronized (globalSIMDPoolMutex)
        {
            // Double-check after acquiring lock
            if (globalSIMDPool is null)
            {
                auto count = workerCount == 0 ? totalCPUs : workerCount;
                globalSIMDPool = new ThreadPool(count);
            }
        }
        
        return globalSIMDPool;
    }
    catch (Exception e)
    {
        // If initialization fails, return null (caller will handle)
        return null;
    }
}

/// Shutdown the global SIMD thread pool (call before program termination)
/// 
/// Safety: This function is @trusted because:
/// 1. Uses mutex to ensure thread-safe shutdown
/// 2. ThreadPool.shutdown() is idempotent (safe to call multiple times)
/// 3. Prevents dangling threads and segfaults on program exit
@trusted
void shutdownGlobalSIMDPool() nothrow
{
    try
    {
        if (globalSIMDPoolMutex !is null)
        {
            synchronized (globalSIMDPoolMutex)
            {
                if (globalSIMDPool !is null)
                {
                    globalSIMDPool.shutdown();
                    globalSIMDPool = null;
                }
            }
        }
    }
    catch (Exception e)
    {
        // Best effort - ignore errors during shutdown
    }
}

/// Shared static destructor: automatically shutdown global SIMD pool
/// This prevents segfaults during program termination
shared static ~this()
{
    shutdownGlobalSIMDPool();
}

/// SIMD-aware parallel operations
/// Combines task parallelism with data parallelism for maximum throughput
/// 
/// Optimization: Uses shared global thread pool to avoid repeated allocation
struct SIMDParallel
{
    /// Parallel map with SIMD acceleration for data operations
    /// Use when func performs SIMD-friendly operations (memcpy, hash, compare)
    /// 
    /// Optimization: Reuses global thread pool instead of creating new one per call
    @trusted // Thread pool access and parallel execution
    static auto mapSIMD(T, F)(T[] items, F func, size_t maxParallelism = 0)
    {
        import std.parallelism : totalCPUs;
        import std.traits : ReturnType;
        
        alias R = ReturnType!F;
        
        if (items.empty)
            return (R[]).init;
        
        if (items.length == 1)
            return [func(items[0])];
        
        // Use global shared pool to avoid repeated allocation overhead
        auto pool = getSIMDPool(maxParallelism);
        if (pool is null)
        {
            // Fallback: create temporary pool if global init fails
            auto workerCount = maxParallelism == 0 ? totalCPUs : maxParallelism;
            pool = new ThreadPool(workerCount);
            scope(exit) pool.shutdown();
        }
        
        return pool.map(items, func);
    }
    
    /// Parallel reduce with SIMD operations
    /// Useful for aggregating hash results, comparing arrays, etc.
    @trusted // Parallel execution
    static R reduceSIMD(T, R)(T[] items, R delegate(R, T) reducer, R initial)
    {
        if (items.empty)
            return initial;
        
        // Use D's parallel reduce (already optimized)
        return items.parallel.reduce!((a, b) => reducer(a, b))(initial);
    }
    
    /// Batch hash multiple byte arrays in parallel using SIMD
    /// This leverages both task parallelism and SIMD acceleration
    @trusted // Parallel execution and hashing
    static string[] hashBatch(const(ubyte[])[] inputs)
    {
        import utils.crypto.blake3;
        
        // Cast to mutable for mapSIMD - hashing is read-only anyway
        return mapSIMD(cast(ubyte[][])inputs, (ubyte[] input) => Blake3.hashHex(cast(const(ubyte)[])input));
    }
    
    /// Parallel XOR of multiple byte arrays
    @trusted // Parallel execution and SIMD operations
    static ubyte[][] xorBatch(const(ubyte[])[] array1, const(ubyte[])[] array2)
    {
        import std.algorithm : min;
        
        if (array1.length != array2.length)
            throw new Exception("Arrays must have same length for batch XOR");
        
        return mapSIMD(
            iota(array1.length).array,
            (ulong i) {
                auto len = min(array1[i].length, array2[i].length);
                auto result = new ubyte[len];
                SIMDOps.xor(result, array1[i][0..len], array2[i][0..len]);
                return result;
            }
        );
    }
    
    /// Parallel comparison of byte arrays
    /// Returns indices where arrays differ
    @trusted // Parallel execution and SIMD operations
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
            (ulong i) {
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
@trusted unittest
{
    import std.stdio;
    import std.array;
    
    // Test parallel hash
    ubyte[][4] testData;
    foreach (i; 0 .. 4) {
        testData[i] = new ubyte[1024];
        foreach (j, ref b; testData[i])
            b = cast(ubyte)((i * 17 + j) & 0xFF);  // Use different multiplier to avoid overflow issues
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

