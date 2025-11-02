module core;

/// Core Build System Package
/// Task execution, dependency graph, and caching
/// 
/// Architecture:
///   graph.d     - Dependency graph and topological sorting
///   executor.d  - Task execution, parallelization, and scheduling
///   cache.d     - Build cache management
///   storage.d   - Persistent storage for artifacts
///   eviction.d  - Cache eviction policies
///
/// Usage:
///   import core;
///   
///   auto graph = new DependencyGraph();
///   graph.addNode(target);
///   
///   auto engine = new ExecutionEngine(graph, config, scheduling, cache, observability, resilience, handlers);
///   engine.execute();
///   
///   auto cache = new BuildCache();
///   if (cache.contains(target)) {
///       cache.restore(target);
///   }

public import core.graph.graph;
public import core.execution;
public import core.caching.targets.cache;
public import core.caching.targets.storage;
public import core.caching.policies.eviction;
public import core.telemetry;
public import core.services.services;
public import core.shutdown.shutdown;

