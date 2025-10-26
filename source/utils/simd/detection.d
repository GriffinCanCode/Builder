module utils.simd.detection;

/// CPU Detection Module
/// Provides runtime CPU feature detection for optimal SIMD selection

extern(C):

/// CPU feature flags
enum CPUFeature : uint
{
    SSE2      = 1 << 0,
    SSE3      = 1 << 1,
    SSSE3     = 1 << 2,
    SSE41     = 1 << 3,
    SSE42     = 1 << 4,
    AVX       = 1 << 5,
    AVX2      = 1 << 6,
    AVX512F   = 1 << 7,
    AVX512VL  = 1 << 8,
    NEON      = 1 << 9,
    ASIMD     = 1 << 10,
}

/// CPU architecture type
enum CPUArch
{
    Unknown,
    X86_64,
    X86,
    ARM64,
    ARM32,
}

/// CPU information structure
struct CPUInfo
{
    CPUArch arch;
    uint features;
    char[13] vendor;
    char[49] brand;
    int cacheLineSize;
    int l1CacheSize;
    int l2CacheSize;
    int l3CacheSize;
}

/// SIMD optimization level
enum SIMDLevel
{
    None,
    SSE2,
    SSE41,
    AVX2,
    AVX512,
    NEON,
}

/// Get CPU information (cached after first call)
const(CPUInfo)* cpu_get_info();

/// Check if specific feature is supported
bool cpu_has_feature(CPUFeature feature);

/// Get optimal SIMD level for current CPU
SIMDLevel cpu_get_simd_level();

/// Get human-readable SIMD level name
const(char)* cpu_simd_level_name(SIMDLevel level);

/// Check multiple features at once
bool cpu_has_all_features(uint featureMask);

/// D-friendly wrapper for CPU info
struct CPU
{
    /// Get current CPU info
    static auto info()
    {
        return *cpu_get_info();
    }
    
    /// Check if feature is supported
    static bool hasFeature(CPUFeature feature)
    {
        return cpu_has_feature(feature);
    }
    
    /// Get SIMD level
    static SIMDLevel simdLevel()
    {
        return cpu_get_simd_level();
    }
    
    /// Get SIMD level name
    static string simdLevelName()
    {
        import std.string : fromStringz;
        return fromStringz(cpu_simd_level_name(cpu_get_simd_level())).idup;
    }
    
    /// Get CPU vendor
    static string vendor()
    {
        auto cpuInfo = info();
        import std.string : fromStringz;
        return fromStringz(cpuInfo.vendor.ptr).idup;
    }
    
    /// Get CPU brand
    static string brand()
    {
        auto cpuInfo = info();
        import std.string : fromStringz;
        return fromStringz(cpuInfo.brand.ptr).idup;
    }
    
    /// Check if running on x86/x64
    static bool isX86()
    {
        auto arch = info().arch;
        return arch == CPUArch.X86_64 || arch == CPUArch.X86;
    }
    
    /// Check if running on ARM
    static bool isARM()
    {
        auto arch = info().arch;
        return arch == CPUArch.ARM64 || arch == CPUArch.ARM32;
    }
    
    /// Print CPU information
    static void printInfo()
    {
        import std.stdio : writeln, writefln;
        
        auto cpuInfo = info();
        
        writeln("=== CPU Information ===");
        writefln("Architecture: %s", cpuInfo.arch);
        writefln("Vendor:       %s", vendor());
        writefln("Brand:        %s", brand());
        writefln("SIMD Level:   %s", simdLevelName());
        writeln("\nSupported Features:");
        
        foreach (feature; [
            CPUFeature.SSE2, CPUFeature.SSE3, CPUFeature.SSSE3,
            CPUFeature.SSE41, CPUFeature.SSE42, CPUFeature.AVX,
            CPUFeature.AVX2, CPUFeature.AVX512F, CPUFeature.AVX512VL,
            CPUFeature.NEON, CPUFeature.ASIMD
        ]) {
            if (hasFeature(feature)) {
                writefln("  ✓ %s", feature);
            }
        }
        
        writeln("\nCache Info:");
        writefln("  Cache Line: %d bytes", cpuInfo.cacheLineSize);
        if (cpuInfo.l1CacheSize > 0)
            writefln("  L1 Cache:   %d KB", cpuInfo.l1CacheSize);
        if (cpuInfo.l2CacheSize > 0)
            writefln("  L2 Cache:   %d KB", cpuInfo.l2CacheSize);
        if (cpuInfo.l3CacheSize > 0)
            writefln("  L3 Cache:   %d KB", cpuInfo.l3CacheSize);
    }
}

// Unit tests
unittest
{
    import std.stdio;
    
    // Test CPU detection
    auto level = CPU.simdLevel();
    writeln("Detected SIMD level: ", CPU.simdLevelName());
    assert(level != SIMDLevel.None || !CPU.isX86());  // x86 always has at least SSE2
    
    // Test feature checking
    if (CPU.isX86()) {
        // All x86_64 CPUs have SSE2
        version(X86_64) {
            assert(CPU.hasFeature(CPUFeature.SSE2));
        }
    }
    
    writeln("CPU detection tests passed!");
}

