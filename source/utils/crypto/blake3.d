module utils.crypto.blake3;

import utils.crypto.blake3_bindings;
import std.conv;
import std.string;
import std.algorithm;
import std.range;

/// High-level D wrapper for BLAKE3 hashing
/// Provides memory-safe, convenient API over the C bindings
struct Blake3
{
    private blake3_hasher hasher;
    
    /// Initialize a new hasher with default settings
    this(int dummy)  // Dummy parameter to allow construction
    {
        blake3_hasher_init(&hasher);
    }
    
    /// Initialize with a key (for keyed hashing/MAC)
    static Blake3 keyed(const ubyte[BLAKE3_KEY_LEN] key)
    {
        Blake3 b;
        blake3_hasher_init_keyed(&b.hasher, key);
        return b;
    }
    
    /// Initialize for key derivation
    static Blake3 deriveKey(string context)
    {
        Blake3 b;
        blake3_hasher_init_derive_key(&b.hasher, context.toStringz());
        return b;
    }
    
    /// Update hasher with data
    void put(const ubyte[] data)
    {
        if (data.length > 0)
            blake3_hasher_update(&hasher, data.ptr, data.length);
    }
    
    /// Update hasher with string
    void put(string data)
    {
        put(cast(ubyte[])data);
    }
    
    /// Finalize and get hash (default 32 bytes)
    ubyte[] finish(size_t length = BLAKE3_OUT_LEN)
    {
        auto output = new ubyte[length];
        blake3_hasher_finalize(&hasher, output.ptr, length);
        return output;
    }
    
    /// Finalize and get hash as hex string
    string finishHex(size_t length = BLAKE3_OUT_LEN)
    {
        auto hash = finish(length);
        return toHexString(hash);
    }
    
    /// Reset hasher to initial state
    void reset()
    {
        blake3_hasher_reset(&hasher);
    }
    
    /// One-shot hash of data
    static ubyte[] hash(const ubyte[] data, size_t length = BLAKE3_OUT_LEN)
    {
        auto b = Blake3(0);
        b.put(data);
        return b.finish(length);
    }
    
    /// One-shot hash of string
    static ubyte[] hash(string data, size_t length = BLAKE3_OUT_LEN)
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
    static string hashHex(string data, size_t length = BLAKE3_OUT_LEN)
    {
        return hashHex(cast(ubyte[])data, length);
    }
}

/// Convert byte array to hex string (lowercase)
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

