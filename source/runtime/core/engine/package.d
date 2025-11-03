module runtime.core.engine;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
import core.atomic;
import core.memory : GC;
import graph.graph;
import graph.dynamic;
import config.schema.schema;
import languages.base.base;
import runtime.services;
import cli.events.events;
import telemetry.distributed.tracing : Span, SpanKind, SpanStatus;
import utils.logging.logger;
import utils.simd.capabilities;
import errors;

// Import split modules
public import runtime.core.engine.lifecycle;
public import runtime.core.engine.executor;
public import runtime.core.engine.coordinator;
public import runtime.core.engine.discovery;

/// Thin orchestration layer for build execution
/// Composes specialized services to execute build graph
/// 
/// Design: Pure coordination - all work delegated to services
/// - SchedulingService: parallelism and task queueing
/// - CacheService: caching decisions
/// - ObservabilityService: events, tracing, logging
/// - ResilienceService: retry and checkpoint logic
/// - HandlerRegistry: language handler dispatch
/// - DynamicGraph: optional runtime dependency discovery
final class ExecutionEngine
{
    private EngineLifecycle lifecycle;
    private EngineExecutor executor;
    private EngineCoordinator coordinator;
    private DynamicBuildGraph dynamicGraph;
    private bool useDynamicGraph;
    
    this(
        BuildGraph graph,
        WorkspaceConfig config,
        ISchedulingService scheduling,
        ICacheService cache,
        IObservabilityService observability,
        IResilienceService resilience,
        IHandlerRegistry handlers,
        SIMDCapabilities simdCaps = null,
        bool enableDynamicGraph = true  // Enable by default
    ) @trusted
    {
        this.useDynamicGraph = enableDynamicGraph;
        
        // Create dynamic graph wrapper if enabled
        if (enableDynamicGraph)
        {
            this.dynamicGraph = new DynamicBuildGraph(graph);
            Logger.info("Dynamic graph support enabled");
        }
        
        // Initialize lifecycle
        lifecycle.initialize(
            graph, config, scheduling, cache, 
            observability, resilience, handlers, simdCaps
        );
        
        // Initialize executor
        executor.initialize(
            cache, observability, resilience, 
            handlers, config, simdCaps
        );
        
        // Initialize coordinator
        coordinator.initialize(&lifecycle, &executor);
        
        // Enable dynamic graph in coordinator if available
        if (enableDynamicGraph)
        {
            coordinator.enableDynamicGraph(dynamicGraph, handlers);
        }
    }
    
    ~this()
    {
        shutdown();
    }
    
    /// Shutdown engine and cleanup resources
    void shutdown() @trusted
    {
        lifecycle.shutdown();
    }
    
    /// Execute the build
    bool execute() @trusted
    {
        auto success = coordinator.execute();
        
        // Report discovery statistics if using dynamic graphs
        if (useDynamicGraph && dynamicGraph !is null)
        {
            auto stats = dynamicGraph.getDiscoveryStats();
            if (stats.targetsDiscovered > 0)
            {
                Logger.info("Dynamic Discovery Summary:");
                Logger.info("  Targets discovered: " ~ stats.targetsDiscovered.to!string);
                Logger.info("  Total discoveries: " ~ stats.totalDiscoveries.to!string);
            }
        }
        
        return success;
    }
    
    /// Get dynamic graph (if enabled)
    @property DynamicBuildGraph getDynamicGraph() @trusted
    {
        return dynamicGraph;
    }
    
    /// Check if dynamic graph is enabled
    @property bool isDynamicGraphEnabled() const pure nothrow @nogc
    {
        return useDynamicGraph;
    }
}
