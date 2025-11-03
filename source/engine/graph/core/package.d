module engine.graph.core;

/// Core graph data structures and algorithms
/// 
/// Exports:
/// - BuildGraph: Main dependency graph structure with topological ordering
/// - BuildNode: Graph node representing a build target with atomic state
/// - BuildStatus: Build execution status enumeration
/// - ValidationMode: Graph validation strategy (Immediate vs Deferred)
/// 
/// Thread Safety:
/// - BuildNode uses atomic operations for status fields
/// - BuildGraph is thread-safe for concurrent reads during execution
/// - Mutations should be performed before parallel execution begins
/// 
/// Performance:
/// - Immediate validation: O(V²) worst-case for dense graphs
/// - Deferred validation: O(V+E) single topological sort
/// - Depth calculation: O(V+E) total with memoization

public import engine.graph.core.graph;

