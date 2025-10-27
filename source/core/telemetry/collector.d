module core.telemetry.collector;

import std.datetime : Duration, SysTime, Clock;
import core.sync.mutex : Mutex;
import cli.events.events;
import errors;

/// Thread-safe telemetry collector that subscribes to build events
/// Aggregates metrics in real-time for analysis and persistence
final class TelemetryCollector : EventSubscriber
{
    private BuildSession currentSession;
    private Mutex collectorMutex;
    private bool sessionActive;
    
    this() @safe
    {
        this.collectorMutex = new Mutex();
        this.sessionActive = false;
    }
    
    /// Event handler - thread-safe
    void onEvent(BuildEvent event) @trusted
    {
        synchronized (collectorMutex)
        {
            final switch (event.type)
            {
                case EventType.BuildStarted:
                    handleBuildStarted(cast(BuildStartedEvent)event);
                    break;
                case EventType.BuildCompleted:
                    handleBuildCompleted(cast(BuildCompletedEvent)event);
                    break;
                case EventType.BuildFailed:
                    handleBuildFailed(cast(BuildFailedEvent)event);
                    break;
                case EventType.TargetStarted:
                    handleTargetStarted(cast(TargetStartedEvent)event);
                    break;
                case EventType.TargetCompleted:
                    handleTargetCompleted(cast(TargetCompletedEvent)event);
                    break;
                case EventType.TargetFailed:
                    handleTargetFailed(cast(TargetFailedEvent)event);
                    break;
                case EventType.TargetCached:
                    handleTargetCached(cast(TargetCachedEvent)event);
                    break;
                case EventType.TargetProgress:
                    // Not tracked for historical data
                    break;
                case EventType.Message:
                    // Not tracked for historical data
                    break;
                case EventType.Warning:
                    // Not tracked for historical data
                    break;
                case EventType.Error:
                    // Not tracked for historical data
                    break;
                case EventType.Statistics:
                    handleStatistics(cast(StatisticsEvent)event);
                    break;
            }
        }
    }
    
    /// Get current session - thread-safe
    Result!(BuildSession, TelemetryError) getSession() @trusted
    {
        synchronized (collectorMutex)
        {
            if (!sessionActive)
                return Result!(BuildSession, TelemetryError).err(
                    TelemetryError.noActiveSession()
                );
            
            return Result!(BuildSession, TelemetryError).ok(currentSession);
        }
    }
    
    /// Reset collector state
    void reset() @trusted
    {
        synchronized (collectorMutex)
        {
            currentSession = BuildSession.init;
            sessionActive = false;
        }
    }
    
    private void handleBuildStarted(BuildStartedEvent event) @safe
    {
        currentSession = BuildSession();
        currentSession.startTime = Clock.currTime();
        currentSession.totalTargets = event.totalTargets;
        currentSession.maxParallelism = event.maxParallelism;
        sessionActive = true;
    }
    
    private void handleBuildCompleted(BuildCompletedEvent event) @safe
    {
        currentSession.endTime = Clock.currTime();
        currentSession.totalDuration = event.duration;
        currentSession.built = event.built;
        currentSession.cached = event.cached;
        currentSession.failed = event.failed;
        currentSession.succeeded = true;
    }
    
    private void handleBuildFailed(BuildFailedEvent event) @safe
    {
        currentSession.endTime = Clock.currTime();
        currentSession.totalDuration = event.duration;
        currentSession.failed = event.failedCount;
        currentSession.succeeded = false;
        currentSession.failureReason = event.reason;
    }
    
    private void handleTargetStarted(TargetStartedEvent event) @safe
    {
        TargetMetric metric;
        metric.targetId = event.targetId;
        metric.startTime = Clock.currTime();
        currentSession.targets[event.targetId] = metric;
    }
    
    private void handleTargetCompleted(TargetCompletedEvent event) @safe
    {
        if (auto metric = event.targetId in currentSession.targets)
        {
            metric.endTime = Clock.currTime();
            metric.duration = event.duration;
            metric.outputSize = event.outputSize;
            metric.status = TargetStatus.Completed;
        }
    }
    
    private void handleTargetFailed(TargetFailedEvent event) @safe
    {
        if (auto metric = event.targetId in currentSession.targets)
        {
            metric.endTime = Clock.currTime();
            metric.duration = event.duration;
            metric.status = TargetStatus.Failed;
            metric.error = event.error;
        }
    }
    
    private void handleTargetCached(TargetCachedEvent event) @safe
    {
        if (auto metric = event.targetId in currentSession.targets)
        {
            metric.endTime = Clock.currTime();
            metric.status = TargetStatus.Cached;
        }
    }
    
    private void handleStatistics(StatisticsEvent event) @safe
    {
        currentSession.cacheHitRate = event.cacheStats.hitRate;
        currentSession.cacheHits = event.cacheStats.hits;
        currentSession.cacheMisses = event.cacheStats.misses;
        currentSession.targetsPerSecond = event.buildStats.targetsPerSecond;
    }
}

/// Represents a complete build session with all metrics
struct BuildSession
{
    SysTime startTime;
    SysTime endTime;
    Duration totalDuration;
    
    size_t totalTargets;
    size_t built;
    size_t cached;
    size_t failed;
    size_t maxParallelism;
    
    double cacheHitRate = 0.0;
    size_t cacheHits;
    size_t cacheMisses;
    double targetsPerSecond = 0.0;
    
    bool succeeded;
    string failureReason;
    
    TargetMetric[string] targets;
    
    /// Calculate actual parallelism utilization
    @property double parallelismUtilization() const pure nothrow @safe
    {
        if (maxParallelism == 0 || totalDuration.total!"msecs" == 0)
            return 0.0;
        
        // Sum all target durations
        long totalTargetTime = 0;
        foreach (target; targets.byValue)
        {
            totalTargetTime += target.duration.total!"msecs";
        }
        
        immutable theoreticalMax = maxParallelism * totalDuration.total!"msecs";
        return (totalTargetTime * 100.0) / theoreticalMax;
    }
    
    /// Get slowest targets
    TargetMetric[] slowest(size_t count = 10) const pure @safe
    {
        import std.algorithm : sort;
        import std.array : array;
        
        auto sorted = targets.values.array.dup
            .sort!((a, b) => a.duration > b.duration);
        
        immutable limit = count < sorted.length ? count : sorted.length;
        return sorted[0 .. limit].array;
    }
    
    /// Get average build time per target
    @property Duration averageTargetTime() const pure nothrow @safe
    {
        import std.datetime : dur;
        
        if (targets.length == 0)
            return dur!"msecs"(0);
        
        long totalMs = 0;
        foreach (target; targets.byValue)
        {
            totalMs += target.duration.total!"msecs";
        }
        
        return dur!"msecs"(totalMs / targets.length);
    }
}

/// Individual target build metrics
struct TargetMetric
{
    string targetId;
    SysTime startTime;
    SysTime endTime;
    Duration duration;
    size_t outputSize;
    TargetStatus status;
    string error;
}

/// Target build status
enum TargetStatus
{
    Pending,
    Completed,
    Failed,
    Cached
}

/// Telemetry-specific errors
struct TelemetryError
{
    string message;
    ErrorCode code;
    
    static TelemetryError noActiveSession() pure @safe
    {
        return TelemetryError("No active build session", ErrorCode.TelemetryNoSession);
    }
    
    static TelemetryError storageError(string details) pure @safe
    {
        return TelemetryError("Storage error: " ~ details, ErrorCode.TelemetryStorage);
    }
    
    static TelemetryError invalidData(string details) pure @safe
    {
        return TelemetryError("Invalid data: " ~ details, ErrorCode.TelemetryInvalid);
    }
    
    string toString() const pure nothrow @safe
    {
        return message;
    }
}

