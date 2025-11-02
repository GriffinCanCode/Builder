module core.caching.storage.cas;

import std.file : exists, read, write, remove, mkdirRecurse, dirEntries, SpanMode;
import std.path : buildPath, dirName;
import std.algorithm : map, filter;
import std.array : array;
import std.conv : to;
import core.sync.mutex : Mutex;
import utils.files.hash : FastHash;
import errors;

/// Content-addressable storage with automatic deduplication
/// Stores blobs by content hash, enabling zero-copy artifact sharing
final class ContentAddressableStorage
{
    private string storageDir;
    private Mutex storageMutex;
    private size_t[string] refCounts;  // Track blob references
    
    this(string storageDir = ".builder-cache/blobs") @system
    {
        this.storageDir = storageDir;
        this.storageMutex = new Mutex();
        
        if (!exists(storageDir))
            mkdirRecurse(storageDir);
    }
    
    /// Store blob by content hash (deduplicates automatically)
    /// Returns: content hash of stored blob
    Result!(string, BuildError) putBlob(const(ubyte)[] data) @system
    {
        try
        {
            // Compute content hash
            immutable hash = FastHash.hashBytes(data);
            immutable blobPath = getBlobPath(hash);
            
            synchronized (storageMutex)
            {
                // Check if blob already exists (deduplication)
                if (exists(blobPath))
                {
                    // Increment reference count
                    if (hash in refCounts)
                        refCounts[hash]++;
                    else
                        refCounts[hash] = 2;  // Existing + new reference
                    
                    return Ok!(string, BuildError)(hash);
                }
                
                // Store new blob
                immutable dir = dirName(blobPath);
                if (!exists(dir))
                    mkdirRecurse(dir);
                
                write(blobPath, data);
                refCounts[hash] = 1;
            }
            
            return Ok!(string, BuildError)(hash);
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Failed to store blob: " ~ e.msg,
                ErrorCode.CacheWriteFailed
            );
            return Err!(string, BuildError)(error);
        }
    }
    
    /// Retrieve blob by content hash
    Result!(ubyte[], BuildError) getBlob(string hash) @system
    {
        try
        {
            immutable blobPath = getBlobPath(hash);
            
            synchronized (storageMutex)
            {
                if (!exists(blobPath))
                {
                    auto error = new CacheError(
                        "Blob not found: " ~ hash,
                        ErrorCode.CacheNotFound
                    );
                    return Err!(ubyte[], BuildError)(error);
                }
                
                auto data = cast(ubyte[])read(blobPath);
                return Ok!(ubyte[], BuildError)(data);
            }
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Failed to read blob: " ~ e.msg,
                ErrorCode.CacheLoadFailed
            );
            return Err!(ubyte[], BuildError)(error);
        }
    }
    
    /// Check if blob exists
    bool hasBlob(string hash) @system
    {
        synchronized (storageMutex)
        {
            return exists(getBlobPath(hash));
        }
    }
    
    /// Increment reference count for blob
    void addRef(string hash) @system
    {
        synchronized (storageMutex)
        {
            if (hash in refCounts)
                refCounts[hash]++;
            else
                refCounts[hash] = 1;
        }
    }
    
    /// Decrement reference count for blob
    /// Returns: true if blob can be deleted (ref count reached zero)
    bool removeRef(string hash) @system
    {
        synchronized (storageMutex)
        {
            if (hash !in refCounts)
                return true;
            
            refCounts[hash]--;
            
            if (refCounts[hash] <= 0)
            {
                refCounts.remove(hash);
                return true;
            }
            
            return false;
        }
    }
    
    /// Delete blob (only if no references)
    Result!BuildError deleteBlob(string hash) @system
    {
        try
        {
            synchronized (storageMutex)
            {
                // Check reference count
                if (hash in refCounts && refCounts[hash] > 0)
                {
                    auto error = new CacheError(
                        "Cannot delete blob with active references",
                        ErrorCode.CacheInUse
                    );
                    return Result!BuildError.err(error);
                }
                
                immutable blobPath = getBlobPath(hash);
                if (exists(blobPath))
                    remove(blobPath);
                
                refCounts.remove(hash);
            }
            
            return Ok!BuildError();
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Failed to delete blob: " ~ e.msg,
                ErrorCode.CacheDeleteFailed
            );
            return Result!BuildError.err(error);
        }
    }
    
    /// Get all blob hashes
    string[] listBlobs() @system
    {
        synchronized (storageMutex)
        {
            try
            {
                return dirEntries(storageDir, SpanMode.depth)
                    .filter!(e => e.isFile)
                    .map!(e => extractHashFromPath(e.name))
                    .array;
            }
            catch (Exception)
            {
                return [];
            }
        }
    }
    
    /// Get storage statistics
    struct StorageStats
    {
        size_t totalBlobs;
        size_t totalSize;
        size_t uniqueBlobs;
        size_t duplicateRefs;
        float deduplicationRatio;
    }
    
    StorageStats getStats() @system
    {
        synchronized (storageMutex)
        {
            StorageStats stats;
            stats.uniqueBlobs = refCounts.length;
            
            foreach (hash, count; refCounts)
            {
                stats.totalBlobs += count;
                if (count > 1)
                    stats.duplicateRefs += (count - 1);
            }
            
            // Calculate total size
            try
            {
                foreach (entry; dirEntries(storageDir, SpanMode.depth))
                {
                    if (entry.isFile)
                        stats.totalSize += entry.size;
                }
            }
            catch (Exception) {}
            
            // Deduplication ratio
            if (stats.totalBlobs > 0)
                stats.deduplicationRatio = (stats.uniqueBlobs * 100.0) / stats.totalBlobs;
            
            return stats;
        }
    }
    
    /// Get blob path from hash (uses sharding for performance)
    private string getBlobPath(string hash) const pure @safe
    {
        // Shard by first 2 characters for better filesystem performance
        if (hash.length < 2)
            return buildPath(storageDir, "00", hash);
        
        immutable shard = hash[0 .. 2];
        return buildPath(storageDir, shard, hash);
    }
    
    /// Extract hash from full path
    private string extractHashFromPath(string path) const pure @safe
    {
        import std.path : baseName;
        return baseName(path);
    }
}

