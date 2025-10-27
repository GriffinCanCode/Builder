module core.graph.graph;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.range;
import config.schema.schema;

/// Represents a node in the build graph
final class BuildNode
{
    string id;
    Target target;
    BuildNode[] dependencies;
    BuildNode[] dependents;
    BuildStatus status;
    string hash;
    
    this(string id, Target target) @safe pure nothrow
    {
        this.id = id;
        this.target = target;
        this.status = BuildStatus.Pending;
        
        // Pre-allocate reasonable capacity to avoid reallocations
        dependencies.reserve(8);  // Most targets have <8 dependencies
        dependents.reserve(4);    // Fewer dependents on average
    }
    
    /// Check if this node is ready to build (all deps built)
    bool isReady() const @safe pure nothrow
    {
        return dependencies.all!(dep => 
            dep.status == BuildStatus.Success || 
            dep.status == BuildStatus.Cached);
    }
    
    /// Get topological depth for scheduling
    size_t depth() const @safe pure nothrow
    {
        if (dependencies.empty)
            return 0;
        return dependencies.map!(d => d.depth()).maxElement + 1;
    }
}

enum BuildStatus
{
    Pending,
    Building,
    Success,
    Failed,
    Cached
}

/// Build graph with topological ordering and cycle detection
final class BuildGraph
{
    BuildNode[string] nodes;
    BuildNode[] roots;
    
    /// Add a target to the graph
    void addTarget(Target target) @safe
    {
        if (target.name !in nodes)
        {
            auto node = new BuildNode(target.name, target);
            nodes[target.name] = node;
        }
    }
    
    /// Add dependency between two targets
    void addDependency(in string from, in string to) @safe
    {
        if (from !in nodes || to !in nodes)
            throw new Exception("Target not found in graph: " ~ (from !in nodes ? from : to));
        
        auto fromNode = nodes[from];
        auto toNode = nodes[to];
        
        // Check for cycles before adding
        if (wouldCreateCycle(fromNode, toNode))
            throw new Exception("Circular dependency detected: " ~ from ~ " -> " ~ to);
        
        fromNode.dependencies ~= toNode;
        toNode.dependents ~= fromNode;
    }
    
    /// Check if adding an edge would create a cycle
    private bool wouldCreateCycle(BuildNode from, BuildNode to) @trusted
    {
        bool[BuildNode] visited;
        
        bool dfs(BuildNode node)
        {
            if (node == from)
                return true;
            if (node in visited)
                return false;
            
            visited[node] = true;
            
            foreach (dep; node.dependencies)
            {
                if (dfs(dep))
                    return true;
            }
            
            return false;
        }
        
        return dfs(to);
    }
    
    /// Get nodes in topological order (leaves first)
    BuildNode[] topologicalSort() const
    {
        BuildNode[] sorted;
        bool[const(BuildNode)] visited;
        bool[const(BuildNode)] visiting;
        
        void visit(const(BuildNode) node)
        {
            if (node in visited)
                return;
            
            if (node in visiting)
                throw new Exception("Circular dependency detected involving: " ~ node.id);
            
            visiting[node] = true;
            
            foreach (dep; node.dependencies)
                visit(dep);
            
            visiting.remove(node);
            visited[node] = true;
            sorted ~= cast(BuildNode)node; // Safe cast for returning mutable reference
        }
        
        foreach (node; nodes.values)
            visit(node);
        
        return sorted;
    }
    
    /// Get all nodes that can be built in parallel (no deps or deps satisfied)
    BuildNode[] getReadyNodes()
    {
        return nodes.values
            .filter!(n => n.status == BuildStatus.Pending && n.isReady())
            .array;
    }
    
    /// Get root nodes (no dependencies)
    BuildNode[] getRoots()
    {
        return nodes.values
            .filter!(n => n.dependencies.empty)
            .array;
    }
    
    /// Print the graph for visualization
    void print() const
    {
        writeln("\nBuild Graph:");
        writeln("============");
        
        auto sorted = topologicalSort();
        
        foreach (node; sorted)
        {
            writeln("\nTarget: ", node.id);
            writeln("  Type: ", node.target.type);
            writeln("  Sources: ", node.target.sources.length, " files");
            
            if (!node.dependencies.empty)
            {
                writeln("  Dependencies:");
                foreach (dep; node.dependencies)
                    writeln("    - ", dep.id);
            }
            
            if (!node.dependents.empty)
            {
                writeln("  Dependents:");
                foreach (dep; node.dependents)
                    writeln("    - ", dep.id);
            }
        }
        
        writeln("\nBuild order (", sorted.length, " targets):");
        foreach (i, node; sorted)
            writeln("  ", i + 1, ". ", node.id, " (depth: ", node.depth(), ")");
    }
    
    /// Get statistics about the graph
    struct GraphStats
    {
        size_t totalNodes;
        size_t totalEdges;
        size_t maxDepth;
        size_t parallelism; // Max nodes that can be built in parallel
    }
    
    GraphStats getStats() const
    {
        GraphStats stats;
        stats.totalNodes = nodes.length;
        
        foreach (node; nodes.values)
        {
            stats.totalEdges += node.dependencies.length;
            stats.maxDepth = max(stats.maxDepth, node.depth());
        }
        
        // Calculate max parallelism by depth
        size_t[size_t] nodesByDepth;
        foreach (node; nodes.values)
            nodesByDepth[node.depth()]++;
        
        if (!nodesByDepth.empty)
            stats.parallelism = nodesByDepth.values.maxElement;
        
        return stats;
    }
}

