module infrastructure.utils.concurrency.simd;

import std.range;
import std.algorithm;
import std.parallelism;
import std.array;
import infrastructure.utils.simd.ops;
import infrastructure.utils.concurrency.pool;
import core.sync.mutex;

/// NOTE: This module is kept only for the unit tests below.
/// Use utils.simd.context.SIMDContext for all SIMD operations with dependency injection.
/// 
/// Modern usage:
///   auto caps = SIMDCapabilities.detect();
///   auto ctx = createSIMDContext(caps);
///   auto results = ctx.mapParallel(data, func);

// Unit tests for backward compatibility verification
@trusted unittest
{
    import std.stdio;
    import std.array;
    import infrastructure.utils.simd.context : createSIMDContext;
    import infrastructure.utils.simd.capabilities : SIMDCapabilities;
    
    // Test with context-based approach
    auto caps = SIMDCapabilities.detect(2);
    auto ctx = createSIMDContext(caps);
    
    // Test parallel hash
    ubyte[][4] testData;
    foreach (i; 0 .. 4) {
        testData[i] = new ubyte[1024];
        foreach (j, ref b; testData[i])
            b = cast(ubyte)((i * 17 + j) & 0xFF);
    }
    
    auto hashes = ctx.hashBatch(testData[]);
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
    
    auto xorResults = ctx.xorBatch(arr1[], arr2[]);
    assert(xorResults.length == 2);
    assert(xorResults[0][0] == 0xF0);  // 0xFF ^ 0x0F
    
    caps.shutdown();
    
    writeln("SIMD context operations tests passed!");
}

