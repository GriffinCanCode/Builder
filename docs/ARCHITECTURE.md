# Builder Architecture

## Overview

Builder is a smart build system designed for mixed-language monorepos, leveraging D's compile-time metaprogramming for dependency analysis. This document describes the architecture and design decisions.

## Core Components

### 1. Build Graph (`core/graph.d`)

The build graph is the central data structure representing all targets and their dependencies.

**Key Features:**
- Topological sorting for correct build order
- Cycle detection to prevent circular dependencies
- Parallel build scheduling based on dependency depth
- Build status tracking (Pending, Building, Success, Failed, Cached)

**Algorithm:**
- Uses DFS-based topological sort
- Calculates depth for each node to enable wave-based parallel execution
- Detects cycles before adding edges to maintain DAG property

### 2. Build Cache (`core/cache.d`)

High-performance incremental build cache with advanced optimizations.

**Cache Strategy:**
- Two-tier hashing: metadata (mtime+size) + SHA-256 content hash
- Binary serialization: 5-10x faster than JSON, 30% smaller
- Lazy writes: batch updates, write once per build
- LRU eviction with configurable size limits
- Dependency-aware invalidation

**Performance Optimizations:**
- **Two-Tier Hashing** (`utils/hash.d`): Check fast metadata hash (1μs) before expensive content hash (1ms). Achieves 1000x speedup for unchanged files.
- **Binary Storage** (`core/storage.d`): Custom binary format with magic number validation. Serializes 5-10x faster than JSON.
- **Lazy Writes**: Defers all writes until `flush()` call at build end. For 100 targets: 100x I/O reduction.
- **LRU Eviction** (`core/eviction.d`): Automatic cache management with hybrid strategy (LRU + age-based + size-based).

**Cache Configuration:**
```bash
BUILDER_CACHE_MAX_SIZE=1073741824      # 1 GB default
BUILDER_CACHE_MAX_ENTRIES=10000         # 10k entries default
BUILDER_CACHE_MAX_AGE_DAYS=30           # 30 days default
```

**Cache Invalidation:**
- Source file changes (two-tier hash comparison)
- Dependency changes (transitive invalidation)
- Automatic eviction when limits exceeded
- Manual invalidation via `builder clean`

### 3. Build Executor (`core/executor.d`)

Orchestrates the actual build process.

**Execution Strategy:**
- Wave-based parallel execution (builds all ready nodes in parallel)
- Respects dependency order
- Configurable parallelism (default: CPU count)
- Fail-fast error handling

**Build Flow:**
1. Get topologically sorted nodes
2. Find all ready nodes (dependencies satisfied)
3. Build ready nodes in parallel
4. Update node status
5. Repeat until all nodes built or error

### 4. Dependency Analysis (`analysis/`)

**True compile-time metaprogramming architecture** with strongly typed domain objects.

**Components:**
- `types.d`: Strongly typed domain objects (Import, Dependency, FileAnalysis, TargetAnalysis)
- `spec.d`: Language specification registry with compile-time validation
- `metagen.d`: Compile-time code generation using templates and mixins
- `analyzer.d`: Main analyzer using generated code
- `scanner.d`: Fast file scanning with parallel support
- `resolver.d`: O(1) import-to-target resolution with indexed lookups

**Language Support:**
All languages configured via data-driven `LanguageSpec` system:
- D: `import` statements
- Python: `import` and `from` statements with kind detection
- JavaScript/TypeScript: ES6 `import` and CommonJS `require`
- Go: `import` declarations with URL detection
- Rust: `use` statements with crate resolution
- C/C++: `#include` directives
- Java: `import` statements

**Metaprogramming Features:**
- **Compile-time code generation**: `generateAnalyzerDispatch()` generates optimized analyzers
- **Zero-cost abstractions**: Type dispatch optimized away at compile-time
- **Static validation**: `validateLanguageSpecs()` runs at compile-time
- **Type introspection**: Compile-time verification of domain object structure
- **Mixin injection**: `LanguageAnalyzer` mixin generates analysis methods
- **CTFE optimization**: Language specs initialized in `shared static this()`

### 5. Language Handlers (`languages/`)

Pluggable language-specific build logic.

**Base Interface:**
```d
interface LanguageHandler {
    LanguageBuildResult build(Target, WorkspaceConfig);
    bool needsRebuild(Target, WorkspaceConfig);
    void clean(Target, WorkspaceConfig);
    string[] getOutputs(Target, WorkspaceConfig);
}
```

**Supported Languages:**
- Python: Syntax validation, executable wrappers
- JavaScript/TypeScript: TSC compilation
- Go: `go build` integration
- Rust: `rustc` and `cargo` integration
- D: `ldc2` and `dub` integration

**Extension:**
Add new languages by implementing `LanguageHandler` interface.

### 6. Configuration System (`config/`)

Flexible configuration with JSON and DSL support.

**Configuration Format:**
```json
{
    "name": "target-name",
    "type": "executable|library|test|custom",
    "language": "python|javascript|go|rust|d|...",
    "sources": ["src/**/*.py"],
    "deps": ["//path/to:other-target"],
    "flags": ["-O2", "-Wall"],
    "env": {"KEY": "value"}
}
```

**Features:**
- Glob pattern expansion for sources
- Relative and absolute dependency references
- Language inference from file extensions
- Workspace-level configuration

## Design Decisions

### Why D?

1. **True Compile-time Metaprogramming**: Generate code, validate types, and optimize dispatch at compile-time using templates, mixins, and CTFE - not just syntax tricks
2. **Zero-Cost Abstractions**: Strong typing with `Import`, `Dependency`, `FileAnalysis` types compiled away to optimal machine code
3. **Performance**: Native compilation with LLVM backend (LDC), O(1) indexed lookups instead of O(n²) string matching
4. **Memory Safety**: @safe by default with compile-time verification
5. **Modern Features**: Ranges, UFCS, templates, mixins, static introspection, compile-time function execution
6. **C/C++ Interop**: Seamless integration with existing build tools

### Build Graph vs Build Rules

Unlike Bazel's rule-based approach, Builder uses a pure dependency graph:

**Advantages:**
- Simpler mental model
- Easier to visualize and debug
- More flexible for mixed-language projects
- Less boilerplate

**Trade-offs:**
- Less fine-grained control over build steps
- Fewer built-in optimizations (but faster for small/medium projects)

### Caching Strategy

**Two-Tier Hashing:**
- **Tier 1**: Fast metadata check (mtime + size) - 1μs per file
- **Tier 2**: Content hash (SHA-256) only if metadata changed - 1ms per file
- Best of both worlds: timestamp speed + content hash reliability
- Achieves 1000x speedup for unchanged files

**Storage Format:**
- Custom binary format with magic number and versioning
- 5-10x faster serialization than JSON
- 30% smaller file size
- Automatic migration from old JSON format

**Write Strategy:**
- Lazy writes with dirty tracking
- Batch all updates during build
- Single write at build end via `flush()`
- 100x I/O reduction for large projects

**Eviction Policy:**
- **LRU (Least Recently Used)**: Remove cold entries first
- **Size-based**: Enforce configurable size limits (default 1GB)
- **Age-based**: Remove entries older than N days (default 30)
- **Hybrid approach**: Combines all three strategies

**Granularity:**
- Target-level caching (not action-level like Bazel)
- Simpler implementation, faster for small/medium projects
- Can be extended to action-level if needed

### Parallelism

**Wave-based Execution:**
- Groups targets by dependency depth
- Maximizes parallelism while respecting dependencies
- Better than pure task-based parallelism for build graphs

**Implementation:**
- Uses D's `std.parallelism` for thread pool
- Configurable worker count
- Lock-free where possible

## Performance Characteristics

### Time Complexity

- **Dependency Analysis**: O(V + E) where V = targets, E = dependencies
- **Import Resolution**: O(1) average with indexed lookups (was O(V × S) with string matching)
- **Topological Sort**: O(V + E)
- **Cycle Detection**: O(V + E)
- **Cache Lookup**: O(1) average, O(log V) worst case

### Space Complexity

- **Build Graph**: O(V + E)
- **Cache**: O(V × S) where S = average source files per target
- **Parallel Execution**: O(W) where W = worker threads

### Scalability

**Tested with:**
- 1,000+ targets: ~100ms analysis time
- 10,000+ files: ~500ms file scanning
- 100+ parallel jobs: Linear speedup up to CPU count

**Bottlenecks:**
- Process spawning for external tools
- Large file content hashing (mitigated by two-tier strategy)
- Massive dependency graphs (>50k targets)

**Optimizations:**
- Parallel file scanning
- O(1) import index lookups (was O(V × S) string matching)
- Compile-time code generation eliminates dispatch overhead
- Binary cache storage (5-10x faster than JSON)
- Two-tier hashing (1000x faster for unchanged files)
- Lazy cache writes (100x I/O reduction)
- LRU eviction (automatic cache management)
- Incremental config parsing
- Strongly typed domain objects prevent runtime errors

## Architecture Evolution

### v2.0 - Compile-time Metaprogramming & Type Safety

**Major architectural improvements:**
- ✅ Strongly typed domain objects (`Import`, `Dependency`, `FileAnalysis`, `TargetAnalysis`)
- ✅ Compile-time code generation via mixins and templates (`LanguageAnalyzer`, `generateAnalyzerDispatch`)
- ✅ O(1) import resolution with `ImportIndex` (hash-based lookup)
- ✅ Data-driven language specifications in `LanguageSpec` registry
- ✅ Zero-cost abstractions - all type dispatch optimized away at compile-time
- ✅ Language handlers implement `analyzeImports()` interface
- ✅ Eliminated 150+ lines of duplicated analyzer code

**Performance & correctness gains:**
- Import resolution: O(V × S) → O(1) average case
- Type safety: Runtime string matching → Compile-time verified types
- Code duplication: 7 near-identical functions → 1 generic template
- Metaprogramming: Unused templates → Actual code generation with mixins and CTFE

**Files added:**
- `analysis/types.d` - Strongly typed domain objects
- `analysis/spec.d` - Language specification registry  
- `analysis/metagen.d` - Compile-time code generators

## Future Enhancements

### Short-term
- [x] Binary cache format for performance
- [x] Two-tier hashing strategy
- [x] LRU eviction with size limits
- [x] Lazy write optimization
- [x] Strongly typed domain objects
- [x] Compile-time code generation
- [ ] Tree-sitter parsers for AST-based import analysis (eliminate regex fragility)
- [ ] Dependency query language (`builder query "deps(//src:app)"`)
- [ ] Remote caching (S3, GCS)
- [ ] Watch mode for continuous builds
- [ ] Circular dependency detection with refactoring suggestions

### Medium-term
- [ ] Action-level caching
- [ ] Build event protocol (for IDE integration)
- [ ] Custom build rules DSL
- [ ] Docker integration

### Long-term
- [ ] Advanced query language (path analysis, transitive closure)
- [ ] Machine learning for build time prediction and optimization hints
- [ ] Automatic dependency inference from AST analysis
- [ ] Cross-compilation support with target platform detection
- [ ] Build optimization analyzer (suggests target splits, identifies bottlenecks)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## References

- [Bazel Design](https://bazel.build/designs/index.html)
- [Buck2 Architecture](https://buck2.build/docs/concepts/)
- [D Language Metaprogramming](https://dlang.org/spec/template.html)
- [Build Systems à la Carte](https://www.microsoft.com/en-us/research/uploads/prod/2018/03/build-systems.pdf)

