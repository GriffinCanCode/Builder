module infrastructure.utils.serialization.core.buffer;

import std.array : Appender;
import infrastructure.utils.serialization.core.bindings;

/// Zero-copy read buffer for deserialization
/// Provides safe, bounds-checked access to serialized data
struct ReadBuffer
{
    private const(ubyte)[] data;
    private size_t position;
    
    /// Create read buffer from data
    this(const(ubyte)[] data) pure nothrow @safe @nogc
    {
        this.data = data;
        this.position = 0;
    }
    
    /// Remaining bytes
    @property size_t remaining() const pure nothrow @safe @nogc
    {
        return data.length - position;
    }
    
    /// Check if we can read N bytes
    bool canRead(size_t n) const pure nothrow @safe @nogc
    {
        return remaining >= n;
    }
    
    /// Get current position
    @property size_t tell() const pure nothrow @safe @nogc
    {
        return position;
    }
    
    /// Seek to position
    void seek(size_t pos) pure @safe
    {
        if (pos > data.length)
            throw new Exception("Seek beyond buffer end");
        position = pos;
    }
    
    /// Skip N bytes
    void skip(size_t n) pure @safe
    {
        if (!canRead(n))
            throw new Exception("Skip beyond buffer end");
        position += n;
    }
    
    /// Peek at next byte without advancing
    ubyte peek() const pure @safe
    {
        if (remaining == 0)
            throw new Exception("Buffer exhausted");
        return data[position];
    }
    
    /// Read single byte
    ubyte readByte() pure @safe
    {
        if (remaining == 0)
            throw new Exception("Buffer exhausted");
        return data[position++];
    }
    
    /// Read fixed-size integers (zero-copy, little-endian)
    
    ushort readU16() pure @trusted
    {
        if (!canRead(2))
            throw new Exception("Cannot read u16");
        auto result = load_u16_le(data.ptr + position);
        position += 2;
        return result;
    }
    
    uint readU32() pure @trusted
    {
        if (!canRead(4))
            throw new Exception("Cannot read u32");
        auto result = load_u32_le(data.ptr + position);
        position += 4;
        return result;
    }
    
    ulong readU64() pure @trusted
    {
        if (!canRead(8))
            throw new Exception("Cannot read u64");
        auto result = load_u64_le(data.ptr + position);
        position += 8;
        return result;
    }
    
    /// Read varint integers
    
    uint readVarU32() @trusted
    {
        uint value;
        size_t len = varint_decode_u32(data.ptr + position, remaining, &value);
        if (len == 0)
            throw new Exception("Invalid varint");
        position += len;
        return value;
    }
    
    ulong readVarU64() @trusted
    {
        ulong value;
        size_t len = varint_decode_u64(data.ptr + position, remaining, &value);
        if (len == 0)
            throw new Exception("Invalid varint");
        position += len;
        return value;
    }
    
    int readVarI32() @trusted
    {
        int value;
        size_t len = varint_decode_i32(data.ptr + position, remaining, &value);
        if (len == 0)
            throw new Exception("Invalid varint");
        position += len;
        return value;
    }
    
    long readVarI64() @trusted
    {
        long value;
        size_t len = varint_decode_i64(data.ptr + position, remaining, &value);
        if (len == 0)
            throw new Exception("Invalid varint");
        position += len;
        return value;
    }
    
    /// Read byte array (zero-copy slice)
    const(ubyte)[] readBytes(size_t n) pure @safe
    {
        if (!canRead(n))
            throw new Exception("Cannot read bytes");
        auto result = data[position .. position + n];
        position += n;
        return result;
    }
    
    /// Read length-prefixed string (zero-copy)
    string readString() pure @trusted
    {
        auto len = readVarU32();
        if (!canRead(len))
            throw new Exception("String length exceeds buffer");
        auto bytes = data[position .. position + len];
        position += len;
        return cast(string)bytes;  // Zero-copy cast
    }
    
    /// Read length-prefixed byte array
    const(ubyte)[] readByteArray() pure @safe
    {
        auto len = readVarU32();
        return readBytes(len);
    }
}

/// Write buffer for serialization with arena allocation
struct WriteBuffer
{
    private Appender!(ubyte[]) buffer;
    
    /// Create write buffer with optional capacity hint
    this(size_t capacity) @safe
    {
        buffer.reserve(capacity);
    }
    
    /// Get serialized data
    @property const(ubyte)[] data() const @safe
    {
        return buffer.data;
    }
    
    /// Current size
    @property size_t length() const @safe
    {
        return buffer.data.length;
    }
    
    /// Write single byte
    void writeByte(ubyte value) @safe
    {
        buffer.put(value);
    }
    
    /// Write fixed-size integers (little-endian)
    
    void writeU16(ushort value) @trusted
    {
        ubyte[2] bytes;
        store_u16_le(bytes.ptr, value);
        buffer.put(bytes[]);
    }
    
    void writeU32(uint value) @trusted
    {
        ubyte[4] bytes;
        store_u32_le(bytes.ptr, value);
        buffer.put(bytes[]);
    }
    
    void writeU64(ulong value) @trusted
    {
        ubyte[8] bytes;
        store_u64_le(bytes.ptr, value);
        buffer.put(bytes[]);
    }
    
    /// Write varint integers
    
    void writeVarU32(uint value) @trusted
    {
        ubyte[5] temp;  // Max 5 bytes for u32
        size_t len = varint_encode_u32(value, temp.ptr);
        buffer.put(temp[0 .. len]);
    }
    
    void writeVarU64(ulong value) @trusted
    {
        ubyte[10] temp;  // Max 10 bytes for u64
        size_t len = varint_encode_u64(value, temp.ptr);
        buffer.put(temp[0 .. len]);
    }
    
    void writeVarI32(int value) @trusted
    {
        ubyte[5] temp;
        size_t len = varint_encode_i32(value, temp.ptr);
        buffer.put(temp[0 .. len]);
    }
    
    void writeVarI64(long value) @trusted
    {
        ubyte[10] temp;
        size_t len = varint_encode_i64(value, temp.ptr);
        buffer.put(temp[0 .. len]);
    }
    
    /// Write byte array
    void writeBytes(scope const(ubyte)[] bytes) @safe
    {
        buffer.put(bytes);
    }
    
    /// Write length-prefixed string
    void writeString(scope const(char)[] str) @trusted
    {
        writeVarU32(cast(uint)str.length);
        buffer.put(cast(const(ubyte)[])str);
    }
    
    /// Write length-prefixed byte array
    void writeByteArray(scope const(ubyte)[] bytes) @safe
    {
        writeVarU32(cast(uint)bytes.length);
        writeBytes(bytes);
    }
    
    /// Reserve capacity
    void reserve(size_t capacity) @safe
    {
        buffer.reserve(capacity);
    }
}

