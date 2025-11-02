module core.execution.remote.pool;

import std.datetime : Duration, Clock, SysTime, seconds, minutes;
import std.algorithm : filter, map, sort, min, max;
import std.array : array;
import std.conv : to;
import std.math : exp, log;
import core.atomic;
import core.sync.mutex : Mutex;
import core.thread : Thread;
import core.distributed.protocol.protocol;
import core.distributed.coordinator.registry;
import core.execution.remote.scaling.predictor : LoadPredictor;
import core.execution.remote.providers;
import errors;
import utils.logging.logger;

/// Worker pool manager with dynamic scaling
/// 
/// Design: Predictive autoscaling using exponential smoothing and queuing theory
/// - Scales based on queue depth, latency, and utilization metrics
/// - Uses Little's Law: L = λW (queue length = arrival rate × wait time)
/// - Exponential smoothing for load prediction: St = αXt + (1-α)St-1
/// - Hysteresis to prevent scaling oscillation

/// Pool configuration
struct PoolConfig
{
    size_t minWorkers = 1;              // Minimum pool size
    size_t maxWorkers = 100;            // Maximum pool size
    size_t targetWorkers = 4;           // Target steady-state
    
    float scaleUpThreshold = 0.75;      // Scale up when utilization > 75%
    float scaleDownThreshold = 0.25;    // Scale down when < 25%
    
    Duration scaleUpCooldown = 30.seconds;   // Cooldown after scale up
    Duration scaleDownCooldown = 2.minutes;  // Cooldown after scale down
    
    Duration healthCheckInterval = 10.seconds;
    Duration workerStartTimeout = 2.minutes;
    
    float smoothingAlpha = 0.3;         // Exponential smoothing factor
    size_t predictionWindow = 10;       // Samples for prediction
    
    bool enablePredictiveScaling = true;
    bool enableAutoScale = true;
}

/// Worker pool statistics
struct PoolStats
{
    size_t totalWorkers;
    size_t idleWorkers;
    size_t busyWorkers;
    size_t failedWorkers;
    size_t pendingTasks;
    float avgUtilization;
    float predictedLoad;
    Duration avgLatency;
}

/// Worker pool entry
private struct PoolWorker
{
    WorkerId id;
    WorkerState state;
    SysTime lastSeen;
    float utilization;
    bool healthy;
}

/// Worker pool manager
final class WorkerPool
{
    private PoolConfig config;
    private WorkerRegistry registry;
    private Mutex mutex;
    
    private LoadPredictor utilizationPredictor;
    private LoadPredictor latencyPredictor;
    
    private SysTime lastScaleUp;
    private SysTime lastScaleDown;
    
    private shared bool running;
    private Thread scalerThread;
    
    this(PoolConfig config, WorkerRegistry registry) @trusted
    {
        this.config = config;
        this.registry = registry;
        this.mutex = new Mutex();
        
        this.utilizationPredictor = LoadPredictor(
            config.smoothingAlpha,
            config.predictionWindow
        );
        
        this.latencyPredictor = LoadPredictor(
            config.smoothingAlpha,
            config.predictionWindow
        );
        
        atomicStore(running, false);
    }
    
    /// Start pool manager
    Result!BuildError start() @trusted
    {
        synchronized (mutex)
        {
            if (atomicLoad(running))
                return Ok!BuildError();
            
            atomicStore(running, true);
            
            // Start autoscaler thread
            if (config.enableAutoScale)
            {
                scalerThread = new Thread(&scalerLoop);
                scalerThread.start();
                Logger.info("Worker pool autoscaler started");
            }
            
            return Ok!BuildError();
        }
    }
    
    /// Stop pool manager
    void stop() @trusted
    {
        atomicStore(running, false);
        
        if (scalerThread !is null)
            scalerThread.join();
        
        Logger.info("Worker pool stopped");
    }
    
    /// Get pool statistics
    PoolStats getStats() @trusted
    {
        synchronized (mutex)
        {
            PoolStats stats;
            
            immutable totalWorkers = registry.count();
            immutable healthyWorkers = registry.healthyCount();
            
            stats.totalWorkers = totalWorkers;
            stats.busyWorkers = 0;  // Would query from registry
            stats.idleWorkers = healthyWorkers - stats.busyWorkers;
            stats.failedWorkers = totalWorkers - healthyWorkers;
            stats.avgUtilization = utilizationPredictor.predict();
            stats.predictedLoad = stats.avgUtilization;
            
            return stats;
        }
    }
    
    /// Compute desired worker count based on current metrics
    private size_t computeDesiredWorkers() @trusted
    {
        immutable stats = getStats();
        
        // Current utilization
        immutable currentUtil = stats.totalWorkers > 0 ?
            cast(float)stats.busyWorkers / cast(float)stats.totalWorkers : 0.0f;
        
        // Update predictor
        utilizationPredictor.observe(currentUtil);
        
        // Get prediction
        immutable predictedUtil = utilizationPredictor.predict();
        immutable trend = utilizationPredictor.trend();
        
        // Adjust target based on prediction and trend
        size_t desired = stats.totalWorkers;
        
        if (predictedUtil > config.scaleUpThreshold || trend > 0.1f)
        {
            // Scale up needed
            immutable scaleUpFactor = (predictedUtil - config.scaleUpThreshold) / 
                                     (1.0f - config.scaleUpThreshold);
            
            // Aggressive scale-up if trend is steep
            immutable trendMultiplier = 1.0f + (trend > 0 ? trend * 2.0f : 0.0f);
            
            immutable increment = max(1, cast(size_t)(stats.totalWorkers * scaleUpFactor * trendMultiplier));
            desired = stats.totalWorkers + increment;
        }
        else if (predictedUtil < config.scaleDownThreshold && trend < -0.05f)
        {
            // Scale down possible
            immutable scaleDownFactor = (config.scaleDownThreshold - predictedUtil) / 
                                       config.scaleDownThreshold;
            
            immutable decrement = max(1, cast(size_t)(stats.totalWorkers * scaleDownFactor * 0.5));
            desired = stats.totalWorkers > decrement ? stats.totalWorkers - decrement : 1;
        }
        
        // Clamp to bounds
        desired = max(config.minWorkers, min(config.maxWorkers, desired));
        
        Logger.debugLog("Pool scaling decision: current=" ~ stats.totalWorkers.to!string ~
                       ", util=" ~ (currentUtil * 100).to!size_t.to!string ~ "%" ~
                       ", predicted=" ~ (predictedUtil * 100).to!size_t.to!string ~ "%" ~
                       ", trend=" ~ trend.to!string ~
                       ", desired=" ~ desired.to!string);
        
        return desired;
    }
    
    /// Scale pool to target size
    private Result!BuildError scale(size_t targetSize) @trusted
    {
        immutable currentSize = registry.count();
        
        if (targetSize == currentSize)
            return Ok!BuildError();
        
        if (targetSize > currentSize)
        {
            // Scale up
            immutable now = Clock.currTime;
            if (now - lastScaleUp < config.scaleUpCooldown)
            {
                Logger.debugLog("Scale up in cooldown");
                return Ok!BuildError();
            }
            
            immutable toAdd = targetSize - currentSize;
            Logger.info("Scaling up: adding " ~ toAdd.to!string ~ " workers");
            
            // Request worker creation (would integrate with actual worker provisioning)
            foreach (_; 0 .. toAdd)
            {
                auto result = provisionWorker();
                if (result.isErr)
                {
                    Logger.error("Failed to provision worker: " ~ 
                               result.unwrapErr().message());
                }
            }
            
            lastScaleUp = now;
        }
        else
        {
            // Scale down
            immutable now = Clock.currTime;
            if (now - lastScaleDown < config.scaleDownCooldown)
            {
                Logger.debugLog("Scale down in cooldown");
                return Ok!BuildError();
            }
            
            immutable toRemove = currentSize - targetSize;
            Logger.info("Scaling down: removing " ~ toRemove.to!string ~ " workers");
            
            // Drain and remove least utilized workers
            auto result = drainWorkers(toRemove);
            if (result.isErr)
            {
                Logger.error("Failed to drain workers: " ~ result.unwrapErr().message());
            }
            
            lastScaleDown = now;
        }
        
        return Ok!BuildError();
    }
    
    /// Provision new worker (stub - would integrate with cloud provider)
    private Result!(WorkerId, BuildError) provisionWorker() @trusted
    {
        // This would:
        // 1. Call cloud provider API (AWS EC2, GCP Compute, K8s, etc.)
        // 2. Launch worker instance with Builder worker binary
        // 3. Wait for worker to register with coordinator
        // 4. Return worker ID
        
        // For now, return placeholder
        import std.random : uniform;
        return Ok!(WorkerId, BuildError)(WorkerId(uniform!ulong()));
    }
    
    /// Drain and remove workers
    private Result!BuildError drainWorkers(size_t count) @trusted
    {
        // This would:
        // 1. Select least utilized workers
        // 2. Mark as draining (no new work)
        // 3. Wait for current work to complete
        // 4. Deregister and terminate workers
        
        Logger.info("Draining " ~ count.to!string ~ " workers");
        return Ok!BuildError();
    }
    
    /// Autoscaler loop
    private void scalerLoop() @trusted
    {
        while (atomicLoad(running))
        {
            try
            {
                // Compute desired size
                immutable desired = computeDesiredWorkers();
                
                // Execute scaling if needed
                auto result = scale(desired);
                if (result.isErr)
                {
                    Logger.error("Scaling failed: " ~ result.unwrapErr().message());
                }
                
                // Sleep until next check
                Thread.sleep(config.healthCheckInterval);
            }
            catch (Exception e)
            {
                Logger.error("Scaler loop exception: " ~ e.msg);
                Thread.sleep(config.healthCheckInterval);
            }
        }
    }
}
