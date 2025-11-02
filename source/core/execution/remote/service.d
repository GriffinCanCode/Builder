module core.execution.remote.service;

import std.datetime : Duration, Clock, SysTime, seconds;
import std.algorithm : map, filter;
import std.array : array;
import std.conv : to;
import core.atomic;
import core.sync.mutex : Mutex;
import core.thread : Thread;
import core.graph.graph : BuildGraph;
import core.distributed.coordinator.coordinator;
import core.distributed.coordinator.registry;
import core.distributed.protocol.protocol : ActionId, WorkerId;
import core.execution.remote.executor;
import core.execution.remote.pool;
import core.execution.remote.reapi;
import core.execution.hermetic;
import errors;
import utils.logging.logger;

/// Remote execution service configuration
struct RemoteServiceConfig
{
    // Coordinator settings
    string coordinatorHost = "0.0.0.0";
    ushort coordinatorPort = 9000;
    
    // Pool settings  
    PoolConfig poolConfig;
    
    // Executor settings
    RemoteExecutorConfig executorConfig;
    
    // Service settings
    bool enableReapi = true;                // Expose REAPI endpoint?
    ushort reapiPort = 9001;                // REAPI service port
    
    Duration healthCheckInterval = 10.seconds;
    bool enableMetrics = true;
}

/// Remote execution service
/// Central orchestrator for distributed build execution
///
/// Architecture:
/// ┌─────────────────────────────────────────────────┐
/// │         Remote Execution Service                 │
/// │                                                   │
/// │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
/// │  │  REAPI   │  │  Native  │  │ Metrics  │      │
/// │  │ Adapter  │  │   API    │  │ Exporter │      │
/// │  └────┬─────┘  └────┬─────┘  └──────────┘      │
/// │       │             │                            │
/// │       └─────┬───────┘                            │
/// │             │                                    │
/// │       ┌─────▼──────┐                            │
/// │       │ Coordinator │                            │
/// │       └─────┬──────┘                            │
/// │             │                                    │
/// │    ┌────────┴────────┐                          │
/// │    │   Worker Pool    │                          │
/// │    │  (Auto-scaling)  │                          │
/// │    └────────┬────────┘                          │
/// └─────────────┼──────────────────────────────────┘
///               │
///       ┌───────┴────────┐
///       │                │
///   ┌───▼───┐        ┌───▼───┐
///   │Worker1│        │Worker2│  (Native hermetic sandboxing)
///   └───────┘        └───────┘
///
final class RemoteExecutionService
{
    private RemoteServiceConfig config;
    private Coordinator coordinator;
    private WorkerRegistry registry;
    private WorkerPool pool;
    private RemoteExecutor executor;
    private ReapiAdapter reapiAdapter;
    private BuildGraph graph;
    
    private shared bool running;
    private Thread healthThread;
    private Mutex mutex;
    
    this(RemoteServiceConfig config, BuildGraph graph) @trusted
    {
        this.config = config;
        this.graph = graph;
        this.mutex = new Mutex();
        atomicStore(running, false);
        
        // Initialize components
        initializeComponents();
    }
    
    /// Initialize service components
    private void initializeComponents() @trusted
    {
        // Worker registry
        this.registry = new WorkerRegistry(config.poolConfig.workerStartTimeout);
        
        // Coordinator
        CoordinatorConfig coordConfig;
        coordConfig.host = config.coordinatorHost;
        coordConfig.port = config.coordinatorPort;
        coordConfig.workerTimeout = config.poolConfig.workerStartTimeout;
        coordConfig.enableWorkStealing = true;
        
        this.coordinator = new Coordinator(graph, coordConfig);
        
        // Worker pool with autoscaling
        this.pool = new WorkerPool(config.poolConfig, registry);
        
        // Remote executor
        this.executor = new RemoteExecutor(config.executorConfig);
        
        // REAPI adapter (if enabled)
        if (config.enableReapi)
        {
            this.reapiAdapter = new ReapiAdapter();
        }
        
        Logger.info("Remote execution service initialized");
    }
    
    /// Start service
    Result!BuildError start() @trusted
    {
        synchronized (mutex)
        {
            if (atomicLoad(running))
                return Ok!BuildError();
            
            Logger.info("Starting remote execution service...");
            
            // Start coordinator
            auto coordResult = coordinator.start();
            if (coordResult.isErr)
            {
                auto error = new GenericError(
                    "Failed to start coordinator: " ~ coordResult.unwrapErr().message(),
                    ErrorCode.InitializationFailed
                );
                return Err!BuildError(error);
            }
            
            // Start worker pool
            auto poolResult = pool.start();
            if (poolResult.isErr)
            {
                coordinator.stop();
                return poolResult;
            }
            
            // Start health monitoring
            atomicStore(running, true);
            healthThread = new Thread(&healthLoop);
            healthThread.start();
            
            Logger.info("Remote execution service started");
            Logger.info("  Coordinator: " ~ config.coordinatorHost ~ ":" ~ 
                       config.coordinatorPort.to!string);
            
            if (config.enableReapi)
            {
                Logger.info("  REAPI endpoint: port " ~ config.reapiPort.to!string);
            }
            
            return Ok!BuildError();
        }
    }
    
    /// Stop service
    void stop() @trusted
    {
        Logger.info("Stopping remote execution service...");
        
        atomicStore(running, false);
        
        // Stop health monitor
        if (healthThread !is null)
            healthThread.join();
        
        // Stop pool
        if (pool !is null)
            pool.stop();
        
        // Stop coordinator
        if (coordinator !is null)
            coordinator.stop();
        
        // Log final statistics
        logFinalStats();
        
        Logger.info("Remote execution service stopped");
    }
    
    /// Execute action remotely
    Result!(RemoteExecutionResult, BuildError) execute(
        ActionId actionId,
        SandboxSpec spec,
        string[] command,
        string workDir
    ) @trusted
    {
        if (!atomicLoad(running))
        {
            auto error = new GenericError(
                "Service not running",
                ErrorCode.NotInitialized
            );
            return Err!(RemoteExecutionResult, BuildError)(error);
        }
        
        return executor.execute(actionId, spec, command, workDir);
    }
    
    /// Execute via REAPI (Bazel compatibility)
    Result!(ExecuteResponse, BuildError) executeReapi(
        Action action,
        bool skipCacheLookup = false
    ) @trusted
    {
        if (!config.enableReapi || reapiAdapter is null)
        {
            auto error = new GenericError(
                "REAPI not enabled",
                ErrorCode.NotSupported
            );
            return Err!(ExecuteResponse, BuildError)(error);
        }
        
        return reapiAdapter.execute(action, skipCacheLookup);
    }
    
    /// Get service status
    ServiceStatus getStatus() @trusted
    {
        ServiceStatus status;
        status.running = atomicLoad(running);
        status.coordinatorStats = coordinator.getStats();
        status.poolStats = pool.getStats();
        status.uptime = Clock.currTime - startTime;
        
        return status;
    }
    
    /// Get service metrics
    ServiceMetrics getMetrics() @trusted
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
        
        return metrics;
    }
    
    /// Health monitoring loop
    private void healthLoop() @trusted
    {
        while (atomicLoad(running))
        {
            try
            {
                // Check coordinator health
                auto coordStats = coordinator.getStats();
                
                // Check pool health
                auto poolStats = pool.getStats();
                
                // Log health status
                if (config.enableMetrics)
                {
                    Logger.debugLog("Health check: " ~ 
                                   "workers=" ~ poolStats.totalWorkers.to!string ~
                                   ", busy=" ~ poolStats.busyWorkers.to!string ~
                                   ", queue=" ~ coordStats.pendingActions.to!string ~
                                   ", util=" ~ (poolStats.avgUtilization * 100).to!size_t.to!string ~ "%");
                }
                
                // Detect issues
                if (poolStats.totalWorkers == 0)
                {
                    Logger.warning("No workers available!");
                }
                
                if (coordStats.pendingActions > poolStats.totalWorkers * 10)
                {
                    Logger.warning("High queue depth: " ~ 
                                  coordStats.pendingActions.to!string ~ " pending");
                }
                
                Thread.sleep(config.healthCheckInterval);
            }
            catch (Exception e)
            {
                Logger.error("Health check failed: " ~ e.msg);
                Thread.sleep(config.healthCheckInterval);
            }
        }
    }
    
    /// Log final statistics
    private void logFinalStats() @trusted
    {
        try
        {
            auto metrics = getMetrics();
            
            Logger.info("Final execution statistics:");
            Logger.info("  Total executions: " ~ metrics.totalExecutions.to!string);
            Logger.info("  Successful: " ~ metrics.successfulExecutions.to!string);
            Logger.info("  Failed: " ~ metrics.failedExecutions.to!string);
            Logger.info("  Cached: " ~ metrics.cachedExecutions.to!string);
            
            if (metrics.totalExecutions > 0)
            {
                immutable successRate = 
                    (cast(float)metrics.successfulExecutions / metrics.totalExecutions) * 100;
                immutable cacheHitRate = 
                    (cast(float)metrics.cachedExecutions / metrics.totalExecutions) * 100;
                
                Logger.info("  Success rate: " ~ successRate.to!size_t.to!string ~ "%");
                Logger.info("  Cache hit rate: " ~ cacheHitRate.to!size_t.to!string ~ "%");
            }
        }
        catch (Exception e)
        {
            Logger.error("Failed to log final stats: " ~ e.msg);
        }
    }
    
    private SysTime startTime;
}

/// Service status
struct ServiceStatus
{
    bool running;
    Coordinator.CoordinatorStats coordinatorStats;
    PoolStats poolStats;
    Duration uptime;
}

/// Service metrics
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
}

/// Service builder for convenient configuration
struct RemoteServiceBuilder
{
    private RemoteServiceConfig config;
    
    /// Create builder with defaults
    static RemoteServiceBuilder create() pure nothrow @safe @nogc
    {
        RemoteServiceBuilder builder;
        builder.config = RemoteServiceConfig();
        return builder;
    }
    
    /// Set coordinator address
    ref RemoteServiceBuilder coordinator(string host, ushort port) return pure nothrow @safe @nogc
    {
        config.coordinatorHost = host;
        config.coordinatorPort = port;
        return this;
    }
    
    /// Set pool configuration
    ref RemoteServiceBuilder pool(PoolConfig poolConfig) return pure nothrow @safe @nogc
    {
        config.poolConfig = poolConfig;
        return this;
    }
    
    /// Set executor configuration
    ref RemoteServiceBuilder executor(RemoteExecutorConfig executorConfig) return pure nothrow @safe @nogc
    {
        config.executorConfig = executorConfig;
        return this;
    }
    
    /// Enable REAPI
    ref RemoteServiceBuilder enableReapi(ushort port = 9001) return pure nothrow @safe @nogc
    {
        config.enableReapi = true;
        config.reapiPort = port;
        return this;
    }
    
    /// Enable metrics
    ref RemoteServiceBuilder enableMetrics(bool enabled = true) return pure nothrow @safe @nogc
    {
        config.enableMetrics = enabled;
        return this;
    }
    
    /// Build service
    RemoteExecutionService build(BuildGraph graph) @trusted
    {
        return new RemoteExecutionService(config, graph);
    }
}

