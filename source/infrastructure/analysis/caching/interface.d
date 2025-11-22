module infrastructure.analysis.caching.interface_;

import infrastructure.analysis.targets.types;
import infrastructure.errors;

/// Interface for analysis caching implementations
/// Enables dependency injection and testing
interface IAnalysisCache
{
    /// Get cached analysis for a file by content hash
    /// Returns: Ok with FileAnalysis* (null on miss), Err on error
    Result!(FileAnalysis*, BuildError) get(string contentHash) @system;
    
    /// Store file analysis indexed by content hash
    Result!BuildError put(string contentHash, const ref FileAnalysis analysis) @system;
    
    /// Check if analysis exists for content hash
    bool has(string contentHash) @system;
    
    /// Get batch of analyses (optimized for bulk operations)
    Result!(FileAnalysis*[string], BuildError) getBatch(string[] contentHashes) @system;
    
    /// Store batch of analyses (optimized for bulk operations)
    Result!BuildError putBatch(FileAnalysis[string] analyses) @system;
    
    /// Clear cache
    void clear() @system;
    
    /// Get cache statistics
    struct Stats
    {
        size_t hits;
        size_t misses;
        size_t stores;
        float hitRate;
        size_t totalQueries;
    }
    
    Stats getStats() const @system;
}

