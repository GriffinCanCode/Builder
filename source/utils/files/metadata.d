module utils.files.metadata;

import std.file;
import std.datetime;
import std.conv;
import std.algorithm;
import std.array : appender;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import utils.crypto.blake3;
import utils.simd.ops;

version(Posix)
{
    import core.sys.posix.sys.stat;
}

/// Advanced file metadata for high-performance cache validation
struct FileMetadata
{
    string path;
    size_t size;
    SysTime mtime;
    ulong inode;        // Unix inode or Windows file index
    ulong device;       // Device ID (detects moves across filesystems)
    bool isSymlink;
    string hash;        // Hash of all metadata fields
    
    /// Create metadata from file path
    @system // File system and platform-specific system calls
    static FileMetadata from(string path)
    {
        FileMetadata meta;
        meta.path = path;
        
        if (!exists(path))
            return meta;
        
        auto entry = DirEntry(path);
        meta.size = entry.size;
        meta.mtime = entry.timeLastModified;
        meta.isSymlink = entry.isSymlink;
        
        // Get inode and device info (platform-specific)
        version(Posix)
        {
            stat_t statbuf;
            if (stat(path.ptr, &statbuf) == 0)
            {
                meta.inode = statbuf.st_ino;
                meta.device = statbuf.st_dev;
            }
        }
        version(Windows)
        {
            // On Windows, use file index as inode equivalent
            import core.sys.windows.windows;
            
            auto handle = CreateFileW(
                cast(wchar*)path.ptr,
                0,
                FILE_SHARE_READ,
                null,
                OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL,
                null
            );
            
            if (handle != INVALID_HANDLE_VALUE)
            {
                BY_HANDLE_FILE_INFORMATION info;
                if (GetFileInformationByHandle(handle, &info))
                {
                    meta.inode = (cast(ulong)info.nFileIndexHigh << 32) | info.nFileIndexLow;
                    meta.device = info.dwVolumeSerialNumber;
                }
                CloseHandle(handle);
            }
        }
        
        meta.hash = meta.computeHash();
        return meta;
    }
    
    /// Compute hash of metadata (SIMD-accelerated BLAKE3)
    @system // Uses trusted Blake3 hasher
    string computeHash() const
    {
        auto hasher = Blake3(0);  // SIMD-accelerated
        
        hasher.put(cast(ubyte[])path);
        hasher.put(nativeToBigEndian(size)[]);
        hasher.put(nativeToBigEndian(mtime.stdTime)[]);
        hasher.put(nativeToBigEndian(inode)[]);
        hasher.put(nativeToBigEndian(device)[]);
        ubyte[1] symlinkByte = [cast(ubyte)isSymlink];
        hasher.put(symlinkByte[]);
        
        return hasher.finishHex();
    }
    
    /// Quick equality check (size only - fastest)
    bool quickEquals(ref const FileMetadata other) const
    {
        return size == other.size;
    }
    
    /// Fast equality check (size + mtime)
    bool fastEquals(ref const FileMetadata other) const
    {
        return size == other.size && mtime == other.mtime;
    }
    
    /// Full equality check (all fields)
    bool equals(ref const FileMetadata other) const
    {
        return size == other.size 
            && mtime == other.mtime
            && inode == other.inode
            && device == other.device
            && path == other.path;
    }
    
    /// Check if file has been moved (same inode, different path)
    bool wasMoved(ref const FileMetadata other) const
    {
        return inode == other.inode 
            && device == other.device
            && inode != 0
            && path != other.path;
    }
    
    /// Serialize metadata
    @system // Safe casts for serialization
    ubyte[] serialize() const
    {
        auto buffer = appender!(ubyte[]);
        
        // Path
        buffer.put(nativeToBigEndian(cast(uint)path.length)[]);
        buffer.put(cast(ubyte[])path);
        
        // Numeric fields
        buffer.put(nativeToBigEndian(size)[]);
        buffer.put(nativeToBigEndian(mtime.stdTime)[]);
        buffer.put(nativeToBigEndian(inode)[]);
        buffer.put(nativeToBigEndian(device)[]);
        buffer.put(cast(ubyte)isSymlink);
        
        // Hash
        buffer.put(nativeToBigEndian(cast(uint)hash.length)[]);
        buffer.put(cast(ubyte[])hash);
        
        return buffer.data;
    }
    
    /// Deserialize metadata
    @system // Array slicing and casts operations
    static FileMetadata deserialize(ubyte[] data)
    {
        FileMetadata meta;
        size_t offset = 0;
        
        if (data.length < 4)
            return meta;
        
        // Path
        ubyte[4] pathLenBytes = data[offset .. offset + 4][0 .. 4];
        auto pathLen = bigEndianToNative!uint(pathLenBytes);
        offset += 4;
        meta.path = cast(string)data[offset .. offset + pathLen];
        offset += pathLen;
        
        // Size
        ubyte[8] sizeBytes = data[offset .. offset + 8][0 .. 8];
        meta.size = bigEndianToNative!size_t(sizeBytes);
        offset += 8;
        
        // Mtime
        ubyte[8] mtimeBytes = data[offset .. offset + 8][0 .. 8];
        meta.mtime = SysTime(bigEndianToNative!long(mtimeBytes));
        offset += 8;
        
        // Inode
        ubyte[8] inodeBytes = data[offset .. offset + 8][0 .. 8];
        meta.inode = bigEndianToNative!ulong(inodeBytes);
        offset += 8;
        
        // Device
        ubyte[8] deviceBytes = data[offset .. offset + 8][0 .. 8];
        meta.device = bigEndianToNative!ulong(deviceBytes);
        offset += 8;
        
        // Symlink flag
        meta.isSymlink = cast(bool)data[offset++];
        
        // Hash
        ubyte[4] hashLenBytes = data[offset .. offset + 4][0 .. 4];
        auto hashLen = bigEndianToNative!uint(hashLenBytes);
        offset += 4;
        meta.hash = cast(string)data[offset .. offset + hashLen];
        
        return meta;
    }
}

/// Three-tier metadata checking strategy
struct MetadataChecker
{
    /// Check result levels
    enum CheckLevel
    {
        Identical,      // Files are definitely identical
        ProbablySame,   // Likely same (quick/fast check passed)
        Different,      // Files are different
        Unknown         // Need content hash to determine
    }
    
    /// Three-tier check: quick -> fast -> full
    static CheckLevel check(ref const FileMetadata old, ref const FileMetadata new_)
    {
        // Tier 1: Quick check (size only) - 1ns
        if (!old.quickEquals(new_))
            return CheckLevel.Different;
        
        // Tier 2: Fast check (size + mtime) - 10ns
        if (!old.fastEquals(new_))
            return CheckLevel.Unknown;
        
        // Tier 3: Full check (all metadata) - 100ns
        if (old.equals(new_))
            return CheckLevel.Identical;
        
        // Metadata changed but might be false positive
        return CheckLevel.Unknown;
    }
    
    /// Batch check multiple files in parallel with SIMD-aware execution
    @system // Parallel processing and file operations
    static CheckLevel[] checkBatch(FileMetadata[] oldFiles, string[] paths)
    {
        import utils.concurrency.simd;
        import std.range : iota, array, empty;
        
        if (paths.empty)
            return [];
        
        // Use SIMD-aware parallel processing
        auto results = SIMDParallel.mapSIMD(
            iota(paths.length).array,
            (ulong i) {
                auto newMeta = FileMetadata.from(paths[i]);
                
                if (i < oldFiles.length)
                    return check(oldFiles[i], newMeta);
                else
                    return CheckLevel.Different;
            }
        );
        
        return results;
    }
}

/// Metadata cache for fast lookups
struct MetadataCache
{
    private FileMetadata[string] cache;
    
    /// Get or create metadata for path
    FileMetadata get(string path)
    {
        if (auto existing = path in cache)
            return *existing;
        
        auto meta = FileMetadata.from(path);
        cache[path] = meta;
        return meta;
    }
    
    /// Update metadata for path
    void update(string path)
    {
        cache[path] = FileMetadata.from(path);
    }
    
    /// Remove metadata for path
    void remove(string path)
    {
        cache.remove(path);
    }
    
    /// Clear entire cache
    void clear()
    {
        cache.clear();
    }
    
    /// Get cache size
    size_t length() const
    {
        return cache.length;
    }
}

