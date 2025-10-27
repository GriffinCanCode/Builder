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
///   auto executor = new BuildExecutor();
///   executor.execute(graph);
///   
///   auto cache = new BuildCache();
///   if (cache.contains(target)) {
///       cache.restore(target);
///   }

public import core.graph.graph;
public import core.execution.executor;
public import core.caching.cache;
public import core.caching.storage;
public import core.caching.eviction;
public import core.telemetry;
public import core.services;

