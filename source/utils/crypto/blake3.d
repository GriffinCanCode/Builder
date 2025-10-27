module utils.crypto.blake3;

import utils.crypto.blake3_bindings;
import std.conv;
import std.string;
import std.algorithm;
import std.range;

@safe:

/// High-level D wrapper for BLAKE3 hashing
/// Provides memory-safe, convenient API over the C bindings
struct Blake3
{
    private blake3_hasher hasher;
    
    /// Initialize a new hasher with default settings
    /// 
    /// Safety: This constructor is @trusted because:
    /// 1. Hasher is a valid struct member (not dangling)
    /// 2. Calls extern(C) blake3_hasher_init with valid pointer
    /// 3. No memory allocation or escaping references
    @trusted
    this(int dummy)  // Dummy parameter to allow construction
    {
        blake3_hasher_init(&hasher);
    }
    
    /// Initialize with a key (for keyed hashing/MAC)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Key is a fixed-size array (BLAKE3_KEY_LEN) - no buffer overflows
    /// 2. Calls extern(C) blake3_hasher_init_keyed with validated static array
    /// 3. Hasher is stack-allocated and returned by value (no dangling)
    @trusted
    static Blake3 keyed(in ubyte[BLAKE3_KEY_LEN] key)
    {
        Blake3 b;
        blake3_hasher_init_keyed(&b.hasher, key);
        return b;
    }
    
    /// Initialize for key derivation
    /// 
    /// Safety: This function is @trusted because:
    /// 1. toStringz() creates a null-terminated copy (safe for C interop)
    /// 2. Calls extern(C) blake3_hasher_init_derive_key with valid C string
    /// 3. No memory leaks - temporary string is GC-managed
    @trusted
    static Blake3 deriveKey(in string context)
    {
        Blake3 b;
        blake3_hasher_init_derive_key(&b.hasher, context.toStringz());
        return b;
    }
    
    /// Update hasher with data
    /// 
    /// Safety: This function is @trusted because:
    /// 1. D slice guarantees pointer validity and accurate length
    /// 2. Empty check prevents invalid pointer dereference
    /// 3. Calls extern(C) blake3_hasher_update with validated parameters
    @trusted
    void put(in ubyte[] data)
    {
        if (data.length > 0)
            blake3_hasher_update(&hasher, data.ptr, data.length);
    }
    
    /// Update hasher with string
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Casting string to ubyte[] is safe (same memory layout)
    /// 2. Delegates to trusted put(ubyte[]) which validates parameters
    /// 3. No mutations to the original string
    @trusted
    void put(in string data)
    {
        put(cast(ubyte[])data);
    }
    
    /// Finalize and get hash (default 32 bytes)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Allocates buffer with exact requested length (no buffer overrun)
    /// 2. Calls extern(C) blake3_hasher_finalize with matching buffer and size
    /// 3. Returns owned array (no dangling references)
    @trusted
    ubyte[] finish(in size_t length = BLAKE3_OUT_LEN)
    {
        auto output = new ubyte[length];
        blake3_hasher_finalize(&hasher, output.ptr, length);
        return output;
    }
    
    /// Finalize and get hash as hex string
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Delegates to trusted finish() which performs validation
    /// 2. toHexString() is @safe (converts to hex representation)
    /// 3. No unsafe operations performed
    @trusted
    string finishHex(in size_t length = BLAKE3_OUT_LEN)
    {
        auto hash = finish(length);
        return toHexString(hash);
    }
    
    /// Reset hasher to initial state
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Hasher is a valid struct member
    /// 2. Calls extern(C) blake3_hasher_reset with valid pointer
    /// 3. No memory allocation or deallocation
    @trusted
    void reset()
    {
        blake3_hasher_reset(&hasher);
    }
    
    /// One-shot hash of data
    @trusted // Delegates to trusted Blake3 methods
    static ubyte[] hash(in ubyte[] data, in size_t length = BLAKE3_OUT_LEN)
    {
        auto b = Blake3(0);
        b.put(data);
        return b.finish(length);
    }
    
    /// One-shot hash of string
    @trusted // Safe cast and delegates to trusted hash()
    static ubyte[] hash(in string data, in size_t length = BLAKE3_OUT_LEN)
    {
        return hash(cast(ubyte[])data, length);
    }
    
    /// One-shot hash returning hex string
    static string hashHex(const ubyte[] data, size_t length = BLAKE3_OUT_LEN)
    {
        auto h = hash(data, length);
        return toHexString(h);
    }
    
    /// One-shot hash of string returning hex string
    @trusted // Safe cast of string to ubyte[] for hashing
    static string hashHex(string data, size_t length = BLAKE3_OUT_LEN)
    {
        return hashHex(cast(ubyte[])data, length);
    }
}

/// Convert byte array to hex string (lowercase)
@trusted // Safe cast of char[] to string (immutable)
string toHexString(const ubyte[] bytes)
{
    static immutable hexDigits = "0123456789abcdef";
    auto result = new char[bytes.length * 2];
    
    foreach (i, b; bytes)
    {
        result[i * 2] = hexDigits[b >> 4];
        result[i * 2 + 1] = hexDigits[b & 0x0F];
    }
    
    return cast(string)result;
}

/// Convert hex string to byte array
ubyte[] fromHexString(string hex)
{
    if (hex.length % 2 != 0)
        throw new Exception("Invalid hex string length");
    
    auto result = new ubyte[hex.length / 2];
    
    foreach (i; 0 .. result.length)
    {
        auto hi = hexDigitValue(hex[i * 2]);
        auto lo = hexDigitValue(hex[i * 2 + 1]);
        result[i] = cast(ubyte)((hi << 4) | lo);
    }
    
    return result;
}

private ubyte hexDigitValue(char c)
{
    if (c >= '0' && c <= '9')
        return cast(ubyte)(c - '0');
    if (c >= 'a' && c <= 'f')
        return cast(ubyte)(c - 'a' + 10);
    if (c >= 'A' && c <= 'F')
        return cast(ubyte)(c - 'A' + 10);
    throw new Exception("Invalid hex digit: " ~ c);
}

// Unit tests
unittest
{
    import std.stdio;
    
    // Test basic hashing
    auto hash1 = Blake3.hashHex("hello world");
    writeln("BLAKE3('hello world') = ", hash1);
    assert(hash1.length == 64); // 32 bytes = 64 hex chars
    
    // Test incremental hashing
    auto b = Blake3(0);
    b.put("hello ");
    b.put("world");
    auto hash2 = b.finishHex();
    assert(hash1 == hash2, "Incremental hash should match one-shot hash");
    
    // Test empty input
    auto emptyHash = Blake3.hashHex("");
    assert(emptyHash.length == 64);
    
    // Test different output lengths
    auto hash16 = Blake3.hashHex("test", 16);
    assert(hash16.length == 32); // 16 bytes = 32 hex chars
    
    writeln("BLAKE3 wrapper tests passed!");
}

