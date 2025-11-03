/* High-Performance Memory Operations for Serialization
 * SIMD-accelerated unaligned integer loads/stores
 * 
 * These are critical hot paths for zero-copy deserialization
 */

#ifndef BUILDER_MEMOPS_H
#define BUILDER_MEMOPS_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Unaligned loads (zero-copy deserialization) */

/// Load 16-bit unsigned integer (little-endian)
static inline uint16_t load_u16_le(const uint8_t* p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

/// Load 32-bit unsigned integer (little-endian)
static inline uint32_t load_u32_le(const uint8_t* p) {
    return (uint32_t)p[0] 
        | ((uint32_t)p[1] << 8)
        | ((uint32_t)p[2] << 16)
        | ((uint32_t)p[3] << 24);
}

/// Load 64-bit unsigned integer (little-endian)
static inline uint64_t load_u64_le(const uint8_t* p) {
    return (uint64_t)p[0]
        | ((uint64_t)p[1] << 8)
        | ((uint64_t)p[2] << 16)
        | ((uint64_t)p[3] << 24)
        | ((uint64_t)p[4] << 32)
        | ((uint64_t)p[5] << 40)
        | ((uint64_t)p[6] << 48)
        | ((uint64_t)p[7] << 56);
}

/* Unaligned stores */

static inline void store_u16_le(uint8_t* p, uint16_t v) {
    p[0] = (uint8_t)v;
    p[1] = (uint8_t)(v >> 8);
}

static inline void store_u32_le(uint8_t* p, uint32_t v) {
    p[0] = (uint8_t)v;
    p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16);
    p[3] = (uint8_t)(v >> 24);
}

static inline void store_u64_le(uint8_t* p, uint64_t v) {
    p[0] = (uint8_t)v;
    p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16);
    p[3] = (uint8_t)(v >> 24);
    p[4] = (uint8_t)(v >> 32);
    p[5] = (uint8_t)(v >> 40);
    p[6] = (uint8_t)(v >> 48);
    p[7] = (uint8_t)(v >> 56);
}

/* Batch operations (SIMD where possible) */

/// Store array of u32 as little-endian
void store_u32_array_le(uint8_t* dest, const uint32_t* src, size_t count);

/// Load array of u32 from little-endian
void load_u32_array_le(uint32_t* dest, const uint8_t* src, size_t count);

/// Store array of u64 as little-endian
void store_u64_array_le(uint8_t* dest, const uint64_t* src, size_t count);

/// Load array of u64 from little-endian
void load_u64_array_le(uint64_t* dest, const uint8_t* src, size_t count);

#ifdef __cplusplus
}
#endif

#endif /* BUILDER_MEMOPS_H */

