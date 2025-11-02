module core.execution.core.engine.lifecycle;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import core.atomic;
import core.memory : GC;
import core.graph.graph;
import config.schema.schema;
import languages.base.base;
import core.execution.services;
import cli.events.events;
import core.telemetry.distributed.tracing : Span, SpanKind, SpanStatus;
import utils.logging.logger;
import utils.simd.capabilities;
import errors;

/// Engine lifecycle management (initialization, shutdown, state)
struct EngineLifecycle
{
    private enum size_t LARGE_BUILD_THRESHOLD = 100;
    
    private BuildGraph graph;
    private WorkspaceConfig config;
    private ISchedulingService scheduling;
    private ICacheService cache;
    private IObservabilityService observability;
    private IResilienceService resilience;
    private IHandlerRegistry handlers;
    private SIMDCapabilities simdCaps;
    
    private shared size_t activeTasks;
    private shared size_t failedTasks;
    private bool _isShutdown = false;
    
    /// Initialize lifecycle with services
    void initialize(
        BuildGraph graph,
        WorkspaceConfig config,
        ISchedulingService scheduling,
        ICacheService cache,
        IObservabilityService observability,
        IResilienceService resilience,
        IHandlerRegistry handlers,
        SIMDCapabilities simdCaps
    ) @trusted
    {
        this.graph = graph;
        this.config = config;
        this.scheduling = scheduling;
        this.cache = cache;
        this.observability = observability;
        this.resilience = resilience;
        this.handlers = handlers;
        this.simdCaps = simdCaps;
        
        atomicStore(activeTasks, cast(size_t)0);
        atomicStore(failedTasks, cast(size_t)0);
    }
    
    /// Shutdown engine and cleanup resources
    void shutdown() @trusted
    {
        if (_isShutdown)
            return;
        
        _isShutdown = true;
        
        scheduling.shutdown();
        cache.close();
        observability.flush();
        
        // Shutdown SIMD capabilities
        if (simdCaps !is null)
            simdCaps.shutdown();
    }
    
    /// Check if shutdown has been initiated
    bool isShutdown() const @trusted
    {
        return _isShutdown;
    }
    
    /// Get current active tasks count
    size_t getActiveTasks() @trusted
    {
        return atomicLoad(activeTasks);
    }
    
    /// Get current failed tasks count
    size_t getFailedTasks() @trusted
    {
        return atomicLoad(failedTasks);
    }
    
    /// Increment active tasks atomically
    void incrementActiveTasks(size_t count = 1) @trusted
    {
        atomicOp!"+="(activeTasks, count);
    }
    
    /// Decrement active tasks atomically
    void decrementActiveTasks(size_t count = 1) @trusted
    {
        atomicOp!"-="(activeTasks, count);
    }
    
    /// Increment failed tasks atomically
    void incrementFailedTasks(size_t count = 1) @trusted
    {
        atomicOp!"+="(failedTasks, count);
    }
    
    /// Enable GC control for large builds
    bool shouldDisableGC(size_t targetCount) const @trusted
    {
        return targetCount > LARGE_BUILD_THRESHOLD;
    }
    
    /// Access to services
    BuildGraph getGraph() @trusted { return graph; }
    WorkspaceConfig getConfig() @trusted { return config; }
    ISchedulingService getScheduling() @trusted { return scheduling; }
    ICacheService getCache() @trusted { return cache; }
    IObservabilityService getObservability() @trusted { return observability; }
    IResilienceService getResilience() @trusted { return resilience; }
    IHandlerRegistry getHandlers() @trusted { return handlers; }
    SIMDCapabilities getSIMDCapabilities() @trusted { return simdCaps; }
}

