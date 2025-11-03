module graph;

/// Dependency graph module
/// 
/// Exports:
/// - BuildGraph: Main dependency graph structure
/// - BuildNode: Graph node representing a build target
/// - GraphCache: High-performance graph caching
/// - GraphStorage: Binary serialization for graphs
/// - BuildStatus: Build status enumeration
/// - ValidationMode: Graph validation strategy
/// - DynamicBuildGraph: Runtime graph extension support
/// - DiscoveryMetadata: Discovery protocol for dynamic dependencies
/// - GraphExtension: Thread-safe graph mutation

public import graph.graph;
public import graph.cache;
public import graph.storage;
public import graph.discovery;
public import graph.dynamic;

