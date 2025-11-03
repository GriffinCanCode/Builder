# Graph Module

The graph module provides the core dependency graph infrastructure for Builder's build system. It handles graph construction, validation, caching, and dynamic runtime extension.

## Architecture Overview

```
graph/
├── core/          Core graph data structures
├── caching/       High-performance graph caching
└── dynamic/       Runtime graph extension
```

### Core (`engine.graph.core`)

Core graph data structures and algorithms:

- **BuildGraph** - Main dependency graph with topological ordering and cycle detection
- **BuildNode** - Thread-safe graph nodes with atomic state management
- **BuildStatus** - Build execution status (Pending, Building, Success, Failed, Cached)
- **ValidationMode** - Cycle detection strategies (Immediate vs Deferred)

**Key Features:**
- Topological ordering for correct build execution
- Two validation modes: immediate O(V²) or deferred O(V+E)
- Thread-safe atomic operations for concurrent execution
- Depth calculation with memoization
- Critical path analysis for scheduling optimization

### Caching (`engine.graph.caching`)

High-performance graph caching subsystem:

- **GraphCache** - Incremental cache with two-tier validation
- **GraphStorage** - SIMD-accelerated binary serialization
- **Schema** - Versioned binary format definitions

**Key Features:**
- 10-50x speedup for unchanged graphs
- Sub-millisecond cache validation
- Two-tier validation: metadata (fast) → content hash (slow)
- SIMD-accelerated hash comparisons
- Integrity validation with workspace-specific keys
- ~10x faster than JSON, ~40% smaller

**Cache Location:**
- `.builder-cache/graph.bin` - Binary graph data
- `.builder-cache/graph-metadata.bin` - Validation metadata

### Dynamic (`engine.graph.dynamic`)

Runtime graph extension and discovery:

- **DynamicBuildGraph** - Extends BuildGraph with runtime mutations
- **DiscoveryMetadata** - Protocol for declaring dynamic dependencies
- **DiscoveryBuilder** - Builder pattern for discovery metadata
- **GraphExtension** - Thread-safe graph mutation engine
- **DiscoveryPatterns** - Common patterns (codegen, tests, libraries)

**Key Features:**
- Runtime dependency discovery during build execution
- Thread-safe synchronized mutations
- Maintains DAG invariants automatically
- Pattern helpers for common use cases

## Usage Examples

### Basic Graph Construction

```d
import engine.graph;

// Create graph with deferred validation for large graphs
auto graph = new BuildGraph(ValidationMode.Deferred);

// Add targets
auto compileTarget = Target("//src:compile", TargetType.Binary);
graph.addTarget(compileTarget).unwrap();

auto libTarget = Target("//lib:mylib", TargetType.Library);
graph.addTarget(libTarget).unwrap();

// Add dependencies
graph.addDependency("//src:compile", "//lib:mylib").unwrap();

// Validate entire graph once (O(V+E))
auto result = graph.validate();
if (result.isErr) {
    // Handle cycle error
}

// Get topological order
auto sorted = graph.topologicalSort().unwrap();
```

### Using Graph Cache

```d
import engine.graph.caching;

// Initialize cache
auto cache = new GraphCache(".builder-cache");

// Try to load cached graph
auto configFiles = ["Builderfile", "Builderspace"];
auto cachedGraph = cache.get(configFiles);

if (cachedGraph !is null) {
    // Cache hit - use cached graph
    writeln("Using cached graph");
} else {
    // Cache miss - build new graph
    auto graph = buildGraph();
    
    // Save to cache
    cache.put(graph, configFiles);
}

// Print cache statistics
cache.printStats();
```

### Dynamic Discovery

```d
import engine.graph.dynamic;

// Create dynamic graph
auto baseGraph = buildStaticGraph();
auto dynamicGraph = new DynamicBuildGraph(baseGraph);

// Mark discoverable targets
dynamicGraph.markDiscoverable(TargetId("//codegen:protobuf"));

// During action execution, record discoveries
auto discovery = DiscoveryBuilder
    .forTarget(TargetId("//codegen:protobuf"))
    .addOutputs(["generated/foo.pb.d", "generated/bar.pb.d"])
    .addDependents([TargetId("//generated:compile")])
    .build();

dynamicGraph.recordDiscovery(discovery);

// Apply discoveries and get new nodes to schedule
auto newNodes = dynamicGraph.applyDiscoveries().unwrap();
foreach (node; newNodes) {
    // Schedule new node for execution
    scheduler.schedule(node);
}
```

### Common Discovery Patterns

```d
import engine.graph.dynamic;

// Code generation discovery (protobuf, GraphQL, etc.)
auto codeGenDiscovery = DiscoveryPatterns.codeGeneration(
    TargetId("//proto:generate"),
    ["generated/user.pb.d", "generated/api.pb.d"],
    "proto-generated"
);

// Dynamic library discovery
auto libDiscovery = DiscoveryPatterns.libraryDiscovery(
    TargetId("//app:link"),
    ["/usr/lib/libfoo.so", "/opt/lib/libbar.so"]
);

// Test discovery
auto testDiscovery = DiscoveryPatterns.testDiscovery(
    TargetId("//test:generate"),
    ["tests/test_foo.d", "tests/test_bar.d"]
);
```

## Performance Characteristics

### Graph Construction

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Add target | O(1) | Constant time hash insert |
| Add dependency (immediate) | O(V+E) | Full cycle check |
| Add dependency (deferred) | O(1) | No validation |
| Validate (deferred) | O(V+E) | Single topological sort |
| Topological sort | O(V+E) | DFS-based |
| Critical path | O(V+E) | Single traversal with memoization |

### Caching

| Operation | Typical Time | Notes |
|-----------|-------------|-------|
| Cache hit (metadata unchanged) | < 1ms | Fast path |
| Cache hit (content check) | 5-50ms | Slow path |
| Cache miss | N/A | Build new graph |
| Serialization | 10-100ms | Depends on graph size |
| Deserialization | 5-50ms | Zero-copy when possible |

### Memory Usage

- **BuildNode**: ~200 bytes per node (without target data)
- **BuildGraph**: O(V + E) for V nodes and E edges
- **Cache**: ~100-500 bytes per target (compressed)

## Thread Safety

### BuildNode

All status fields use atomic operations:
- `status` - Atomically readable/writable
- `retryAttempts` - Atomic increment/reset
- `pendingDeps` - Atomic decrement for lock-free scheduling

**Safe operations:**
- Concurrent status reads from multiple threads
- Atomic status updates during execution
- Lock-free dependency counting

**Unsafe operations:**
- Modifying `dependencyIds` or `dependentIds` after construction
- These arrays must be immutable after graph construction

### BuildGraph

**Safe operations:**
- Concurrent reads from multiple threads after construction
- Topological sort (uses local data structures)
- Node lookup and traversal

**Unsafe operations:**
- Adding nodes/edges during concurrent execution
- Use `DynamicBuildGraph` for runtime mutations

### GraphCache

**All operations are thread-safe:**
- Protected by internal mutex
- Safe to call from multiple threads
- Synchronized access to cache files

### DynamicBuildGraph

**All operations are thread-safe:**
- Discovery recording is synchronized
- Graph mutations are atomic
- Safe to call from parallel actions

## Validation Modes

### Immediate Validation

```d
auto graph = new BuildGraph(ValidationMode.Immediate);
```

**Characteristics:**
- Checks for cycles on every `addDependency()` call
- O(V²) worst-case for dense graphs
- Provides immediate feedback on cycle errors
- Best for: Interactive use, small graphs (<100 nodes)

### Deferred Validation

```d
auto graph = new BuildGraph(ValidationMode.Deferred);
// ... add many nodes and edges ...
graph.validate().unwrap(); // Single O(V+E) check
```

**Characteristics:**
- No validation during construction
- Single O(V+E) topological sort for validation
- Optimal for large graphs (1000+ nodes)
- Best for: Batch construction, large codebases

## Error Handling

All graph operations return `Result` types:

```d
// Success case
auto result = graph.addTarget(target);
if (result.isOk) {
    // Success
}

// Error case
if (result.isErr) {
    auto error = result.unwrapErr();
    writeln("Error: ", error.message);
    
    // Rich error context
    foreach (ctx; error.contexts) {
        writeln("  ", ctx.operation, ": ", ctx.details);
    }
    
    // Suggestions
    foreach (suggestion; error.suggestions) {
        writeln("  Suggestion: ", suggestion);
    }
}
```

**Common errors:**
- `ErrorCode.GraphInvalid` - Duplicate target
- `ErrorCode.GraphCycle` - Circular dependency detected
- `ErrorCode.NodeNotFound` - Target not found in graph

## Best Practices

### Graph Construction

1. **Use deferred validation for large graphs:**
   ```d
   auto graph = new BuildGraph(ValidationMode.Deferred);
   // Batch add all targets and dependencies
   graph.validate().unwrap(); // Validate once
   ```

2. **Pre-allocate capacity when known:**
   ```d
   // BuildNode already pre-allocates reasonable capacities
   // dependencyIds.reserve(8), dependentIds.reserve(4)
   ```

3. **Use strongly-typed TargetId:**
   ```d
   auto id = TargetId.parse("//path:target").unwrap();
   graph.addTargetById(id, target);
   ```

### Caching

1. **Always use cache for large projects:**
   ```d
   auto cache = new GraphCache();
   auto graph = cache.get(configFiles) ?? buildNewGraph();
   ```

2. **Include all config files in cache key:**
   ```d
   auto configFiles = [
       "Builderfile",
       "Builderspace",
       "config/build.conf"
   ];
   ```

3. **Check cache stats periodically:**
   ```d
   cache.printStats(); // See hit rates
   ```

### Dynamic Discovery

1. **Mark discoverable upfront:**
   ```d
   dynamicGraph.markDiscoverable(targetId);
   ```

2. **Use pattern helpers:**
   ```d
   // Instead of manual DiscoveryBuilder
   auto discovery = DiscoveryPatterns.codeGeneration(...);
   ```

3. **Apply discoveries in batches:**
   ```d
   // Let multiple actions record discoveries
   // Then apply all at once
   auto newNodes = dynamicGraph.applyDiscoveries().unwrap();
   ```

## Design Decisions

### Why TargetId[] instead of BuildNode[] for dependencies?

To avoid GC cycles from bidirectional references. Storing pointers would create:
- `A.dependencies → B`
- `B.dependents → A`

This prevents garbage collection and can leak memory. Using TargetId[] instead:
- No circular references
- Reduced memory pressure
- Clean GC behavior
- Small overhead for lookup (amortized O(1) with hash map)

### Why two validation modes?

Different use cases have different needs:
- **Interactive CLI**: Want immediate feedback on errors → Immediate mode
- **Large codebases**: Want fast batch construction → Deferred mode
- **Build servers**: Want optimal performance → Deferred mode

### Why separate caching module?

Separation of concerns:
- Core graph logic is independent of persistence
- Caching can be disabled without affecting core
- Different serialization strategies can be implemented
- Easier to test graph algorithms in isolation

### Why dynamic discovery?

Many build tools require two-pass analysis:
1. Static analysis determines most dependencies
2. Some tools (codegen, dynamic linking) discover more at runtime

Dynamic discovery enables:
- Single-pass builds with runtime extension
- Correct incremental builds for generated code
- Optimal parallelism (don't wait for full analysis)

## Contributing

When modifying the graph module:

1. **Maintain invariants:**
   - DAG property (no cycles)
   - Topological order correctness
   - Thread safety guarantees

2. **Update tests:**
   - Add unit tests for new features
   - Update integration tests
   - Performance benchmarks for critical paths

3. **Document complexity:**
   - Add Big-O notation for algorithms
   - Explain trade-offs in comments
   - Update this README

4. **Preserve thread safety:**
   - Use atomic operations for shared state
   - Document thread safety in module docs
   - Add `@system`/`@trusted` annotations carefully

## See Also

- [Build System Architecture](/docs/architecture/overview.md)
- [Caching Design](/docs/architecture/cachedesign.md)
- [Dynamic Integration](/docs/architecture/dynamic-integration.md)
- [Performance Guide](/docs/features/performance.md)

