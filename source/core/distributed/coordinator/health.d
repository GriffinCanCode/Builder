module core.distributed.coordinator.health;

import std.datetime : Duration, Clock, SysTime, seconds, msecs, hnsecs;
import std.algorithm : min, max, filter, map, sort;
import std.array : array;
import std.math : exp, log10;
import std.conv : to;
import core.atomic;
import core.sync.mutex : Mutex;
import core.thread : Thread;
import core.distributed.protocol.protocol;
import core.distributed.coordinator.registry;
import core.distributed.coordinator.scheduler;
import errors : Result, Ok, Err;
import utils.logging.logger;

/// Worker health state (circuit breaker states)
enum HealthState : ubyte
{
    Healthy,        // Normal operation
    Degraded,       // Performance issues detected
    Failing,        // Intermittent failures
    Failed,         // Circuit open - not accepting work
    Recovering      // Circuit half-open - testing recovery
}

/// Health check result
struct HealthCheckResult
{
    WorkerId worker;
    HealthState state;
    SysTime timestamp;
    Duration latency;
    bool responsive;
    string reason;
}

/// Worker health tracking (circuit breaker pattern)
struct WorkerHealth
{
    WorkerId id;
    HealthState state;
    SysTime lastHealthy;
    SysTime lastFailed;
    size_t consecutiveFailures;
    size_t totalFailures;
    size_t recoveryAttempts;
    Duration avgResponseTime;
    float failureRate;
    
    /// Exponential backoff for recovery attempts
    Duration nextRetryDelay() const pure @safe nothrow @nogc
    {
        // Exponential backoff: 2^attempts seconds, max 300s
        immutable baseSeconds = 1;
        immutable maxSeconds = 300;
        immutable delaySeconds = min(
            baseSeconds * (1 << min(recoveryAttempts, 8)),
            maxSeconds
        );
        return seconds(delaySeconds);
    }
    
    /// Should we attempt recovery?
    bool shouldAttemptRecovery(SysTime now) const @safe
    {
        if (state != HealthState.Failed)
            return false;
        
        immutable elapsed = now - lastFailed;
        return elapsed >= nextRetryDelay();
    }
}

/// Advanced health monitor with circuit breaker pattern
/// Implements adaptive heartbeat intervals and failure detection
final class HealthMonitor
{
    private WorkerRegistry registry;
    private DistributedScheduler scheduler;
    private WorkerHealth[WorkerId] health;
    private Mutex mutex;
    private Thread monitorThread;
    private shared bool running;
    
    // Configuration
    private Duration heartbeatInterval;
    private Duration heartbeatTimeout;
    private Duration degradedThreshold;
    private size_t failureThreshold;
    private float degradedCpuThreshold;
    private float degradedMemThreshold;
    
    // Adaptive intervals
    private shared Duration[WorkerId] adaptiveIntervals;
    
    // Statistics
    private shared size_t totalChecks;
    private shared size_t healthyChecks;
    private shared size_t failedChecks;
    
    this(
        WorkerRegistry registry,
        DistributedScheduler scheduler,
        Duration heartbeatInterval = 5.seconds,
        Duration heartbeatTimeout = 15.seconds) @trusted
    {
        this.registry = registry;
        this.scheduler = scheduler;
        this.heartbeatInterval = heartbeatInterval;
        this.heartbeatTimeout = heartbeatTimeout;
        this.degradedThreshold = 10.seconds;
        this.failureThreshold = 3;
        this.degradedCpuThreshold = 0.95;
        this.degradedMemThreshold = 0.90;
        this.mutex = new Mutex();
    }
    
    /// Start health monitoring
    Result!DistributedError start() @trusted
    {
        if (atomicLoad(running))
            return Result!DistributedError.err(
                new DistributedError("Health monitor already running"));
        
        atomicStore(running, true);
        
        monitorThread = new Thread(&monitorLoop);
        monitorThread.start();
        
        Logger.info("Health monitor started");
        return Ok!DistributedError();
    }
    
    /// Stop health monitoring
    void stop() @trusted
    {
        atomicStore(running, false);
        
        if (monitorThread !is null)
        {
            monitorThread.join();
            monitorThread = null;
        }
        
        Logger.info("Health monitor stopped");
    }
    
    /// Process heartbeat from worker
    void onHeartBeat(WorkerId worker, HeartBeat hb) @trusted
    {
        synchronized (mutex)
        {
            // Update registry
            registry.updateHeartbeat(worker, hb);
            
            // Update health tracking
            if (worker !in health)
                health[worker] = WorkerHealth.init;
            
            auto h = &health[worker];
            h.id = worker;
            h.lastHealthy = Clock.currTime;
            h.consecutiveFailures = 0;
            
            // Calculate average response time (exponential moving average)
            immutable elapsed = Clock.currTime - hb.timestamp;
            if (h.avgResponseTime == Duration.zero)
                h.avgResponseTime = elapsed;
            else
            {
                // Use total hnsecs (100-nanosecond intervals) for calculation
                immutable avgHnsecs = cast(long)(h.avgResponseTime.total!"hnsecs" * 0.9 + elapsed.total!"hnsecs" * 0.1);
                h.avgResponseTime = avgHnsecs.hnsecs;
            }
            
            // Check for degraded performance
            if (hb.metrics.cpuUsage > degradedCpuThreshold)
            {
                transitionState(worker, HealthState.Degraded, 
                              "High CPU usage: " ~ hb.metrics.cpuUsage.to!string);
            }
            else if (hb.metrics.memoryUsage > degradedMemThreshold)
            {
                transitionState(worker, HealthState.Degraded,
                              "High memory usage: " ~ hb.metrics.memoryUsage.to!string);
            }
            else if (h.avgResponseTime > degradedThreshold)
            {
                transitionState(worker, HealthState.Degraded,
                              "High latency: " ~ h.avgResponseTime.toString());
            }
            else if (h.state == HealthState.Degraded || h.state == HealthState.Recovering)
            {
                // Recovery to healthy
                transitionState(worker, HealthState.Healthy, "Metrics normalized");
            }
            
            // Adapt heartbeat interval based on worker state
            updateAdaptiveInterval(worker, hb);
        }
        
        atomicOp!"+="(totalChecks, 1);
        atomicOp!"+="(healthyChecks, 1);
    }
    
    /// Check worker health (called periodically)
    void checkHealth() @trusted
    {
        immutable now = Clock.currTime;
        auto workers = registry.allWorkers();
        
        foreach (worker; workers)
        {
            synchronized (mutex)
            {
                if (worker.id !in health)
                    health[worker.id] = WorkerHealth.init;
                
                auto h = &health[worker.id];
                immutable elapsed = now - worker.lastSeen;
                
                // Check for timeout
                if (elapsed > heartbeatTimeout)
                {
                    handleWorkerTimeout(worker.id, h, elapsed);
                }
                // Check for recovery attempt
                else if (h.shouldAttemptRecovery(now))
                {
                    attemptRecovery(worker.id, h);
                }
            }
        }
        
        atomicOp!"+="(totalChecks, 1);
    }
    
    /// Get worker health state
    HealthState getWorkerHealth(WorkerId worker) @trusted
    {
        synchronized (mutex)
        {
            if (auto h = worker in health)
                return h.state;
            return HealthState.Healthy;
        }
    }
    
    /// Get all worker health states
    WorkerHealth[] getAllHealth() @trusted
    {
        synchronized (mutex)
        {
            return health.values.dup;
        }
    }
    
    /// Get health statistics
    struct HealthStats
    {
        size_t totalWorkers;
        size_t healthyWorkers;
        size_t degradedWorkers;
        size_t failingWorkers;
        size_t failedWorkers;
        size_t recoveringWorkers;
        float overallHealthRate;
    }
    
    HealthStats getStats() @trusted
    {
        HealthStats stats;
        
        synchronized (mutex)
        {
            stats.totalWorkers = health.length;
            
            foreach (h; health.values)
            {
                final switch (h.state)
                {
                    case HealthState.Healthy:
                        stats.healthyWorkers++;
                        break;
                    case HealthState.Degraded:
                        stats.degradedWorkers++;
                        break;
                    case HealthState.Failing:
                        stats.failingWorkers++;
                        break;
                    case HealthState.Failed:
                        stats.failedWorkers++;
                        break;
                    case HealthState.Recovering:
                        stats.recoveringWorkers++;
                        break;
                }
            }
            
            if (stats.totalWorkers > 0)
            {
                stats.overallHealthRate = 
                    cast(float)(stats.healthyWorkers + stats.recoveringWorkers) / 
                    cast(float)stats.totalWorkers;
            }
        }
        
        return stats;
    }
    
    private:
    
    /// Main monitoring loop
    void monitorLoop() @trusted
    {
        while (atomicLoad(running))
        {
            try
            {
                checkHealth();
                Thread.sleep(heartbeatInterval);
            }
            catch (Exception e)
            {
                Logger.error("Health check failed: " ~ e.msg);
            }
        }
    }
    
    /// Handle worker timeout
    void handleWorkerTimeout(WorkerId worker, WorkerHealth* h, Duration elapsed) @trusted
    {
        h.consecutiveFailures++;
        h.totalFailures++;
        h.lastFailed = Clock.currTime;
        
        atomicOp!"+="(failedChecks, 1);
        
        Logger.warning("Worker timeout: " ~ worker.toString() ~ 
                      " (elapsed: " ~ elapsed.toString() ~ 
                      ", failures: " ~ h.consecutiveFailures.to!string ~ ")");
        
        // State transitions based on failure count
        if (h.consecutiveFailures >= failureThreshold)
        {
            // Circuit breaker opens
            transitionState(worker, HealthState.Failed, 
                          "Consecutive failures: " ~ h.consecutiveFailures.to!string);
            
            // Mark worker as failed in registry
            registry.markWorkerFailed(worker);
            
            // Reassign its work
            scheduler.onWorkerFailure(worker);
        }
        else if (h.consecutiveFailures >= failureThreshold / 2)
        {
            transitionState(worker, HealthState.Failing,
                          "Intermittent failures detected");
        }
    }
    
    /// Attempt to recover failed worker
    void attemptRecovery(WorkerId worker, WorkerHealth* h) @trusted
    {
        h.recoveryAttempts++;
        
        Logger.info("Attempting recovery for worker " ~ worker.toString() ~ 
                   " (attempt " ~ h.recoveryAttempts.to!string ~ ")");
        
        // Transition to recovering state (circuit half-open)
        transitionState(worker, HealthState.Recovering,
                      "Recovery attempt " ~ h.recoveryAttempts.to!string);
        
        // Send test heartbeat request
        // If worker responds, it will call onHeartBeat and transition to Healthy
        // If it doesn't respond, next timeout will transition back to Failed
    }
    
    /// Transition worker to new health state
    void transitionState(WorkerId worker, HealthState newState, string reason) @trusted
    {
        if (auto h = worker in health)
        {
            immutable oldState = h.state;
            if (oldState != newState)
            {
                h.state = newState;
                
                Logger.info("Worker " ~ worker.toString() ~ 
                          " health transition: " ~ oldState.to!string ~ 
                          " -> " ~ newState.to!string ~ 
                          " (" ~ reason ~ ")");
                
                // Reset recovery attempts on successful recovery
                if (newState == HealthState.Healthy)
                    h.recoveryAttempts = 0;
            }
        }
    }
    
    /// Update adaptive heartbeat interval based on worker state
    void updateAdaptiveInterval(WorkerId worker, HeartBeat hb) @trusted
    {
        // Adaptive heartbeat frequency based on load and state
        // High load = less frequent (reduce overhead)
        // Low load = more frequent (better responsiveness)
        
        immutable load = hb.metrics.cpuUsage * 0.7 + hb.metrics.memoryUsage * 0.3;
        
        Duration interval;
        if (load > 0.8)
            interval = heartbeatInterval * 2;  // Reduce frequency
        else if (load < 0.3)
            interval = heartbeatInterval / 2;  // Increase frequency
        else
            interval = heartbeatInterval;      // Default
        
        // Store adaptive interval for this worker
        adaptiveIntervals[worker] = interval;
    }
    
    /// Get adaptive interval for worker
    Duration getAdaptiveInterval(WorkerId worker) @trusted
    {
        if (auto interval = worker in adaptiveIntervals)
            return atomicLoad(*interval);
        return heartbeatInterval;
    }
}

/// Failure detector using phi-accrual algorithm
/// More sophisticated than simple timeout
/// Reference: "The φ Accrual Failure Detector" (Hayashibara et al.)
struct PhiAccrualDetector
{
    private double[] intervalHistory;  // Recent inter-arrival times
    private SysTime lastHeartbeat;
    private immutable size_t windowSize = 100;
    private immutable double threshold = 8.0;  // phi threshold
    
    /// Update with new heartbeat
    void update(SysTime now) @safe
    {
        if (lastHeartbeat != SysTime.init)
        {
            immutable interval = (now - lastHeartbeat).total!"msecs";
            
            // Add to history (circular buffer)
            if (intervalHistory.length >= windowSize)
                intervalHistory = intervalHistory[1 .. $];
            
            intervalHistory ~= cast(double)interval;
        }
        
        lastHeartbeat = now;
    }
    
    /// Calculate phi (suspicion level)
    double phi(SysTime now) const @safe
    {
        if (intervalHistory.length < 2)
            return 0.0;
        
        // Calculate mean and standard deviation
        immutable mean = calculateMean(intervalHistory);
        immutable stddev = calculateStdDev(intervalHistory, mean);
        
        // Time since last heartbeat
        immutable timeSince = (now - lastHeartbeat).total!"msecs";
        
        // Calculate phi
        immutable p = probabilityOfLater(timeSince, mean, stddev);
        return -log10(p);
    }
    
    /// Is the worker suspected as failed?
    bool isSuspected(SysTime now) const @safe
    {
        return phi(now) > threshold;
    }
    
    private:
    
    static double calculateMean(const double[] values) pure @safe nothrow
    {
        if (values.length == 0)
            return 0.0;
        
        double sum = 0.0;
        foreach (v; values)
            sum += v;
        
        return sum / values.length;
    }
    
    static double calculateStdDev(const double[] values, double mean) pure @safe nothrow
    {
        if (values.length <= 1)
            return 0.0;
        
        double sumSq = 0.0;
        foreach (v; values)
        {
            immutable diff = v - mean;
            sumSq += diff * diff;
        }
        
        import std.math : sqrt;
        return sqrt(sumSq / (values.length - 1));
    }
    
    static double probabilityOfLater(double time, double mean, double stddev) pure @safe nothrow
    {
        import std.math : sqrt, exp, PI;
        
        if (stddev == 0.0)
            return time > mean ? 0.01 : 0.99;
        
        // Normal distribution CDF approximation
        immutable z = (time - mean) / stddev;
        return 0.5 * (1.0 + erf(z / sqrt(2.0)));
    }
    
    // Error function approximation
    static double erf(double x) pure @safe nothrow
    {
        import std.math : abs, sqrt, PI;
        
        // Abramowitz and Stegun approximation
        immutable a1 =  0.254829592;
        immutable a2 = -0.284496736;
        immutable a3 =  1.421413741;
        immutable a4 = -1.453152027;
        immutable a5 =  1.061405429;
        immutable p  =  0.3275911;
        
        immutable sign = x < 0 ? -1.0 : 1.0;
        immutable absX = abs(x);
        
        immutable t = 1.0 / (1.0 + p * absX);
        immutable y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * 
                      exp(-absX * absX);
        
        return sign * y;
    }
}



