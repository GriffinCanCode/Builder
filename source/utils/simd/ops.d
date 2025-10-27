module utils.simd.ops;

@safe:

/// SIMD-accelerated memory operations
/// Automatically selects optimal implementation based on CPU

extern(C) @system:

/// Fast memory copy (automatically selects SIMD)
void simd_memcpy(void* dest, const void* src, size_t n);

/// Fast memory comparison (returns 0 if equal)
int simd_memcmp(const void* s1, const void* s2, size_t n);

/// Fast memory set
void simd_memset(void* dest, int val, size_t n);

/// Find byte in memory (returns pointer or NULL)
void* simd_memchr(const void* s, int c, size_t n);

/// Count matching bytes between two buffers
size_t simd_count_matches(const ubyte* s1, const ubyte* s2, size_t n);

/// XOR two byte arrays
void simd_xor(ubyte* dest, const ubyte* src1, const ubyte* src2, size_t n);

/// Rolling hash for chunking (Rabin fingerprint)
ulong simd_rolling_hash(const ubyte* data, size_t length, size_t window);

/// Parallel hash multiple buffers
void simd_parallel_hash(
    const ubyte** inputs,
    size_t numInputs,
    size_t inputSize,
    ubyte* outputs  /* numInputs * 32 bytes */
);

/// D-friendly SIMD operations wrapper
struct SIMDOps
{
    /// Fast memory copy
    @trusted // Calls extern C SIMD function
    static void copy(void[] dest, const void[] src)
    {
        import std.algorithm : min;
        auto n = min(dest.length, src.length);
        simd_memcpy(dest.ptr, src.ptr, n);
    }
    
    /// Fast memory comparison
    @trusted // Calls extern C SIMD function
    static bool equals(const void[] a, const void[] b)
    {
        if (a.length != b.length) return false;
        return simd_memcmp(a.ptr, b.ptr, a.length) == 0;
    }
    
    /// Fast memory set
    @trusted // Calls extern C SIMD function
    static void fill(void[] dest, ubyte value)
    {
        simd_memset(dest.ptr, value, dest.length);
    }
    
    /// Find byte in array
    @trusted // Calls extern C SIMD function and pointer arithmetic
    static ptrdiff_t find(const ubyte[] haystack, ubyte needle)
    {
        auto result = simd_memchr(haystack.ptr, needle, haystack.length);
        if (result is null) return -1;
        return cast(ptrdiff_t)(result - haystack.ptr);
    }
    
    /// Count matching bytes
    @trusted // Calls extern C SIMD function
    static size_t countMatches(const ubyte[] a, const ubyte[] b)
    {
        import std.algorithm : min;
        auto n = min(a.length, b.length);
        return simd_count_matches(a.ptr, b.ptr, n);
    }
    
    /// XOR two arrays
    @trusted // Calls extern C SIMD function
    static void xor(ubyte[] dest, const ubyte[] a, const ubyte[] b)
    {
        import std.algorithm : min;
        auto n = min(dest.length, min(a.length, b.length));
        simd_xor(dest.ptr, a.ptr, b.ptr, n);
    }
    
    /// Calculate rolling hash
    @trusted // Calls extern C SIMD function
    static ulong rollingHash(const ubyte[] data, size_t windowSize = 64)
    {
        if (data.length == 0) return 0;
        return simd_rolling_hash(data.ptr, data.length, windowSize);
    }
}

// Unit tests
unittest
{
    import std.stdio;
    
    // Test memory copy
    ubyte[1024] src;
    ubyte[1024] dest;
    foreach (i, ref b; src) b = cast(ubyte)i;
    SIMDOps.copy(dest, src);
    assert(SIMDOps.equals(dest, src));
    
    // Test memory fill
    ubyte[256] buffer;
    SIMDOps.fill(buffer, 0xAB);
    foreach (b; buffer) assert(b == 0xAB);
    
    // Test find
    ubyte[100] searchBuf;
    searchBuf[50] = 0xFF;
    assert(SIMDOps.find(searchBuf, 0xFF) == 50);
    
    // Test XOR
    ubyte[16] a = [0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0xAA, 0xAA, 0xAA, 0xAA, 0, 0, 0, 0];
    ubyte[16] b = [0x0F, 0x0F, 0x0F, 0x0F, 0, 0, 0, 0, 0x55, 0x55, 0x55, 0x55, 0, 0, 0, 0];
    ubyte[16] result;
    SIMDOps.xor(result, a, b);
    assert(result[0] == 0xF0);
    assert(result[8] == 0xFF);
    
    // Test rolling hash
    ubyte[256] data;
    foreach (i, ref b; data) b = cast(ubyte)i;
    auto hash1 = SIMDOps.rollingHash(data);
    data[0] = 123;  // Change data
    auto hash2 = SIMDOps.rollingHash(data);
    assert(hash1 != hash2);  // Hash should change
    
    writeln("SIMD operations tests passed!");
}

