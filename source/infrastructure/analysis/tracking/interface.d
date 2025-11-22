module infrastructure.analysis.tracking.interface_;

import infrastructure.analysis.tracking.tracker : FileState, ChangeResult;
import infrastructure.errors;

/// Interface for file change tracking implementations
/// Enables dependency injection and testing
interface IFileChangeTracker
{
    /// Initialize tracking for a file
    Result!BuildError track(string path) @system;
    
    /// Track multiple files (batch operation)
    Result!BuildError trackBatch(string[] paths) @system;
    
    /// Check if file has changed since last track
    /// Returns: ChangeResult with change status and content hash
    Result!(ChangeResult, BuildError) checkChange(string path) @system;
    
    /// Check multiple files for changes (batch operation)
    Result!(ChangeResult[string], BuildError) checkChanges(string[] paths) @system;
    
    /// Get current state for a file
    Result!(FileState*, BuildError) getState(string path) @system;
    
    /// Update state for a file (after analysis)
    Result!BuildError updateState(string path, string contentHash) @system;
    
    /// Remove file from tracking
    void untrack(string path) @system;
    
    /// Get all tracked files
    string[] getTrackedFiles() @system;
    
    /// Clear all tracking state
    void clear() @system;
    
    /// Get statistics
    struct Stats
    {
        size_t trackedFiles;
        size_t metadataChecks;
        size_t contentHashChecks;
        size_t changesDetected;
        float fastPathRate;
    }
    
    Stats getStats() const @system;
}

