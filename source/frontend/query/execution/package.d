module frontend.query.execution;

/// Query Execution Module
/// 
/// Evaluates query AST against build graph using efficient
/// graph algorithms and set operations.
/// 
/// Components:
/// - Evaluator: Visitor-based AST execution engine
/// - Algorithms: Graph traversal (BFS, DFS, path finding)
/// - Operators: Set operations (union, intersect, except)
/// 
/// Example:
/// ```d
/// auto evaluator = new QueryEvaluator(buildGraph);
/// auto result = evaluator.evaluate(ast);
/// // result contains BuildNode[]
/// ```

public import frontend.query.execution.evaluator;
public import frontend.query.execution.algorithms;
public import frontend.query.execution.operators;

