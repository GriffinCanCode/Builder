module engine.runtime.remote.service;

import std.datetime : Duration, Clock, SysTime, seconds;
import std.algorithm : map, filter;
import std.array : array;
import std.conv : to;
import core.atomic;
import core.sync.mutex : Mutex;
import core.thread : Thread;
import engine.graph.graph : BuildGraph;
import engine.distributed.coordinator.coordinator;
import engine.distributed.coordinator.registry;
import engine.distributed.protocol.protocol : ActionId, WorkerId;
import engine.runtime.remote.executor;
import engine.runtime.remote.pool;
import engine.runtime.remote.reapi;
import engine.runtime.remote.providers.provisioner : WorkerProvisioner;
import engine.runtime.remote.providers.base : CloudProvider;
import engine.runtime.remote.providers.mock : MockCloudProvider;
import engine.runtime.remote.monitoring.health : RemoteServiceHealthMonitor;
import engine.runtime.remote.monitoring.metrics : RemoteServiceMetricsCollector, ServiceMetrics;
import engine.runtime.hermetic;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

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
    private WorkerProvisioner provisioner;
    private RemoteExecutor executor;
    private ReapiAdapter reapiAdapter;
    private BuildGraph graph;
    private RemoteServiceHealthMonitor healthMonitor;
    private RemoteServiceMetricsCollector metricsCollector;
    
    private shared bool running;
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
        
        // Worker provisioner (SRP: separated from pool management)
        CloudProvider provider = createProvider(config.poolConfig);
        this.provisioner = new WorkerProvisioner(provider);
        
        // Worker pool with autoscaling (now delegating provisioning to provisioner)
        this.pool = new WorkerPool(config.poolConfig, registry, provisioner);
        
        // Remote executor
        this.executor = new RemoteExecutor(config.executorConfig);
        
        // REAPI adapter (if enabled)
        if (config.enableReapi)
        {
            this.reapiAdapter = new ReapiAdapter();
        }
        
        // Initialize dedicated monitoring components
        this.healthMonitor = new RemoteServiceHealthMonitor(
            coordinator,
            pool,
            config.healthCheckInterval,
            config.enableMetrics
        );
        
        this.metricsCollector = new RemoteServiceMetricsCollector(
            coordinator,
            pool
        );
        
        Logger.info("Remote execution service initialized");
    }
    
    /// Create worker provider based on configuration
    /// 
    /// Responsibility: Factory method for provider selection
    private CloudProvider createProvider(PoolConfig poolConfig) @trusted
    {
        // Would select provider based on configuration
        // For now, use mock provider (stub implementation)
        // In production, would check config and return:
        // - AwsCloudProvider for AWS EC2
        // - KubernetesCloudProvider for K8s
        // - GcpCloudProvider for GCP Compute
        return new MockCloudProvider();
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
                BuildError error = new GenericError(
                    "Failed to start coordinator: " ~ coordResult.unwrapErr().message(),
                    ErrorCode.InitializationFailed
                );
                return Result!BuildError.err(error);
            }
            
            // Start worker pool
            auto poolResult = pool.start();
            if (poolResult.isErr)
            {
                coordinator.stop();
                return poolResult;
            }
            
            // Start health monitoring (delegated to dedicated monitor)
            auto healthResult = healthMonitor.start();
            if (healthResult.isErr)
            {
                pool.stop();
                coordinator.stop();
                return healthResult;
            }
            
            atomicStore(running, true);
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
        
        // Stop health monitor (delegated to dedicated monitor)
        if (healthMonitor !is null)
            healthMonitor.stop();
        
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
        status.metrics = metricsCollector.collect();
        
        return status;
    }
    
    /// Get service metrics (delegated to dedicated collector)
    ServiceMetrics getMetrics() @trusted
    {
        return metricsCollector.collect();
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
}

/// Service status
struct ServiceStatus
{
    bool running;
    Coordinator.CoordinatorStats coordinatorStats;
    PoolStats poolStats;
    ServiceMetrics metrics;
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

