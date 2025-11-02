module core.execution.services.cache;

import core.caching.cache : BuildCache, CacheConfig;
import core.caching.action : ActionCache, ActionCacheConfig, ActionId;
import core.caching.remote : RemoteCacheClient, RemoteCacheConfig;
import core.shutdown.shutdown : ShutdownCoordinator;
import errors;

/// Unified cache statistics for service layer
struct ServiceCacheStats
{
    // Build cache stats
    size_t metadataHits;
    size_t metadataMisses;
    size_t contentHashes;
    float metadataHitRate;
    size_t hashCacheHits;
    size_t hashCacheMisses;
    float hashCacheHitRate;
    size_t totalEntries;
    size_t totalSize;
    
    // Action cache stats
    size_t actionEntries;
    size_t actionSize;
    size_t actionHits;
    size_t actionMisses;
    float actionHitRate;
    size_t successfulActions;
    size_t failedActions;
    
    // Remote cache stats
    size_t remoteGetRequests;
    size_t remotePutRequests;
    size_t remoteHits;
    size_t remoteMisses;
    float remoteHitRate;
    size_t remoteBytesUploaded;
    size_t remoteBytesDownloaded;
    float remoteAverageLatency;
}

/// Cache service interface
interface ICacheService
{
    /// Check if target is cached
    bool isCached(string targetId, string[] sources, string[] deps);
    
    /// Update cache after successful build
    void update(string targetId, string[] sources, string[] deps, string outputHash);
    
    /// Record an action for fine-grained caching
    void recordAction(ActionId actionId, string[] inputs, string[] outputs, 
                     string[string] metadata, bool success);
    
    /// Flush caches to disk
    void flush();
    
    /// Close caches and ensure data is persisted
    void close();
    
    /// Get unified cache statistics
    ServiceCacheStats getStats();
    
    /// Clear all caches
    void clear();
}

/// Concrete cache service implementation
/// Coordinates BuildCache, ActionCache, and RemoteCacheClient behind unified interface
final class CacheService : ICacheService
{
    private BuildCache buildCache;
    private ActionCache actionCache;
    private RemoteCacheClient remoteCache;
    private string cacheDir;
    
    this(string cacheDir = ".builder-cache")
    {
        this.cacheDir = cacheDir;
        
        // Initialize build cache
        auto buildCacheConfig = CacheConfig.fromEnvironment();
        this.buildCache = new BuildCache(cacheDir, buildCacheConfig);
        
        // Initialize action cache
        auto actionCacheConfig = ActionCacheConfig.fromEnvironment();
        this.actionCache = new ActionCache(cacheDir ~ "/actions", actionCacheConfig);
        
        // Initialize remote cache if configured
        auto remoteCacheConfig = RemoteCacheConfig.fromEnvironment();
        if (remoteCacheConfig.enabled())
        {
            this.remoteCache = new RemoteCacheClient(remoteCacheConfig);
        }
        
        // Register with shutdown coordinator for explicit cleanup
        auto coordinator = ShutdownCoordinator.instance();
        coordinator.registerCache(this.buildCache);
        coordinator.registerCache(this.actionCache);
    }
    
    // Constructor for dependency injection (testing)
    this(BuildCache buildCache, ActionCache actionCache, RemoteCacheClient remoteCache = null)
    {
        this.buildCache = buildCache;
        this.actionCache = actionCache;
        this.remoteCache = remoteCache;
    }
    
    bool isCached(string targetId, string[] sources, string[] deps) @trusted
    {
        // Check local cache first (fast path)
        if (buildCache.isCached(targetId, sources, deps))
            return true;
        
        // Check remote cache if available
        if (remoteCache is null)
            return false;
        
        // Compute content hash for remote lookup
        auto contentHash = computeContentHash(targetId, sources, deps);
        if (contentHash.length == 0)
            return false;
        
        // Check if remote has this artifact
        auto hasResult = remoteCache.has(contentHash);
        if (hasResult.isErr || !hasResult.unwrap())
            return false;
        
        // Remote has it - we could pull here, but for now just report hit
        // The actual artifact pull would happen during build
        // This is a design choice: lazy pull vs eager pull
        return true;
    }
    
    void update(string targetId, string[] sources, string[] deps, string outputHash) @trusted
    {
        // Update local cache immediately
        buildCache.update(targetId, sources, deps, outputHash);
        
        // Push to remote cache asynchronously if available
        if (remoteCache !is null && outputHash.length > 0)
        {
            // Compute content hash
            auto contentHash = computeContentHash(targetId, sources, deps);
            if (contentHash.length > 0)
            {
                // For now, we'll serialize the cache entry metadata
                // In production, this would include actual build artifacts
                auto metadata = serializeCacheMetadata(targetId, sources, deps, outputHash);
                
                // Push to remote (non-blocking - errors are logged but not fatal)
                auto pushResult = remoteCache.put(contentHash, metadata);
                if (pushResult.isErr)
                {
                    // Log but don't fail - remote cache is optional
                    import utils.logging.logger : Logger;
                    Logger.debugLog("Failed to push to remote cache: " ~ pushResult.unwrapErr().message);
                }
            }
        }
    }
    
    private string computeContentHash(string targetId, string[] sources, string[] deps) @trusted nothrow
    {
        try
        {
            import std.digest.sha : SHA256, toHexString;
            import std.conv : to;
            import utils.files.hash : FastHash;
            import std.file : exists;
            
            SHA256 hash;
            hash.start();
            
            // Hash target ID
            hash.put(cast(ubyte[])targetId);
            
            // Hash all source files
            foreach (source; sources)
            {
                if (exists(source))
                {
                    auto sourceHash = FastHash.hashFile(source);
                    hash.put(cast(ubyte[])sourceHash);
                }
            }
            
            // Hash dependencies
            foreach (dep; deps)
                hash.put(cast(ubyte[])dep);
            
            return toHexString(hash.finish()).to!string;
        }
        catch (Exception)
        {
            return "";
        }
    }
    
    private ubyte[] serializeCacheMetadata(string targetId, string[] sources, string[] deps, string outputHash) @trusted nothrow
    {
        try
        {
            import std.bitmanip : write;
            import std.utf : toUTF8;
            
            ubyte[] buffer;
            buffer.reserve(1024);
            
            // Write target ID
            immutable tidBytes = targetId.toUTF8();
            buffer.write!uint(cast(uint)tidBytes.length, buffer.length);
            buffer ~= tidBytes;
            
            // Write sources count and hashes
            buffer.write!uint(cast(uint)sources.length, buffer.length);
            foreach (source; sources)
            {
                immutable srcBytes = source.toUTF8();
                buffer.write!uint(cast(uint)srcBytes.length, buffer.length);
                buffer ~= srcBytes;
            }
            
            // Write deps count
            buffer.write!uint(cast(uint)deps.length, buffer.length);
            foreach (dep; deps)
            {
                immutable depBytes = dep.toUTF8();
                buffer.write!uint(cast(uint)depBytes.length, buffer.length);
                buffer ~= depBytes;
            }
            
            // Write output hash
            immutable hashBytes = outputHash.toUTF8();
            buffer.write!uint(cast(uint)hashBytes.length, buffer.length);
            buffer ~= hashBytes;
            
            return buffer;
        }
        catch (Exception)
        {
            return new ubyte[0];
        }
    }
    
    void recordAction(ActionId actionId, string[] inputs, string[] outputs,
                     string[string] metadata, bool success) @trusted
    {
        actionCache.update(actionId, inputs, outputs, metadata, success);
    }
    
    void flush() @trusted
    {
        buildCache.flush();
        actionCache.flush();
    }
    
    void close() @trusted
    {
        if (buildCache !is null)
        {
            buildCache.close();
        }
        
        if (actionCache !is null)
        {
            actionCache.close();
        }
    }
    
    ServiceCacheStats getStats() @trusted
    {
        ServiceCacheStats stats;
        
        // Build cache statistics
        auto buildStats = buildCache.getStats();
        stats.metadataHits = buildStats.metadataHits;
        stats.metadataMisses = buildStats.contentHashes;
        stats.contentHashes = buildStats.contentHashes;
        stats.metadataHitRate = buildStats.metadataHitRate;
        stats.hashCacheHits = buildStats.hashCacheHits;
        stats.hashCacheMisses = buildStats.hashCacheMisses;
        stats.hashCacheHitRate = buildStats.hashCacheHitRate;
        stats.totalEntries = buildStats.totalEntries;
        stats.totalSize = buildStats.totalSize;
        
        // Action cache statistics
        auto actionStats = actionCache.getStats();
        stats.actionEntries = actionStats.totalEntries;
        stats.actionSize = actionStats.totalSize;
        stats.actionHits = actionStats.hits;
        stats.actionMisses = actionStats.misses;
        stats.actionHitRate = actionStats.hitRate;
        stats.successfulActions = actionStats.successfulActions;
        stats.failedActions = actionStats.failedActions;
        
        // Remote cache statistics
        if (remoteCache !is null)
        {
            import core.caching.remote.protocol : RemoteCacheStats;
            auto remoteStats = remoteCache.getStats();
            stats.remoteGetRequests = remoteStats.getRequests;
            stats.remotePutRequests = remoteStats.putRequests;
            stats.remoteHits = remoteStats.hits;
            stats.remoteMisses = remoteStats.misses;
            stats.remoteHitRate = remoteStats.hitRate;
            stats.remoteBytesUploaded = remoteStats.bytesUploaded;
            stats.remoteBytesDownloaded = remoteStats.bytesDownloaded;
            stats.remoteAverageLatency = remoteStats.averageLatency;
        }
        
        return stats;
    }
    
    void clear() @trusted
    {
        // Implementation would clear cache directories
        // Left as exercise - depends on cache implementation
    }
}

