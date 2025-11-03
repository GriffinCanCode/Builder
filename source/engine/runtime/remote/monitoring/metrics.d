module engine.runtime.remote.monitoring.metrics;

import std.datetime : Duration, Clock, SysTime;
import engine.distributed.coordinator.coordinator;
import engine.runtime.remote.pool;
import core.sync.mutex : Mutex;

/// Service metrics collector
/// 
/// Responsibility: Collect and aggregate service metrics
/// Separate from service lifecycle for SRP
final class RemoteServiceMetricsCollector
{
    private Coordinator coordinator;
    private WorkerPool pool;
    private Mutex mutex;
    private SysTime startTime;
    
    this(Coordinator coordinator, WorkerPool pool) @trusted
    {
        this.coordinator = coordinator;
        this.pool = pool;
        this.mutex = new Mutex();
        this.startTime = Clock.currTime;
    }
    
    /// Get service metrics
    ServiceMetrics collect() @trusted
    {
        synchronized (mutex)
        {
            ServiceMetrics metrics;
            
            auto coordStats = coordinator.getStats();
            auto poolStats = pool.getStats();
            
            metrics.totalExecutions = coordStats.completedActions + coordStats.failedActions;
            metrics.successfulExecutions = coordStats.completedActions;
            metrics.failedExecutions = coordStats.failedActions;
            metrics.cachedExecutions = 0;  // Would track from action cache
            
            metrics.activeWorkers = poolStats.totalWorkers;
            metrics.idleWorkers = poolStats.idleWorkers;
            metrics.busyWorkers = poolStats.busyWorkers;
            
            metrics.queueDepth = coordStats.pendingActions;
            metrics.avgUtilization = poolStats.avgUtilization;
            
            metrics.uptime = Clock.currTime - startTime;
            
            return metrics;
        }
    }
    
    /// Reset metrics collection (e.g., after rotation)
    void reset() @trusted
    {
        synchronized (mutex)
        {
            startTime = Clock.currTime;
        }
    }
}

/// Service metrics snapshot
struct ServiceMetrics
{
    // Execution metrics
    size_t totalExecutions;
    size_t successfulExecutions;
    size_t failedExecutions;
    size_t cachedExecutions;
    
    // Worker metrics
    size_t activeWorkers;
    size_t idleWorkers;
    size_t busyWorkers;
    
    // Queue metrics
    size_t queueDepth;
    float avgUtilization;
    
    // Service metrics
    Duration uptime;
}

