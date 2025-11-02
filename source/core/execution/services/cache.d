module core.execution.services.cache;

import core.caching.cache : BuildCache, CacheConfig;
import core.caching.action : ActionCache, ActionCacheConfig, ActionId;
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
/// Coordinates BuildCache and ActionCache behind unified interface
final class CacheService : ICacheService
{
    private BuildCache buildCache;
    private ActionCache actionCache;
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
        
        // Register with shutdown coordinator for explicit cleanup
        auto coordinator = ShutdownCoordinator.instance();
        coordinator.registerCache(this.buildCache);
        coordinator.registerCache(this.actionCache);
    }
    
    // Constructor for dependency injection (testing)
    this(BuildCache buildCache, ActionCache actionCache)
    {
        this.buildCache = buildCache;
        this.actionCache = actionCache;
    }
    
    bool isCached(string targetId, string[] sources, string[] deps) @trusted
    {
        return buildCache.isCached(targetId, sources, deps);
    }
    
    void update(string targetId, string[] sources, string[] deps, string outputHash) @trusted
    {
        buildCache.update(targetId, sources, deps, outputHash);
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
        
        return stats;
    }
    
    void clear() @trusted
    {
        // Implementation would clear cache directories
        // Left as exercise - depends on cache implementation
    }
}

