module engine.caching.incremental;

/// Incremental Compilation Cache Package
/// 
/// Provides module-level dependency tracking for incremental compilation.
/// Tracks which source files depend on which headers/modules/files and
/// determines minimal rebuild sets when dependencies change.
/// 
/// Architecture:
///   dependency.d - Core dependency tracking and analysis
///   storage.d    - Binary serialization for dependency cache
///   filter.d     - Smart file filtering for operations
/// 
/// Usage:
///   ```d
///   auto cache = new DependencyCache(".builder-cache/incremental");
///   
///   // Record dependencies
///   cache.recordDependencies("main.cpp", ["header.h", "utils.h"]);
///   
///   // Analyze changes
///   auto changes = cache.analyzeChanges(["header.h"]);
///   // Returns: ["main.cpp"] needs rebuild
///   
///   // Filter files for operations
///   auto filter = IncrementalFilter.create(depCache, actionCache);
///   auto filesToLint = filter.filterFiles(allFiles, changedFiles, 
///                                         ActionType.Lint, metadata);
///   ```
/// 
/// Integration:
///   - Works with ActionCache for action-level caching
///   - Integrates with language-specific dependency analyzers
///   - Used by compilation, testing, linting, and formatting

public import engine.caching.incremental.dependency;
public import engine.caching.incremental.storage;
public import engine.caching.incremental.schema;
public import engine.caching.incremental.filter;

