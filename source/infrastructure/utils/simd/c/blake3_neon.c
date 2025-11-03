/* BLAKE3 NEON Implementation
 * Optimized for ARM processors with NEON (most ARM64, some ARM32)
 */

#include "blake3_simd.h"

/* Don't compile NEON implementation when using D's ImportC */
#if !defined(__LDC__) && (defined(__ARM_NEON) || defined(__aarch64__))
#include <arm_neon.h>

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

/* NEON rotate right - use macros because intrinsics require compile-time constants */
#define rotr32_16(x) vorrq_u32(vshrq_n_u32((x), 16), vshlq_n_u32((x), 16))
#define rotr32_12(x) vorrq_u32(vshrq_n_u32((x), 12), vshlq_n_u32((x), 20))
#define rotr32_8(x)  vorrq_u32(vshrq_n_u32((x), 8), vshlq_n_u32((x), 24))
#define rotr32_7(x)  vorrq_u32(vshrq_n_u32((x), 7), vshlq_n_u32((x), 25))

INLINE void g_neon(uint32x4_t* state, int a, int b, int c, int d, uint32x4_t mx, uint32x4_t my) {
    state[a] = vaddq_u32(state[a], vaddq_u32(state[b], mx));
    state[d] = rotr32_16(veorq_u32(state[d], state[a]));
    state[c] = vaddq_u32(state[c], state[d]);
    state[b] = rotr32_12(veorq_u32(state[b], state[c]));
    state[a] = vaddq_u32(state[a], vaddq_u32(state[b], my));
    state[d] = rotr32_8(veorq_u32(state[d], state[a]));
    state[c] = vaddq_u32(state[c], state[d]);
    state[b] = rotr32_7(veorq_u32(state[b], state[c]));
}

INLINE void round_neon(uint32x4_t* state, const uint32x4_t* msg, size_t round) {
    const uint8_t* s = MSG_SCHEDULE[round];
    g_neon(state, 0, 4, 8, 12, msg[s[0]], msg[s[1]]);
    g_neon(state, 1, 5, 9, 13, msg[s[2]], msg[s[3]]);
    g_neon(state, 2, 6, 10, 14, msg[s[4]], msg[s[5]]);
    g_neon(state, 3, 7, 11, 15, msg[s[6]], msg[s[7]]);
    g_neon(state, 0, 5, 10, 15, msg[s[8]], msg[s[9]]);
    g_neon(state, 1, 6, 11, 12, msg[s[10]], msg[s[11]]);
    g_neon(state, 2, 7, 8, 13, msg[s[12]], msg[s[13]]);
    g_neon(state, 3, 4, 9, 14, msg[s[14]], msg[s[15]]);
}

void blake3_compress_neon(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64])
{
    uint32x4_t msg[16];
    for (int i = 0; i < 16; i++) {
        msg[i] = vdupq_n_u32(((const uint32_t*)block)[i]);
    }
    
    uint32x4_t state[16];
    for (int i = 0; i < 8; i++) state[i] = vdupq_n_u32(cv[i]);
    for (int i = 0; i < 4; i++) state[8 + i] = vdupq_n_u32(IV[i]);
    state[12] = vdupq_n_u32((uint32_t)counter);
    state[13] = vdupq_n_u32((uint32_t)(counter >> 32));
    state[14] = vdupq_n_u32(block_len);
    state[15] = vdupq_n_u32(flags);
    
    for (int r = 0; r < 7; r++) round_neon(state, msg, r);
    
    for (int i = 0; i < 8; i++) {
        uint32x4_t result = veorq_u32(state[i], state[i + 8]);
        ((uint32_t*)out)[i] = vgetq_lane_u32(result, 0);
    }
    for (int i = 0; i < 8; i++) {
        uint32x4_t result = veorq_u32(state[i + 8], vdupq_n_u32(cv[i]));
        ((uint32_t*)out)[i + 8] = vgetq_lane_u32(result, 0);
    }
}

void blake3_hash_many_neon(
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
    /* Process 4 inputs at a time with NEON */
    for (size_t base = 0; base < num_inputs; base += 4) {
        size_t batch_size = (num_inputs - base < 4) ? (num_inputs - base) : 4;
        
        uint32x4_t cv[8];
        for (int i = 0; i < 8; i++) {
            cv[i] = vdupq_n_u32(key[i]);
        }
        
        for (size_t b = 0; b < blocks; b++) {
            uint32x4_t msg[16];
            for (int w = 0; w < 16; w++) {
                uint32_t words[4] = {0};
                for (size_t lane = 0; lane < batch_size; lane++) {
                    words[lane] = ((const uint32_t*)(inputs[base + lane] + b * 64))[w];
                }
                msg[w] = vld1q_u32(words);
            }
            
            uint32x4_t state[16];
            for (int i = 0; i < 8; i++) state[i] = cv[i];
            for (int i = 0; i < 4; i++) state[8 + i] = vdupq_n_u32(IV[i]);
            
            uint64_t ctr = increment_counter ? (counter + b) : counter;
            state[12] = vdupq_n_u32((uint32_t)ctr);
            state[13] = vdupq_n_u32((uint32_t)(ctr >> 32));
            state[14] = vdupq_n_u32(64);
            
            uint8_t block_flags = flags;
            if (b == 0) block_flags |= flags_start;
            if (b == blocks - 1) block_flags |= flags_end;
            state[15] = vdupq_n_u32(block_flags);
            
            for (int r = 0; r < 7; r++) round_neon(state, msg, r);
            
            for (int i = 0; i < 8; i++) {
                cv[i] = veorq_u32(state[i], state[i + 8]);
            }
        }
        
        /* Extract results - store vectors to memory and read back (NEON doesn't support dynamic lane access) */
        uint32_t cv_tmp[8][4];
        for (int i = 0; i < 8; i++) {
            vst1q_u32(cv_tmp[i], cv[i]);
        }
        
        for (size_t lane = 0; lane < batch_size; lane++) {
            uint8_t* output = out + (base + lane) * 32;
            for (int i = 0; i < 8; i++) {
                ((uint32_t*)output)[i] = cv_tmp[i][lane];
            }
        }
    }
}

#else

/* Fallback for non-NEON ARM */
void blake3_compress_neon(const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64])
{
    blake3_compress_portable(cv, block, block_len, counter, flags, out);
}

void blake3_hash_many_neon(const uint8_t* const* inputs, size_t num_inputs,
    size_t blocks, const uint32_t key[8], uint64_t counter, bool increment_counter,
    uint8_t flags, uint8_t flags_start, uint8_t flags_end, uint8_t* out)
{
    blake3_hash_many_portable(inputs, num_inputs, blocks, key, counter,
                             increment_counter, flags, flags_start, flags_end, out);
}

#endif

