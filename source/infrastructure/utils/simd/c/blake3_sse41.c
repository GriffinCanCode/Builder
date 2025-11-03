/* BLAKE3 SSE4.1 Implementation
 * Optimized for processors with SSE4.1 support (2007+)
 */

#include "blake3_simd.h"
#include <smmintrin.h>

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

INLINE __m128i rotr32_sse(__m128i x, int n) {
    return _mm_or_si128(_mm_srli_epi32(x, n), _mm_slli_epi32(x, 32 - n));
}

INLINE void g_sse(__m128i* state, int a, int b, int c, int d, __m128i mx, __m128i my) {
    state[a] = _mm_add_epi32(state[a], _mm_add_epi32(state[b], mx));
    state[d] = rotr32_sse(_mm_xor_si128(state[d], state[a]), 16);
    state[c] = _mm_add_epi32(state[c], state[d]);
    state[b] = rotr32_sse(_mm_xor_si128(state[b], state[c]), 12);
    state[a] = _mm_add_epi32(state[a], _mm_add_epi32(state[b], my));
    state[d] = rotr32_sse(_mm_xor_si128(state[d], state[a]), 8);
    state[c] = _mm_add_epi32(state[c], state[d]);
    state[b] = rotr32_sse(_mm_xor_si128(state[b], state[c]), 7);
}

INLINE void round_sse(__m128i* state, const __m128i* msg, size_t round) {
    const uint8_t* s = MSG_SCHEDULE[round];
    g_sse(state, 0, 4, 8, 12, msg[s[0]], msg[s[1]]);
    g_sse(state, 1, 5, 9, 13, msg[s[2]], msg[s[3]]);
    g_sse(state, 2, 6, 10, 14, msg[s[4]], msg[s[5]]);
    g_sse(state, 3, 7, 11, 15, msg[s[6]], msg[s[7]]);
    g_sse(state, 0, 5, 10, 15, msg[s[8]], msg[s[9]]);
    g_sse(state, 1, 6, 11, 12, msg[s[10]], msg[s[11]]);
    g_sse(state, 2, 7, 8, 13, msg[s[12]], msg[s[13]]);
    g_sse(state, 3, 4, 9, 14, msg[s[14]], msg[s[15]]);
}

void blake3_compress_sse41(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64])
{
    __m128i msg[16];
    for (int i = 0; i < 16; i++) {
        msg[i] = _mm_set1_epi32(((const uint32_t*)block)[i]);
    }
    
    __m128i state[16];
    for (int i = 0; i < 8; i++) state[i] = _mm_set1_epi32(cv[i]);
    for (int i = 0; i < 4; i++) state[8 + i] = _mm_set1_epi32(IV[i]);
    state[12] = _mm_set1_epi32((uint32_t)counter);
    state[13] = _mm_set1_epi32((uint32_t)(counter >> 32));
    state[14] = _mm_set1_epi32(block_len);
    state[15] = _mm_set1_epi32(flags);
    
    for (int r = 0; r < 7; r++) round_sse(state, msg, r);
    
    for (int i = 0; i < 8; i++) {
        __m128i result = _mm_xor_si128(state[i], state[i + 8]);
        ((uint32_t*)out)[i] = _mm_extract_epi32(result, 0);
    }
    for (int i = 0; i < 8; i++) {
        __m128i result = _mm_xor_si128(state[i + 8], _mm_set1_epi32(cv[i]));
        ((uint32_t*)out)[i + 8] = _mm_extract_epi32(result, 0);
    }
}

