# Incremental Compilation Engine

Language-agnostic incremental compilation orchestration.

## Modules

### engine.d
Core incremental compilation engine:
- `IncrementalEngine` - Rebuild determination and orchestration
- `CompilationStrategy` - Compilation strategy enumeration
- `IncrementalResult` - Compilation analysis result

### analyzer.d
Dependency analysis interface:
- `DependencyAnalyzer` - Language-agnostic interface
- `BaseDependencyAnalyzer` - Base implementation
- `TransitiveAnalyzer` - Transitive dependency helper

## Usage

```d
import compilation.incremental;
import caching.incremental;
import caching.actions;

// Initialize
auto depCache = new DependencyCache();
auto actionCache = new ActionCache();
auto engine = new IncrementalEngine(depCache, actionCache);

// Determine rebuild set
auto result = engine.determineRebuildSet(
    allSources,
    changedFiles,
    (file) => makeActionId(file),
    (file) => makeMetadata(file)
);

// Compile affected files
foreach (file; result.filesToCompile)
{
    auto deps = analyzer.analyzeDependencies(file);
    compile(file);
    
    engine.recordCompilation(
        file,
        deps.unwrap(),
        actionId,
        outputs,
        metadata
    );
}

// Report
writeln("Compiled: ", result.compiledFiles, "/", result.totalFiles);
writeln("Cached: ", result.cachedFiles_);
writeln("Reduction: ", result.reductionRate, "%");
```

## Strategies

### Full
```d
auto engine = new IncrementalEngine(
    depCache, actionCache, CompilationStrategy.Full
);
```
Rebuild everything. Use for CI or when caches are untrusted.

### Incremental (Default)
```d
auto engine = new IncrementalEngine(
    depCache, actionCache, CompilationStrategy.Incremental
);
```
Rebuild files with cache misses or dependency changes, plus transitive dependents.

### Minimal
```d
auto engine = new IncrementalEngine(
    depCache, actionCache, CompilationStrategy.Minimal
);
```
Rebuild only directly changed files or cache misses. Skip transitive dependents.

## Algorithm

1. **Phase 1: Action Cache Check**
   - For each source file, check if ActionCache has valid entry
   - Mark cache misses for compilation

2. **Phase 2: Dependency Analysis**
   - Analyze which files were changed
   - Use DependencyCache to find all files that depend on changed files
   - Mark dependent files for compilation

3. **Phase 3: Strategy Application**
   - Full: Mark all files
   - Incremental: Keep Phase 1 + Phase 2 results
   - Minimal: Keep only Phase 1 results

4. **Result**
   - Return set of files to compile
   - Return set of cached files
   - Calculate reduction percentage

## Design Philosophy

- **Language-Agnostic**: Works with any language via DependencyAnalyzer interface
- **Dual-Layer**: Combines ActionCache (fast) with DependencyCache (smart)
- **Flexible**: Multiple strategies for different use cases
- **Observable**: Detailed statistics and reasoning for each decision

## Performance

Typical build with 100 files, 1 header change affecting 10 files:
- Phase 1: 100 cache checks (~1ms)
- Phase 2: Dependency analysis (~5ms)
- Phase 3: Strategy application (~1ms)
- **Total: ~7ms overhead**
- **Savings: 90 compilations not needed (~9 minutes saved)**

## Testing

See `tests/unit/compilation/test_incremental_engine.d` for comprehensive tests.

