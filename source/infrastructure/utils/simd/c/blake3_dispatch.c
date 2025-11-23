/* BLAKE3 SIMD Dispatch
 * Runtime selection of optimal SIMD implementation
 */

#include "blake3_simd.h"
#include "cpu_detect.h"
#include <stdbool.h>

/* Global function pointers (initialized once) */
static blake3_compress_fn g_compress_fn = NULL;
static blake3_hash_many_fn g_hash_many_fn = NULL;
static bool g_initialized = false;

void blake3_simd_init(void) {
    if (g_initialized) return;
    
    simd_level_t level = cpu_get_simd_level();
    
    /* Select optimal SIMD implementation based on CPU capabilities */
    switch (level) {
        case SIMD_LEVEL_AVX512:
            g_compress_fn = blake3_compress_avx512;
            g_hash_many_fn = blake3_hash_many_avx512;
            break;
        case SIMD_LEVEL_AVX2:
            g_compress_fn = blake3_compress_avx2;
            g_hash_many_fn = blake3_hash_many_avx2;
            break;
        case SIMD_LEVEL_SSE41:
            g_compress_fn = blake3_compress_sse41;
            g_hash_many_fn = blake3_hash_many_portable;
            break;
        case SIMD_LEVEL_SSE2:
            g_compress_fn = blake3_compress_sse2;
            g_hash_many_fn = blake3_hash_many_portable;
            break;
        case SIMD_LEVEL_NEON:
            g_compress_fn = blake3_compress_neon;
            g_hash_many_fn = blake3_hash_many_neon;
            break;
        default:
            g_compress_fn = blake3_compress_portable;
            g_hash_many_fn = blake3_hash_many_portable;
            break;
    }
    
    g_initialized = true;
}

blake3_compress_fn blake3_get_compress_fn(void) {
    if (!g_initialized) {
        blake3_simd_init();
    }
    return g_compress_fn;
}

blake3_hash_many_fn blake3_get_hash_many_fn(void) {
    if (!g_initialized) {
        blake3_simd_init();
    }
    return g_hash_many_fn;
}

/* Portable implementation (fallback) */
void blake3_compress_portable(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64])
{
    /* Use existing implementation from blake3.c */
    extern void compress(const uint32_t cv[8], const uint8_t block[64],
                        uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);
    compress(cv, block, block_len, counter, flags, out);
}

void blake3_hash_many_portable(
    const uint8_t* const* inputs,
    size_t num_inputs,
    size_t blocks,
    const uint32_t key[8],
    uint64_t counter,
    bool increment_counter,
    uint8_t flags,
    uint8_t flags_start,
    uint8_t flags_end,
    uint8_t* out)
{
    /* Simple serial implementation */
    for (size_t i = 0; i < num_inputs; i++) {
        const uint8_t* input = inputs[i];
        uint8_t* output = out + (i * 32);
        
        /* Hash this input */
        uint8_t block[64];
        for (size_t b = 0; b < blocks; b++) {
            for (size_t j = 0; j < 64 && (b * 64 + j) < blocks * 64; j++) {
                block[j] = input[b * 64 + j];
            }
            
            uint8_t block_flags = flags;
            if (b == 0) block_flags |= flags_start;
            if (b == blocks - 1) block_flags |= flags_end;
            
            uint64_t ctr = increment_counter ? (counter + b) : counter;
            blake3_compress_portable(key, block, 64, ctr, block_flags, output);
        }
    }
}
