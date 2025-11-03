module engine.compilation.incremental.engine;

import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.path;
import engine.caching.incremental.dependency;
import engine.caching.actions.action;
import infrastructure.config.schema.schema;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;
import infrastructure.errors;

/// Incremental compilation strategy
enum CompilationStrategy
{
    Full,         // Rebuild everything
    Incremental,  // Rebuild only affected files
    Minimal       // Rebuild only changed files (no transitive deps)
}

/// Incremental compilation result
struct IncrementalResult
{
    string[] filesToCompile;      // Files that need compilation
    string[] cachedFiles;         // Files that can use cached results
    CompilationStrategy strategy; // Strategy used
    string[string] reasons;       // Reason for each file compilation
    size_t totalFiles;
    size_t compiledFiles;
    size_t cachedFiles_;
    float reductionRate;
}

/// Incremental compilation engine
/// Orchestrates minimal rebuild determination using dependency tracking
final class IncrementalEngine
{
    private DependencyCache depCache;
    private ActionCache actionCache;
    private CompilationStrategy strategy;
    
    this(
        DependencyCache depCache,
        ActionCache actionCache,
        CompilationStrategy strategy = CompilationStrategy.Incremental
    ) @trusted
    {
        this.depCache = depCache;
        this.actionCache = actionCache;
        this.strategy = strategy;
    }
    
    /// Determine which files need compilation
    /// 
    /// Algorithm:
    /// 1. Check action cache for each file
    /// 2. For files with valid cache, check dependency changes
    /// 3. If dependency changed, mark file for recompilation
    /// 4. Transitively mark dependent files
    IncrementalResult determineRebuildSet(
        string[] sourceFiles,
        string[] changedFiles,
        ActionId delegate(string) makeActionId,
        string[string] delegate(string) makeMetadata
    ) @system
    {
        IncrementalResult result;
        result.totalFiles = sourceFiles.length;
        result.strategy = strategy;
        
        if (strategy == CompilationStrategy.Full)
        {
            result.filesToCompile = sourceFiles.dup;
            result.compiledFiles = sourceFiles.length;
            foreach (file; sourceFiles)
                result.reasons[file] = "full rebuild requested";
            return result;
        }
        
        bool[string] needsCompile;
        bool[string] isCached;
        
        // Phase 1: Check action cache for each file
        foreach (sourceFile; sourceFiles)
        {
            auto actionId = makeActionId(sourceFile);
            auto metadata = makeMetadata(sourceFile);
            
            // Check if this compilation is cached
            if (actionCache.isCached(actionId, [sourceFile], metadata))
            {
                isCached[sourceFile] = true;
                Logger.debugLog("  [ActionCache Hit] " ~ sourceFile);
            }
            else
            {
                needsCompile[sourceFile] = true;
                result.reasons[sourceFile] = "action cache miss";
                Logger.debugLog("  [ActionCache Miss] " ~ sourceFile);
            }
        }
        
        // Phase 2: Analyze dependency changes
        if (changedFiles.length > 0)
        {
            auto changes = depCache.analyzeChanges(changedFiles);
            
            foreach (file; changes.filesToRebuild)
            {
                if (file !in needsCompile)
                {
                    needsCompile[file] = true;
                    auto reason = file in changes.changeReasons;
                    result.reasons[file] = reason ? *reason : "dependency changed";
                    Logger.debugLog("  [Dependency Change] " ~ file ~ ": " ~ result.reasons[file]);
                }
            }
        }
        
        // Phase 3: Minimal strategy - only direct changes
        if (strategy == CompilationStrategy.Minimal)
        {
            // Only compile files that directly changed or have cache misses
            foreach (file; changedFiles)
            {
                if (sourceFiles.canFind(file) && file !in needsCompile)
                {
                    needsCompile[file] = true;
                    result.reasons[file] = "source file changed";
                }
            }
        }
        
        // Build result
        result.filesToCompile = needsCompile.keys;
        result.cachedFiles = isCached.keys.filter!(f => f !in needsCompile).array;
        result.compiledFiles = result.filesToCompile.length;
        result.cachedFiles_ = result.cachedFiles.length;
        
        if (result.totalFiles > 0)
        {
            result.reductionRate = 
                (cast(float)result.cachedFiles.length / result.totalFiles) * 100.0;
        }
        
        Logger.info("Incremental analysis: " ~
                   result.compiledFiles.to!string ~ " to compile, " ~
                   result.cachedFiles_.to!string ~ " cached (" ~
                   result.reductionRate.to!string[0..min(5, $)] ~ "% reduction)");
        
        return result;
    }
    
    /// Record successful compilation with dependencies
    void recordCompilation(
        string sourceFile,
        string[] dependencies,
        ActionId actionId,
        string[] outputs,
        string[string] metadata
    ) @system
    {
        // Record in dependency cache
        depCache.recordDependencies(sourceFile, dependencies);
        
        // Record in action cache
        actionCache.update(actionId, [sourceFile], outputs, metadata, true);
    }
    
    /// Invalidate cache for files
    void invalidate(string[] files) @system
    {
        foreach (file; files)
        {
            depCache.invalidate([file]);
        }
    }
    
    /// Clear all caches
    void clear() @system
    {
        depCache.clear();
    }
    
    /// Get combined statistics
    struct Stats
    {
        size_t totalDependencies;
        size_t validDependencies;
        size_t invalidDependencies;
        size_t actionCacheHits;
        size_t actionCacheMisses;
    }
    
    Stats getStats() @system
    {
        Stats stats;
        
        auto depStats = depCache.getStats();
        stats.totalDependencies = depStats.totalSources;
        stats.validDependencies = depStats.validEntries;
        stats.invalidDependencies = depStats.invalidEntries;
        
        return stats;
    }
}

