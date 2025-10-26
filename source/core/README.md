# Core Package

The core package provides the fundamental build system capabilities including task execution, dependency graphs, caching, and scheduling.

## Modules

- **graph.d** - Dependency graph construction and topological sorting
- **executor.d** - Parallel task execution engine with scheduling
- **cache.d** - Build cache with content-based hashing
- **storage.d** - Persistent storage for build artifacts
- **eviction.d** - Cache eviction policies (LRU, size-based)

## Usage

```d
import core;

auto graph = new DependencyGraph();
graph.addNode(target);

auto executor = new BuildExecutor();
executor.execute(graph);

auto cache = new BuildCache();
if (cache.contains(target)) {
    cache.restore(target);
}
```

## Key Features

- Lock-free task execution with work-stealing
- Content-addressable build cache
- Incremental builds with change detection
- Parallel execution with dependency ordering
- Configurable cache eviction policies
- Persistent artifact storage

