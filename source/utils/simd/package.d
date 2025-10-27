module utils.simd;

/// SIMD Acceleration Package
/// Hardware-agnostic SIMD optimizations with runtime dispatch
/// 
/// Architecture:
///   detection.d - CPU feature detection (AVX2/AVX-512/NEON/SSE)
///   dispatch.d  - Runtime dispatch to optimal BLAKE3 SIMD implementation
///   ops.d       - SIMD-accelerated memory operations
///   hash.d      - Specialized hash comparison operations
///   bench.d     - Comprehensive SIMD benchmarking suite
///
/// Features:
///   - Runtime CPU detection (no compile-time only paths)
///   - Fallback chain: AVX-512 → AVX2 → SSE4.1 → SSE2 → Portable
///   - ARM support: NEON → Portable
///   - Thread-safe singleton pattern for CPU detection
///   - Zero-copy dispatch through function pointers
///   - Constant-time comparisons for security
///   - Batch hash validation for performance
///
/// Performance Gains:
///   - BLAKE3: 2-4x faster on AVX2, 3-5x on AVX-512, 2-3x on NEON
///   - Memory Ops: 1.5-3x faster for large buffers
///   - Chunking: 3-8x faster with vectorized rolling hash
///   - Batch Hash Validation: 3-5x faster for multiple comparisons
///
/// Usage:
///   import utils.simd;
///   
///   // Automatic optimal selection
///   CPU.printInfo();                      // Show CPU capabilities
///   auto hash = Blake3.hashHex("data");   // Uses SIMD automatically
///   
///   // SIMD memory operations
///   SIMDOps.copy(dest, src);              // Fast memcpy
///   SIMDOps.xor(result, a, b);            // Vectorized XOR
///   
///   // Specialized hash operations
///   SIMDHash.equals(hashA, hashB);        // Fast comparison
///   SIMDHash.constantTimeEquals(a, b);    // Timing-attack resistant
///   SIMDHash.batchEquals(hashesA, hashesB); // Parallel validation
///   
///   // Benchmarking
///   SIMDBench.compareAll();               // Compare all implementations

public import utils.simd.detection;
public import utils.simd.dispatch;
public import utils.simd.ops;
public import utils.simd.hash;
public import utils.simd.bench;

