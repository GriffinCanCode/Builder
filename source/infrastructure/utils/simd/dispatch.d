module infrastructure.utils.simd.dispatch;

/// BLAKE3 SIMD Dispatch
/// Runtime selection of optimal SIMD implementation

import infrastructure.utils.crypto.blake3_bindings;

extern(C):

/// BLAKE3 compression function signature
alias blake3_compress_fn = void function(
    const uint[8] cv,
    const ubyte[64] block,
    ubyte blockLen,
    ulong counter,
    ubyte flags,
    ubyte[64] out_
);

/// BLAKE3 hash many function signature
alias blake3_hash_many_fn = void function(
    const ubyte** inputs,
    size_t numInputs,
    size_t blocks,
    const uint[8] key,
    ulong counter,
    bool incrementCounter,
    ubyte flags,
    ubyte flagsStart,
    ubyte flagsEnd,
    ubyte* out_
);

/// Get optimal compression function for current CPU
blake3_compress_fn blake3_get_compress_fn();

/// Get optimal hash_many function for current CPU
blake3_hash_many_fn blake3_get_hash_many_fn();

/// Specific implementations (for benchmarking)
void blake3_compress_portable(
    const uint[8] cv, const ubyte[64] block,
    ubyte blockLen, ulong counter, ubyte flags, ubyte[64] out_);

void blake3_compress_sse2(
    const uint[8] cv, const ubyte[64] block,
    ubyte blockLen, ulong counter, ubyte flags, ubyte[64] out_);

void blake3_compress_sse41(
    const uint[8] cv, const ubyte[64] block,
    ubyte blockLen, ulong counter, ubyte flags, ubyte[64] out_);

void blake3_compress_avx2(
    const uint[8] cv, const ubyte[64] block,
    ubyte blockLen, ulong counter, ubyte flags, ubyte[64] out_);

void blake3_compress_avx512(
    const uint[8] cv, const ubyte[64] block,
    ubyte blockLen, ulong counter, ubyte flags, ubyte[64] out_);

void blake3_compress_neon(
    const uint[8] cv, const ubyte[64] block,
    ubyte blockLen, ulong counter, ubyte flags, ubyte[64] out_);

/// Hash many blocks in parallel
void blake3_hash_many_portable(
    const ubyte** inputs, size_t numInputs, size_t blocks,
    const uint[8] key, ulong counter, bool incrementCounter,
    ubyte flags, ubyte flagsStart, ubyte flagsEnd, ubyte* out_);

void blake3_hash_many_avx2(
    const ubyte** inputs, size_t numInputs, size_t blocks,
    const uint[8] key, ulong counter, bool incrementCounter,
    ubyte flags, ubyte flagsStart, ubyte flagsEnd, ubyte* out_);

void blake3_hash_many_avx512(
    const ubyte** inputs, size_t numInputs, size_t blocks,
    const uint[8] key, ulong counter, bool incrementCounter,
    ubyte flags, ubyte flagsStart, ubyte flagsEnd, ubyte* out_);

void blake3_hash_many_neon(
    const ubyte** inputs, size_t numInputs, size_t blocks,
    const uint[8] key, ulong counter, bool incrementCounter,
    ubyte flags, ubyte flagsStart, ubyte flagsEnd, ubyte* out_);

/// Initialize SIMD dispatch (called automatically)
void blake3_simd_init();

/// D-friendly wrapper for SIMD dispatch with automatic lazy initialization
struct SIMDDispatch
{
    private __gshared bool _initialized = false;
    
    /// Ensure SIMD is initialized (thread-safe, idempotent)
    /// 
    /// Safety: This function is @system because:
    /// 1. Uses synchronized block for thread-safe initialization
    /// 2. Double-checked locking pattern prevents race conditions
    /// 3. blake3_simd_init() is idempotent (safe to call multiple times)
    /// 4. _initialized flag prevents redundant initialization
    /// 
    /// Invariants:
    /// - After first call, SIMD dispatch is fully initialized
    /// - Concurrent calls are serialized by synchronized block
    /// 
    /// What could go wrong:
    /// - Nothing: C code has its own initialization guard
    private static void ensureInitialized() @system
    {
        // Fast path: already initialized (no lock needed)
        if (_initialized)
            return;
        
        // Slow path: need to initialize (with lock)
        synchronized
        {
            // Double-check after acquiring lock
            if (!_initialized)
            {
                blake3_simd_init();
                _initialized = true;
            }
        }
    }
    
    /// Initialize dispatch system (now optional - auto-initializes on first use)
    /// Can still be called explicitly for control over initialization timing
    static void initialize() @system
    {
        ensureInitialized();
    }
    
    /// Get compression function (auto-initializes if needed)
    static blake3_compress_fn getCompressFn() @system
    {
        ensureInitialized();
        return blake3_get_compress_fn();
    }
    
    /// Get hash-many function (auto-initializes if needed)
    static blake3_hash_many_fn getHashManyFn() @system
    {
        ensureInitialized();
        return blake3_get_hash_many_fn();
    }
    
    /// Get active compression implementation name
    static string compressionImpl()
    {
        import infrastructure.utils.simd.detection;
        
        final switch (CPU.simdLevel()) {
            case SIMDLevel.AVX512: return "AVX-512";
            case SIMDLevel.AVX2:   return "AVX2";
            case SIMDLevel.SSE41:  return "SSE4.1";
            case SIMDLevel.SSE2:   return "SSE2";
            case SIMDLevel.NEON:   return "NEON";
            case SIMDLevel.None:   return "Portable";
        }
    }
    
    /// Check if SIMD is active
    static bool isActive()
    {
        import infrastructure.utils.simd.detection;
        return CPU.simdLevel() != SIMDLevel.None;
    }
    
    /// Check if SIMD has been initialized
    static bool isInitialized() @system nothrow @nogc
    {
        return _initialized;
    }
}

