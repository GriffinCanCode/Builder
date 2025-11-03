/* High-Performance Varint Encoding/Decoding with SIMD
 * LEB128-compatible variable-length integer encoding
 * 
 * Performance optimizations:
 * - SIMD batch encoding/decoding (4-8 integers at once)
 * - Unaligned loads/stores
 * - Branchless decoding where possible
 * - Cache-line friendly operations
 */

#ifndef BUILDER_VARINT_H
#define BUILDER_VARINT_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Single varint operations */

/// Encode 32-bit unsigned integer to varint
/// Returns number of bytes written (1-5)
size_t varint_encode_u32(uint32_t value, uint8_t* dest);

/// Encode 64-bit unsigned integer to varint
/// Returns number of bytes written (1-10)
size_t varint_encode_u64(uint64_t value, uint8_t* dest);

/// Decode varint to 32-bit unsigned integer
/// Returns number of bytes read (0 on error)
/// On success, writes decoded value to *value
size_t varint_decode_u32(const uint8_t* src, size_t max_len, uint32_t* value);

/// Decode varint to 64-bit unsigned integer
/// Returns number of bytes read (0 on error)
size_t varint_decode_u64(const uint8_t* src, size_t max_len, uint64_t* value);

/// Encode signed integer (zigzag encoding)
size_t varint_encode_i32(int32_t value, uint8_t* dest);
size_t varint_encode_i64(int64_t value, uint8_t* dest);

/// Decode signed integer (zigzag decoding)
size_t varint_decode_i32(const uint8_t* src, size_t max_len, int32_t* value);
size_t varint_decode_i64(const uint8_t* src, size_t max_len, int64_t* value);

/* Batch SIMD operations (4-8x faster for arrays) */

/// Encode array of u32 to varint stream
/// Returns total bytes written
/// dest must have at least count * 5 bytes available
size_t varint_encode_u32_batch(
    const uint32_t* values,
    size_t count,
    uint8_t* dest,
    size_t* offsets  /* Optional: byte offset for each value */
);

/// Encode array of u64 to varint stream
size_t varint_encode_u64_batch(
    const uint64_t* values,
    size_t count,
    uint8_t* dest,
    size_t* offsets
);

/// Decode varint stream to array of u32
/// Returns number of values decoded (may be < count on error)
size_t varint_decode_u32_batch(
    const uint8_t* src,
    size_t src_len,
    uint32_t* values,
    size_t count
);

/// Decode varint stream to array of u64
size_t varint_decode_u64_batch(
    const uint8_t* src,
    size_t src_len,
    uint64_t* values,
    size_t count
);

/* Utility functions */

/// Calculate encoded size without actually encoding
size_t varint_size_u32(uint32_t value);
size_t varint_size_u64(uint64_t value);

/// Skip over varint in buffer (for faster scanning)
/// Returns number of bytes to skip (0 on error)
size_t varint_skip(const uint8_t* src, size_t max_len);

/* Zigzag encoding helpers (for signed integers) */
static inline uint32_t zigzag_encode_i32(int32_t n) {
    return (uint32_t)((n << 1) ^ (n >> 31));
}

static inline int32_t zigzag_decode_u32(uint32_t n) {
    return (int32_t)((n >> 1) ^ (~(n & 1) + 1));
}

static inline uint64_t zigzag_encode_i64(int64_t n) {
    return (uint64_t)((n << 1) ^ (n >> 63));
}

static inline int64_t zigzag_decode_u64(uint64_t n) {
    return (int64_t)((n >> 1) ^ (~(n & 1) + 1));
}

#ifdef __cplusplus
}
#endif

#endif /* BUILDER_VARINT_H */

