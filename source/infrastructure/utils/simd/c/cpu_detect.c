/* CPU Feature Detection Implementation
 * Thread-safe runtime detection using CPUID (x86) and getauxval (ARM)
 */

#include "cpu_detect.h"
#include <string.h>
#include <stdio.h>

#if defined(__x86_64__) || defined(_M_X64) || defined(__i386__) || defined(_M_IX86)
#define CPU_X86
#include <cpuid.h>
#elif defined(__aarch64__) || defined(_M_ARM64) || defined(__arm__) || defined(_M_ARM)
#define CPU_ARM
#if defined(__linux__)
#include <sys/auxv.h>
#include <asm/hwcap.h>
#elif defined(__APPLE__)
#include <sys/sysctl.h>
#endif
#endif

/* Global CPU info (initialized once) */
static cpu_info_t g_cpu_info = {0};
static bool g_cpu_info_initialized = false;

/* X86/X64 CPUID helper */
#ifdef CPU_X86
static void run_cpuid(uint32_t eax, uint32_t ecx, uint32_t* regs) {
    __cpuid_count(eax, ecx, regs[0], regs[1], regs[2], regs[3]);
}

static void detect_x86_features(cpu_info_t* info) {
    uint32_t regs[4];
    
    /* Get vendor string */
    run_cpuid(0, 0, regs);
    memcpy(info->vendor, &regs[1], 4);
    memcpy(info->vendor + 4, &regs[3], 4);
    memcpy(info->vendor + 8, &regs[2], 4);
    info->vendor[12] = '\0';
    
    /* Feature detection */
    run_cpuid(1, 0, regs);
    
    if (regs[3] & (1 << 26)) info->features |= CPU_FEATURE_SSE2;
    if (regs[2] & (1 << 0))  info->features |= CPU_FEATURE_SSE3;
    if (regs[2] & (1 << 9))  info->features |= CPU_FEATURE_SSSE3;
    if (regs[2] & (1 << 19)) info->features |= CPU_FEATURE_SSE41;
    if (regs[2] & (1 << 20)) info->features |= CPU_FEATURE_SSE42;
    if (regs[2] & (1 << 28)) info->features |= CPU_FEATURE_AVX;
    
    /* Extended features */
    run_cpuid(7, 0, regs);
    if (regs[1] & (1 << 5))  info->features |= CPU_FEATURE_AVX2;
    if (regs[1] & (1 << 16)) info->features |= CPU_FEATURE_AVX512F;
    if (regs[1] & (1 << 31)) info->features |= CPU_FEATURE_AVX512VL;
    
    /* Brand string */
    for (int i = 0; i < 3; i++) {
        run_cpuid(0x80000002 + i, 0, regs);
        memcpy(info->brand + i * 16, regs, 16);
    }
    info->brand[48] = '\0';
    
    /* Cache info */
    info->cache_line_size = 64; /* Common default */
    run_cpuid(0x80000006, 0, regs);
    info->l2_cache_size = (regs[2] >> 16) & 0xFFFF; /* KB */
    info->l3_cache_size = ((regs[3] >> 18) & 0x3FFF) * 512; /* KB */
}
#endif

/* ARM feature detection */
#ifdef CPU_ARM
static void detect_arm_features(cpu_info_t* info) {
    strcpy(info->vendor, "ARM");
    
#if defined(__linux__)
    unsigned long hwcaps = getauxval(AT_HWCAP);
    
#if defined(__aarch64__)
    /* ARM64 NEON is always available */
    info->features |= CPU_FEATURE_NEON;
    info->features |= CPU_FEATURE_ASIMD;
    info->arch = CPU_ARCH_ARM64;
#else
    /* ARM32 - check for NEON */
    if (hwcaps & HWCAP_NEON) {
        info->features |= CPU_FEATURE_NEON;
    }
    info->arch = CPU_ARCH_ARM32;
#endif
    
#elif defined(__APPLE__)
    /* Apple Silicon - NEON always available */
    info->features |= CPU_FEATURE_NEON;
    info->features |= CPU_FEATURE_ASIMD;
    info->arch = CPU_ARCH_ARM64;
    
    /* Get brand string */
    char brand[64];
    size_t size = sizeof(brand);
    if (sysctlbyname("machdep.cpu.brand_string", brand, &size, NULL, 0) == 0) {
        strncpy(info->brand, brand, 48);
        info->brand[48] = '\0';
    }
#endif
    
    info->cache_line_size = 64;
}
#endif

/* Initialize CPU info */
static void init_cpu_info(void) {
    if (g_cpu_info_initialized) return;
    
    memset(&g_cpu_info, 0, sizeof(cpu_info_t));
    
#ifdef CPU_X86
#if defined(__x86_64__) || defined(_M_X64)
    g_cpu_info.arch = CPU_ARCH_X86_64;
#else
    g_cpu_info.arch = CPU_ARCH_X86;
#endif
    detect_x86_features(&g_cpu_info);
#elif defined(CPU_ARM)
    detect_arm_features(&g_cpu_info);
#else
    g_cpu_info.arch = CPU_ARCH_UNKNOWN;
#endif
    
    g_cpu_info_initialized = true;
}

/* Public API */
const cpu_info_t* cpu_get_info(void) {
    if (!g_cpu_info_initialized) {
        init_cpu_info();
    }
    return &g_cpu_info;
}

bool cpu_has_feature(cpu_feature_t feature) {
    const cpu_info_t* info = cpu_get_info();
    return (info->features & feature) != 0;
}

bool cpu_has_all_features(uint32_t feature_mask) {
    const cpu_info_t* info = cpu_get_info();
    return (info->features & feature_mask) == feature_mask;
}

simd_level_t cpu_get_simd_level(void) {
    const cpu_info_t* info = cpu_get_info();
    
    /* ARM path */
    if (info->arch == CPU_ARCH_ARM64 || info->arch == CPU_ARCH_ARM32) {
        if (info->features & CPU_FEATURE_NEON) {
            return SIMD_LEVEL_NEON;
        }
        return SIMD_LEVEL_NONE;
    }
    
    /* x86/x64 path - check from highest to lowest */
    if (info->features & CPU_FEATURE_AVX512F) {
        return SIMD_LEVEL_AVX512;
    }
    if (info->features & CPU_FEATURE_AVX2) {
        return SIMD_LEVEL_AVX2;
    }
    if (info->features & CPU_FEATURE_SSE41) {
        return SIMD_LEVEL_SSE41;
    }
    if (info->features & CPU_FEATURE_SSE2) {
        return SIMD_LEVEL_SSE2;
    }
    
    return SIMD_LEVEL_NONE;
}

const char* cpu_simd_level_name(simd_level_t level) {
    switch (level) {
        case SIMD_LEVEL_NONE:   return "Portable";
        case SIMD_LEVEL_SSE2:   return "SSE2";
        case SIMD_LEVEL_SSE41:  return "SSE4.1";
        case SIMD_LEVEL_AVX2:   return "AVX2";
        case SIMD_LEVEL_AVX512: return "AVX-512";
        case SIMD_LEVEL_NEON:   return "NEON";
        default:                return "Unknown";
    }
}

