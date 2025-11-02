module query.algorithms;

import std.algorithm;
import std.array;
import std.container : DList, RedBlackTree;
import std.range;
import std.string : toLower, lastIndexOf, indexOf;
import graph.graph;
import config.schema.schema;

/// Graph traversal algorithms library
/// 
/// Optimized implementations of standard graph algorithms
/// using D's compile-time features and efficient data structures

/// Result of a graph traversal
struct TraversalResult
{
    BuildNode[] nodes;
    size_t[][] paths;  // For path-finding algorithms
}

/// BFS queue item
private struct BfsItem
{
    BuildNode node;
    int depth;
}

/// Breadth-First Search with depth limit
/// 
/// Complexity: O(V + E) where depth is bounded
/// Memory: O(V) for visited set + O(W) for queue (W = width at current level)
BuildNode[] bfs(BuildGraph graph, BuildNode[] starts, int maxDepth = -1) @system
{
    if (starts.empty)
        return [];
    
    BuildNode[] result;
    bool[BuildNode] visited;
    
    // Use DList as efficient queue (O(1) front insertion/removal)
    auto queue = DList!BfsItem();
    
    foreach (start; starts)
    {
        if (start is null)
            continue;
        queue.insertBack(BfsItem(start, 0));
        visited[start] = true;
    }
    
    while (!queue.empty)
    {
        auto item = queue.front;
        queue.removeFront();
        
        auto node = item.node;
        auto depth = item.depth;
        
        result ~= node;
        
        // Check depth limit
        if (maxDepth != -1 && depth >= maxDepth)
            continue;
        
        // Explore neighbors
        foreach (depId; node.dependencyIds)
        {
            auto depKey = depId.toString();
            if (depKey !in graph.nodes)
                continue;
            
            auto neighbor = graph.nodes[depKey];
            if (neighbor in visited)
                continue;
            
            visited[neighbor] = true;
            queue.insertBack(BfsItem(neighbor, depth + 1));
        }
    }
    
    return result;
}

/// Depth-First Search with depth limit
/// 
/// Complexity: O(V + E)
/// Memory: O(V) for visited set + O(D) for recursion stack (D = max depth)
BuildNode[] dfs(BuildGraph graph, BuildNode[] starts, int maxDepth = -1) @system
{
    if (starts.empty)
        return [];
    
    BuildNode[] result;
    bool[BuildNode] visited;
    
    void visit(BuildNode node, int depth) @system
    {
        if (node is null || node in visited)
            return;
        
        visited[node] = true;
        result ~= node;
        
        if (maxDepth != -1 && depth >= maxDepth)
            return;
        
        foreach (depId; node.dependencyIds)
        {
            auto depKey = depId.toString();
            if (depKey in graph.nodes)
                visit(graph.nodes[depKey], depth + 1);
        }
    }
    
    foreach (start; starts)
        visit(start, 0);
    
    return result;
}

/// Reverse BFS (following dependents instead of dependencies)
/// 
/// Finds all nodes that transitively depend on the given starts
BuildNode[] reverseBfs(BuildGraph graph, BuildNode[] starts, int maxDepth = -1) @system
{
    if (starts.empty)
        return [];
    
    BuildNode[] result;
    bool[BuildNode] visited;
    auto queue = DList!BfsItem();
    
    foreach (start; starts)
    {
        if (start is null)
            continue;
        queue.insertBack(BfsItem(start, 0));
        visited[start] = true;
    }
    
    while (!queue.empty)
    {
        auto item = queue.front;
        queue.removeFront();
        
        auto node = item.node;
        auto depth = item.depth;
        
        result ~= node;
        
        if (maxDepth != -1 && depth >= maxDepth)
            continue;
        
        // Explore dependents (reverse edges)
        foreach (depId; node.dependentIds)
        {
            auto depKey = depId.toString();
            if (depKey !in graph.nodes)
                continue;
            
            auto neighbor = graph.nodes[depKey];
            if (neighbor in visited)
                continue;
            
            visited[neighbor] = true;
            queue.insertBack(BfsItem(neighbor, depth + 1));
        }
    }
    
    return result;
}

/// Find shortest path using BFS (unweighted)
/// 
/// Returns: Array of nodes forming shortest path, or empty if no path exists
/// Complexity: O(V + E)
BuildNode[] shortestPath(BuildGraph graph, BuildNode from, BuildNode to) @system
{
    if (from is null || to is null)
        return [];
    
    if (from is to)
        return [from];
    
    // BFS with parent tracking
    BuildNode[BuildNode] parent;
    bool[BuildNode] visited;
    auto queue = DList!BuildNode();
    
    queue.insertBack(from);
    visited[from] = true;
    
    while (!queue.empty)
    {
        auto node = queue.front;
        queue.removeFront();
        
        if (node is to)
        {
            // Reconstruct path
            BuildNode[] path;
            auto current = to;
            while (current !is null)
            {
                path = current ~ path;
                current = (current in parent) ? parent[current] : null;
            }
            return path;
        }
        
        foreach (depId; node.dependencyIds)
        {
            auto depKey = depId.toString();
            if (depKey !in graph.nodes)
                continue;
            
            auto neighbor = graph.nodes[depKey];
            if (neighbor in visited)
                continue;
            
            visited[neighbor] = true;
            parent[neighbor] = node;
            queue.insertBack(neighbor);
        }
    }
    
    return [];  // No path found
}

/// Find all paths between two nodes using DFS
/// 
/// Returns: Array of all nodes that lie on any path from 'from' to 'to'
/// Complexity: O(V! * E) worst case (exponential in dense graphs)
/// Note: Use with caution on large graphs
BuildNode[] allPaths(BuildGraph graph, BuildNode from, BuildNode to) @system
{
    if (from is null || to is null)
        return [];
    
    BuildNode[] allNodesInPaths;
    bool[BuildNode] globalVisited;
    BuildNode[] currentPath;
    bool[BuildNode] pathVisited;
    
    void dfsAllPaths(BuildNode node) @system
    {
        if (node is null)
            return;
        
        pathVisited[node] = true;
        currentPath ~= node;
        
        if (node is to)
        {
            // Found a path - mark all nodes in this path
            foreach (pathNode; currentPath)
            {
                if (pathNode !in globalVisited)
                {
                    globalVisited[pathNode] = true;
                    allNodesInPaths ~= pathNode;
                }
            }
        }
        else
        {
            // Continue searching
            foreach (depId; node.dependencyIds)
            {
                auto depKey = depId.toString();
                if (depKey !in graph.nodes)
                    continue;
                
                auto neighbor = graph.nodes[depKey];
                if (neighbor !in pathVisited)
                    dfsAllPaths(neighbor);
            }
        }
        
        currentPath = currentPath[0 .. $ - 1];
        pathVisited.remove(node);
    }
    
    dfsAllPaths(from);
    return allNodesInPaths;
}

/// Find any single path (faster than allPaths)
/// 
/// Returns: Nodes forming a single path, or empty if no path exists
/// Complexity: O(V + E)
BuildNode[] somePath(BuildGraph graph, BuildNode from, BuildNode to) @system
{
    if (from is null || to is null)
        return [];
    
    if (from is to)
        return [from];
    
    BuildNode[] path;
    bool[BuildNode] visited;
    bool found = false;
    
    void dfs(BuildNode node) @system
    {
        if (found || node is null || node in visited)
            return;
        
        visited[node] = true;
        path ~= node;
        
        if (node is to)
        {
            found = true;
            return;
        }
        
        foreach (depId; node.dependencyIds)
        {
            auto depKey = depId.toString();
            if (depKey in graph.nodes)
            {
                dfs(graph.nodes[depKey]);
                if (found)
                    return;
            }
        }
        
        if (!found)
            path = path[0 .. $ - 1];  // Backtrack
    }
    
    dfs(from);
    return found ? path : [];
}

/// Get all targets matching a pattern
/// 
/// Patterns:
/// - "//..." - all targets
/// - "//path/..." - all targets in path
/// - "//path:target" - specific target
/// - "//path:*" - all targets in directory
BuildNode[] matchPattern(BuildGraph graph, string pattern) @system
{
    BuildNode[] result;
    
    if (pattern == "//...")
    {
        // All targets
        return graph.nodes.values.array;
    }
    else if (pattern.endsWith("..."))
    {
        // All targets in a path: //path/...
        string prefix = pattern[0 .. $ - 3];
        foreach (node; graph.nodes.values)
        {
            if (node.idString.startsWith(prefix))
                result ~= node;
        }
    }
    else if (pattern.endsWith(":*"))
    {
        // All targets in a specific directory: //path:*
        string prefix = pattern[0 .. $ - 1];
        foreach (node; graph.nodes.values)
        {
            if (node.idString.startsWith(prefix))
                result ~= node;
        }
    }
    else
    {
        // Specific target: //path:target
        if (pattern in graph.nodes)
            result ~= graph.nodes[pattern];
    }
    
    return result;
}

/// Filter nodes by target type
BuildNode[] filterByKind(BuildNode[] nodes, string kind) @system
{
    TargetType targetType;
    
    switch (kind.toLower())
    {
        case "executable":
        case "binary":
            targetType = TargetType.Executable;
            break;
        case "library":
        case "lib":
            targetType = TargetType.Library;
            break;
        case "test":
            targetType = TargetType.Test;
            break;
        case "custom":
            targetType = TargetType.Custom;
            break;
        default:
            return [];
    }
    
    return nodes.filter!(n => n !is null && n.target.type == targetType).array;
}

/// Filter nodes by attribute value
BuildNode[] filterByAttribute(BuildNode[] nodes, string attrName, string attrValue) @system
{
    return nodes.filter!(n => 
        n !is null && 
        attrName in n.target.langConfig && 
        n.target.langConfig[attrName] == attrValue
    ).array;
}

/// Filter nodes by regex on attribute
BuildNode[] filterByRegex(BuildNode[] nodes, string attrName, string regexPattern) @system
{
    import std.regex : regex, matchFirst;
    
    try
    {
        auto re = regex(regexPattern);
        return nodes.filter!(n => 
            n !is null && 
            attrName in n.target.langConfig && 
            !matchFirst(n.target.langConfig[attrName], re).empty
        ).array;
    }
    catch (Exception)
    {
        return [];  // Invalid regex returns empty set
    }
}

/// Get siblings (targets in same directory)
BuildNode[] getSiblings(BuildGraph graph, BuildNode[] targets) @system
{
    if (targets.empty)
        return [];
    
    bool[BuildNode] result;
    
    foreach (target; targets)
    {
        if (target is null)
            continue;
        
        // Extract directory from target ID (//path:target -> //path)
        string targetId = target.idString;
        auto colonPos = targetId.lastIndexOf(':');
        if (colonPos == -1)
            continue;
        
        string directory = targetId[0 .. colonPos];
        
        // Find all targets with same directory prefix
        foreach (node; graph.nodes.values)
        {
            if (node.idString.startsWith(directory ~ ":"))
                result[node] = true;
        }
    }
    
    return result.keys;
}

