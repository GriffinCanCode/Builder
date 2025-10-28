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
    string id;  // String ID for backward compatibility
    Target target;
    BuildNode[] dependencies;
    BuildNode[] dependents;
    private shared BuildStatus _status;  // Atomic access only
    string hash;
    
    // Retry metadata
    private shared size_t _retryAttempts;  // Atomic access only
    string lastError;                       // Last error message
    
    // Lock-free execution metadata
    private shared size_t _pendingDeps;  // Atomic: remaining dependencies to build
    
    this(string id, Target target) @safe pure nothrow
    {
        this.id = id;
        this.target = target;
        atomicStore(this._status, BuildStatus.Pending);
        atomicStore(this._retryAttempts, cast(size_t)0);
        atomicStore(this._pendingDeps, cast(size_t)0);
        
        // Pre-allocate reasonable capacity to avoid reallocations
        dependencies.reserve(8);  // Most targets have <8 dependencies
        dependents.reserve(4);    // Fewer dependents on average
    }
    
    /// Get strongly-typed target identifier
    @property TargetId targetId() const @safe
    {
        return target.id;
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
    
    /// Initialize pending dependencies counter (call before execution)
    /// 
    /// Safety: This function is @trusted because:
    /// 1. atomicStore() performs sequentially-consistent atomic write
    /// 2. _pendingDeps is shared - requires atomic operations
    /// 3. dependencies.length is safe to read
    void initPendingDeps() nothrow @trusted @nogc
    {
        atomicStore(this._pendingDeps, dependencies.length);
    }
    
    /// Atomically decrement pending dependencies and return new count
    /// Used by lock-free execution to detect when node becomes ready
    /// 
    /// Safety: This function is @trusted because:
    /// 1. atomicOp!"-=" performs atomic read-modify-write operation
    /// 2. _pendingDeps is shared - requires atomic operations
    /// 3. Returns the new value after decrement
    /// 
    /// Invariants:
    /// - Decrement is atomic (no lost updates)
    /// - Returns value after decrement
    /// 
    /// What could go wrong:
    /// - Underflow: If decremented too many times (caller's responsibility)
    size_t decrementPendingDeps() nothrow @trusted @nogc
    {
        atomicOp!"-="(this._pendingDeps, 1);
        return atomicLoad(this._pendingDeps);
    }
    
    /// Get current pending dependencies count
    size_t pendingDeps() const nothrow @trusted @nogc
    {
        return atomicLoad(this._pendingDeps);
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
    
    /// Cached depth value (size_t.max = uncomputed)
    private size_t _cachedDepth = size_t.max;
    
    /// Get topological depth for scheduling (memoized)
    /// 
    /// Performance: O(V+E) total across all nodes due to memoization.
    /// Without memoization, this would be O(E^depth) - exponential for deep graphs.
    size_t depth() const @trusted nothrow
    {
        if (_cachedDepth != size_t.max)
            return _cachedDepth;
        
        if (dependencies.empty)
        {
            (cast()this)._cachedDepth = 0;
            return 0;
        }
        
        size_t maxDepth = 0;
        foreach (dep; dependencies)
        {
            // Safety: Skip null dependencies to prevent segfault
            if (dep is null)
                continue;
            
            auto depDepth = dep.depth();
            if (depDepth > maxDepth)
                maxDepth = depDepth;
        }
        
        (cast()this)._cachedDepth = maxDepth + 1;
        return _cachedDepth;
    }
    
    /// Invalidate cached depth (call when dependencies change)
    private void invalidateDepthCache() @safe nothrow
    {
        _cachedDepth = size_t.max;
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

/// Cycle detection strategy for graph construction
enum ValidationMode
{
    /// Check for cycles on every edge addition (O(V²) worst-case)
    /// Provides immediate feedback but slower for large graphs
    Immediate,
    
    /// Defer cycle detection until validate() is called (O(V+E) total)
    /// Optimal for batch construction of large graphs
    Deferred
}

/// Build graph with topological ordering and cycle detection
/// 
/// Performance:
/// - Immediate validation: O(V²) for dense graphs (per-edge cycle check)
/// - Deferred validation: O(V+E) total (single topological sort)
/// 
/// Usage:
/// ```d
/// // Fast batch construction for large graphs
/// auto graph = new BuildGraph(ValidationMode.Deferred);
/// foreach (target; targets) graph.addTarget(target);
/// foreach (dep; deps) graph.addDependency(from, to).unwrap();
/// auto result = graph.validate(); // Single O(V+E) validation
/// if (result.isErr) handleCycle(result.unwrapErr());
/// ```
/// 
/// TargetId Migration:
/// - Use `addTargetById(TargetId, Target)` for type-safe target addition
/// - Use `addDependencyById(TargetId, TargetId)` for type-safe dependencies
/// - Use `getNode(TargetId)` and `hasTarget(TargetId)` for lookups
/// - Old string-based methods still available for backward compatibility
/// 
/// Example:
///   auto id = TargetId.parse("//path:target").unwrap();
///   graph.addTargetById(id, target);
///   graph.addDependencyById(id, otherId);
final class BuildGraph
{
    BuildNode[string] nodes;  // Keep string keys for backward compatibility
    BuildNode[] roots;
    private ValidationMode _validationMode;
    private bool _validated;
    
    /// Create graph with specified validation mode
    this(ValidationMode mode = ValidationMode.Immediate) @safe pure nothrow
    {
        _validationMode = mode;
        _validated = false;
    }
    
    /// Validate entire graph for cycles (O(V+E))
    /// 
    /// Must be called when using ValidationMode.Deferred before execution.
    /// For Immediate mode, this is optional (cycles already detected).
    /// 
    /// Returns: Ok on success, Err with cycle details on failure
    Result!BuildError validate() const @trusted
    {
        auto sortResult = topologicalSort();
        if (sortResult.isErr)
            return Result!BuildError.err(sortResult.unwrapErr());
        
        (cast()this)._validated = true;
        return Ok!BuildError();
    }
    
    /// Check if graph has been validated
    @property bool isValidated() const @safe pure nothrow @nogc
    {
        return _validated || _validationMode == ValidationMode.Immediate;
    }
    
    /// Add a target to the graph (string version for backward compatibility)
    /// 
    /// Throws: Exception if target with same name already exists
    void addTarget(Target target) @safe
    {
        if (target.name in nodes)
        {
            throw new Exception("Duplicate target name: " ~ target.name ~ 
                              " - target names must be unique within a build graph");
        }
        
        auto node = new BuildNode(target.name, target);
        nodes[target.name] = node;
    }
    
    /// Add a target to the graph using TargetId
    /// 
    /// Throws: Exception if target with same ID already exists
    void addTargetById(TargetId id, Target target) @safe
    {
        auto key = id.toString();
        if (key in nodes)
        {
            throw new Exception("Duplicate target ID: " ~ key ~ 
                              " - target IDs must be unique within a build graph");
        }
        
        auto node = new BuildNode(key, target);
        nodes[key] = node;
    }
    
    /// Get node by TargetId
    BuildNode* getNode(TargetId id) @safe
    {
        auto key = id.toString();
        if (key in nodes)
            return &nodes[key];
        return null;
    }
    
    /// Check if graph contains a target by TargetId
    bool hasTarget(TargetId id) @safe
    {
        return (id.toString() in nodes) !is null;
    }
    
    /// Add dependency between two targets (string version for backward compatibility)
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
        
        // Check for cycles only in immediate mode
        if (_validationMode == ValidationMode.Immediate)
        {
        if (wouldCreateCycle(fromNode, toNode))
        {
            auto error = new GraphError("Circular dependency detected: " ~ from ~ " -> " ~ to, ErrorCode.GraphCycle);
            error.addContext(ErrorContext("adding dependency", "would create cycle"));
            return Result!BuildError.err(cast(BuildError) error);
            }
        }
        
        fromNode.dependencies ~= toNode;
        toNode.dependents ~= fromNode;
        
        // Invalidate depth cache for affected nodes
        invalidateDepthCascade(fromNode);
        
        return Ok!BuildError();
    }
    
    /// Add dependency using TargetId (type-safe version)
    Result!BuildError addDependencyById(TargetId from, TargetId to) @safe
    {
        auto fromKey = from.toString();
        auto toKey = to.toString();
        
        if (fromKey !in nodes)
        {
            auto error = new GraphError("Target not found in graph: " ~ fromKey, ErrorCode.NodeNotFound);
            error.addContext(ErrorContext("adding dependency", "from: " ~ fromKey ~ ", to: " ~ toKey));
            return Result!BuildError.err(cast(BuildError) error);
        }
        
        if (toKey !in nodes)
        {
            auto error = new GraphError("Target not found in graph: " ~ toKey, ErrorCode.NodeNotFound);
            error.addContext(ErrorContext("adding dependency", "from: " ~ fromKey ~ ", to: " ~ toKey));
            return Result!BuildError.err(cast(BuildError) error);
        }
        
        auto fromNode = nodes[fromKey];
        auto toNode = nodes[toKey];
        
        // Check for cycles only in immediate mode
        if (_validationMode == ValidationMode.Immediate)
        {
        if (wouldCreateCycle(fromNode, toNode))
        {
            auto error = new GraphError("Circular dependency detected: " ~ fromKey ~ " -> " ~ toKey, ErrorCode.GraphCycle);
            error.addContext(ErrorContext("adding dependency", "would create cycle"));
            return Result!BuildError.err(cast(BuildError) error);
            }
        }
        
        fromNode.dependencies ~= toNode;
        toNode.dependents ~= fromNode;
        
        // Invalidate depth cache for affected nodes
        invalidateDepthCascade(fromNode);
        
        return Ok!BuildError();
    }
    
    /// Invalidate depth cache for node and all dependents (cascade upward)
    /// 
    /// When a node gains a new dependency, all nodes that depend on it
    /// may need recalculation of their depth.
    private void invalidateDepthCascade(BuildNode node) @safe nothrow
    {
        node.invalidateDepthCache();
        foreach (dependent; node.dependents)
        {
            invalidateDepthCascade(dependent);
        }
    }
    
    /// Check if adding an edge would create a cycle (O(V+E) worst case)
    /// 
    /// Note: This function could potentially be @safe as it only performs
    /// safe operations (AA access, reference comparisons, array traversal).
    /// Marked @trusted conservatively for nested function with closure.
    /// 
    /// Used only in Immediate validation mode. For large graphs, prefer
    /// Deferred mode with a single O(V+E) topological sort.
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
            // Safety: Skip null nodes to prevent segfault
            if (node is null)
                continue;
            
            writeln("\nTarget: ", node.id);
            writeln("  Type: ", node.target.type);
            writeln("  Sources: ", node.target.sources.length, " files");
            
            if (!node.dependencies.empty)
            {
                writeln("  Dependencies:");
                foreach (dep; node.dependencies)
                {
                    // Safety: Skip null dependencies
                    if (dep !is null)
                        writeln("    - ", dep.id);
                }
            }
            
            if (!node.dependents.empty)
            {
                writeln("  Dependents:");
                foreach (dep; node.dependents)
                {
                    // Safety: Skip null dependents
                    if (dep !is null)
                        writeln("    - ", dep.id);
                }
            }
        }
        
        writeln("\nBuild order (", sorted.length, " targets):");
        foreach (i, node; sorted)
        {
            // Safety: Skip null nodes and catch any exceptions from depth()
            if (node !is null)
            {
                try
                {
                    writeln("  ", i + 1, ". ", node.id, " (depth: ", node.depth(), ")");
                }
                catch (Exception e)
                {
                    writeln("  ", i + 1, ". ", node.id, " (depth: ERROR)");
                }
            }
        }
    }
    
    /// Get statistics about the graph
    struct GraphStats
    {
        size_t totalNodes;
        size_t totalEdges;
        size_t maxDepth;
        size_t parallelism; // Max nodes that can be built in parallel
        size_t criticalPathLength; // Longest path through graph
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
        
        // Calculate critical path length
        stats.criticalPathLength = calculateCriticalPathLength();
        
        return stats;
    }
    
    /// Calculate critical path cost for all nodes
    /// Returns map of node ID to critical path cost (estimated build time to completion)
    size_t[string] calculateCriticalPath(size_t delegate(BuildNode) @safe estimateCost) const @trusted
    {
        size_t[string] costs;
        bool[string] visited;
        
        size_t visit(const BuildNode node) @trusted
        {
            if (node.id in visited)
                return costs[node.id];
            
            visited[node.id] = true;
            
            // Get max cost of dependents (reverse direction - who depends on me)
            size_t maxDependentCost = 0;
            foreach (dependent; node.dependents)
            {
                immutable depCost = visit(dependent);
                maxDependentCost = max(maxDependentCost, depCost);
            }
            
            // Critical path cost = own cost + max dependent cost
            immutable cost = estimateCost(cast(BuildNode)node) + maxDependentCost;
            costs[node.id] = cost;
            return cost;
        }
        
        foreach (node; nodes.values)
            visit(node);
        
        return costs;
    }
    
    /// Calculate critical path length (longest chain)
    private size_t calculateCriticalPathLength() const @trusted
    {
        if (nodes.empty)
            return 0;
        
        size_t maxPath = 0;
        bool[const(BuildNode)] visited;
        
        size_t dfs(const BuildNode node)
        {
            if (node in visited)
                return 0;
            
            visited[node] = true;
            
            size_t maxDepPath = 0;
            foreach (dep; node.dependencies)
                maxDepPath = max(maxDepPath, dfs(dep));
            
            return 1 + maxDepPath;
        }
        
        foreach (node; nodes.values)
            maxPath = max(maxPath, dfs(node));
        
        return maxPath;
    }
}

