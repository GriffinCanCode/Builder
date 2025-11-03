/* SIMD Memory Operations
 * Hardware-agnostic accelerated memory operations
 */

#ifndef BUILDER_SIMD_OPS_H
#define BUILDER_SIMD_OPS_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Fast memory copy (automatically selects SIMD) */
void simd_memcpy(void* dest, const void* src, size_t n);

/* Fast memory comparison (returns 0 if equal) */
int simd_memcmp(const void* s1, const void* s2, size_t n);

/* Fast memory set */
void simd_memset(void* dest, int val, size_t n);

/* Find byte in memory (returns pointer or NULL) */
void* simd_memchr(const void* s, int c, size_t n);

/* Count matching bytes between two buffers */
size_t simd_count_matches(const uint8_t* s1, const uint8_t* s2, size_t n);

/* XOR two byte arrays */
void simd_xor(uint8_t* dest, const uint8_t* src1, const uint8_t* src2, size_t n);

/* Rolling hash for chunking (Rabin fingerprint) */
uint64_t simd_rolling_hash(const uint8_t* data, size_t length, size_t window);

/* Parallel hash multiple buffers */
void simd_parallel_hash(
    const uint8_t* const* inputs,
    size_t num_inputs,
    size_t input_size,
    uint8_t* outputs  /* num_inputs * 32 bytes */
);

/* Constant-time memory comparison (returns 0 if equal)
 * Prevents timing side-channel attacks by processing all bytes
 * Uses SIMD but never short-circuits on differences */
int simd_constant_time_equals(const void* s1, const void* s2, size_t n);

#ifdef __cplusplus
}
#endif

#endif /* BUILDER_SIMD_OPS_H */

