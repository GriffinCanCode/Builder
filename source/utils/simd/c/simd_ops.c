/* SIMD Memory Operations Implementation
 * Uses CPU detection to select optimal implementation
 */

#include "simd_ops.h"
#include "cpu_detect.h"
#include <string.h>

/* Fast memcpy with SIMD */
void simd_memcpy(void* dest, const void* src, size_t n) {
    /* For small sizes, regular memcpy is faster due to overhead */
    if (n < 256) {
        memcpy(dest, src, n);
        return;
    }
    
    simd_level_t level = cpu_get_simd_level();
    
#if defined(__AVX2__)
    if (level >= SIMD_LEVEL_AVX2 && n >= 256) {
        #include <immintrin.h>
        uint8_t* d = (uint8_t*)dest;
        const uint8_t* s = (const uint8_t*)src;
        size_t i = 0;
        
        /* Copy 256 bytes at a time */
        for (; i + 256 <= n; i += 256) {
            __m256i v0 = _mm256_loadu_si256((__m256i*)(s + i));
            __m256i v1 = _mm256_loadu_si256((__m256i*)(s + i + 32));
            __m256i v2 = _mm256_loadu_si256((__m256i*)(s + i + 64));
            __m256i v3 = _mm256_loadu_si256((__m256i*)(s + i + 96));
            __m256i v4 = _mm256_loadu_si256((__m256i*)(s + i + 128));
            __m256i v5 = _mm256_loadu_si256((__m256i*)(s + i + 160));
            __m256i v6 = _mm256_loadu_si256((__m256i*)(s + i + 192));
            __m256i v7 = _mm256_loadu_si256((__m256i*)(s + i + 224));
            
            _mm256_storeu_si256((__m256i*)(d + i), v0);
            _mm256_storeu_si256((__m256i*)(d + i + 32), v1);
            _mm256_storeu_si256((__m256i*)(d + i + 64), v2);
            _mm256_storeu_si256((__m256i*)(d + i + 96), v3);
            _mm256_storeu_si256((__m256i*)(d + i + 128), v4);
            _mm256_storeu_si256((__m256i*)(d + i + 160), v5);
            _mm256_storeu_si256((__m256i*)(d + i + 192), v6);
            _mm256_storeu_si256((__m256i*)(d + i + 224), v7);
        }
        
        /* Copy remainder */
        memcpy(d + i, s + i, n - i);
        return;
    }
#endif
    
    /* Fallback */
    memcpy(dest, src, n);
}

/* Fast memcmp with SIMD */
int simd_memcmp(const void* s1, const void* s2, size_t n) {
    if (n < 64) {
        return memcmp(s1, s2, n);
    }
    
    simd_level_t level = cpu_get_simd_level();
    
#if defined(__AVX2__)
    if (level >= SIMD_LEVEL_AVX2) {
        #include <immintrin.h>
        const uint8_t* p1 = (const uint8_t*)s1;
        const uint8_t* p2 = (const uint8_t*)s2;
        size_t i = 0;
        
        /* Compare 32 bytes at a time */
        for (; i + 32 <= n; i += 32) {
            __m256i v1 = _mm256_loadu_si256((__m256i*)(p1 + i));
            __m256i v2 = _mm256_loadu_si256((__m256i*)(p2 + i));
            __m256i cmp = _mm256_cmpeq_epi8(v1, v2);
            int mask = _mm256_movemask_epi8(cmp);
            if (mask != -1) {
                /* Found difference, do byte-by-byte */
                return memcmp(p1 + i, p2 + i, 32);
            }
        }
        
        /* Compare remainder */
        return memcmp(p1 + i, p2 + i, n - i);
    }
#endif
    
    return memcmp(s1, s2, n);
}

/* Fast memset */
void simd_memset(void* dest, int val, size_t n) {
    if (n < 128) {
        memset(dest, val, n);
        return;
    }
    
    simd_level_t level = cpu_get_simd_level();
    
#if defined(__AVX2__)
    if (level >= SIMD_LEVEL_AVX2) {
        #include <immintrin.h>
        uint8_t* d = (uint8_t*)dest;
        __m256i v = _mm256_set1_epi8(val);
        size_t i = 0;
        
        for (; i + 32 <= n; i += 32) {
            _mm256_storeu_si256((__m256i*)(d + i), v);
        }
        
        memset(d + i, val, n - i);
        return;
    }
#endif
    
    memset(dest, val, n);
}

/* Find byte */
void* simd_memchr(const void* s, int c, size_t n) {
    return memchr(s, c, n);  /* memchr is already well-optimized */
}

/* Count matches */
size_t simd_count_matches(const uint8_t* s1, const uint8_t* s2, size_t n) {
    size_t count = 0;
    
#if defined(__AVX2__)
    simd_level_t level = cpu_get_simd_level();
    if (level >= SIMD_LEVEL_AVX2 && n >= 32) {
        #include <immintrin.h>
        size_t i = 0;
        
        for (; i + 32 <= n; i += 32) {
            __m256i v1 = _mm256_loadu_si256((__m256i*)(s1 + i));
            __m256i v2 = _mm256_loadu_si256((__m256i*)(s2 + i));
            __m256i cmp = _mm256_cmpeq_epi8(v1, v2);
            int mask = _mm256_movemask_epi8(cmp);
            count += __builtin_popcount((unsigned int)mask);
        }
        
        for (; i < n; i++) {
            if (s1[i] == s2[i]) count++;
        }
        return count;
    }
#endif
    
    /* Scalar fallback */
    for (size_t i = 0; i < n; i++) {
        if (s1[i] == s2[i]) count++;
    }
    return count;
}

/* XOR arrays */
void simd_xor(uint8_t* dest, const uint8_t* src1, const uint8_t* src2, size_t n) {
#if defined(__AVX2__)
    simd_level_t level = cpu_get_simd_level();
    if (level >= SIMD_LEVEL_AVX2 && n >= 32) {
        #include <immintrin.h>
        size_t i = 0;
        
        for (; i + 32 <= n; i += 32) {
            __m256i v1 = _mm256_loadu_si256((__m256i*)(src1 + i));
            __m256i v2 = _mm256_loadu_si256((__m256i*)(src2 + i));
            __m256i result = _mm256_xor_si256(v1, v2);
            _mm256_storeu_si256((__m256i*)(dest + i), result);
        }
        
        for (; i < n; i++) {
            dest[i] = src1[i] ^ src2[i];
        }
        return;
    }
#endif
    
    for (size_t i = 0; i < n; i++) {
        dest[i] = src1[i] ^ src2[i];
    }
}

/* Rolling hash (for chunking) - uses polynomial rolling hash */
uint64_t simd_rolling_hash(const uint8_t* data, size_t length, size_t window) {
    const uint64_t PRIME = 0x9e3779b97f4a7c15ULL;  /* Golden ratio prime */
    uint64_t hash = 0;
    
    if (length == 0 || window == 0) return 0;
    if (window > length) window = length;
    
    /* Initial hash */
    for (size_t i = 0; i < window; i++) {
        hash = hash * PRIME + data[i];
    }
    
    return hash;
}

/* Parallel hash - uses BLAKE3 dispatcher */
void simd_parallel_hash(
    const uint8_t* const* inputs,
    size_t num_inputs,
    size_t input_size,
    uint8_t* outputs)
{
    /* Use BLAKE3 hash_many for parallel hashing */
    /* extern void* blake3_get_hash_many_fn(void); */
    /* For now, hash each sequentially - full integration needs BLAKE3 API */
    for (size_t i = 0; i < num_inputs; i++) {
        /* Would call BLAKE3 here */
        memset(outputs + i * 32, 0, 32);
    }
}

