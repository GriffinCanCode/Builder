module core.caching.events;

import std.datetime : Duration, SysTime;
import cli.events.events : BuildEvent, EventType;

/// Cache event types for telemetry integration
enum CacheEventType : ubyte
{
    Hit,            /// Cache hit (artifact found)
    Miss,           /// Cache miss (artifact not found)
    Update,         /// Cache entry updated
    Evict,          /// Entry evicted from cache
    RemoteHit,      /// Remote cache hit
    RemoteMiss,     /// Remote cache miss
    RemotePush,     /// Artifact pushed to remote
    RemotePull,     /// Artifact pulled from remote
    GCStarted,      /// Garbage collection started
    GCCompleted,    /// Garbage collection completed
    ActionHit,      /// Action cache hit
    ActionMiss      /// Action cache miss
}

/// Base cache event
abstract class CacheEvent : BuildEvent
{
    CacheEventType cacheType;
    SysTime eventTime;
    private immutable EventType _type = EventType.Statistics;
    private immutable Duration _timestamp;
    
    this(CacheEventType cacheType) @safe
    {
        this.cacheType = cacheType;
        import std.datetime : Clock;
        this.eventTime = Clock.currTime();
        import std.datetime : Duration, msecs;
        this._timestamp = 0.msecs;
    }
    
    @property EventType type() const pure nothrow
    {
        return _type;
    }
    
    @property Duration timestamp() const pure nothrow
    {
        return _timestamp;
    }
}

/// Cache hit event
final class CacheHitEvent : CacheEvent
{
    string targetId;
    size_t artifactSize;
    Duration lookupTime;
    bool wasRemote;
    
    this(string targetId, size_t artifactSize, Duration lookupTime, bool wasRemote = false) @safe
    {
        super(CacheEventType.Hit);
        this.targetId = targetId;
        this.artifactSize = artifactSize;
        this.lookupTime = lookupTime;
        this.wasRemote = wasRemote;
    }
}

/// Cache miss event
final class CacheMissEvent : CacheEvent
{
    string targetId;
    Duration lookupTime;
    
    this(string targetId, Duration lookupTime) @safe
    {
        super(CacheEventType.Miss);
        this.targetId = targetId;
        this.lookupTime = lookupTime;
    }
}

/// Cache update event
final class CacheUpdateEvent : CacheEvent
{
    string targetId;
    size_t artifactSize;
    Duration updateTime;
    
    this(string targetId, size_t artifactSize, Duration updateTime) @safe
    {
        super(CacheEventType.Update);
        this.targetId = targetId;
        this.artifactSize = artifactSize;
        this.updateTime = updateTime;
    }
}

/// Cache eviction event
final class CacheEvictionEvent : CacheEvent
{
    size_t evictedCount;
    size_t freedBytes;
    Duration evictionTime;
    
    this(size_t evictedCount, size_t freedBytes, Duration evictionTime) @safe
    {
        super(CacheEventType.Evict);
        this.evictedCount = evictedCount;
        this.freedBytes = freedBytes;
        this.evictionTime = evictionTime;
    }
}

/// Remote cache event
final class RemoteCacheEvent : CacheEvent
{
    string targetId;
    size_t artifactSize;
    Duration networkTime;
    bool success;
    
    this(CacheEventType type, string targetId, size_t artifactSize, 
         Duration networkTime, bool success = true) @safe
    {
        super(type);
        this.targetId = targetId;
        this.artifactSize = artifactSize;
        this.networkTime = networkTime;
        this.success = success;
    }
}

/// Garbage collection event
final class CacheGCEvent : CacheEvent
{
    size_t collectedBlobs;
    size_t freedBytes;
    size_t orphanedArtifacts;
    Duration gcTime;
    
    this(CacheEventType type, size_t collectedBlobs, size_t freedBytes, 
         size_t orphanedArtifacts, Duration gcTime) @safe
    {
        super(type);
        this.collectedBlobs = collectedBlobs;
        this.freedBytes = freedBytes;
        this.orphanedArtifacts = orphanedArtifacts;
        this.gcTime = gcTime;
    }
}

/// Action cache event
final class ActionCacheEvent : CacheEvent
{
    string actionId;
    string targetId;
    Duration lookupTime;
    
    this(CacheEventType type, string actionId, string targetId, Duration lookupTime) @safe
    {
        super(type);
        this.actionId = actionId;
        this.targetId = targetId;
        this.lookupTime = lookupTime;
    }
}

