module engine.caching.coordinator.coordinator;

import std.datetime : Clock, Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.conv : to;
import core.sync.mutex : Mutex;
import engine.caching.targets.cache : BuildCache, CacheConfig;
import engine.caching.actions.action : ActionCache, ActionCacheConfig, ActionId;
import engine.caching.incremental.dependency : DependencyCache;
import engine.caching.incremental.filter : IncrementalFilter;
import engine.caching.distributed.remote.client : RemoteCacheClient;
import engine.caching.distributed.remote.protocol : RemoteCacheConfig;
import engine.caching.storage : ContentAddressableStorage, CacheGarbageCollector, SourceRepository, SourceTracker, SourceRef, SourceRefSet;
import engine.caching.events;
import frontend.cli.events.events : EventPublisher;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

/// Unified cache coordinator orchestrating all caching tiers
/// Single source of truth for cache operations with:
/// - Multi-tier caching (local target, action, remote)
/// - Incremental compilation and smart filtering
/// - Content-addressable storage with deduplication
/// - Automatic garbage collection
/// - Event emission for telemetry integration
final class CacheCoordinator
{
    private BuildCache targetCache;
    private ActionCache actionCache;
    private DependencyCache depCache;
    private IncrementalFilter filter;
    private RemoteCacheClient remoteCache;
    private ContentAddressableStorage cas;
    private CacheGarbageCollector gc;
    private SourceRepository sourceRepo;
    private SourceTracker sourceTracker;
    private EventPublisher publisher;
    private Mutex coordinatorMutex;
    private CoordinatorConfig config;
    
    this(
        string cacheDir = ".builder-cache",
        EventPublisher publisher = null,
        CoordinatorConfig config = CoordinatorConfig.init
    ) @system
    {
        this.config = config;
        this.publisher = publisher;
        this.coordinatorMutex = new Mutex();
        
        // Initialize content-addressable storage
        this.cas = new ContentAddressableStorage(cacheDir ~ "/blobs");
        
        // Initialize source repository (content-addressed sources)
        this.sourceRepo = new SourceRepository(cas, cacheDir ~ "/sources");
        
        // Initialize source tracker
        this.sourceTracker = new SourceTracker(sourceRepo);
        
        // Initialize target cache
        auto targetConfig = CacheConfig.fromEnvironment();
        this.targetCache = new BuildCache(cacheDir, targetConfig);
        
        // Initialize action cache
        auto actionConfig = ActionCacheConfig.fromEnvironment();
        this.actionCache = new ActionCache(cacheDir ~ "/actions", actionConfig);
        
        // Initialize dependency cache for incremental compilation
        this.depCache = new DependencyCache(cacheDir ~ "/incremental");
        
        // Initialize smart filter
        this.filter = IncrementalFilter.create(depCache, actionCache);
        
        // Initialize remote cache if configured
        auto remoteConfig = RemoteCacheConfig.fromEnvironment();
        if (remoteConfig.enabled())
        {
            this.remoteCache = new RemoteCacheClient(remoteConfig);
        }
        
        // Initialize garbage collector
        this.gc = new CacheGarbageCollector(cas, publisher);
    }
    
    /// Check if target is cached (checks all tiers)
    bool isCached(string targetId, const(string)[] sources, const(string)[] deps) @system
    {
        auto timer = StopWatch(AutoStart.yes);
        
        // Check local target cache first (fastest)
        if (targetCache.isCached(targetId, sources, deps))
        {
            emitEvent!CacheHitEvent(targetId, 0, timer.peek(), false);
            return true;
        }
        
        // Check remote cache if available
        if (remoteCache !is null)
        {
            auto contentHash = computeContentHash(targetId, sources, deps);
            auto hasResult = remoteCache.has(contentHash);
            if (contentHash.length > 0 && hasResult.match(
                (bool ok) => ok,
                (BuildError err) => false
            ))
            {
                emitEvent!CacheHitEvent(targetId, 0, timer.peek(), true);
                return true;
            }
        }
        
        emitEvent!CacheMissEvent(targetId, timer.peek());
        return false;
    }
    
    /// Update cache after successful build
    void update(
        string targetId,
        const(string)[] sources,
        const(string)[] deps,
        string outputHash
    ) @system
    {
        auto timer = StopWatch(AutoStart.yes);
        
        synchronized (coordinatorMutex)
        {
            targetCache.update(targetId, sources, deps, outputHash);
            emitEvent!CacheUpdateEvent(targetId, 0, timer.peek());
            
            // Push to remote cache asynchronously if configured
            if (remoteCache !is null && config.enableRemotePush)
            {
                import core.thread : Thread;
                (new Thread(() => pushToRemote(targetId, sources, deps, outputHash))).start();
            }
        }
    }
    
    /// Check if action is cached
    bool isActionCached(
        ActionId actionId,
        const(string)[] inputs,
        const(string[string]) metadata
    ) @system
    {
        auto timer = StopWatch(AutoStart.yes);
        immutable cached = actionCache.isCached(actionId, inputs, metadata);
        immutable actionIdStr = actionId.toString();
        immutable eventType = cached ? CacheEventType.ActionHit : CacheEventType.ActionMiss;
        
        emitEvent!ActionCacheEvent(eventType, actionIdStr, actionId.targetId, timer.peek());
        return cached;
    }
    
    /// Record action result
    void recordAction(
        ActionId actionId,
        const(string)[] inputs,
        const(string)[] outputs,
        const(string[string]) metadata,
        bool success
    ) @system
    {
        actionCache.update(actionId, inputs, outputs, metadata, success);
    }
    
    /// Flush all caches to disk
    void flush() @system
    {
        synchronized (coordinatorMutex)
        {
            targetCache.flush();
            actionCache.flush();
            sourceRepo.flush();
        }
    }
    
    /// Close all caches
    void close() @system
    {
        synchronized (coordinatorMutex)
        {
            if (targetCache) targetCache.close();
            if (actionCache) actionCache.close();
        }
    }
    
    /// Run garbage collection
    Result!(size_t, BuildError) runGC() @system
    {
        auto gcResult = gc.collect(targetCache, actionCache);
        if (gcResult.isErr)
            return Err!(size_t, BuildError)(gcResult.unwrapErr());
        
        auto result = gcResult.unwrap();
        return Ok!(size_t, BuildError)(result.bytesFreed);
    }
    
    /// Get unified cache statistics
    struct CacheCoordinatorStats
    {
        size_t targetCacheEntries;
        size_t targetCacheSize;
        float targetHitRate;
        
        size_t actionCacheEntries;
        size_t actionCacheSize;
        float actionHitRate;
        
        size_t uniqueBlobs;
        size_t totalBlobSize;
        float deduplicationRatio;
        
        size_t remoteHits;
        size_t remoteMisses;
        float remoteHitRate;
        
        // Source repository stats
        size_t sourcesStored;
        size_t sourceDeduplicationHits;
        ulong sourceBytes;
        ulong sourceBytesSaved;
        float sourceDeduplicationRatio;
    }
    
    CacheCoordinatorStats getStats() @system
    {
        synchronized (coordinatorMutex)
        {
            CacheCoordinatorStats stats;
            
            // Target cache stats
            auto targetStats = targetCache.getStats();
            stats.targetCacheEntries = targetStats.totalEntries;
            stats.targetCacheSize = targetStats.totalSize;
            stats.targetHitRate = targetStats.metadataHitRate;
            
            // Action cache stats
            auto actionStats = actionCache.getStats();
            stats.actionCacheEntries = actionStats.totalEntries;
            stats.actionCacheSize = actionStats.totalSize;
            stats.actionHitRate = actionStats.hitRate;
            
            // CAS stats
            auto casStats = cas.getStats();
            stats.uniqueBlobs = casStats.uniqueBlobs;
            stats.totalBlobSize = casStats.totalSize;
            stats.deduplicationRatio = casStats.deduplicationRatio;
            
            // Remote cache stats
            if (remoteCache !is null)
            {
                auto remoteStats = remoteCache.getStats();
                stats.remoteHits = remoteStats.hits;
                stats.remoteMisses = remoteStats.misses;
                stats.remoteHitRate = remoteStats.hitRate;
            }
            
            // Source repository stats
            auto sourceStats = sourceRepo.getStats();
            stats.sourcesStored = sourceStats.sourcesStored;
            stats.sourceDeduplicationHits = sourceStats.deduplicationHits;
            stats.sourceBytes = sourceStats.bytesStored;
            stats.sourceBytesSaved = sourceStats.bytesSaved;
            stats.sourceDeduplicationRatio = sourceStats.deduplicationRatio;
            
            return stats;
        }
    }
    
    /// Push artifact to remote cache (runs asynchronously)
    private void pushToRemote(
        string targetId,
        const(string)[] sources,
        const(string)[] deps,
        string outputHash
    ) @system nothrow
    {
        auto timer = StopWatch(AutoStart.yes);
        
        try
        {
            auto contentHash = computeContentHash(targetId, sources, deps);
            if (contentHash.length == 0) return;
            
            auto metadata = serializeCacheMetadata(targetId, sources, deps, outputHash);
            auto pushResult = remoteCache.put(contentHash, metadata);
            
            emitEvent!RemoteCacheEvent(CacheEventType.RemotePush, targetId, 
                                       metadata.length, timer.peek(), pushResult.isOk);
            
            if (pushResult.isErr)
                Logger.debugLog("Remote push failed: " ~ pushResult.unwrapErr().message);
        }
        catch (Exception e)
        {
            try { Logger.debugLog("Remote push exception: " ~ e.msg); } catch (Exception) {}
        }
    }
    
    /// Compute content hash for remote cache key
    private string computeContentHash(
        string targetId,
        const(string)[] sources,
        const(string)[] deps
    ) @system nothrow
    {
        try
        {
            import std.digest.sha : SHA256, toHexString;
            import infrastructure.utils.files.hash : FastHash;
            import std.file : exists;
            
            SHA256 hash;
            hash.start();
            
            hash.put(cast(ubyte[])targetId);
            
            foreach (source; sources)
            {
                if (exists(source))
                {
                    auto sourceHash = FastHash.hashFile(source);
                    hash.put(cast(ubyte[])sourceHash);
                }
            }
            
            foreach (dep; deps)
                hash.put(cast(ubyte[])dep);
            
            return toHexString(hash.finish()).to!string;
        }
        catch (Exception)
        {
            return "";
        }
    }
    
    /// Serialize cache metadata for remote storage
    private ubyte[] serializeCacheMetadata(
        string targetId,
        const(string)[] sources,
        const(string)[] deps,
        string outputHash
    ) @system nothrow
    {
        try
        {
            import std.bitmanip : write;
            import std.utf : toUTF8;
            
            ubyte[] buffer;
            buffer.reserve(1024);
            
            // Version
            buffer.write!ubyte(1, buffer.length);
            
            // Target ID
            immutable tidBytes = targetId.toUTF8();
            buffer.write!uint(cast(uint)tidBytes.length, buffer.length);
            buffer ~= tidBytes;
            
            // Sources count
            buffer.write!uint(cast(uint)sources.length, buffer.length);
            foreach (source; sources)
            {
                immutable srcBytes = source.toUTF8();
                buffer.write!uint(cast(uint)srcBytes.length, buffer.length);
                buffer ~= srcBytes;
            }
            
            // Deps count
            buffer.write!uint(cast(uint)deps.length, buffer.length);
            foreach (dep; deps)
            {
                immutable depBytes = dep.toUTF8();
                buffer.write!uint(cast(uint)depBytes.length, buffer.length);
                buffer ~= depBytes;
            }
            
            // Output hash
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
    
    // Event emission helper
    private void emitEvent(T, Args...)(Args args) nothrow
    {
        if (publisher is null) return;
        try { publisher.publish(new T(args)); } catch (Exception) {}
    }
    
    /// Get action cache
    ActionCache getActionCache() @system
    {
        return actionCache;
    }
    
    /// Get dependency cache
    DependencyCache getDependencyCache() @system
    {
        return depCache;
    }
    
    /// Get incremental filter
    IncrementalFilter getFilter() @system
    {
        return filter;
    }
    
    /// Get source repository
    SourceRepository getSourceRepository() @system
    {
        return sourceRepo;
    }
    
    /// Get source tracker
    SourceTracker getSourceTracker() @system
    {
        return sourceTracker;
    }
    
    /// Store sources in CAS and return references
    Result!(SourceRefSet, BuildError) storeSources(const(string)[] paths) @system
    {
        auto timer = StopWatch(AutoStart.yes);
        
        synchronized (coordinatorMutex)
        {
            auto result = sourceTracker.trackBatch(paths);
            
            if (result.isOk)
            {
                auto refSet = result.unwrap();
                immutable duration = timer.peek();
                
                // Emit telemetry event
                if (publisher !is null)
                {
                    try
                    {
                        import std.format : format;
                        immutable msg = format("Stored %d sources (%d bytes) in CAS",
                            refSet.length, refSet.totalSize);
                        // Could emit custom SourceStorageEvent here if needed
                    }
                    catch (Exception) {}
                }
            }
            
            return result;
        }
    }
    
    /// Materialize sources from CAS to workspace
    Result!BuildError materializeSources(SourceRefSet refSet) @system
    {
        synchronized (coordinatorMutex)
        {
            return sourceRepo.materializeBatch(refSet);
        }
    }
    
    /// Detect changed sources and update CAS
    Result!(SourceTracker.ChangedFile[], BuildError) detectSourceChanges(const(string)[] paths) @system
    {
        synchronized (coordinatorMutex)
        {
            auto result = sourceTracker.detectChanges(paths);
            
            if (result.isOk)
            {
                auto changes = result.unwrap();
                if (changes.length > 0 && publisher !is null)
                {
                    try
                    {
                        import std.format : format;
                        immutable msg = format("%d source file(s) changed", changes.length);
                        // Could emit SourceChangeEvent here
                    }
                    catch (Exception) {}
                }
            }
            
            return result;
        }
    }
}

/// Coordinator configuration
struct CoordinatorConfig
{
    bool enableRemotePush = true;
    bool enableAutoGC = false;
    Duration gcInterval = dur!"hours"(24);
}

