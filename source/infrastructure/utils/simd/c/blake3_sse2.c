/* BLAKE3 SSE2 Implementation
 * Basic SIMD for older x86_64 processors (2001+)
 * SSE2 is baseline for x86_64, so always available
 */

#include "blake3_simd.h"
#include <emmintrin.h>

#define INLINE static inline __attribute__((always_inline))

static const uint32_t IV[8] = {
    0x6A09E667UL, 0xBB67AE85UL, 0x3C6EF372UL, 0xA54FF53AUL,
    0x510E527FUL, 0x9B05688CUL, 0x1F83D9ABUL, 0x5BE0CD19UL
};

INLINE __m128i rotr32_sse2(__m128i x, int n) {
    return _mm_or_si128(_mm_srli_epi32(x, n), _mm_slli_epi32(x, 32 - n));
}

INLINE void g_sse2(__m128i* state, int a, int b, int c, int d, __m128i mx, __m128i my) {
    state[a] = _mm_add_epi32(state[a], _mm_add_epi32(state[b], mx));
    state[d] = rotr32_sse2(_mm_xor_si128(state[d], state[a]), 16);
    state[c] = _mm_add_epi32(state[c], state[d]);
    state[b] = rotr32_sse2(_mm_xor_si128(state[b], state[c]), 12);
    state[a] = _mm_add_epi32(state[a], _mm_add_epi32(state[b], my));
    state[d] = rotr32_sse2(_mm_xor_si128(state[d], state[a]), 8);
    state[c] = _mm_add_epi32(state[c], state[d]);
    state[b] = rotr32_sse2(_mm_xor_si128(state[b], state[c]), 7);
}

void blake3_compress_sse2(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64])
{
    /* SSE2 has limited benefit for single block - use portable */
    extern void compress(const uint32_t cv[8], const uint8_t block[64],
                        uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);
    compress(cv, block, block_len, counter, flags, out);
}

