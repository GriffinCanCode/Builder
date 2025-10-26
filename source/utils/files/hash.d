module utils.files.hash;

import std.digest.sha;
import std.file;
import std.stdio;
import std.algorithm;
import std.range;
import std.conv;
import std.mmfile;
import std.bitmanip;

/// Fast hashing utilities with intelligent size-tiered strategy
struct FastHash
{
    // Size thresholds for different hashing strategies
    private enum size_t TINY_THRESHOLD = 4_096;           // 4 KB
    private enum size_t SMALL_THRESHOLD = 1_048_576;      // 1 MB
    private enum size_t MEDIUM_THRESHOLD = 104_857_600;   // 100 MB
    
    // Sampling parameters for medium/large files
    private enum size_t SAMPLE_HEAD = 262_144;    // 256 KB from start
    private enum size_t SAMPLE_TAIL = 262_144;    // 256 KB from end
    private enum size_t SAMPLE_COUNT = 8;          // Number of middle samples
    private enum size_t SAMPLE_SIZE = 16_384;      // 16 KB per sample
    
    /// Hash a file with intelligent size-tiered strategy
    static string hashFile(string path)
    {
        if (!exists(path))
            return "";
        
        auto size = getSize(path);
        
        // Tier 1: Tiny files - direct read
        if (size <= TINY_THRESHOLD)
            return hashFileDirect(path);
        
        // Tier 2: Small files - chunked reading (current approach)
        if (size <= SMALL_THRESHOLD)
            return hashFileChunked(path);
        
        // Tier 3: Medium files - sampled hashing
        if (size <= MEDIUM_THRESHOLD)
            return hashFileSampled(path, size);
        
        // Tier 4: Large files - aggressive sampling with mmap
        return hashFileLargeSampled(path, size);
    }
    
    /// Direct hash for tiny files
    private static string hashFileDirect(string path)
    {
        auto data = cast(ubyte[])std.file.read(path);
        return toHexString(sha256Of(data)).idup;
    }
    
    /// Chunked hash for small files (original approach)
    private static string hashFileChunked(string path)
    {
        auto file = File(path, "rb");
        SHA256 hash;
        
        ubyte[4096] buffer;
        
        while (!file.eof())
        {
            auto chunk = file.rawRead(buffer);
            hash.put(chunk);
        }
        
        return toHexString(hash.finish()).idup;
    }
    
    /// Sampled hash for medium files (head + tail + middle samples)
    private static string hashFileSampled(string path, size_t fileSize)
    {
        SHA256 hash;
        
        // Include file size in hash to prevent collisions
        hash.put(nativeToLittleEndian(fileSize)[]);
        
        auto file = File(path, "rb");
        
        // Hash head
        size_t headSize = min(SAMPLE_HEAD, fileSize);
        auto headBuffer = new ubyte[headSize];
        file.rawRead(headBuffer);
        hash.put(headBuffer);
        
        // Hash tail if file is large enough
        if (fileSize > SAMPLE_HEAD + SAMPLE_TAIL)
        {
            file.seek(fileSize - SAMPLE_TAIL);
            auto tailBuffer = new ubyte[SAMPLE_TAIL];
            file.rawRead(tailBuffer);
            hash.put(tailBuffer);
        }
        
        // Hash middle samples
        if (fileSize > SAMPLE_HEAD + SAMPLE_TAIL + SAMPLE_SIZE * SAMPLE_COUNT)
        {
            size_t middleStart = SAMPLE_HEAD;
            size_t middleEnd = fileSize - SAMPLE_TAIL;
            size_t middleSize = middleEnd - middleStart;
            size_t step = middleSize / (SAMPLE_COUNT + 1);
            
            auto sampleBuffer = new ubyte[SAMPLE_SIZE];
            
            foreach (i; 0 .. SAMPLE_COUNT)
            {
                size_t pos = middleStart + step * (i + 1);
                file.seek(pos);
                auto bytesRead = file.rawRead(sampleBuffer[0 .. min(SAMPLE_SIZE, fileSize - pos)]);
                hash.put(bytesRead);
            }
        }
        
        return toHexString(hash.finish()).idup;
    }
    
    /// Aggressive sampling for large files using memory mapping
    private static string hashFileLargeSampled(string path, size_t fileSize)
    {
        SHA256 hash;
        
        // Include file size
        hash.put(nativeToLittleEndian(fileSize)[]);
        
        try
        {
            // Use memory-mapped file for efficient access
            auto mmfile = new MmFile(path, MmFile.Mode.read, 0, null);
            auto data = cast(ubyte[])mmfile[];
            
            // Hash first 512KB
            size_t headSize = min(524_288, fileSize);
            hash.put(data[0 .. headSize]);
            
            // Hash last 512KB
            if (fileSize > 1_048_576)
            {
                hash.put(data[$ - 524_288 .. $]);
            }
            
            // Hash 16 samples from middle
            if (fileSize > 2_097_152)
            {
                size_t middleStart = 524_288;
                size_t middleEnd = fileSize - 524_288;
                size_t step = (middleEnd - middleStart) / 17;
                
                foreach (i; 0 .. 16)
                {
                    size_t pos = middleStart + step * (i + 1);
                    size_t sampleEnd = min(pos + 32_768, middleEnd);
                    hash.put(data[pos .. sampleEnd]);
                }
            }
            
            destroy(mmfile);
        }
        catch (Exception e)
        {
            // Fallback to sampled approach if mmap fails
            return hashFileSampled(path, fileSize);
        }
        
        return toHexString(hash.finish()).idup;
    }
    
    /// Hash a string
    static string hashString(string content)
    {
        return toHexString(sha256Of(content)).idup;
    }
    
    /// Hash multiple strings together
    static string hashStrings(string[] strings)
    {
        SHA256 hash;
        foreach (s; strings)
            hash.put(cast(ubyte[])s);
        return toHexString(hash.finish()).idup;
    }
    
    /// Hash file metadata (size + mtime) for quick checks
    /// 1000x faster than content hash for unchanged files
    static string hashMetadata(string path)
    {
        if (!exists(path))
            return "";
        
        auto info = DirEntry(path);
        auto data = path ~ info.size.to!string ~ info.timeLastModified.toISOExtString();
        return hashString(data);
    }
    
    /// Two-tier hash: check metadata first, only hash content if changed
    /// Returns tuple: (metadataHash, contentHash, contentHashed)
    static TwoTierHash hashFileTwoTier(string path, string oldMetadataHash = "")
    {
        TwoTierHash result;
        
        if (!exists(path))
            return result;
        
        // Always compute metadata hash (fast)
        result.metadataHash = hashMetadata(path);
        
        // Only compute content hash if metadata changed
        if (oldMetadataHash.empty || result.metadataHash != oldMetadataHash)
        {
            result.contentHash = hashFile(path);
            result.contentHashed = true;
        }
        else
        {
            result.contentHash = ""; // Not needed, metadata unchanged
            result.contentHashed = false;
        }
        
        return result;
    }
}

/// Result of two-tier hashing
struct TwoTierHash
{
    string metadataHash;    // Fast: mtime + size
    string contentHash;     // Slow: SHA-256 of content
    bool contentHashed;     // Whether content was actually hashed
}

