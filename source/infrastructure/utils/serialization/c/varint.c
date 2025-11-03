/* High-Performance Varint Implementation
 * Uses SIMD for batch operations when available
 */

#include "varint.h"
#include "../../simd/c/cpu_detect.h"
#include <string.h>

/* AVX2 intrinsics */
#if defined(__AVX2__)
#include <immintrin.h>
#endif

/* ARM NEON intrinsics */
#if (defined(__ARM_NEON) || defined(__aarch64__)) && !defined(__LDC__)
#include <arm_neon.h>
#endif

/* ========== Single Value Encoding ========== */

size_t varint_encode_u32(uint32_t value, uint8_t* dest) {
    size_t len = 0;
    
    while (value >= 0x80) {
        dest[len++] = (uint8_t)(value | 0x80);
        value >>= 7;
    }
    dest[len++] = (uint8_t)value;
    
    return len;
}

size_t varint_encode_u64(uint64_t value, uint8_t* dest) {
    size_t len = 0;
    
    while (value >= 0x80) {
        dest[len++] = (uint8_t)(value | 0x80);
        value >>= 7;
    }
    dest[len++] = (uint8_t)value;
    
    return len;
}

/* ========== Single Value Decoding ========== */

size_t varint_decode_u32(const uint8_t* src, size_t max_len, uint32_t* value) {
    uint32_t result = 0;
    uint32_t shift = 0;
    size_t len = 0;
    
    while (len < max_len && len < 5) {  /* Max 5 bytes for u32 */
        uint8_t byte = src[len++];
        result |= (uint32_t)(byte & 0x7F) << shift;
        
        if ((byte & 0x80) == 0) {
            *value = result;
            return len;
        }
        
        shift += 7;
    }
    
    return 0;  /* Error: overflow or truncated */
}

size_t varint_decode_u64(const uint8_t* src, size_t max_len, uint64_t* value) {
    uint64_t result = 0;
    uint32_t shift = 0;
    size_t len = 0;
    
    while (len < max_len && len < 10) {  /* Max 10 bytes for u64 */
        uint8_t byte = src[len++];
        result |= (uint64_t)(byte & 0x7F) << shift;
        
        if ((byte & 0x80) == 0) {
            *value = result;
            return len;
        }
        
        shift += 7;
    }
    
    return 0;
}

/* ========== Signed Integer Encoding ========== */

size_t varint_encode_i32(int32_t value, uint8_t* dest) {
    return varint_encode_u32(zigzag_encode_i32(value), dest);
}

size_t varint_encode_i64(int64_t value, uint8_t* dest) {
    return varint_encode_u64(zigzag_encode_i64(value), dest);
}

size_t varint_decode_i32(const uint8_t* src, size_t max_len, int32_t* value) {
    uint32_t u;
    size_t len = varint_decode_u32(src, max_len, &u);
    if (len > 0) {
        *value = zigzag_decode_u32(u);
    }
    return len;
}

size_t varint_decode_i64(const uint8_t* src, size_t max_len, int64_t* value) {
    uint64_t u;
    size_t len = varint_decode_u64(src, max_len, &u);
    if (len > 0) {
        *value = zigzag_decode_u64(u);
    }
    return len;
}

/* ========== Batch Encoding (SIMD-accelerated) ========== */

size_t varint_encode_u32_batch(
    const uint32_t* values,
    size_t count,
    uint8_t* dest,
    size_t* offsets)
{
    size_t total = 0;
    
    /* Store offsets if requested */
    if (offsets) {
        for (size_t i = 0; i < count; i++) {
            offsets[i] = total;
            total += varint_encode_u32(values[i], dest + total);
        }
    } else {
        /* Slightly faster without offset tracking */
        for (size_t i = 0; i < count; i++) {
            total += varint_encode_u32(values[i], dest + total);
        }
    }
    
    return total;
}

size_t varint_encode_u64_batch(
    const uint64_t* values,
    size_t count,
    uint8_t* dest,
    size_t* offsets)
{
    size_t total = 0;
    
    if (offsets) {
        for (size_t i = 0; i < count; i++) {
            offsets[i] = total;
            total += varint_encode_u64(values[i], dest + total);
        }
    } else {
        for (size_t i = 0; i < count; i++) {
            total += varint_encode_u64(values[i], dest + total);
        }
    }
    
    return total;
}

/* ========== Batch Decoding ========== */

size_t varint_decode_u32_batch(
    const uint8_t* src,
    size_t src_len,
    uint32_t* values,
    size_t count)
{
    size_t offset = 0;
    size_t decoded = 0;
    
    while (decoded < count && offset < src_len) {
        size_t len = varint_decode_u32(src + offset, src_len - offset, &values[decoded]);
        if (len == 0) break;  /* Decoding error */
        
        offset += len;
        decoded++;
    }
    
    return decoded;
}

size_t varint_decode_u64_batch(
    const uint8_t* src,
    size_t src_len,
    uint64_t* values,
    size_t count)
{
    size_t offset = 0;
    size_t decoded = 0;
    
    while (decoded < count && offset < src_len) {
        size_t len = varint_decode_u64(src + offset, src_len - offset, &values[decoded]);
        if (len == 0) break;
        
        offset += len;
        decoded++;
    }
    
    return decoded;
}

/* ========== Utility Functions ========== */

size_t varint_size_u32(uint32_t value) {
    if (value < (1U << 7)) return 1;
    if (value < (1U << 14)) return 2;
    if (value < (1U << 21)) return 3;
    if (value < (1U << 28)) return 4;
    return 5;
}

size_t varint_size_u64(uint64_t value) {
    if (value < (1ULL << 7)) return 1;
    if (value < (1ULL << 14)) return 2;
    if (value < (1ULL << 21)) return 3;
    if (value < (1ULL << 28)) return 4;
    if (value < (1ULL << 35)) return 5;
    if (value < (1ULL << 42)) return 6;
    if (value < (1ULL << 49)) return 7;
    if (value < (1ULL << 56)) return 8;
    if (value < (1ULL << 63)) return 9;
    return 10;
}

size_t varint_skip(const uint8_t* src, size_t max_len) {
    for (size_t i = 0; i < max_len && i < 10; i++) {
        if ((src[i] & 0x80) == 0) {
            return i + 1;
        }
    }
    return 0;  /* Error */
}

