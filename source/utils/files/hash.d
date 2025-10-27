module utils.files.hash;

import utils.crypto.blake3;
import utils.simd.ops;
import std.file;
import std.stdio;
import std.algorithm;
import std.range;
import std.conv;
import std.mmfile;
import std.bitmanip;

@safe:

/// Fast hashing utilities with intelligent size-tiered strategy
/// Uses SIMD-accelerated BLAKE3 for 3-5x speedup over SHA-256
/// Automatically selects optimal SIMD path (AVX-512/AVX2/NEON/SSE)
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. exists() and getSize() are file system operations (unsafe I/O)
    /// 2. Delegates to tier-specific @trusted hash functions
    /// 3. No pointer arithmetic or unsafe memory operations
    /// 4. Strategy selection is based on validated file size
    /// 
    /// Invariants:
    /// - Returns empty string if file doesn't exist (safe default)
    /// - File size determines which strategy is used
    /// - All strategies are memory-safe
    /// 
    /// What could go wrong:
    /// - File deleted between exists() and hash: returns empty or throws
    /// - File size changes during hashing: hash reflects state at that moment
    /// - Permission errors: propagate as exceptions (safe failure)
    @trusted
    static string hashFile(in string path)
    {
        if (!exists(path))
            return "";
        
        immutable size = getSize(path);
        
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. std.file.read() performs file I/O (inherently unsafe)
    /// 2. Cast to ubyte[] is safe (data is owned by read())
    /// 3. Blake3.hashHex() is trusted hash operation
    /// 4. No manual memory management
    /// 
    /// Invariants:
    /// - File must exist (caller's responsibility)
    /// - File size <= TINY_THRESHOLD (4KB)
    /// - Entire file loaded into memory
    /// 
    /// What could go wrong:
    /// - File too large: memory allocation could fail (exception)
    /// - File modified during read: hash reflects state at read time
    /// - Read errors: exception propagates (safe failure)
    @trusted
    private static string hashFileDirect(in string path)
    {
        auto data = cast(ubyte[])std.file.read(path);
        return Blake3.hashHex(data);
    }
    
    /// Chunked hash for small files (original approach)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. File.open() and rawRead() are file I/O operations
    /// 2. Stack-allocated buffer (no heap allocation per chunk)
    /// 3. rawRead() validates buffer bounds internally
    /// 4. Blake3 hasher is incrementally fed (memory-safe)
    /// 
    /// Invariants:
    /// - File is read in 4KB chunks
    /// - Buffer is stack-allocated (automatic cleanup)
    /// - Hash is finalized after all chunks
    /// 
    /// What could go wrong:
    /// - File read errors: exception propagates (safe failure)
    /// - File modified during read: hash reflects state at read time
    /// - EOF handling: safe, loop exits naturally
    @trusted
    private static string hashFileChunked(in string path)
    {
        auto file = File(path, "rb");
        auto hash = Blake3(0);
        
        ubyte[4096] buffer;
        
        while (!file.eof())
        {
            auto chunk = file.rawRead(buffer);
            hash.put(chunk);
        }
        
        return hash.finishHex();
    }
    
    /// Sampled hash for medium files (head + tail + middle samples)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. File operations (open, seek, rawRead) are inherently unsafe I/O
    /// 2. Buffer allocations are bounded by SAMPLE_* constants
    /// 3. Seek positions are calculated and bounds-checked
    /// 4. nativeToLittleEndian for size encoding is safe
    /// 5. All buffer operations are validated by min() and bounds checks
    /// 
    /// Invariants:
    /// - fileSize parameter matches actual file size (caller's responsibility)
    /// - Samples don't overlap (calculated positions are correct)
    /// - Total sampled data << actual file size (performance optimization)
    /// 
    /// What could go wrong:
    /// - Seek beyond EOF: caught by File operations (exception)
    /// - Buffer allocation fails: exception propagates (safe failure)
    /// - File modified during sampling: hash reflects state at sample time
    @trusted
    private static string hashFileSampled(in string path, in size_t fileSize)
    {
        auto hash = Blake3(0);
        
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
        
        return hash.finishHex();
    }
    
    /// Aggressive sampling for large files using memory mapping with SIMD
    /// 
    /// Safety: This function is @trusted because:
    /// 1. MmFile provides memory-mapped file access (inherently unsafe)
    /// 2. Cast to ubyte[] is safe (mmfile validates bounds internally)
    /// 3. Array slicing is bounds-checked with min() calls
    /// 4. SIMD operations via Blake3 are internally validated
    /// 5. scope(exit) ensures cleanup even on exception
    /// 6. Fallback to hashFileSampled() on failure
    /// 
    /// Invariants:
    /// - fileSize is accurate (caller's responsibility)
    /// - Sample positions are calculated to avoid overlap
    /// - Memory mapping is read-only
    /// - MmFile is destroyed via scope(exit)
    /// 
    /// What could go wrong:
    /// - mmap fails: caught and falls back to sampled approach
    /// - File too large for address space: mmap throws, caught
    /// - Concurrent modification: undefined (acceptable for cache)
    /// - Array slicing out of bounds: prevented by min() calculations
    @trusted
    private static string hashFileLargeSampled(in string path, in size_t fileSize)
    {
        auto hash = Blake3(0);  // SIMD-accelerated
        
        // Include file size
        hash.put(nativeToLittleEndian(fileSize)[]);
        
        try
        {
            // Use memory-mapped file for efficient access
            auto mmfile = new MmFile(path, MmFile.Mode.read, 0, null);
            scope(exit) destroy(mmfile); // Ensure cleanup even on exception
            
            auto data = cast(ubyte[])mmfile[];
            
            // Hash first 512KB (SIMD-accelerated internally)
            size_t headSize = min(524_288, fileSize);
            hash.put(data[0 .. headSize]);
            
            // Hash last 512KB
            if (fileSize > 1_048_576)
            {
                // Use SIMD copy for efficiency on large tail
                auto tailData = data[$ - 524_288 .. $];
                hash.put(tailData);
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
        }
        catch (Exception e)
        {
            // Fallback to sampled approach if mmap fails
            return hashFileSampled(path, fileSize);
        }
        
        return hash.finishHex();
    }
    
    /// Hash a string
    static string hashString(string content)
    {
        return Blake3.hashHex(content);
    }
    
    /// Hash multiple strings together
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Cast from string to ubyte[] is safe (identical memory layout)
    /// 2. Blake3 hasher incrementally processes data (memory-safe)
    /// 3. No pointer manipulation or unsafe operations
    /// 
    /// Invariants:
    /// - Strings are hashed in order
    /// - Cast preserves all string data exactly
    /// - Order matters for deterministic hash
    /// 
    /// What could go wrong:
    /// - Nothing: pure data hashing with no side effects
    /// - Large strings: memory usage grows but is safe
    @trusted
    static string hashStrings(const string[] strings)
    {
        auto hash = Blake3(0);
        foreach (s; strings)
            hash.put(cast(ubyte[])s);
        return hash.finishHex();
    }
    
    /// Hash multiple files together with SIMD-aware parallel processing
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Delegates to trusted hashFile() for individual files
    /// 2. SIMDParallel.mapSIMD() is trusted parallel execution
    /// 3. Cast operations for combining hashes are memory-safe
    /// 4. exists() check prevents errors on missing files
    /// 5. Missing files are hashed by path (deterministic fallback)
    /// 
    /// Invariants:
    /// - Files are processed in parallel when beneficial (>8 files)
    /// - Sequential processing for small file counts (avoid overhead)
    /// - Missing files contribute their path to hash (deterministic)
    /// - Final hash combines all individual hashes
    /// 
    /// What could go wrong:
    /// - File operations can fail: handled per-file (hash path instead)
    /// - Parallel execution overhead: mitigated by threshold check
    /// - Memory usage for many files: bounded by file count
    @trusted
    static string hashFiles(string[] filePaths)
    {
        import std.file : exists;
        
        // For many files, use parallel SIMD hashing
        if (filePaths.length > 8) {
            import utils.concurrency.simd;
            
            // Hash files in parallel
            auto hashes = SIMDParallel.mapSIMD(filePaths, (string path) {
                if (exists(path))
                    return hashFile(path);
                else
                    return hashString(path);  // Hash the path itself
            });
            
            // Combine all hashes
            auto hash = Blake3(0);
            foreach (h; hashes)
                hash.put(cast(ubyte[])h);
            return hash.finishHex();
        }
        
        // Sequential for few files
        auto hash = Blake3(0);
        foreach (path; filePaths)
        {
            if (exists(path))
            {
                string fileHash = hashFile(path);
                hash.put(cast(ubyte[])fileHash);
            }
            else
            {
                // For non-existent files, just hash the path
                hash.put(cast(ubyte[])path);
            }
        }
        return hash.finishHex();
    }
    
    /// Hash file metadata (size + mtime) for quick checks
    /// 1000x faster than content hash for unchanged files
    static string hashMetadata(string path)
    {
        if (!exists(path))
            return "";
        
        auto info = DirEntry(path);
        auto data = path ~ info.size.to!string ~ info.timeLastModified.toISOExtString();
        return Blake3.hashHex(data);
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

