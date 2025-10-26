/* CPU Feature Detection Header
 * Hardware-agnostic runtime detection for x86/x64 and ARM architectures
 * Provides thread-safe singleton pattern for optimal dispatch
 */

#ifndef BUILDER_CPU_DETECT_H
#define BUILDER_CPU_DETECT_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* CPU feature flags */
typedef enum {
    CPU_FEATURE_SSE2      = 1 << 0,
    CPU_FEATURE_SSE3      = 1 << 1,
    CPU_FEATURE_SSSE3     = 1 << 2,
    CPU_FEATURE_SSE41     = 1 << 3,
    CPU_FEATURE_SSE42     = 1 << 4,
    CPU_FEATURE_AVX       = 1 << 5,
    CPU_FEATURE_AVX2      = 1 << 6,
    CPU_FEATURE_AVX512F   = 1 << 7,
    CPU_FEATURE_AVX512VL  = 1 << 8,
    CPU_FEATURE_NEON      = 1 << 9,
    CPU_FEATURE_ASIMD     = 1 << 10,
} cpu_feature_t;

/* CPU architecture type */
typedef enum {
    CPU_ARCH_UNKNOWN,
    CPU_ARCH_X86_64,
    CPU_ARCH_X86,
    CPU_ARCH_ARM64,
    CPU_ARCH_ARM32,
} cpu_arch_t;

/* CPU information structure */
typedef struct {
    cpu_arch_t arch;
    uint32_t features;
    char vendor[13];
    char brand[49];
    int cache_line_size;
    int l1_cache_size;
    int l2_cache_size;
    int l3_cache_size;
} cpu_info_t;

/* Get CPU information (cached after first call) */
const cpu_info_t* cpu_get_info(void);

/* Check if specific feature is supported */
bool cpu_has_feature(cpu_feature_t feature);

/* Get optimal SIMD level for current CPU */
typedef enum {
    SIMD_LEVEL_NONE,
    SIMD_LEVEL_SSE2,
    SIMD_LEVEL_SSE41,
    SIMD_LEVEL_AVX2,
    SIMD_LEVEL_AVX512,
    SIMD_LEVEL_NEON,
} simd_level_t;

simd_level_t cpu_get_simd_level(void);

/* Get human-readable SIMD level name */
const char* cpu_simd_level_name(simd_level_t level);

/* Utility: check multiple features at once */
bool cpu_has_all_features(uint32_t feature_mask);

#ifdef __cplusplus
}
#endif

#endif /* BUILDER_CPU_DETECT_H */

