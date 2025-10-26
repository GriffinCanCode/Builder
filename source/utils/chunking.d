module utils.chunking;

import std.digest.sha;
import std.file;
import std.stdio;
import std.algorithm;
import std.range;
import std.conv;
import std.array : appender;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;

/// Content-defined chunking for incremental hashing
/// Uses Rabin fingerprinting to identify chunk boundaries
/// Similar to rsync and git's approach
struct ContentChunker
{
    // Rabin fingerprint parameters
    private enum ulong POLYNOMIAL = 0x3DA3358B4DC173;
    private enum uint WINDOW_SIZE = 64;
    
    // Chunk size constraints
    private enum size_t MIN_CHUNK = 2_048;      // 2 KB minimum
    private enum size_t AVG_CHUNK = 16_384;     // 16 KB average
    private enum size_t MAX_CHUNK = 65_536;     // 64 KB maximum
    
    // Boundary detection mask (determines average chunk size)
    private enum ulong MASK = (1UL << 14) - 1;  // 14 bits = ~16KB average
    
    /// Chunk metadata for incremental updates
    struct Chunk
    {
        size_t offset;      // Byte offset in file
        size_t length;      // Chunk length
        string hash;        // SHA-256 hash of chunk content
    }
    
    /// Result of chunking operation
    struct ChunkResult
    {
        Chunk[] chunks;
        string combinedHash;  // Hash of all chunk hashes (file signature)
    }
    
    /// Chunk a file using content-defined boundaries
    static ChunkResult chunkFile(string path)
    {
        ChunkResult result;
        
        if (!exists(path))
            return result;
        
        auto size = getSize(path);
        if (size == 0)
            return result;
        
        auto file = File(path, "rb");
        
        size_t offset = 0;
        ubyte[MAX_CHUNK] buffer;
        ulong fingerprint = 0;
        size_t chunkStart = 0;
        
        SHA256 combinedHasher;  // Hash all chunk hashes
        
        while (!file.eof())
        {
            auto bytesRead = file.rawRead(buffer);
            if (bytesRead.empty)
                break;
            
            foreach (i, b; bytesRead)
            {
                // Update rolling hash (Rabin fingerprint)
                fingerprint = ((fingerprint << 1) | (fingerprint >> 63)) ^ b;
                
                size_t currentPos = offset + i;
                size_t chunkLen = currentPos - chunkStart + 1;
                
                // Check for chunk boundary
                bool isBoundary = false;
                
                if (chunkLen >= MIN_CHUNK)
                {
                    // Check if fingerprint matches mask (content-defined boundary)
                    if ((fingerprint & MASK) == 0)
                        isBoundary = true;
                    
                    // Force boundary at max chunk size
                    if (chunkLen >= MAX_CHUNK)
                        isBoundary = true;
                }
                
                if (isBoundary)
                {
                    // Create chunk
                    Chunk chunk;
                    chunk.offset = chunkStart;
                    chunk.length = chunkLen;
                    chunk.hash = hashChunk(file, chunkStart, chunkLen);
                    
                    result.chunks ~= chunk;
                    combinedHasher.put(cast(ubyte[])chunk.hash);
                    
                    chunkStart = currentPos + 1;
                    fingerprint = 0;
                }
            }
            
            offset += bytesRead.length;
        }
        
        // Handle final chunk if there's remaining data
        if (chunkStart < offset)
        {
            Chunk chunk;
            chunk.offset = chunkStart;
            chunk.length = offset - chunkStart;
            chunk.hash = hashChunk(file, chunkStart, chunk.length);
            
            result.chunks ~= chunk;
            combinedHasher.put(cast(ubyte[])chunk.hash);
        }
        
        result.combinedHash = toHexString(combinedHasher.finish()).idup;
        return result;
    }
    
    /// Hash a specific chunk of a file
    private static string hashChunk(ref File file, size_t offset, size_t length)
    {
        file.seek(offset);
        
        SHA256 hasher;
        ubyte[4096] buffer;
        size_t remaining = length;
        
        while (remaining > 0)
        {
            size_t toRead = min(buffer.length, remaining);
            auto chunk = file.rawRead(buffer[0 .. toRead]);
            hasher.put(chunk);
            remaining -= chunk.length;
        }
        
        return toHexString(hasher.finish()).idup;
    }
    
    /// Compare two chunk results and identify changed chunks
    static size_t[] findChangedChunks(ChunkResult oldChunks, ChunkResult newChunks)
    {
        size_t[] changedIndices;
        
        // Simple comparison - in practice you'd use a more sophisticated algorithm
        size_t maxLen = max(oldChunks.chunks.length, newChunks.chunks.length);
        
        foreach (i; 0 .. maxLen)
        {
            if (i >= oldChunks.chunks.length || i >= newChunks.chunks.length)
            {
                changedIndices ~= i;
            }
            else if (oldChunks.chunks[i].hash != newChunks.chunks[i].hash)
            {
                changedIndices ~= i;
            }
        }
        
        return changedIndices;
    }
    
    /// Serialize chunk metadata for caching
    static ubyte[] serialize(ChunkResult result)
    {
        auto buffer = appender!(ubyte[]);
        
        // Write number of chunks
        buffer.put(nativeToBigEndian(cast(uint)result.chunks.length)[]);
        
        // Write combined hash
        buffer.put(nativeToBigEndian(cast(uint)result.combinedHash.length)[]);
        buffer.put(cast(ubyte[])result.combinedHash);
        
        // Write each chunk
        foreach (chunk; result.chunks)
        {
            buffer.put(nativeToBigEndian(cast(ulong)chunk.offset)[]);
            buffer.put(nativeToBigEndian(cast(ulong)chunk.length)[]);
            buffer.put(nativeToBigEndian(cast(uint)chunk.hash.length)[]);
            buffer.put(cast(ubyte[])chunk.hash);
        }
        
        return buffer.data;
    }
    
    /// Deserialize chunk metadata
    static ChunkResult deserialize(ubyte[] data)
    {
        ChunkResult result;
        size_t offset = 0;
        
        if (data.length < 4)
            return result;
        
        // Read number of chunks
        ubyte[4] countBytes = data[offset .. offset + 4][0 .. 4];
        auto count = bigEndianToNative!uint(countBytes);
        offset += 4;
        
        // Read combined hash
        ubyte[4] hashLenBytes = data[offset .. offset + 4][0 .. 4];
        auto hashLen = bigEndianToNative!uint(hashLenBytes);
        offset += 4;
        
        result.combinedHash = cast(string)data[offset .. offset + hashLen];
        offset += hashLen;
        
        // Read chunks
        foreach (_; 0 .. count)
        {
            Chunk chunk;
            
            ubyte[8] offsetBytes = data[offset .. offset + 8][0 .. 8];
            chunk.offset = bigEndianToNative!ulong(offsetBytes);
            offset += 8;
            
            ubyte[8] lengthBytes = data[offset .. offset + 8][0 .. 8];
            chunk.length = bigEndianToNative!ulong(lengthBytes);
            offset += 8;
            
            ubyte[4] chunkHashLenBytes = data[offset .. offset + 4][0 .. 4];
            auto chunkHashLen = bigEndianToNative!uint(chunkHashLenBytes);
            offset += 4;
            
            chunk.hash = cast(string)data[offset .. offset + chunkHashLen];
            offset += chunkHashLen;
            
            result.chunks ~= chunk;
        }
        
        return result;
    }
}

/// Rolling hash implementation (Rabin fingerprint variant)
struct RollingHash
{
    private ulong hash;
    private ulong polynomial;
    
    this(ulong poly)
    {
        this.polynomial = poly;
        this.hash = 0;
    }
    
    /// Update hash with new byte
    void update(ubyte b)
    {
        hash = ((hash << 1) | (hash >> 63)) ^ (b * polynomial);
    }
    
    /// Get current hash value
    ulong value() const
    {
        return hash;
    }
    
    /// Reset hash
    void reset()
    {
        hash = 0;
    }
}

