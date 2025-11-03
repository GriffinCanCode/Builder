/* BLAKE3 AVX-512 Implementation
 * Optimized for Intel/AMD processors with AVX-512 (2017+)
 * Processes 16x parallel lanes for maximum throughput
 */

#include "blake3_simd.h"

#if defined(__AVX512F__) && defined(__AVX512VL__)
#include <immintrin.h>

#define INLINE static inline __attribute__((always_inline))

static const uint32_t IV[8] = {
    0x6A09E667UL, 0xBB67AE85UL, 0x3C6EF372UL, 0xA54FF53AUL,
    0x510E527FUL, 0x9B05688CUL, 0x1F83D9ABUL, 0x5BE0CD19UL
};

static const uint8_t MSG_SCHEDULE[7][16] = {
    {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
    {2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8},
    {3, 4, 10, 12, 13, 2, 7, 14, 6, 5, 9, 0, 11, 15, 8, 1},
    {10, 7, 12, 9, 14, 3, 13, 15, 4, 0, 11, 2, 5, 8, 1, 6},
    {12, 13, 9, 11, 15, 10, 14, 8, 7, 2, 5, 3, 0, 1, 6, 4},
    {9, 14, 11, 5, 8, 12, 15, 1, 13, 3, 0, 10, 2, 6, 4, 7},
    {11, 15, 5, 0, 1, 9, 8, 6, 14, 10, 2, 12, 3, 4, 7, 13},
};

INLINE __m512i rotr32_avx512(__m512i x, int n) {
    return _mm512_or_si512(_mm512_srli_epi32(x, n), _mm512_slli_epi32(x, 32 - n));
}

INLINE void g_avx512(__m512i* state, int a, int b, int c, int d, __m512i mx, __m512i my) {
    state[a] = _mm512_add_epi32(state[a], _mm512_add_epi32(state[b], mx));
    state[d] = rotr32_avx512(_mm512_xor_si512(state[d], state[a]), 16);
    state[c] = _mm512_add_epi32(state[c], state[d]);
    state[b] = rotr32_avx512(_mm512_xor_si512(state[b], state[c]), 12);
    state[a] = _mm512_add_epi32(state[a], _mm512_add_epi32(state[b], my));
    state[d] = rotr32_avx512(_mm512_xor_si512(state[d], state[a]), 8);
    state[c] = _mm512_add_epi32(state[c], state[d]);
    state[b] = rotr32_avx512(_mm512_xor_si512(state[b], state[c]), 7);
}

INLINE void round_avx512(__m512i* state, const __m512i* msg, size_t round) {
    const uint8_t* s = MSG_SCHEDULE[round];
    g_avx512(state, 0, 4, 8, 12, msg[s[0]], msg[s[1]]);
    g_avx512(state, 1, 5, 9, 13, msg[s[2]], msg[s[3]]);
    g_avx512(state, 2, 6, 10, 14, msg[s[4]], msg[s[5]]);
    g_avx512(state, 3, 7, 11, 15, msg[s[6]], msg[s[7]]);
    g_avx512(state, 0, 5, 10, 15, msg[s[8]], msg[s[9]]);
    g_avx512(state, 1, 6, 11, 12, msg[s[10]], msg[s[11]]);
    g_avx512(state, 2, 7, 8, 13, msg[s[12]], msg[s[13]]);
    g_avx512(state, 3, 4, 9, 14, msg[s[14]], msg[s[15]]);
}

void blake3_compress_avx512(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64])
{
    __m512i msg[16];
    for (int i = 0; i < 16; i++) {
        msg[i] = _mm512_set1_epi32(((const uint32_t*)block)[i]);
    }
    
    __m512i state[16];
    for (int i = 0; i < 8; i++) state[i] = _mm512_set1_epi32(cv[i]);
    for (int i = 0; i < 4; i++) state[8 + i] = _mm512_set1_epi32(IV[i]);
    state[12] = _mm512_set1_epi32((uint32_t)counter);
    state[13] = _mm512_set1_epi32((uint32_t)(counter >> 32));
    state[14] = _mm512_set1_epi32(block_len);
    state[15] = _mm512_set1_epi32(flags);
    
    for (int r = 0; r < 7; r++) round_avx512(state, msg, r);
    
    for (int i = 0; i < 8; i++) {
        __m512i result = _mm512_xor_si512(state[i], state[i + 8]);
        ((uint32_t*)out)[i] = _mm512_cvtsi512_si32(result);
    }
    for (int i = 0; i < 8; i++) {
        __m512i result = _mm512_xor_si512(state[i + 8], _mm512_set1_epi32(cv[i]));
        ((uint32_t*)out)[i + 8] = _mm512_cvtsi512_si32(result);
    }
}

void blake3_hash_many_avx512(
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
    /* Process 16 inputs at a time */
    for (size_t base = 0; base < num_inputs; base += 16) {
        size_t batch_size = (num_inputs - base < 16) ? (num_inputs - base) : 16;
        
        __m512i cv[8];
        for (int i = 0; i < 8; i++) {
            cv[i] = _mm512_set1_epi32(key[i]);
        }
        
        for (size_t b = 0; b < blocks; b++) {
            __m512i msg[16];
            for (int w = 0; w < 16; w++) {
                uint32_t words[16] = {0};
                for (size_t lane = 0; lane < batch_size; lane++) {
                    words[lane] = ((const uint32_t*)(inputs[base + lane] + b * 64))[w];
                }
                msg[w] = _mm512_loadu_si512((__m512i*)words);
            }
            
            __m512i state[16];
            for (int i = 0; i < 8; i++) state[i] = cv[i];
            for (int i = 0; i < 4; i++) state[8 + i] = _mm512_set1_epi32(IV[i]);
            
            uint64_t ctr = increment_counter ? (counter + b) : counter;
            state[12] = _mm512_set1_epi32((uint32_t)ctr);
            state[13] = _mm512_set1_epi32((uint32_t)(ctr >> 32));
            state[14] = _mm512_set1_epi32(64);
            
            uint8_t block_flags = flags;
            if (b == 0) block_flags |= flags_start;
            if (b == blocks - 1) block_flags |= flags_end;
            state[15] = _mm512_set1_epi32(block_flags);
            
            for (int r = 0; r < 7; r++) round_avx512(state, msg, r);
            
            for (int i = 0; i < 8; i++) {
                cv[i] = _mm512_xor_si512(state[i], state[i + 8]);
            }
        }
        
        for (size_t lane = 0; lane < batch_size; lane++) {
            uint8_t* output = out + (base + lane) * 32;
            for (int i = 0; i < 8; i++) {
                __m512i temp = cv[i];
                uint32_t value;
                memcpy(&value, ((uint32_t*)&temp) + lane, 4);
                ((uint32_t*)output)[i] = value;
            }
        }
    }
}

#else

/* Fallback when AVX-512 not available */
void blake3_compress_avx512(const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64])
{
    blake3_compress_avx2(cv, block, block_len, counter, flags, out);
}

void blake3_hash_many_avx512(const uint8_t* const* inputs, size_t num_inputs,
    size_t blocks, const uint32_t key[8], uint64_t counter, bool increment_counter,
    uint8_t flags, uint8_t flags_start, uint8_t flags_end, uint8_t* out)
{
    blake3_hash_many_avx2(inputs, num_inputs, blocks, key, counter,
                          increment_counter, flags, flags_start, flags_end, out);
}

#endif

