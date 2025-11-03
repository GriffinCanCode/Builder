module infrastructure.utils.crypto.blake3;

import infrastructure.utils.crypto.blake3_bindings;
import std.conv;
import std.string;
import std.algorithm;
import std.range;
import infrastructure.errors.handling.result : Result, Ok, Err;


/// High-level D wrapper for BLAKE3 hashing
/// Provides memory-safe, convenient API over the C bindings
struct Blake3
{
    private blake3_hasher hasher;
    
    /// Initialize a new hasher with default settings
    /// 
    /// Safety: This constructor is @system because:
    /// 1. Hasher is a valid struct member (not dangling)
    /// 2. Calls extern(C) blake3_hasher_init with valid pointer
    /// 3. No memory allocation or escaping references
    /// 
    /// Invariants:
    /// - Hasher is initialized to default BLAKE3 state
    /// - Safe for immediate use after construction
    /// 
    /// What could go wrong:
    /// - C library not linked: linker error (compile-time)
    /// - Pointer to hasher is guaranteed valid (stack-allocated struct member)
    @system
    this(int dummy)  // Dummy parameter to allow construction
    {
        blake3_hasher_init(&hasher);
    }
    
    /// Initialize with a key (for keyed hashing/MAC)
    /// 
    /// Safety: This function is @system because:
    /// 1. Key is a fixed-size array (BLAKE3_KEY_LEN) - no buffer overflows
    /// 2. Calls extern(C) blake3_hasher_init_keyed with validated static array
    /// 3. Hasher is stack-allocated and returned by value (no dangling)
    /// 
    /// Invariants:
    /// - Key must be exactly BLAKE3_KEY_LEN (32) bytes (enforced by type)
    /// - Same key produces deterministic hashes
    /// 
    /// What could go wrong:
    /// - Weak key: user's responsibility to provide strong key
    /// - Key reuse across contexts: user's responsibility to manage keys
    /// - C library call is safe (key length validated by type system)
    @system
    static Blake3 keyed(in ubyte[BLAKE3_KEY_LEN] key)
    {
        Blake3 b;
        blake3_hasher_init_keyed(&b.hasher, key);
        return b;
    }
    
    /// Initialize for key derivation
    /// 
    /// Safety: This function is @system because:
    /// 1. toStringz() creates a null-terminated copy (safe for C interop)
    /// 2. Calls extern(C) blake3_hasher_init_derive_key with valid C string
    /// 3. No memory leaks - temporary string is GC-managed
    /// 
    /// Invariants:
    /// - Context string is null-terminated for C interop
    /// - Same context produces same key derivation
    /// 
    /// What could go wrong:
    /// - Empty context: allowed, produces deterministic result
    /// - toStringz() allocates: GC-managed, no leaks
    /// - Context with null bytes: truncated by toStringz (D string semantics)
    @system
    static Blake3 deriveKey(in string context)
    {
        Blake3 b;
        blake3_hasher_init_derive_key(&b.hasher, context.toStringz());
        return b;
    }
    
    /// Update hasher with data
    /// 
    /// Safety: This function is @system because:
    /// 1. D slice guarantees pointer validity and accurate length
    /// 2. Empty check prevents invalid pointer dereference
    /// 3. Calls extern(C) blake3_hasher_update with validated parameters
    /// 
    /// Invariants:
    /// - data.ptr is valid for data.length bytes (D slice guarantee)
    /// - Empty data is no-op (safe to call)
    /// 
    /// What could go wrong:
    /// - Nothing: D slices ensure pointer safety
    /// - Empty data: handled explicitly with early return
    /// - C function respects length parameter (BLAKE3 implementation validated)
    @system
    void put(in ubyte[] data)
    {
        if (data.length > 0)
            blake3_hasher_update(&hasher, data.ptr, data.length);
    }
    
    /// Update hasher with string
    /// 
    /// Safety: This function is @system because:
    /// 1. Casting string to ubyte[] is safe (same memory layout)
    /// 2. Delegates to trusted put(ubyte[]) which validates parameters
    /// 3. No mutations to the original string
    /// 
    /// Invariants:
    /// - String is valid UTF-8 (D guarantee, but not required for hashing)
    /// - Cast preserves all bytes exactly
    /// 
    /// What could go wrong:
    /// - Nothing: string and ubyte[] have identical memory representation
    /// - UTF-8 validity not checked: intentional, hashing raw bytes
    @system
    void put(in string data)
    {
        put(cast(ubyte[])data);
    }
    
    /// Finalize and get hash (default 32 bytes)
    /// 
    /// Safety: This function is @system because:
    /// 1. Allocates buffer with exact requested length (no buffer overrun)
    /// 2. Calls extern(C) blake3_hasher_finalize with matching buffer and size
    /// 3. Returns owned array (no dangling references)
    /// 
    /// Invariants:
    /// - Output buffer is exactly 'length' bytes
    /// - BLAKE3 can produce arbitrary-length output (XOF mode)
    /// - Hasher state is consumed but remains valid for reuse
    /// 
    /// What could go wrong:
    /// - Very large length: allocation could fail (exception propagates)
    /// - Zero length: valid, returns empty array
    /// - C function writes exactly 'length' bytes (BLAKE3 specification)
    @system
    ubyte[] finish(in size_t length = BLAKE3_OUT_LEN)
    {
        auto output = new ubyte[length];
        blake3_hasher_finalize(&hasher, output.ptr, length);
        return output;
    }
    
    /// Finalize and get hash as hex string
    /// 
    /// Safety: This function is @system because:
    /// 1. Delegates to trusted finish() which performs validation
    /// 2. toHexString() itself is @system but wraps safe operations
    /// 3. No unsafe operations performed
    /// 
    /// Invariants:
    /// - Output is lowercase hexadecimal string
    /// - Length of result is 2 * length (2 hex chars per byte)
    /// 
    /// What could go wrong:
    /// - Large length: could cause memory allocation failure (propagates)
    /// - Nothing else: hex encoding is deterministic and safe
    @system
    string finishHex(in size_t length = BLAKE3_OUT_LEN)
    {
        auto hash = finish(length);
        return toHexString(hash);
    }
    
    /// Reset hasher to initial state
    /// 
    /// Safety: This function is @system because:
    /// 1. Hasher is a valid struct member
    /// 2. Calls extern(C) blake3_hasher_reset with valid pointer
    /// 3. No memory allocation or deallocation
    /// 
    /// Invariants:
    /// - Hasher returns to initial state (as if freshly constructed)
    /// - Safe to reuse for new hash computation
    /// 
    /// What could go wrong:
    /// - Nothing: reset is idempotent and safe
    /// - Pointer to hasher is always valid (struct member)
    @system
    void reset()
    {
        blake3_hasher_reset(&hasher);
    }
    
    /// One-shot hash of data
    /// 
    /// Safety: This function is @system because:
    /// 1. Delegates to trusted Blake3 constructor, put(), and finish()
    /// 2. Local Blake3 instance is stack-allocated (no leaks)
    /// 3. All operations are validated by called methods
    /// 
    /// Invariants:
    /// - Equivalent to constructing Blake3, calling put(), then finish()
    /// - Deterministic: same data produces same hash
    /// 
    /// What could go wrong:
    /// - Large data or length: allocation could fail (exception propagates)
    /// - Otherwise: all operations are safe (validated by callees)
    @system
    static ubyte[] hash(in ubyte[] data, in size_t length = BLAKE3_OUT_LEN)
    {
        auto b = Blake3(0);
        b.put(data);
        return b.finish(length);
    }
    
    /// One-shot hash of string
    /// 
    /// Safety: This function is @system because:
    /// 1. Cast from string to ubyte[] is safe (identical memory layout)
    /// 2. Delegates to trusted hash(ubyte[]) method
    /// 
    /// Invariants:
    /// - String bytes are hashed as-is (UTF-8 encoding)
    /// 
    /// What could go wrong:
    /// - Nothing: cast and delegation are both safe
    @system
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
    /// 
    /// Safety: This function is @system because:
    /// 1. Cast from string to ubyte[] is safe (identical memory layout)
    /// 2. Delegates to hashHex(ubyte[]) overload
    /// 
    /// Invariants:
    /// - Produces lowercase hexadecimal string
    /// 
    /// What could go wrong:
    /// - Nothing: safe cast and delegation
    @system
    static string hashHex(string data, size_t length = BLAKE3_OUT_LEN)
    {
        return hashHex(cast(ubyte[])data, length);
    }
}

/// Convert byte array to hex string (lowercase)
/// 
/// Safety: This function is @system because:
/// 1. Allocates char array with exact required size (2 * bytes.length)
/// 2. Array indexing is in-bounds (i * 2 and i * 2 + 1 for i < bytes.length)
/// 3. Cast from char[] to string is safe (chars are valid UTF-8)
/// 
/// Invariants:
/// - Output length is exactly 2 * input length
/// - Output is valid UTF-8 (only contains 0-9, a-f)
/// - Deterministic: same bytes produce same hex string
/// 
/// What could go wrong:
/// - Very large input: allocation could fail (exception propagates)
/// - Array indexing is mathematically proven in-bounds
@system
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
/// Returns: Result with byte array or error message
Result!(ubyte[], string) fromHexString(string hex)
{
    if (hex.length % 2 != 0)
        return Err!(ubyte[], string)("Invalid hex string length: expected even number of characters, got " ~ hex.length.to!string);
    
    auto result = new ubyte[hex.length / 2];
    
    foreach (i; 0 .. result.length)
    {
        auto hiResult = hexDigitValue(hex[i * 2]);
        if (hiResult.isErr)
            return Err!(ubyte[], string)(hiResult.unwrapErr());
        
        auto loResult = hexDigitValue(hex[i * 2 + 1]);
        if (loResult.isErr)
            return Err!(ubyte[], string)(loResult.unwrapErr());
        
        result[i] = cast(ubyte)((hiResult.unwrap() << 4) | loResult.unwrap());
    }
    
    return Ok!(ubyte[], string)(result);
}

/// Convert hex digit character to numeric value
/// Returns: Result with byte value or error message
private Result!(ubyte, string) hexDigitValue(char c)
{
    if (c >= '0' && c <= '9')
        return Ok!(ubyte, string)(cast(ubyte)(c - '0'));
    if (c >= 'a' && c <= 'f')
        return Ok!(ubyte, string)(cast(ubyte)(c - 'a' + 10));
    if (c >= 'A' && c <= 'F')
        return Ok!(ubyte, string)(cast(ubyte)(c - 'A' + 10));
    return Err!(ubyte, string)("Invalid hex digit: '" ~ c ~ "' (expected 0-9, a-f, or A-F)");
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

