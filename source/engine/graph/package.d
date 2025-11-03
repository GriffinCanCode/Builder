module engine.graph;

/// Dependency graph module - build graph construction, analysis, and execution
/// 
/// ## Module Organization
/// 
/// ### Core (`engine.graph.core`)
/// Core graph data structures and algorithms:
/// - BuildGraph: Main dependency graph with topological ordering
/// - BuildNode: Thread-safe graph nodes with atomic state
/// - BuildStatus: Build execution status tracking
/// - ValidationMode: Cycle detection strategies
/// 
/// ### Caching (`engine.graph.caching`)
/// High-performance graph caching subsystem:
/// - GraphCache: Incremental cache with two-tier validation
/// - GraphStorage: SIMD-accelerated binary serialization
/// - Schema definitions for versioned binary format
/// 
/// ### Dynamic (`engine.graph.dynamic`)
/// Runtime graph extension and discovery:
/// - DynamicBuildGraph: Runtime dependency discovery
/// - DiscoveryMetadata: Protocol for dynamic dependencies
/// - Common patterns for codegen, tests, libraries
/// 
/// ## Performance
/// - Graph construction: O(V+E) with deferred validation
/// - Cache hits: 10-50x speedup, sub-millisecond validation
/// - Binary format: ~10x faster than JSON, ~40% smaller
/// - Thread-safe: atomic operations for concurrent execution
/// 
/// ## Thread Safety
/// - BuildNode: Atomic status fields for concurrent reads/writes
/// - GraphCache: Mutex-protected cache operations
/// - DynamicBuildGraph: Synchronized mutation operations

// Core graph structures
public import engine.graph.core;

// Caching subsystem
public import engine.graph.caching;

// Dynamic discovery
public import engine.graph.dynamic;

