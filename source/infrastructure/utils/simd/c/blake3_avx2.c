/* BLAKE3 AVX2 Implementation
 * Optimized for Intel/AMD processors with AVX2 support (2013+)
 * Processes 8x parallel lanes for maximum throughput
 */

#include "blake3_simd.h"
#include <immintrin.h>
#include <string.h>

#define INLINE static inline __attribute__((always_inline))

/* BLAKE3 constants */
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

/* Rotate right */
INLINE __m256i rotr32_avx2(__m256i x, int n) {
    return _mm256_or_si256(_mm256_srli_epi32(x, n), _mm256_slli_epi32(x, 32 - n));
}

/* G function for AVX2 */
INLINE void g_avx2(__m256i* state, int a, int b, int c, int d, __m256i mx, __m256i my) {
    state[a] = _mm256_add_epi32(state[a], _mm256_add_epi32(state[b], mx));
    state[d] = rotr32_avx2(_mm256_xor_si256(state[d], state[a]), 16);
    state[c] = _mm256_add_epi32(state[c], state[d]);
    state[b] = rotr32_avx2(_mm256_xor_si256(state[b], state[c]), 12);
    state[a] = _mm256_add_epi32(state[a], _mm256_add_epi32(state[b], my));
    state[d] = rotr32_avx2(_mm256_xor_si256(state[d], state[a]), 8);
    state[c] = _mm256_add_epi32(state[c], state[d]);
    state[b] = rotr32_avx2(_mm256_xor_si256(state[b], state[c]), 7);
}

/* Round function */
INLINE void round_avx2(__m256i* state, const __m256i* msg, size_t round) {
    const uint8_t* schedule = MSG_SCHEDULE[round];
    
    /* Column step */
    g_avx2(state, 0, 4, 8, 12, msg[schedule[0]], msg[schedule[1]]);
    g_avx2(state, 1, 5, 9, 13, msg[schedule[2]], msg[schedule[3]]);
    g_avx2(state, 2, 6, 10, 14, msg[schedule[4]], msg[schedule[5]]);
    g_avx2(state, 3, 7, 11, 15, msg[schedule[6]], msg[schedule[7]]);
    
    /* Diagonal step */
    g_avx2(state, 0, 5, 10, 15, msg[schedule[8]], msg[schedule[9]]);
    g_avx2(state, 1, 6, 11, 12, msg[schedule[10]], msg[schedule[11]]);
    g_avx2(state, 2, 7, 8, 13, msg[schedule[12]], msg[schedule[13]]);
    g_avx2(state, 3, 4, 9, 14, msg[schedule[14]], msg[schedule[15]]);
}

/* Compress single block */
void blake3_compress_avx2(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64])
{
    /* Load message words */
    __m256i msg[16];
    for (int i = 0; i < 8; i++) {
        msg[i] = _mm256_set1_epi32(((const uint32_t*)block)[i]);
    }
    for (int i = 8; i < 16; i++) {
        msg[i] = _mm256_set1_epi32(((const uint32_t*)block)[i]);
    }
    
    /* Initialize state */
    __m256i state[16];
    for (int i = 0; i < 8; i++) {
        state[i] = _mm256_set1_epi32(cv[i]);
    }
    for (int i = 0; i < 4; i++) {
        state[8 + i] = _mm256_set1_epi32(IV[i]);
    }
    state[12] = _mm256_set1_epi32((uint32_t)counter);
    state[13] = _mm256_set1_epi32((uint32_t)(counter >> 32));
    state[14] = _mm256_set1_epi32(block_len);
    state[15] = _mm256_set1_epi32(flags);
    
    /* 7 rounds */
    for (int r = 0; r < 7; r++) {
        round_avx2(state, msg, r);
    }
    
    /* Finalize - XOR state halves */
    for (int i = 0; i < 8; i++) {
        __m256i result = _mm256_xor_si256(state[i], state[i + 8]);
        /* Store only first lane (scalar compression) */
        ((uint32_t*)out)[i] = _mm256_extract_epi32(result, 0);
    }
    
    for (int i = 0; i < 8; i++) {
        __m256i result = _mm256_xor_si256(state[i + 8], _mm256_set1_epi32(cv[i]));
        ((uint32_t*)out)[i + 8] = _mm256_extract_epi32(result, 0);
    }
}

/* Hash many blocks in parallel (8-way) */
void blake3_hash_many_avx2(
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
    /* Process 8 inputs at a time */
    for (size_t base = 0; base < num_inputs; base += 8) {
        size_t batch_size = (num_inputs - base < 8) ? (num_inputs - base) : 8;
        
        /* Load initial CVs */
        __m256i cv[8];
        for (int i = 0; i < 8; i++) {
            cv[i] = _mm256_set1_epi32(key[i]);
        }
        
        /* Process blocks */
        for (size_t b = 0; b < blocks; b++) {
            /* Load 8 message blocks in parallel */
            __m256i msg[16];
            for (int w = 0; w < 16; w++) {
                uint32_t words[8] = {0};
                for (size_t lane = 0; lane < batch_size; lane++) {
                    const uint8_t* input = inputs[base + lane] + b * 64;
                    words[lane] = ((const uint32_t*)input)[w];
                }
                msg[w] = _mm256_loadu_si256((__m256i*)words);
            }
            
            /* Initialize state */
            __m256i state[16];
            for (int i = 0; i < 8; i++) {
                state[i] = cv[i];
            }
            for (int i = 0; i < 4; i++) {
                state[8 + i] = _mm256_set1_epi32(IV[i]);
            }
            
            uint64_t ctr = increment_counter ? (counter + b) : counter;
            state[12] = _mm256_set1_epi32((uint32_t)ctr);
            state[13] = _mm256_set1_epi32((uint32_t)(ctr >> 32));
            state[14] = _mm256_set1_epi32(64);
            
            uint8_t block_flags = flags;
            if (b == 0) block_flags |= flags_start;
            if (b == blocks - 1) block_flags |= flags_end;
            state[15] = _mm256_set1_epi32(block_flags);
            
            /* 7 rounds */
            for (int r = 0; r < 7; r++) {
                round_avx2(state, msg, r);
            }
            
            /* Finalize */
            for (int i = 0; i < 8; i++) {
                cv[i] = _mm256_xor_si256(state[i], state[i + 8]);
            }
        }
        
        /* Store results */
        for (size_t lane = 0; lane < batch_size; lane++) {
            uint8_t* output = out + (base + lane) * 32;
            for (int i = 0; i < 8; i++) {
                ((uint32_t*)output)[i] = _mm256_extract_epi32(cv[i], lane);
            }
        }
    }
}

