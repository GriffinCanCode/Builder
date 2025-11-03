module engine.runtime.services.cache;

import engine.caching.coordinator : CacheCoordinator, CoordinatorConfig;
import engine.caching.actions.action : ActionId;
import engine.caching.metrics : CacheMetricsCollector;
import engine.runtime.shutdown.shutdown : ShutdownCoordinator;
import frontend.cli.events.events : EventPublisher;
import infrastructure.errors;

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
/// Uses unified CacheCoordinator for all caching operations
final class CacheService : ICacheService
{
    private CacheCoordinator coordinator;
    private CacheMetricsCollector metricsCollector;
    private EventPublisher publisher;
    
    this(string cacheDir = ".builder-cache", EventPublisher publisher = null)
    {
        this.publisher = publisher;
        
        // Initialize metrics collector if publisher available
        if (publisher !is null)
        {
            this.metricsCollector = new CacheMetricsCollector();
            publisher.subscribe(this.metricsCollector);
        }
        
        // Initialize unified cache coordinator
        auto config = CoordinatorConfig.init;
        this.coordinator = new CacheCoordinator(cacheDir, publisher, config);
        
        // Note: BuildServices automatically registers coordinator for cleanup
    }
    
    // Constructor for dependency injection (testing)
    this(CacheCoordinator coordinator, EventPublisher publisher = null)
    {
        this.coordinator = coordinator;
        this.publisher = publisher;
        
        if (publisher !is null)
        {
            this.metricsCollector = new CacheMetricsCollector();
            publisher.subscribe(this.metricsCollector);
        }
    }
    
    bool isCached(string targetId, string[] sources, string[] deps) @trusted
    {
        return coordinator.isCached(targetId, sources, deps);
    }
    
    void update(string targetId, string[] sources, string[] deps, string outputHash) @trusted
    {
        coordinator.update(targetId, sources, deps, outputHash);
    }
    
    void recordAction(ActionId actionId, string[] inputs, string[] outputs,
                     string[string] metadata, bool success) @trusted
    {
        coordinator.recordAction(actionId, inputs, outputs, metadata, success);
    }
    
    void flush() @trusted
    {
        coordinator.flush();
    }
    
    void close() @trusted
    {
        if (coordinator !is null)
        {
            coordinator.close();
        }
    }
    
    ServiceCacheStats getStats() @trusted
    {
        ServiceCacheStats stats;
        
        // Get coordinator stats
        auto coordStats = coordinator.getStats();
        
        // Map to service stats structure
        stats.totalEntries = coordStats.targetCacheEntries;
        stats.totalSize = coordStats.targetCacheSize;
        stats.metadataHitRate = coordStats.targetHitRate;
        
        stats.actionEntries = coordStats.actionCacheEntries;
        stats.actionSize = coordStats.actionCacheSize;
        stats.actionHitRate = coordStats.actionHitRate;
        
        stats.remoteHits = coordStats.remoteHits;
        stats.remoteMisses = coordStats.remoteMisses;
        stats.remoteHitRate = coordStats.remoteHitRate;
        
        // Get detailed metrics from collector if available
        if (metricsCollector !is null)
        {
            auto metrics = metricsCollector.getMetrics();
            stats.contentHashes = metrics.targetMisses;  // Approximation
            stats.metadataHits = metrics.targetHits;
            stats.hashCacheHits = 0;  // Not tracked separately
            stats.hashCacheMisses = 0;
            stats.hashCacheHitRate = 0;
            stats.actionHits = metrics.actionHits;
            stats.actionMisses = metrics.actionMisses;
            stats.remoteBytesUploaded = metrics.totalBytesUploaded;
            stats.remoteBytesDownloaded = metrics.totalBytesDownloaded;
            stats.remoteAverageLatency = metrics.avgNetworkLatency;
        }
        
        return stats;
    }
    
    void clear() @trusted
    {
        // Clear coordinator (clears all caches)
        if (coordinator !is null)
        {
            coordinator.close();
            // Reinitialize fresh
            auto config = CoordinatorConfig.init;
            coordinator = new CacheCoordinator(".builder-cache", publisher, config);
        }
    }
    
    /// Get internal coordinator for advanced operations
    /// Note: This breaks encapsulation but needed for migration period
    CacheCoordinator getCoordinator() @trusted
    {
        return coordinator;
    }
    
    /// Get internal BuildCache for backwards compatibility
    /// Note: Direct BuildCache access breaks unified caching
    /// Legacy method: Prefer using CacheService interface methods directly
    auto getInternalCache() @trusted
    {
        import engine.caching.targets.cache : BuildCache;
        // Return a reference to coordinator's internal cache
        // This is a migration shim
        return cast(BuildCache)coordinator;  // Will need proper accessor
    }
}


