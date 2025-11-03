/* Memory Operations Implementation */

#include "memops.h"
#include "../../simd/c/cpu_detect.h"

#if defined(__AVX2__)
#include <immintrin.h>
#endif

/* ========== Batch Array Operations ========== */

void store_u32_array_le(uint8_t* dest, const uint32_t* src, size_t count) {
    /* For small arrays, use scalar code */
    if (count < 8) {
        for (size_t i = 0; i < count; i++) {
            store_u32_le(dest + i * 4, src[i]);
        }
        return;
    }
    
#if defined(__AVX2__)
    simd_level_t level = cpu_get_simd_level();
    if (level >= SIMD_LEVEL_AVX2) {
        /* AVX2 can process 8 u32 at once (256 bits) */
        size_t i = 0;
        for (; i + 8 <= count; i += 8) {
            __m256i v = _mm256_loadu_si256((__m256i*)(src + i));
            _mm256_storeu_si256((__m256i*)(dest + i * 4), v);
        }
        
        /* Handle remainder */
        for (; i < count; i++) {
            store_u32_le(dest + i * 4, src[i]);
        }
        return;
    }
#endif
    
    /* Scalar fallback */
    for (size_t i = 0; i < count; i++) {
        store_u32_le(dest + i * 4, src[i]);
    }
}

void load_u32_array_le(uint32_t* dest, const uint8_t* src, size_t count) {
    if (count < 8) {
        for (size_t i = 0; i < count; i++) {
            dest[i] = load_u32_le(src + i * 4);
        }
        return;
    }
    
#if defined(__AVX2__)
    simd_level_t level = cpu_get_simd_level();
    if (level >= SIMD_LEVEL_AVX2) {
        size_t i = 0;
        for (; i + 8 <= count; i += 8) {
            __m256i v = _mm256_loadu_si256((__m256i*)(src + i * 4));
            _mm256_storeu_si256((__m256i*)(dest + i), v);
        }
        
        for (; i < count; i++) {
            dest[i] = load_u32_le(src + i * 4);
        }
        return;
    }
#endif
    
    for (size_t i = 0; i < count; i++) {
        dest[i] = load_u32_le(src + i * 4);
    }
}

void store_u64_array_le(uint8_t* dest, const uint64_t* src, size_t count) {
    if (count < 4) {
        for (size_t i = 0; i < count; i++) {
            store_u64_le(dest + i * 8, src[i]);
        }
        return;
    }
    
#if defined(__AVX2__)
    simd_level_t level = cpu_get_simd_level();
    if (level >= SIMD_LEVEL_AVX2) {
        /* AVX2 can process 4 u64 at once (256 bits) */
        size_t i = 0;
        for (; i + 4 <= count; i += 4) {
            __m256i v = _mm256_loadu_si256((__m256i*)(src + i));
            _mm256_storeu_si256((__m256i*)(dest + i * 8), v);
        }
        
        for (; i < count; i++) {
            store_u64_le(dest + i * 8, src[i]);
        }
        return;
    }
#endif
    
    for (size_t i = 0; i < count; i++) {
        store_u64_le(dest + i * 8, src[i]);
    }
}

void load_u64_array_le(uint64_t* dest, const uint8_t* src, size_t count) {
    if (count < 4) {
        for (size_t i = 0; i < count; i++) {
            dest[i] = load_u64_le(src + i * 8);
        }
        return;
    }
    
#if defined(__AVX2__)
    simd_level_t level = cpu_get_simd_level();
    if (level >= SIMD_LEVEL_AVX2) {
        size_t i = 0;
        for (; i + 4 <= count; i += 4) {
            __m256i v = _mm256_loadu_si256((__m256i*)(src + i * 8));
            _mm256_storeu_si256((__m256i*)(dest + i), v);
        }
        
        for (; i < count; i++) {
            dest[i] = load_u64_le(src + i * 8);
        }
        return;
    }
#endif
    
    for (size_t i = 0; i < count; i++) {
        dest[i] = load_u64_le(src + i * 8);
    }
}

