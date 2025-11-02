module core.distributed.storage.store;

import std.file : exists, read, write, mkdirRecurse, remove;
import std.path : buildPath, dirName;
import std.algorithm : min, filter, sort, sum;
import std.array : array;
import std.datetime : Clock, SysTime, Duration;
import core.sync.mutex : Mutex;
import core.distributed.protocol.protocol;
import errors;

/// Artifact store interface
interface ArtifactStore
{
    /// Check if artifact exists
    Result!(bool, DistributedError) has(ArtifactId id);
    
    /// Fetch artifact data
    Result!(ubyte[], DistributedError) get(ArtifactId id);
    
    /// Store artifact data
    Result!(ArtifactId, DistributedError) put(ubyte[] data);
    
    /// Batch operations (more efficient)
    Result!(bool[], DistributedError) hasMany(ArtifactId[] ids);
    Result!(ubyte[][], DistributedError) getMany(ArtifactId[] ids);
}

/// Local filesystem artifact store
final class LocalArtifactStore : ArtifactStore
{
    private string cacheDir;
    private Mutex mutex;
    private size_t maxSize;
    private size_t currentSize;
    
    /// Cache entry metadata
    private struct CacheEntry
    {
        ArtifactId id;
        size_t size;
        SysTime lastAccess;
    }
    
    private CacheEntry[ArtifactId] entries;
    
    this(string cacheDir, size_t maxSize) @trusted
    {
        this.cacheDir = cacheDir;
        this.maxSize = maxSize;
        this.mutex = new Mutex();
        
        // Ensure cache directory exists
        if (!exists(cacheDir))
            mkdirRecurse(cacheDir);
        
        // Load existing entries
        loadEntries();
    }
    
    Result!(bool, DistributedError) has(ArtifactId id) @trusted
    {
        synchronized (mutex)
        {
            immutable path = artifactPath(id);
            return Ok!(bool, DistributedError)(exists(path));
        }
    }
    
    Result!(ubyte[], DistributedError) get(ArtifactId id) @trusted
    {
        synchronized (mutex)
        {
            immutable path = artifactPath(id);
            
            if (!exists(path))
                return Err!(ubyte[], DistributedError)(
                    new DistributedError("Artifact not found: " ~ id.toString()));
            
            try
            {
                auto data = cast(ubyte[])read(path);
                
                // Update access time (LRU)
                if (auto entry = id in entries)
                    entry.lastAccess = Clock.currTime;
                
                return Ok!(ubyte[], DistributedError)(data);
            }
            catch (Exception e)
            {
                return Err!(ubyte[], DistributedError)(
                    new DistributedError("Failed to read artifact: " ~ e.msg));
            }
        }
    }
    
    Result!(ArtifactId, DistributedError) put(ubyte[] data) @trusted
    {
        // Compute content hash (BLAKE3)
        auto id = computeArtifactId(data);
        
        synchronized (mutex)
        {
            immutable path = artifactPath(id);
            
            // Skip if already exists
            if (exists(path))
                return Ok!(ArtifactId, DistributedError)(id);
            
            // Check if eviction needed
            if (currentSize + data.length > maxSize)
            {
                auto evictResult = evictLRU(data.length);
                if (evictResult.isErr)
                    return Err!(ArtifactId, DistributedError)(evictResult.unwrapErr());
            }
            
            try
            {
                // Ensure directory exists
                immutable dir = dirName(path);
                if (!exists(dir))
                    mkdirRecurse(dir);
                
                // Write artifact
                write(path, data);
                
                // Update metadata
                CacheEntry entry;
                entry.id = id;
                entry.size = data.length;
                entry.lastAccess = Clock.currTime;
                entries[id] = entry;
                
                currentSize += data.length;
                
                return Ok!(ArtifactId, DistributedError)(id);
            }
            catch (Exception e)
            {
                return Err!(ArtifactId, DistributedError)(
                    new DistributedError("Failed to write artifact: " ~ e.msg));
            }
        }
    }
    
    Result!(bool[], DistributedError) hasMany(ArtifactId[] ids) @trusted
    {
        bool[] results;
        results.reserve(ids.length);
        
        foreach (id; ids)
        {
            auto result = has(id);
            if (result.isErr)
                return Err!(bool[], DistributedError)(result.unwrapErr());
            results ~= result.unwrap();
        }
        
        return Ok!(bool[], DistributedError)(results);
    }
    
    Result!(ubyte[][], DistributedError) getMany(ArtifactId[] ids) @trusted
    {
        ubyte[][] results;
        results.reserve(ids.length);
        
        foreach (id; ids)
        {
            auto result = get(id);
            if (result.isErr)
                return Err!(ubyte[][], DistributedError)(result.unwrapErr());
            results ~= result.unwrap();
        }
        
        return Ok!(ubyte[][], DistributedError)(results);
    }
    
    /// Compute artifact ID from content
    private ArtifactId computeArtifactId(const ubyte[] data) @trusted
    {
        import utils.files.hash : FastHash;
        auto hash = FastHash.compute(data);
        return ArtifactId(hash);
    }
    
    /// Get filesystem path for artifact
    private string artifactPath(ArtifactId id) @safe
    {
        immutable idStr = id.toString();
        // Use first 2 chars as subdirectory (256-way split)
        return buildPath(cacheDir, idStr[0 .. 2], idStr);
    }
    
    /// Load existing cache entries
    private void loadEntries() @trusted
    {
        // TODO: Scan cache directory and build entry map
        currentSize = 0;
    }
    
    /// Evict least-recently-used entries to free space
    private Result!DistributedError evictLRU(size_t needed) @trusted
    {
        import std.algorithm : sort;
        
        // Sort entries by last access time
        auto sorted = entries.values.array
            .sort!((a, b) => a.lastAccess < b.lastAccess);
        
        size_t freed = 0;
        
        foreach (entry; sorted)
        {
            if (freed >= needed)
                break;
            
            try
            {
                // Remove from filesystem
                immutable path = artifactPath(entry.id);
                if (exists(path))
                    remove(path);
                
                // Remove from map
                entries.remove(entry.id);
                
                freed += entry.size;
                currentSize -= entry.size;
            }
            catch (Exception e)
            {
                // Continue evicting even if one fails
            }
        }
        
        if (freed < needed)
            return Err!DistributedError(
                new DistributedError("Failed to evict enough space"));
        
        return Ok!DistributedError();
    }
}

/// Tiered artifact store (L1 local, L2 shared, L3 remote)
final class TieredArtifactStore : ArtifactStore
{
    private ArtifactStore l1;  // Local cache
    private ArtifactStore l2;  // Shared cache (optional)
    private ArtifactStore l3;  // Remote cache (optional)
    
    this(ArtifactStore l1, ArtifactStore l2 = null, ArtifactStore l3 = null) @safe
    {
        this.l1 = l1;
        this.l2 = l2;
        this.l3 = l3;
    }
    
    Result!(bool, DistributedError) has(ArtifactId id) @trusted
    {
        // Check L1 first
        auto l1Result = l1.has(id);
        if (l1Result.isOk && l1Result.unwrap())
            return l1Result;
        
        // Check L2
        if (l2 !is null)
        {
            auto l2Result = l2.has(id);
            if (l2Result.isOk && l2Result.unwrap())
                return l2Result;
        }
        
        // Check L3
        if (l3 !is null)
            return l3.has(id);
        
        return Ok!(bool, DistributedError)(false);
    }
    
    Result!(ubyte[], DistributedError) get(ArtifactId id) @trusted
    {
        // Try L1 (local cache)
        auto l1Result = l1.get(id);
        if (l1Result.isOk)
            return l1Result;
        
        // Try L2 (shared cache)
        if (l2 !is null)
        {
            auto l2Result = l2.get(id);
            if (l2Result.isOk)
            {
                auto data = l2Result.unwrap();
                // Populate L1
                l1.put(data);
                return Ok!(ubyte[], DistributedError)(data);
            }
        }
        
        // Try L3 (remote cache)
        if (l3 !is null)
        {
            auto l3Result = l3.get(id);
            if (l3Result.isOk)
            {
                auto data = l3Result.unwrap();
                // Populate L1 and L2
                l1.put(data);
                if (l2 !is null)
                    l2.put(data);
                return Ok!(ubyte[], DistributedError)(data);
            }
        }
        
        return Err!(ubyte[], DistributedError)(
            new DistributedError("Artifact not found in any tier: " ~ id.toString()));
    }
    
    Result!(ArtifactId, DistributedError) put(ubyte[] data) @trusted
    {
        // Write to all tiers
        auto l1Result = l1.put(data);
        if (l1Result.isErr)
            return l1Result;
        
        auto id = l1Result.unwrap();
        
        // Best-effort write to L2 and L3
        if (l2 !is null)
            l2.put(data);
        
        if (l3 !is null)
            l3.put(data);
        
        return Ok!(ArtifactId, DistributedError)(id);
    }
    
    Result!(bool[], DistributedError) hasMany(ArtifactId[] ids) @trusted
    {
        return l1.hasMany(ids);
    }
    
    Result!(ubyte[][], DistributedError) getMany(ArtifactId[] ids) @trusted
    {
        ubyte[][] results;
        results.reserve(ids.length);
        
        foreach (id; ids)
        {
            auto result = get(id);
            if (result.isErr)
                return Err!(ubyte[][], DistributedError)(result.unwrapErr());
            results ~= result.unwrap();
        }
        
        return Ok!(ubyte[][], DistributedError)(results);
    }
}



