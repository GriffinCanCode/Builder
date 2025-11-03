module infrastructure.utils.serialization.core.bindings;

/// D bindings for C SIMD serialization hot paths

extern(C) @system nothrow @nogc:

/* Varint encoding/decoding */

size_t varint_encode_u32(uint value, ubyte* dest);
size_t varint_encode_u64(ulong value, ubyte* dest);
size_t varint_decode_u32(const(ubyte)* src, size_t max_len, uint* value);
size_t varint_decode_u64(const(ubyte)* src, size_t max_len, ulong* value);

size_t varint_encode_i32(int value, ubyte* dest);
size_t varint_encode_i64(long value, ubyte* dest);
size_t varint_decode_i32(const(ubyte)* src, size_t max_len, int* value);
size_t varint_decode_i64(const(ubyte)* src, size_t max_len, long* value);

/* Batch operations */
size_t varint_encode_u32_batch(
    const(uint)* values,
    size_t count,
    ubyte* dest,
    size_t* offsets
);

size_t varint_encode_u64_batch(
    const(ulong)* values,
    size_t count,
    ubyte* dest,
    size_t* offsets
);

size_t varint_decode_u32_batch(
    const(ubyte)* src,
    size_t src_len,
    uint* values,
    size_t count
);

size_t varint_decode_u64_batch(
    const(ubyte)* src,
    size_t src_len,
    ulong* values,
    size_t count
);

/* Utilities */
size_t varint_size_u32(uint value);
size_t varint_size_u64(ulong value);
size_t varint_skip(const(ubyte)* src, size_t max_len);

/* Memory operations */

void store_u32_array_le(ubyte* dest, const(uint)* src, size_t count);
void load_u32_array_le(uint* dest, const(ubyte)* src, size_t count);
void store_u64_array_le(ubyte* dest, const(ulong)* src, size_t count);
void load_u64_array_le(ulong* dest, const(ubyte)* src, size_t count);

/* Inline helpers for direct use */

pragma(inline, true)
ushort load_u16_le(const(ubyte)* p) pure
{
    return cast(ushort)p[0] | (cast(ushort)p[1] << 8);
}

pragma(inline, true)
uint load_u32_le(const(ubyte)* p) pure
{
    return cast(uint)p[0]
        | (cast(uint)p[1] << 8)
        | (cast(uint)p[2] << 16)
        | (cast(uint)p[3] << 24);
}

pragma(inline, true)
ulong load_u64_le(const(ubyte)* p) pure
{
    return cast(ulong)p[0]
        | (cast(ulong)p[1] << 8)
        | (cast(ulong)p[2] << 16)
        | (cast(ulong)p[3] << 24)
        | (cast(ulong)p[4] << 32)
        | (cast(ulong)p[5] << 40)
        | (cast(ulong)p[6] << 48)
        | (cast(ulong)p[7] << 56);
}

pragma(inline, true)
void store_u16_le(ubyte* p, ushort v) pure
{
    p[0] = cast(ubyte)v;
    p[1] = cast(ubyte)(v >> 8);
}

pragma(inline, true)
void store_u32_le(ubyte* p, uint v) pure
{
    p[0] = cast(ubyte)v;
    p[1] = cast(ubyte)(v >> 8);
    p[2] = cast(ubyte)(v >> 16);
    p[3] = cast(ubyte)(v >> 24);
}

pragma(inline, true)
void store_u64_le(ubyte* p, ulong v) pure
{
    p[0] = cast(ubyte)v;
    p[1] = cast(ubyte)(v >> 8);
    p[2] = cast(ubyte)(v >> 16);
    p[3] = cast(ubyte)(v >> 24);
    p[4] = cast(ubyte)(v >> 32);
    p[5] = cast(ubyte)(v >> 40);
    p[6] = cast(ubyte)(v >> 48);
    p[7] = cast(ubyte)(v >> 56);
}

/* Zigzag encoding (for signed integers) */

pragma(inline, true)
uint zigzag_encode_i32(int n) pure
{
    return cast(uint)((n << 1) ^ (n >> 31));
}

pragma(inline, true)
int zigzag_decode_u32(uint n) pure
{
    return cast(int)((n >> 1) ^ (~(n & 1) + 1));
}

pragma(inline, true)
ulong zigzag_encode_i64(long n) pure
{
    return cast(ulong)((n << 1) ^ (n >> 63));
}

pragma(inline, true)
long zigzag_decode_u64(ulong n) pure
{
    return cast(long)((n >> 1) ^ (~(n & 1) + 1));
}

