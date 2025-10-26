module cli.events;

import std.datetime : Duration;
import core.graph : BuildStatus;

/// Strongly-typed build events for event-driven rendering
/// Events are immutable to enable lock-free publishing

/// Base event interface
interface BuildEvent
{
    @property EventType type() const pure nothrow;
    @property Duration timestamp() const pure nothrow;
}

/// Event type enumeration
enum EventType
{
    BuildStarted,
    BuildCompleted,
    BuildFailed,
    TargetStarted,
    TargetCompleted,
    TargetFailed,
    TargetCached,
    TargetProgress,
    Message,
    Warning,
    Error,
    Statistics
}

/// Event severity levels
enum Severity
{
    Debug,
    Info,
    Warning,
    Error,
    Critical
}

/// Build lifecycle events

final class BuildStartedEvent : BuildEvent
{
    private EventType _type = EventType.BuildStarted;
    private Duration _timestamp;
    
    size_t totalTargets;
    size_t maxParallelism;
    
    this(size_t totalTargets, size_t maxParallelism, Duration timestamp)
    {
        this.totalTargets = totalTargets;
        this.maxParallelism = maxParallelism;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

final class BuildCompletedEvent : BuildEvent
{
    private EventType _type = EventType.BuildCompleted;
    private Duration _timestamp;
    
    size_t built;
    size_t cached;
    size_t failed;
    Duration duration;
    
    this(size_t built, size_t cached, size_t failed, Duration duration, Duration timestamp)
    {
        this.built = built;
        this.cached = cached;
        this.failed = failed;
        this.duration = duration;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

final class BuildFailedEvent : BuildEvent
{
    private EventType _type = EventType.BuildFailed;
    private Duration _timestamp;
    
    string reason;
    size_t failedCount;
    Duration duration;
    
    this(string reason, size_t failedCount, Duration duration, Duration timestamp)
    {
        this.reason = reason;
        this.failedCount = failedCount;
        this.duration = duration;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

/// Target-level events

final class TargetStartedEvent : BuildEvent
{
    private EventType _type = EventType.TargetStarted;
    private Duration _timestamp;
    
    string targetId;
    size_t index;
    size_t total;
    
    this(string targetId, size_t index, size_t total, Duration timestamp)
    {
        this.targetId = targetId;
        this.index = index;
        this.total = total;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

final class TargetCompletedEvent : BuildEvent
{
    private EventType _type = EventType.TargetCompleted;
    private Duration _timestamp;
    
    string targetId;
    Duration duration;
    size_t outputSize;
    
    this(string targetId, Duration duration, size_t outputSize, Duration timestamp)
    {
        this.targetId = targetId;
        this.duration = duration;
        this.outputSize = outputSize;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

final class TargetFailedEvent : BuildEvent
{
    private EventType _type = EventType.TargetFailed;
    private Duration _timestamp;
    
    string targetId;
    string error;
    Duration duration;
    
    this(string targetId, string error, Duration duration, Duration timestamp)
    {
        this.targetId = targetId;
        this.error = error;
        this.duration = duration;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

final class TargetCachedEvent : BuildEvent
{
    private EventType _type = EventType.TargetCached;
    private Duration _timestamp;
    
    string targetId;
    
    this(string targetId, Duration timestamp)
    {
        this.targetId = targetId;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

/// Progress tracking events

final class TargetProgressEvent : BuildEvent
{
    private EventType _type = EventType.TargetProgress;
    private Duration _timestamp;
    
    string targetId;
    string phase;
    double progress; // 0.0 to 1.0
    
    this(string targetId, string phase, double progress, Duration timestamp)
    {
        this.targetId = targetId;
        this.phase = phase;
        this.progress = progress;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

/// Message events

final class MessageEvent : BuildEvent
{
    private EventType _type = EventType.Message;
    private Duration _timestamp;
    
    string message;
    Severity severity;
    string targetId; // Optional: associated target
    
    this(string message, Severity severity, string targetId, Duration timestamp)
    {
        this.message = message;
        this.severity = severity;
        this.targetId = targetId;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

/// Statistics event for cache/performance metrics

final class StatisticsEvent : BuildEvent
{
    private EventType _type = EventType.Statistics;
    private Duration _timestamp;
    
    CacheStats cacheStats;
    BuildStats buildStats;
    
    this(CacheStats cacheStats, BuildStats buildStats, Duration timestamp)
    {
        this.cacheStats = cacheStats;
        this.buildStats = buildStats;
        this._timestamp = timestamp;
    }
    
    @property EventType type() const pure nothrow { return _type; }
    @property Duration timestamp() const pure nothrow { return _timestamp; }
}

/// Statistics structures

struct CacheStats
{
    size_t hits;
    size_t misses;
    size_t totalEntries;
    size_t totalSize;
    double hitRate;
}

struct BuildStats
{
    size_t totalTargets;
    size_t completedTargets;
    size_t failedTargets;
    size_t cachedTargets;
    Duration elapsed;
    double targetsPerSecond;
}

/// Event publisher interface for dependency injection
interface EventPublisher
{
    void publish(BuildEvent event);
    void subscribe(EventSubscriber subscriber);
    void unsubscribe(EventSubscriber subscriber);
}

/// Event subscriber interface
interface EventSubscriber
{
    void onEvent(BuildEvent event);
}

