module core.graph;

/// Dependency graph module
/// 
/// Exports:
/// - BuildGraph: Main dependency graph structure
/// - BuildNode: Graph node representing a build target
/// - GraphCache: High-performance graph caching
/// - GraphStorage: Binary serialization for graphs
/// - BuildStatus: Build status enumeration
/// - ValidationMode: Graph validation strategy

public import core.graph.graph;
public import core.graph.cache;
public import core.graph.storage;

