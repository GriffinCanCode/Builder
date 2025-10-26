module utils.simd.dispatch;

/// BLAKE3 SIMD Dispatch
/// Runtime selection of optimal SIMD implementation

import utils.crypto.blake3_bindings;

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

/// D-friendly wrapper for SIMD dispatch
struct SIMDDispatch
{
    /// Initialize dispatch system
    static void initialize()
    {
        blake3_simd_init();
    }
    
    /// Get active compression implementation name
    static string compressionImpl()
    {
        import utils.simd.detection;
        
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
        import utils.simd.detection;
        return CPU.simdLevel() != SIMDLevel.None;
    }
}

