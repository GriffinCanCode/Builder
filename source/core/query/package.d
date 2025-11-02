module core.query;

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

public import core.query.ast;
public import core.query.lexer;
public import core.query.parser;
public import core.query.evaluator;
public import core.query.algorithms;
public import core.query.operators;
public import core.query.formatter;

// Convenience imports for common usage
import errors;
import core.graph.graph;

/// Execute a query string and return results
/// 
/// This is the main entry point for query execution
Result!(BuildNode[], string) query(string queryString, BuildGraph graph) @system
{
    return executeQuery(queryString, graph);
}

