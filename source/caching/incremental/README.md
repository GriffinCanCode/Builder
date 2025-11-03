# Incremental Compilation Cache

Module-level dependency tracking for incremental compilation.

## Modules

### dependency.d
Core dependency tracking and analysis:
- `FileDependency` - File-to-file dependency relationship
- `DependencyCache` - Persistent dependency tracking cache
- `DependencyChanges` - Change analysis result

### storage.d
Binary storage for dependency cache:
- `DependencyStorage` - Efficient binary serialization

## Usage

```d
import caching.incremental;

// Create cache
auto cache = new DependencyCache(".builder-cache/incremental");

// Record dependencies
cache.recordDependencies("main.cpp", ["header.h", "utils.h"]);

// Analyze changes
auto changes = cache.analyzeChanges(["header.h"]);
// Returns: files that need rebuilding

// Get statistics
auto stats = cache.getStats();
writeln("Tracked dependencies: ", stats.totalSources);
writeln("Valid entries: ", stats.validEntries);
```

## Design Philosophy

- **Persistent**: Dependency information survives across builds
- **Incremental**: Only changed files trigger reanalysis
- **Efficient**: Binary storage with fast lookups
- **Language-Agnostic**: Works with any language's dependency model

## Performance

- **Storage**: ~100 bytes per source file with 10 dependencies
- **Lookup**: O(1) hash table lookup
- **Analysis**: O(D) where D is number of dependencies
- **Load/Save**: Binary format is 5-10x faster than JSON

## Integration

Works in conjunction with:
- ActionCache (action-level caching)
- IncrementalEngine (rebuild determination)
- Language analyzers (dependency extraction)

