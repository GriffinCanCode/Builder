module core;

/// Core Build System Package
/// Task execution, dependency graph, and caching
/// 
/// Architecture:
///   graph.d     - Dependency graph and topological sorting
///   executor.d  - Task execution and parallelization
///   scheduler.d - Build scheduling and coordination
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

public import core.graph;
public import core.executor;
public import core.cache;
public import core.storage;
public import core.eviction;

