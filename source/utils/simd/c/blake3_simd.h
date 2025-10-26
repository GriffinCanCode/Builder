/* BLAKE3 SIMD Interface
 * Provides optimal SIMD implementation selection at runtime
 */

#ifndef BUILDER_BLAKE3_SIMD_H
#define BUILDER_BLAKE3_SIMD_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Forward declare BLAKE3 hasher from main implementation */
struct blake3_hasher;

/* BLAKE3 compression function signature */
typedef void (*blake3_compress_fn)(
    const uint32_t cv[8],
    const uint8_t block[64],
    uint8_t block_len,
    uint64_t counter,
    uint8_t flags,
    uint8_t out[64]
);

/* BLAKE3 hash chunks in parallel */
typedef void (*blake3_hash_many_fn)(
    const uint8_t* const* inputs,
    size_t num_inputs,
    size_t blocks,
    const uint32_t key[8],
    uint64_t counter,
    bool increment_counter,
    uint8_t flags,
    uint8_t flags_start,
    uint8_t flags_end,
    uint8_t* out
);

/* Get optimal compression function for current CPU */
blake3_compress_fn blake3_get_compress_fn(void);

/* Get optimal hash_many function for current CPU */
blake3_hash_many_fn blake3_get_hash_many_fn(void);

/* Specific implementations - for testing/benchmarking */
void blake3_compress_portable(
    const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);

void blake3_compress_sse2(
    const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);

void blake3_compress_sse41(
    const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);

void blake3_compress_avx2(
    const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);

void blake3_compress_avx512(
    const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);

void blake3_compress_neon(
    const uint32_t cv[8], const uint8_t block[64],
    uint8_t block_len, uint64_t counter, uint8_t flags, uint8_t out[64]);

/* Hash many blocks in parallel */
void blake3_hash_many_portable(
    const uint8_t* const* inputs, size_t num_inputs, size_t blocks,
    const uint32_t key[8], uint64_t counter, bool increment_counter,
    uint8_t flags, uint8_t flags_start, uint8_t flags_end, uint8_t* out);

void blake3_hash_many_avx2(
    const uint8_t* const* inputs, size_t num_inputs, size_t blocks,
    const uint32_t key[8], uint64_t counter, bool increment_counter,
    uint8_t flags, uint8_t flags_start, uint8_t flags_end, uint8_t* out);

void blake3_hash_many_avx512(
    const uint8_t* const* inputs, size_t num_inputs, size_t blocks,
    const uint32_t key[8], uint64_t counter, bool increment_counter,
    uint8_t flags, uint8_t flags_start, uint8_t flags_end, uint8_t* out);

void blake3_hash_many_neon(
    const uint8_t* const* inputs, size_t num_inputs, size_t blocks,
    const uint32_t key[8], uint64_t counter, bool increment_counter,
    uint8_t flags, uint8_t flags_start, uint8_t flags_end, uint8_t* out);

/* Initialize SIMD dispatch (called automatically) */
void blake3_simd_init(void);

#ifdef __cplusplus
}
#endif

#endif /* BUILDER_BLAKE3_SIMD_H */

