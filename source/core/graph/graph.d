module core.graph.graph;

import std.stdio;
import std.algorithm;
import std.array;
import std.conv;
import std.range;
import core.atomic;
import config.schema.schema;
import errors;

/// Represents a node in the build graph
/// Thread-safe: status field is accessed atomically
final class BuildNode
{
    string id;
    Target target;
    BuildNode[] dependencies;
    BuildNode[] dependents;
    private shared BuildStatus _status;  // Atomic access only
    string hash;
    
    // Retry metadata
    private shared size_t _retryAttempts;  // Atomic access only
    string lastError;                       // Last error message
    
    this(string id, Target target) @safe pure nothrow
    {
        this.id = id;
        this.target = target;
        atomicStore(this._status, BuildStatus.Pending);
        atomicStore(this._retryAttempts, cast(size_t)0);
        
        // Pre-allocate reasonable capacity to avoid reallocations
        dependencies.reserve(8);  // Most targets have <8 dependencies
        dependents.reserve(4);    // Fewer dependents on average
    }
    
    /// Get status atomically (thread-safe)
    /// 
    /// Safety: This property is @trusted because:
    /// 1. atomicLoad() performs sequentially-consistent atomic read
    /// 2. _status is shared - requires atomic operations for thread safety
    /// 3. Read-only operation with no side effects
    /// 4. Returns enum by value (no references)
    /// 
    /// Invariants:
    /// - _status is always a valid BuildStatus enum value
    /// 
    /// What could go wrong:
    /// - Nothing: atomic read of shared enum is safe, no memory corruption possible
    @property BuildStatus status() const nothrow @trusted @nogc
    {
        return atomicLoad(this._status);
    }
    
    /// Set status atomically (thread-safe)
    /// 
    /// Safety: This property is @trusted because:
    /// 1. atomicStore() performs sequentially-consistent atomic write
    /// 2. _status is shared - requires atomic operations for thread safety
    /// 3. Prevents data races during concurrent builds
    /// 4. Enum parameter is trivially copyable
    /// 
    /// Invariants:
    /// - Only valid BuildStatus enum values are written
    /// 
    /// What could go wrong:
    /// - Nothing: atomic write of shared enum is safe, no memory corruption possible
    @property void status(BuildStatus newStatus) nothrow @trusted @nogc
    {
        atomicStore(this._status, newStatus);
    }
    
    /// Get retry attempts atomically (thread-safe)
    /// 
    /// Safety: This property is @trusted because:
    /// 1. atomicLoad() performs sequentially-consistent atomic read
    /// 2. _retryAttempts is shared - requires atomic operations
    /// 3. Read-only operation with no side effects
    /// 
    /// Invariants:
    /// - _retryAttempts is always >= 0 (size_t is unsigned)
    /// 
    /// What could go wrong:
    /// - Nothing: atomic read of shared size_t is safe, no memory corruption possible
    @property size_t retryAttempts() const nothrow @trusted @nogc
    {
        return atomicLoad(this._retryAttempts);
    }
    
    /// Increment retry attempts atomically (thread-safe)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. atomicOp!"+=" performs atomic read-modify-write operation
    /// 2. _retryAttempts is shared - requires atomic operations
    /// 3. Prevents race conditions during concurrent retries
    /// 
    /// Invariants:
    /// - Counter increments are atomic (no lost updates)
    /// 
    /// What could go wrong:
    /// - Overflow: If retries exceed size_t.max, wraps to 0 (extremely unlikely)
    void incrementRetries() nothrow @trusted @nogc
    {
        atomicOp!"+="(this._retryAttempts, 1);
    }
    
    /// Reset retry attempts atomically (thread-safe)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. atomicStore() performs sequentially-consistent atomic write
    /// 2. _retryAttempts is shared - requires atomic operations
    /// 3. Cast to size_t is safe (compile-time constant 0)
    /// 
    /// Invariants:
    /// - Counter is reset to exactly 0
    /// 
    /// What could go wrong:
    /// - Nothing: atomic write of constant 0 is safe, no memory corruption possible
    void resetRetries() nothrow @trusted @nogc
    {
        atomicStore(this._retryAttempts, cast(size_t)0);
    }
    
    /// Check if this node is ready to build (all deps built)
    /// Thread-safe: reads dependency status atomically
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Reads _status atomically from dependency nodes
    /// 2. dependencies array is immutable after graph construction
    /// 3. atomicLoad() ensures memory-safe concurrent reads
    /// 4. Read-only operation with no mutations
    /// 
    /// Invariants:
    /// - dependencies array must NOT be modified after graph construction
    /// - All dependency nodes must remain valid for the lifetime of this node
    /// 
    /// What could go wrong:
    /// - If dependencies array is modified during iteration: undefined behavior
    /// - If dependency nodes are freed: dangling pointer access
    /// - These are prevented by design: graph is immutable after construction
    bool isReady() const @trusted nothrow
    {
        foreach (dep; dependencies)
        {
            auto depStatus = atomicLoad(dep._status);
            if (depStatus != BuildStatus.Success && depStatus != BuildStatus.Cached)
                return false;
        }
        return true;
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
    Result!BuildError addDependency(in string from, in string to) @safe
    {
        if (from !in nodes)
        {
            auto error = new GraphError("Target not found in graph: " ~ from, ErrorCode.NodeNotFound);
            error.addContext(ErrorContext("adding dependency", "from: " ~ from ~ ", to: " ~ to));
            return Result!BuildError.err(cast(BuildError) error);
        }
        
        if (to !in nodes)
        {
            auto error = new GraphError("Target not found in graph: " ~ to, ErrorCode.NodeNotFound);
            error.addContext(ErrorContext("adding dependency", "from: " ~ from ~ ", to: " ~ to));
            return Result!BuildError.err(cast(BuildError) error);
        }
        
        auto fromNode = nodes[from];
        auto toNode = nodes[to];
        
        // Check for cycles before adding
        if (wouldCreateCycle(fromNode, toNode))
        {
            auto error = new GraphError("Circular dependency detected: " ~ from ~ " -> " ~ to, ErrorCode.GraphCycle);
            error.addContext(ErrorContext("adding dependency", "would create cycle"));
            return Result!BuildError.err(cast(BuildError) error);
        }
        
        fromNode.dependencies ~= toNode;
        toNode.dependents ~= fromNode;
        
        return Ok!BuildError();
    }
    
    /// Check if adding an edge would create a cycle
    /// 
    /// Note: This function could potentially be @safe as it only performs
    /// safe operations (AA access, reference comparisons, array traversal).
    /// Marked @trusted conservatively for nested function with closure.
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
    /// Returns Result to handle cycles gracefully
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Nested function captures only local variables and const graph
    /// 2. Associative array operations are bounds-checked
    /// 3. Array appending (~=) is memory-safe
    /// 4. const(BuildNode) prevents mutations during traversal
    /// 5. Error result propagation maintains type safety
    /// 6. CRITICAL: Casts away const on line 254 to return mutable BuildNode[]
    ///    This is safe because callers have mutable access to the graph nodes
    /// 
    /// Invariants:
    /// - Graph structure is not modified during traversal (const method)
    /// - Node references remain valid (classes on GC heap)
    /// - const-to-mutable cast only returns references, doesn't enable mutation
    ///   of graph structure itself
    /// 
    /// What could go wrong:
    /// - If this method is called on a truly const BuildGraph (not just const ref
    ///   to mutable graph), and caller modifies returned nodes: undefined behavior
    /// - In practice, graph is mutable; const is for read-only traversal guarantee
    Result!(BuildNode[], BuildError) topologicalSort() const @trusted
    {
        BuildNode[] sorted;
        bool[const(BuildNode)] visited;
        bool[const(BuildNode)] visiting;
        BuildError cycleError = null;
        
        void visit(const(BuildNode) node)
        {
            if (cycleError !is null)
                return;
                
            if (node in visited)
                return;
            
            if (node in visiting)
            {
                auto error = new GraphError("Circular dependency detected involving: " ~ node.id, ErrorCode.GraphCycle);
                error.addContext(ErrorContext("topological sort", "cycle detected"));
                cycleError = cast(BuildError) error;
                return;
            }
            
            visiting[node] = true;
            
            foreach (dep; node.dependencies)
                visit(dep);
            
            visiting.remove(node);
            visited[node] = true;
            sorted ~= cast(BuildNode)node; // Safe cast for returning mutable reference
        }
        
        foreach (node; nodes.values)
        {
            visit(node);
            if (cycleError !is null)
                return Result!(BuildNode[], BuildError).err(cycleError);
        }
        
        return Result!(BuildNode[], BuildError).ok(sorted);
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
        import utils.logging.logger;
        import errors.formatting.format;
        
        writeln("\nBuild Graph:");
        writeln("============");
        
        auto sortResult = topologicalSort();
        if (sortResult.isErr)
        {
            Logger.error("Cannot print graph: " ~ format(sortResult.unwrapErr()));
            return;
        }
        
        auto sorted = sortResult.unwrap();
        
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

