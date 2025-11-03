module engine.compilation.incremental;

/// Incremental Compilation Package
/// 
/// Provides language-agnostic incremental compilation infrastructure.
/// Determines minimal rebuild sets based on dependency tracking and action caching.
/// 
/// Architecture:
///   engine.d   - Core incremental compilation orchestration
///   analyzer.d - Language-agnostic dependency analysis interface
/// 
/// Usage:
///   ```d
///   auto depCache = new DependencyCache();
///   auto actionCache = new ActionCache();
///   auto engine = new IncrementalEngine(depCache, actionCache);
///   
///   // Determine what needs rebuilding
///   auto result = engine.determineRebuildSet(
///       allSources,
///       changedFiles,
///       (file) => makeActionId(file),
///       (file) => makeMetadata(file)
///   );
///   
///   // Compile only necessary files
///   foreach (file; result.filesToCompile)
///   {
///       compile(file);
///       engine.recordCompilation(file, dependencies, ...);
///   }
///   ```
/// 
/// Design Philosophy:
///   - Language-agnostic core
///   - Integrates with ActionCache for action-level caching
///   - Pluggable dependency analyzers per language
///   - Minimal rebuild determination
///   - Transitive dependency tracking

public import engine.compilation.incremental.engine;
public import engine.compilation.incremental.analyzer;

