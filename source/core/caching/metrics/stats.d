module core.caching.metrics.stats;

import std.conv : to;
import std.format : format;

/// Comprehensive cache statistics
struct CacheMetrics
{
    // Target-level cache
    size_t targetHits;
    size_t targetMisses;
    float targetHitRate = 0.0;
    
    // Action-level cache
    size_t actionHits;
    size_t actionMisses;
    float actionHitRate = 0.0;
    
    // Remote cache
    size_t remoteHits;
    size_t remoteMisses;
    size_t remotePushes;
    size_t remotePulls;
    size_t remotePushFailures;
    size_t remotePullFailures;
    float remoteHitRate = 0.0;
    
    // Storage metrics
    size_t totalBytesStored;
    size_t totalBytesServed;
    size_t totalBytesEvicted;
    size_t totalBytesUploaded;
    size_t totalBytesDownloaded;
    size_t totalBytesCollected;  // From GC
    
    // Operation counts
    size_t updates;
    size_t evictions;
    size_t gcRuns;
    size_t orphansCollected;
    
    // Performance metrics (in milliseconds)
    float avgLookupLatency = 0.0;
    float avgUpdateLatency = 0.0;
    float avgActionLookupLatency = 0.0;
    float avgNetworkLatency = 0.0;
    float avgGCLatency = 0.0;
    
    /// Compute derived statistics
    void compute() pure nothrow @safe
    {
        // Target hit rate
        immutable targetTotal = targetHits + targetMisses;
        if (targetTotal > 0)
            targetHitRate = (targetHits * 100.0) / targetTotal;
        
        // Action hit rate
        immutable actionTotal = actionHits + actionMisses;
        if (actionTotal > 0)
            actionHitRate = (actionHits * 100.0) / actionTotal;
        
        // Remote hit rate
        immutable remoteTotal = remoteHits + remoteMisses;
        if (remoteTotal > 0)
            remoteHitRate = (remoteHits * 100.0) / remoteTotal;
    }
    
    /// Get formatted summary
    string summary() const pure @system
    {
        import std.array : appender;
        auto result = appender!string();
        
        result ~= "Cache Metrics Summary:\n";
        result ~= "=====================\n\n";
        
        // Target cache
        result ~= "Target Cache:\n";
        result ~= format("  Hits:     %d\n", targetHits);
        result ~= format("  Misses:   %d\n", targetMisses);
        result ~= format("  Hit Rate: %.1f%%\n", targetHitRate);
        result ~= format("  Avg Lookup: %.2f ms\n\n", avgLookupLatency);
        
        // Action cache
        if (actionHits + actionMisses > 0)
        {
            result ~= "Action Cache:\n";
            result ~= format("  Hits:     %d\n", actionHits);
            result ~= format("  Misses:   %d\n", actionMisses);
            result ~= format("  Hit Rate: %.1f%%\n", actionHitRate);
            result ~= format("  Avg Lookup: %.2f ms\n\n", avgActionLookupLatency);
        }
        
        // Remote cache
        if (remoteHits + remoteMisses > 0)
        {
            result ~= "Remote Cache:\n";
            result ~= format("  Hits:     %d\n", remoteHits);
            result ~= format("  Misses:   %d\n", remoteMisses);
            result ~= format("  Hit Rate: %.1f%%\n", remoteHitRate);
            result ~= format("  Pushes:   %d\n", remotePushes);
            result ~= format("  Pulls:    %d\n", remotePulls);
            result ~= format("  Avg Network: %.2f ms\n\n", avgNetworkLatency);
        }
        
        // Storage
        result ~= "Storage:\n";
        result ~= format("  Stored:   %s\n", formatBytes(totalBytesStored));
        result ~= format("  Served:   %s\n", formatBytes(totalBytesServed));
        result ~= format("  Evicted:  %s\n", formatBytes(totalBytesEvicted));
        
        if (totalBytesUploaded > 0 || totalBytesDownloaded > 0)
        {
            result ~= format("  Uploaded: %s\n", formatBytes(totalBytesUploaded));
            result ~= format("  Downloaded: %s\n", formatBytes(totalBytesDownloaded));
        }
        
        // Garbage collection
        if (gcRuns > 0)
        {
            result ~= "\nGarbage Collection:\n";
            result ~= format("  Runs:     %d\n", gcRuns);
            result ~= format("  Orphans:  %d\n", orphansCollected);
            result ~= format("  Collected: %s\n", formatBytes(totalBytesCollected));
            result ~= format("  Avg GC Time: %.2f ms\n", avgGCLatency);
        }
        
        return result.data;
    }
    
    /// Format bytes as human-readable
    private static string formatBytes(size_t bytes) pure @system
    {
        if (bytes < 1024)
            return format("%d B", bytes);
        else if (bytes < 1024 * 1024)
            return format("%.1f KB", bytes / 1024.0);
        else if (bytes < 1024 * 1024 * 1024)
            return format("%.1f MB", bytes / (1024.0 * 1024.0));
        else
            return format("%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0));
    }
}

