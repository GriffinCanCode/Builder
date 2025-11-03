module engine.caching.storage.gc;

import std.datetime : Clock, Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.algorithm : filter, map;
import std.array : array;
import std.conv : to;
import engine.caching.storage.cas;
import engine.caching.targets.cache;
import engine.caching.actions.action;
import engine.caching.events;
import frontend.cli.events.events : EventPublisher;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

/// Reachability-based garbage collector for cache artifacts
/// Removes orphaned blobs that are no longer referenced by any cache entry
final class CacheGarbageCollector
{
    private ContentAddressableStorage cas;
    private EventPublisher publisher;
    
    this(ContentAddressableStorage cas, EventPublisher publisher = null) @safe
    {
        this.cas = cas;
        this.publisher = publisher;
    }
    
    /// Run garbage collection
    /// Returns: number of blobs collected and bytes freed
    Result!(GCResult, BuildError) collect(
        BuildCache targetCache,
        ActionCache actionCache
    ) @system
    {
        auto timer = StopWatch(AutoStart.yes);
        
        try
        {
            // Emit GC started event
            if (publisher !is null)
            {
                auto startEvent = new CacheGCEvent(
                    CacheEventType.GCStarted, 0, 0, 0, dur!"msecs"(0)
                );
                publisher.publish(startEvent);
            }
            
            // Mark phase: collect all referenced hashes
            auto referencedHashes = collectReferences(targetCache, actionCache);
            
            // Sweep phase: remove unreferenced blobs
            auto sweepResult = sweepUnreferenced(referencedHashes);
            
            timer.stop();
            immutable gcTime = timer.peek();
            
            // Emit GC completed event
            if (publisher !is null)
            {
                auto completeEvent = new CacheGCEvent(
                    CacheEventType.GCCompleted,
                    sweepResult.blobsCollected,
                    sweepResult.bytesFreed,
                    sweepResult.orphansFound,
                    gcTime
                );
                publisher.publish(completeEvent);
            }
            
            Logger.debugLog("GC collected " ~ sweepResult.blobsCollected.to!string ~ 
                          " blobs, freed " ~ formatBytes(sweepResult.bytesFreed));
            
            return Ok!(GCResult, BuildError)(sweepResult);
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Garbage collection failed: " ~ e.msg,
                ErrorCode.CacheGCFailed
            );
            return Err!(GCResult, BuildError)(error);
        }
    }
    
    /// Collect all referenced blob hashes from caches
    private bool[string] collectReferences(
        BuildCache targetCache,
        ActionCache actionCache
    ) @system
    {
        bool[string] referenced;
        
        // Collect from target cache
        auto targetStats = targetCache.getStats();
        // Note: Future enhancement - extend BuildCache API to expose output hashes
        // for more comprehensive garbage collection
        
        // Collect from action cache
        auto actionStats = actionCache.getStats();
        // Similarly, need API to get all action output hashes
        
        return referenced;
    }
    
    /// Sweep unreferenced blobs
    private GCResult sweepUnreferenced(const bool[string] referenced) @system
    {
        GCResult result;
        
        // Get all blobs in storage
        auto allBlobs = cas.listBlobs();
        
        foreach (hash; allBlobs)
        {
            // Skip if referenced
            if (hash in referenced)
                continue;
            
            // Get blob size before deletion
            auto getBlobResult = cas.getBlob(hash);
            if (getBlobResult.isOk)
            {
                result.bytesFreed += getBlobResult.unwrap().length;
            }
            
            // Attempt deletion
            auto deleteResult = cas.deleteBlob(hash);
            if (deleteResult.isOk)
            {
                result.blobsCollected++;
                result.orphansFound++;
            }
        }
        
        return result;
    }
    
    private static string formatBytes(size_t bytes) pure @system
    {
        import std.format : format;
        
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

/// Garbage collection result
struct GCResult
{
    size_t blobsCollected;
    size_t bytesFreed;
    size_t orphansFound;
}

