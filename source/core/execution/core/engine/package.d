module core.execution.core.engine;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.datetime.stopwatch;
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

// Import split modules
public import core.execution.core.engine.lifecycle;
public import core.execution.core.engine.executor;
public import core.execution.core.engine.coordinator;

/// Thin orchestration layer for build execution
/// Composes specialized services to execute build graph
/// 
/// Design: Pure coordination - all work delegated to services
/// - SchedulingService: parallelism and task queueing
/// - CacheService: caching decisions
/// - ObservabilityService: events, tracing, logging
/// - ResilienceService: retry and checkpoint logic
/// - HandlerRegistry: language handler dispatch
final class ExecutionEngine
{
    private EngineLifecycle lifecycle;
    private EngineExecutor executor;
    private EngineCoordinator coordinator;
    
    this(
        BuildGraph graph,
        WorkspaceConfig config,
        ISchedulingService scheduling,
        ICacheService cache,
        IObservabilityService observability,
        IResilienceService resilience,
        IHandlerRegistry handlers,
        SIMDCapabilities simdCaps = null
    ) @trusted
    {
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
        return coordinator.execute();
    }
}
