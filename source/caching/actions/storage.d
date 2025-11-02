module caching.actions.storage;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.bitmanip;
import std.exception : assumeUnique;
import core.memory : GC;
import caching.actions.action;
import utils.simd.ops;

/// High-performance binary storage for action cache entries
/// Specialized for ActionEntry serialization
/// 
/// Design:
/// - Similar to BinaryStorage but optimized for action-level data
/// - Handles ActionId composite keys
/// - Supports ActionType enum serialization
/// - Efficient string array and map serialization
/// - SIMD acceleration for large data transfers
struct ActionStorage
{
    /// Magic number for format validation
    private enum uint MAGIC = 0x41435443; // "ACTC" (Action Cache)
    private enum ubyte VERSION = 1;
    
    /// Configuration constants
    private enum size_t MAX_BUFFER_POOL_SIZE = 4;
    private enum size_t ESTIMATED_ENTRY_SIZE = 512;  // Actions typically larger than targets
    private enum size_t HEADER_SIZE = 64;
    private enum size_t MIN_HEADER_SIZE = 9;
    private enum size_t SIMD_STRING_THRESHOLD = 64;
    
    /// Thread-local buffer pool
    private static Appender!(ubyte[])[] bufferPool;
    private static size_t poolIndex;
    
    /// Acquire buffer from pool
    private static ref Appender!(ubyte[]) acquireBuffer() @system nothrow
    {
        import core.exception : AssertError;
        
        assert(poolIndex <= bufferPool.length, "Pool index out of bounds");
        
        if (poolIndex < bufferPool.length && poolIndex < MAX_BUFFER_POOL_SIZE)
        {
            assert(poolIndex < bufferPool.length, "Pool index exceeds buffer pool length");
            auto buf = &bufferPool[poolIndex++];
            buf.clear();
            return *buf;
        }
        
        if (bufferPool.length < MAX_BUFFER_POOL_SIZE)
        {
            bufferPool ~= appender!(ubyte[]);
            poolIndex = bufferPool.length;
            assert(bufferPool.length > 0, "Buffer pool unexpectedly empty after append");
            return bufferPool[$ - 1];
        }
        
        assert(bufferPool.length >= MAX_BUFFER_POOL_SIZE, "Buffer pool size invariant violated");
        bufferPool[0].clear();
        poolIndex = 1;
        return bufferPool[0];
    }
    
    /// Release buffer back to pool
    private static void releaseBuffer() @system nothrow
    {
        if (poolIndex > 0)
            poolIndex--;
    }
    
    /// Serialize action cache entries to binary format
    static ubyte[] serialize(T)(scope T[string] entries) @system
    {
        auto buffer = acquireBuffer();
        scope(exit) releaseBuffer();
        
        immutable estimatedSize = entries.length * ESTIMATED_ENTRY_SIZE + HEADER_SIZE;
        buffer.reserve(estimatedSize);
        
        // Write header
        buffer.put(nativeToBigEndian(MAGIC)[]);
        buffer.put(VERSION);
        
        // Write entry count
        buffer.put(nativeToBigEndian(cast(uint)entries.length)[]);
        
        // Write each entry
        foreach (key, ref entry; entries)
        {
            writeString(buffer, key);
            writeActionEntry(buffer, entry);
        }
        
        return buffer.data.dup;
    }
    
    /// Deserialize action cache entries from binary format
    static T[string] deserialize(T)(scope ubyte[] data) @system
    {
        if (data.length < MIN_HEADER_SIZE)
            return null;
        
        size_t offset = 0;
        
        // Read and validate header
        immutable ubyte[4] magicBytes = data[offset .. offset + 4][0 .. 4];
        immutable magic = bigEndianToNative!uint(magicBytes);
        offset += 4;
        
        if (magic != MAGIC)
            throw new Exception("Invalid action cache file format");
        
        immutable version_ = data[offset++];
        if (version_ != VERSION)
            throw new Exception("Unsupported action cache version");
        
        // Read entry count
        immutable ubyte[4] countBytes = data[offset .. offset + 4][0 .. 4];
        immutable count = bigEndianToNative!uint(countBytes);
        offset += 4;
        
        T[string] entries;
        
        // Read entries
        foreach (_; 0 .. count)
        {
            immutable key = readString(data, offset);
            auto entry = readActionEntry!T(data, offset);
            entries[key] = entry;
        }
        
        entries.rehash();
        return entries;
    }
    
    /// Write string with length prefix
    private static void writeString(ref Appender!(ubyte[]) buffer, scope const(char)[] str) @system pure
    {
        buffer.put(nativeToBigEndian(cast(uint)str.length)[]);
        buffer.put(cast(const(ubyte)[])str);
    }
    
    /// Read string with length prefix
    private static string readString(scope const(ubyte)[] data, ref size_t offset) @system
    {
        import std.utf : validate, UTFException;
        import std.exception : enforce;
        
        enforce(offset + 4 <= data.length, "Invalid cache data: insufficient bytes for string length");
        
        immutable ubyte[4] lengthBytes = data[offset .. offset + 4][0 .. 4];
        immutable length = bigEndianToNative!uint(lengthBytes);
        offset += 4;
        
        enforce(offset + length <= data.length, "Invalid cache data: string length exceeds data bounds");
        
        auto slice = data[offset .. offset + length];
        auto charSlice = cast(const(char)[])slice;
        
        try
        {
            validate(charSlice);
        }
        catch (UTFException e)
        {
            throw new Exception("Invalid UTF-8 in cached data: " ~ e.msg);
        }
        
        auto str = cast(immutable(char)[])slice;
        offset += length;
        
        return str;
    }
    
    /// Write ActionId
    private static void writeActionId(ref Appender!(ubyte[]) buffer, ref const(ActionId) id) @system
    {
        writeString(buffer, id.targetId);
        buffer.put(cast(ubyte)id.type);
        writeString(buffer, id.inputHash);
        writeString(buffer, id.subId);
    }
    
    /// Read ActionId
    private static ActionId readActionId(scope const(ubyte)[] data, ref size_t offset) @system
    {
        ActionId id;
        id.targetId = readString(data, offset);
        id.type = cast(ActionType)data[offset++];
        id.inputHash = readString(data, offset);
        id.subId = readString(data, offset);
        return id;
    }
    
    /// Write string array
    private static void writeStringArray(ref Appender!(ubyte[]) buffer, scope const(string)[] arr) @system
    {
        buffer.put(nativeToBigEndian(cast(uint)arr.length)[]);
        foreach (str; arr)
            writeString(buffer, str);
    }
    
    /// Read string array
    private static string[] readStringArray(scope const(ubyte)[] data, ref size_t offset) @system
    {
        immutable ubyte[4] countBytes = data[offset .. offset + 4][0 .. 4];
        immutable count = bigEndianToNative!uint(countBytes);
        offset += 4;
        
        string[] result;
        result.reserve(count);
        
        foreach (_; 0 .. count)
            result ~= readString(data, offset);
        
        return result;
    }
    
    /// Write string-to-string map
    private static void writeStringMap(ref Appender!(ubyte[]) buffer, scope const(string[string]) map) @system
    {
        buffer.put(nativeToBigEndian(cast(uint)map.length)[]);
        foreach (key, value; map)
        {
            writeString(buffer, key);
            writeString(buffer, value);
        }
    }
    
    /// Read string-to-string map
    private static string[string] readStringMap(scope const(ubyte)[] data, ref size_t offset) @system
    {
        immutable ubyte[4] countBytes = data[offset .. offset + 4][0 .. 4];
        immutable count = bigEndianToNative!uint(countBytes);
        offset += 4;
        
        string[string] result;
        
        foreach (_; 0 .. count)
        {
            immutable key = readString(data, offset);
            immutable value = readString(data, offset);
            result[key] = value;
        }
        
        if (count > 0)
            result.rehash();
        
        return result;
    }
    
    /// Write ActionEntry
    private static void writeActionEntry(T)(ref Appender!(ubyte[]) buffer, ref const(T) entry) @system
    {
        // Write ActionId
        writeActionId(buffer, entry.actionId);
        
        // Write inputs array
        writeStringArray(buffer, entry.inputs);
        
        // Write inputHashes map
        writeStringMap(buffer, entry.inputHashes);
        
        // Write outputs array
        writeStringArray(buffer, entry.outputs);
        
        // Write outputHashes map
        writeStringMap(buffer, entry.outputHashes);
        
        // Write metadata map
        writeStringMap(buffer, entry.metadata);
        
        // Write timestamp
        immutable stdTime = entry.timestamp.stdTime;
        buffer.put(nativeToBigEndian(stdTime)[]);
        
        // Write lastAccess
        immutable lastAccessTime = entry.lastAccess.stdTime;
        buffer.put(nativeToBigEndian(lastAccessTime)[]);
        
        // Write executionHash
        writeString(buffer, entry.executionHash);
        
        // Write success flag
        buffer.put(cast(ubyte)(entry.success ? 1 : 0));
    }
    
    /// Read ActionEntry
    private static T readActionEntry(T)(scope const(ubyte)[] data, ref size_t offset) @system
    {
        T entry;
        
        // Read ActionId
        entry.actionId = readActionId(data, offset);
        
        // Read inputs array
        entry.inputs = readStringArray(data, offset);
        
        // Read inputHashes map
        entry.inputHashes = readStringMap(data, offset);
        
        // Read outputs array
        entry.outputs = readStringArray(data, offset);
        
        // Read outputHashes map
        entry.outputHashes = readStringMap(data, offset);
        
        // Read metadata map
        entry.metadata = readStringMap(data, offset);
        
        // Read timestamp
        immutable ubyte[8] stdTimeBytes = data[offset .. offset + 8][0 .. 8];
        immutable stdTime = bigEndianToNative!long(stdTimeBytes);
        offset += 8;
        entry.timestamp = SysTime(stdTime);
        
        // Read lastAccess
        immutable ubyte[8] lastAccessBytes = data[offset .. offset + 8][0 .. 8];
        immutable lastAccessTime = bigEndianToNative!long(lastAccessBytes);
        offset += 8;
        entry.lastAccess = SysTime(lastAccessTime);
        
        // Read executionHash
        entry.executionHash = readString(data, offset);
        
        // Read success flag
        entry.success = data[offset++] != 0;
        
        return entry;
    }
}

