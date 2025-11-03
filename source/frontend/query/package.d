module frontend.query;

/// bldrquery - Bazel-compatible query language for Builder
/// 
/// Comprehensive query DSL for exploring dependency graphs
/// 
/// Features:
/// - Full Bazel query compatibility
/// - Set operations (union, intersect, except)
/// - Advanced path finding (shortest, somepath, allpaths)
/// - Regex filtering
/// - Multiple output formats (pretty, list, JSON, DOT)
/// 
/// Example Queries:
/// ```d
/// deps(//src:app)                    // All dependencies
/// rdeps(//lib:utils)                 // Reverse dependencies
/// allpaths(//a:x, //b:y)            // All paths between targets
/// shortest(//a:x, //b:y)            // Shortest path
/// kind(library, //...)               // All libraries
/// filter("name", ".*test.*", //...) // Regex filter
/// deps(//...) & kind(library)        // Set intersection
/// //src/... - //src/test/...        // Set difference
/// ```

public import frontend.query.ast;
public import frontend.query.lexer;
public import frontend.query.parser;
public import frontend.query.evaluator;
public import frontend.query.algorithms;
public import frontend.query.operators;
public import frontend.query.formatter;

// Convenience imports for common usage
import infrastructure.errors;
import engine.graph.graph;