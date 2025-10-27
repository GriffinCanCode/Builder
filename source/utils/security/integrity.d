module utils.security.integrity;

import std.datetime;
import std.conv;
import std.algorithm;
import std.bitmanip;
import utils.crypto.blake3;

@safe:

/// BLAKE3-based HMAC for cache integrity validation
/// Provides cryptographic verification to prevent tampering
struct IntegrityValidator
{
    private static immutable ubyte[32] DEFAULT_KEY = [
        0x62, 0x75, 0x69, 0x6c, 0x64, 0x65, 0x72, 0x2d,  // "builder-"
        0x63, 0x61, 0x63, 0x68, 0x65, 0x2d, 0x6b, 0x65,  // "cache-ke"
        0x79, 0x2d, 0x76, 0x31, 0x00, 0x00, 0x00, 0x00,  // "y-v1...."
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00   // "...."
    ];
    
    private ubyte[32] key;
    
    /// Create with custom key
    static IntegrityValidator withKey(in ubyte[32] customKey) @safe pure nothrow @nogc
    {
        IntegrityValidator v;
        v.key = customKey;
        return v;
    }
    
    /// Create with default key (suitable for local cache validation)
    static IntegrityValidator create() @safe pure nothrow @nogc
    {
        IntegrityValidator v;
        v.key = DEFAULT_KEY;
        return v;
    }
    
    /// Create with environment-specific key (for distributed builds)
    static IntegrityValidator fromEnvironment(string workspace) @trusted
    {
        import std.digest.sha : sha256Of;
        
        IntegrityValidator v;
        // Derive key from workspace path + machine ID
        auto keyMaterial = workspace ~ getMachineId();
        auto hash = sha256Of(keyMaterial);
        v.key[0 .. 32] = hash[0 .. 32];
        return v;
    }
    
    /// Generate HMAC-BLAKE3 for data
    ubyte[32] sign(scope const(ubyte)[] data) const @trusted
    {
        // HMAC-BLAKE3: H(K XOR opad || H(K XOR ipad || message))
        // Using keyed BLAKE3 for simpler, faster implementation
        auto hasher = Blake3.keyed(key);
        hasher.put(cast(ubyte[])data);
        auto result = hasher.finish(32);
        
        ubyte[32] signature;
        signature[0 .. 32] = result[0 .. 32];
        return signature;
    }
    
    /// Verify HMAC-BLAKE3 signature (constant-time comparison)
    bool verify(scope const(ubyte)[] data, in ubyte[32] signature) const @trusted
    {
        auto computed = sign(data);
        return constantTimeEquals(computed, signature);
    }
    
    /// Sign with timestamp and version info
    SignedData signWithMetadata(scope const(ubyte)[] data, uint version_ = 1) const @trusted
    {
        SignedData signed;
        signed.version_ = version_;
        signed.timestamp = Clock.currTime().stdTime;
        signed.data = cast(ubyte[])data.dup;
        
        // Create payload: version(4) || timestamp(8) || data(N)
        ubyte[] payload;
        payload ~= nativeToBigEndian(version_)[];
        payload ~= nativeToBigEndian(signed.timestamp)[];
        payload ~= signed.data;
        
        signed.signature = sign(payload);
        return signed;
    }
    
    /// Verify signed data with metadata
    bool verifyWithMetadata(in SignedData signed) const @trusted
    {
        // Reconstruct payload
        ubyte[] payload;
        payload ~= nativeToBigEndian(signed.version_)[];
        payload ~= nativeToBigEndian(signed.timestamp)[];
        payload ~= signed.data;
        
        return verify(payload, signed.signature);
    }
    
    /// Check if signed data is expired
    static bool isExpired(in SignedData signed, Duration maxAge) @safe
    {
        auto signedTime = SysTime(signed.timestamp);
        auto now = Clock.currTime();
        return (now - signedTime) > maxAge;
    }
}

/// Signed data container
struct SignedData
{
    uint version_;
    long timestamp;  // stdTime
    ubyte[] data;
    ubyte[32] signature;
    
    /// Serialize to binary format
    ubyte[] serialize() const @trusted pure
    {
        ubyte[] result;
        result.reserve(4 + 8 + 32 + 4 + data.length);
        
        result ~= nativeToBigEndian(version_)[];
        result ~= nativeToBigEndian(timestamp)[];
        result ~= signature[];
        result ~= nativeToBigEndian(cast(uint)data.length)[];
        result ~= data;
        
        return result;
    }
    
    /// Deserialize from binary format
    static SignedData deserialize(scope const(ubyte)[] bytes) @trusted
    {
        if (bytes.length < 4 + 8 + 32 + 4)
            throw new Exception("Invalid signed data: too short");
        
        SignedData signed;
        size_t offset = 0;
        
        signed.version_ = bigEndianToNative!uint(bytes[offset .. offset + 4][0 .. 4]);
        offset += 4;
        
        signed.timestamp = bigEndianToNative!long(bytes[offset .. offset + 8][0 .. 8]);
        offset += 8;
        
        signed.signature[0 .. 32] = bytes[offset .. offset + 32];
        offset += 32;
        
        auto dataLen = bigEndianToNative!uint(bytes[offset .. offset + 4][0 .. 4]);
        offset += 4;
        
        if (offset + dataLen != bytes.length)
            throw new Exception("Invalid signed data: length mismatch");
        
        signed.data = cast(ubyte[])bytes[offset .. $].dup;
        
        return signed;
    }
}

/// Constant-time equality comparison (prevents timing attacks)
bool constantTimeEquals(in ubyte[] a, in ubyte[] b) @safe pure nothrow @nogc
{
    if (a.length != b.length)
        return false;
    
    ubyte result = 0;
    foreach (i; 0 .. a.length)
        result |= a[i] ^ b[i];
    
    return result == 0;
}

/// Get machine-specific identifier
private string getMachineId() @trusted
{
    version(Posix)
    {
        import std.process : execute;
        import std.string : strip;
        
        // Try /etc/machine-id first (Linux)
        try
        {
            import std.file : readText;
            return readText("/etc/machine-id").strip;
        }
        catch (Exception) {}
        
        // Try hostid (Unix)
        try
        {
            auto result = execute(["hostid"]);
            if (result.status == 0)
                return result.output.strip;
        }
        catch (Exception) {}
    }
    
    version(Windows)
    {
        import std.process : execute;
        import std.string : strip;
        
        try
        {
            auto result = execute(["wmic", "csproduct", "get", "UUID"]);
            if (result.status == 0)
                return result.output.strip;
        }
        catch (Exception) {}
    }
    
    // Fallback: use username + hostname
    import std.socket : Socket;
    return Socket.hostName();
}

@safe unittest
{
    // Test basic signing and verification
    auto validator = IntegrityValidator.create();
    ubyte[] data = [1, 2, 3, 4, 5];
    auto signature = validator.sign(data);
    assert(validator.verify(data, signature));
    
    // Test tampering detection
    data[0] = 99;
    assert(!validator.verify(data, signature));
    
    // Test metadata signing
    auto signed = validator.signWithMetadata([10, 20, 30]);
    assert(validator.verifyWithMetadata(signed));
    
    // Test tampering with metadata
    signed.data[0] = 99;
    assert(!validator.verifyWithMetadata(signed));
    
    // Test serialization
    auto bytes = signed.serialize();
    auto deserialized = SignedData.deserialize(bytes);
    assert(deserialized.version_ == signed.version_);
    assert(deserialized.timestamp == signed.timestamp);
    assert(deserialized.data == signed.data);
    
    // Test constant-time comparison
    assert(constantTimeEquals([1, 2, 3], [1, 2, 3]));
    assert(!constantTimeEquals([1, 2, 3], [1, 2, 4]));
}

