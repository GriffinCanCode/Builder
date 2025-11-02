module core.caching.metrics.collector;

import std.datetime : Duration, SysTime, Clock, dur;
import core.sync.mutex : Mutex;
import core.caching.events;
import core.caching.metrics.stats;
import cli.events.events : EventSubscriber, BuildEvent;
import errors;

/// Thread-safe cache metrics collector
/// Subscribes to cache events and aggregates statistics
final class CacheMetricsCollector : EventSubscriber
{
    private CacheMetrics metrics;
    private Mutex metricsMutex;
    private SysTime sessionStart;
    
    this() @system
    {
        this.metricsMutex = new Mutex();
        this.metrics = CacheMetrics.init;
        this.sessionStart = Clock.currTime();
    }
    
    /// Handle cache events
    void onEvent(BuildEvent event) @system
    {
        // Filter for cache events only
        auto cacheEvent = cast(CacheEvent)event;
        if (cacheEvent is null)
            return;
        
        synchronized (metricsMutex)
        {
            final switch (cacheEvent.cacheType)
            {
                case CacheEventType.Hit:
                    handleHit(cast(CacheHitEvent)cacheEvent);
                    break;
                case CacheEventType.Miss:
                    handleMiss(cast(CacheMissEvent)cacheEvent);
                    break;
                case CacheEventType.Update:
                    handleUpdate(cast(CacheUpdateEvent)cacheEvent);
                    break;
                case CacheEventType.Evict:
                    handleEviction(cast(CacheEvictionEvent)cacheEvent);
                    break;
                case CacheEventType.RemoteHit:
                    handleRemoteHit(cast(RemoteCacheEvent)cacheEvent);
                    break;
                case CacheEventType.RemoteMiss:
                    handleRemoteMiss(cast(RemoteCacheEvent)cacheEvent);
                    break;
                case CacheEventType.RemotePush:
                    handleRemotePush(cast(RemoteCacheEvent)cacheEvent);
                    break;
                case CacheEventType.RemotePull:
                    handleRemotePull(cast(RemoteCacheEvent)cacheEvent);
                    break;
                case CacheEventType.GCStarted:
                    handleGCStarted(cast(CacheGCEvent)cacheEvent);
                    break;
                case CacheEventType.GCCompleted:
                    handleGCCompleted(cast(CacheGCEvent)cacheEvent);
                    break;
                case CacheEventType.ActionHit:
                    handleActionHit(cast(ActionCacheEvent)cacheEvent);
                    break;
                case CacheEventType.ActionMiss:
                    handleActionMiss(cast(ActionCacheEvent)cacheEvent);
                    break;
            }
        }
    }
    
    /// Get current metrics snapshot
    CacheMetrics getMetrics() @system
    {
        synchronized (metricsMutex)
        {
            // Compute derived metrics
            metrics.compute();
            return metrics;
        }
    }
    
    /// Reset metrics
    void reset() @system
    {
        synchronized (metricsMutex)
        {
            metrics = CacheMetrics.init;
            sessionStart = Clock.currTime();
        }
    }
    
    private void handleHit(CacheHitEvent event) @system
    {
        metrics.targetHits++;
        metrics.totalBytesServed += event.artifactSize;
        updateLatency(metrics.avgLookupLatency, event.lookupTime);
        
        if (event.wasRemote)
            metrics.remoteHits++;
    }
    
    private void handleMiss(CacheMissEvent event) @system
    {
        metrics.targetMisses++;
        updateLatency(metrics.avgLookupLatency, event.lookupTime);
    }
    
    private void handleUpdate(CacheUpdateEvent event) @system
    {
        metrics.updates++;
        metrics.totalBytesStored += event.artifactSize;
        updateLatency(metrics.avgUpdateLatency, event.updateTime);
    }
    
    private void handleEviction(CacheEvictionEvent event) @system
    {
        metrics.evictions += event.evictedCount;
        metrics.totalBytesEvicted += event.freedBytes;
    }
    
    private void handleRemoteHit(RemoteCacheEvent event) @system
    {
        metrics.remoteHits++;
        updateLatency(metrics.avgNetworkLatency, event.networkTime);
    }
    
    private void handleRemoteMiss(RemoteCacheEvent event) @system
    {
        metrics.remoteMisses++;
        updateLatency(metrics.avgNetworkLatency, event.networkTime);
    }
    
    private void handleRemotePush(RemoteCacheEvent event) @system
    {
        if (event.success)
        {
            metrics.remotePushes++;
            metrics.totalBytesUploaded += event.artifactSize;
        }
        else
        {
            metrics.remotePushFailures++;
        }
        updateLatency(metrics.avgNetworkLatency, event.networkTime);
    }
    
    private void handleRemotePull(RemoteCacheEvent event) @system
    {
        if (event.success)
        {
            metrics.remotePulls++;
            metrics.totalBytesDownloaded += event.artifactSize;
        }
        else
        {
            metrics.remotePullFailures++;
        }
        updateLatency(metrics.avgNetworkLatency, event.networkTime);
    }
    
    private void handleGCStarted(CacheGCEvent event) @system
    {
        metrics.gcRuns++;
    }
    
    private void handleGCCompleted(CacheGCEvent event) @system
    {
        metrics.totalBytesCollected += event.freedBytes;
        metrics.orphansCollected += event.orphanedArtifacts;
        updateLatency(metrics.avgGCLatency, event.gcTime);
    }
    
    private void handleActionHit(ActionCacheEvent event) @system
    {
        metrics.actionHits++;
        updateLatency(metrics.avgActionLookupLatency, event.lookupTime);
    }
    
    private void handleActionMiss(ActionCacheEvent event) @system
    {
        metrics.actionMisses++;
        updateLatency(metrics.avgActionLookupLatency, event.lookupTime);
    }
    
    /// Update exponential moving average for latency
    private void updateLatency(ref float avg, Duration latency) pure nothrow @system
    {
        immutable newValue = latency.total!"usecs" / 1000.0;  // Convert to ms
        immutable alpha = 0.2;  // Smoothing factor
        
        if (avg == 0.0)
            avg = newValue;
        else
            avg = alpha * newValue + (1.0 - alpha) * avg;
    }
}

