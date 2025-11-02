module analysis.tracking.tracker;

import std.file;
import std.path;
import std.datetime;
import std.algorithm;
import std.array;
import std.conv;
import core.sync.mutex;
import utils.files.hash;
import errors;

/// File change tracking state
struct FileState
{
    string path;
    string metadataHash;  // Fast: mtime + size
    string contentHash;   // Slow: full content hash
    SysTime lastModified;
    ulong size;
    bool exists;
}

/// File change detection using two-tier validation
/// Optimized for minimal I/O: metadata check → content hash only if needed
final class FileChangeTracker
{
    private FileState[string] states;
    private Mutex trackerMutex;
    
    // Performance metrics
    private size_t metadataChecks;
    private size_t contentHashChecks;
    private size_t changesDetected;
    
    this() @system
    {
        this.trackerMutex = new Mutex();
    }
    
    /// Initialize tracking for a file
    Result!BuildError track(string path) @system
    {
        synchronized (trackerMutex)
        {
            try
            {
                auto state = captureState(path);
                states[path] = state;
                return Ok!BuildError();
            }
            catch (Exception e)
            {
                auto error = new IOError(
                    path,
                    "Failed to track file: " ~ e.msg,
                    ErrorCode.FileReadFailed
                );
                return Result!BuildError.err(error);
            }
        }
    }
    
    /// Track multiple files (batch operation)
    Result!BuildError trackBatch(string[] paths) @system
    {
        foreach (path; paths)
        {
            auto result = track(path);
            if (result.isErr)
                return result;
        }
        return Ok!BuildError();
    }
    
    /// Check if file has changed since last track
    /// Returns: tuple (hasChanged, contentHash)
    Result!(ChangeResult, BuildError) checkChange(string path) @system
    {
        synchronized (trackerMutex)
        {
            metadataChecks++;
            
            try
            {
                auto oldState = path in states;
                if (oldState is null)
                {
                    // File not tracked - consider it changed
                    auto newState = captureState(path);
                    states[path] = newState;
                    changesDetected++;
                    
                    return Result!(ChangeResult, BuildError).ok(
                        ChangeResult(true, newState.contentHash, ChangeKind.New)
                    );
                }
                
                // Check if file still exists
                if (!exists(path))
                {
                    if (oldState.exists)
                    {
                        // File was deleted
                        states[path].exists = false;
                        changesDetected++;
                        return Result!(ChangeResult, BuildError).ok(
                            ChangeResult(true, "", ChangeKind.Deleted)
                        );
                    }
                    else
                    {
                        // Still doesn't exist
                        return Result!(ChangeResult, BuildError).ok(
                            ChangeResult(false, "", ChangeKind.Unchanged)
                        );
                    }
                }
                
                // Fast path: metadata check
                auto newMetadataHash = FastHash.hashMetadata(path);
                if (newMetadataHash == oldState.metadataHash)
                {
                    // Metadata unchanged - assume content unchanged
                    return Result!(ChangeResult, BuildError).ok(
                        ChangeResult(false, oldState.contentHash, ChangeKind.Unchanged)
                    );
                }
                
                // Slow path: content changed or metadata touch
                contentHashChecks++;
                auto newContentHash = FastHash.hashFile(path);
                
                if (newContentHash == oldState.contentHash)
                {
                    // Content unchanged, just metadata (e.g., touch)
                    // Update metadata hash
                    states[path].metadataHash = newMetadataHash;
                    states[path].lastModified = DirEntry(path).timeLastModified;
                    
                    return Result!(ChangeResult, BuildError).ok(
                        ChangeResult(false, newContentHash, ChangeKind.Unchanged)
                    );
                }
                
                // Content actually changed
                auto newState = captureState(path);
                states[path] = newState;
                changesDetected++;
                
                return Result!(ChangeResult, BuildError).ok(
                    ChangeResult(true, newContentHash, ChangeKind.Modified)
                );
            }
            catch (Exception e)
            {
                auto error = new IOError(
                    path,
                    "Failed to check file change: " ~ e.msg,
                    ErrorCode.FileReadFailed
                );
                return Result!(ChangeResult, BuildError).err(error);
            }
        }
    }
    
    /// Check multiple files for changes (batch operation)
    Result!(ChangeResult[string], BuildError) checkChanges(string[] paths) @system
    {
        ChangeResult[string] results;
        
        foreach (path; paths)
        {
            auto result = checkChange(path);
            if (result.isErr)
                return Result!(ChangeResult[string], BuildError).err(result.unwrapErr());
            
            results[path] = result.unwrap();
        }
        
        return Result!(ChangeResult[string], BuildError).ok(results);
    }
    
    /// Get current state for a file
    Result!(FileState*, BuildError) getState(string path) @system
    {
        synchronized (trackerMutex)
        {
            auto state = path in states;
            if (state is null)
            {
                auto error = new IOError(
                    path,
                    "File not tracked",
                    ErrorCode.FileNotFound
                );
                return Result!(FileState*, BuildError).err(error);
            }
            
            return Result!(FileState*, BuildError).ok(state);
        }
    }
    
    /// Update state for a file (after analysis)
    Result!BuildError updateState(string path, string contentHash) @system
    {
        synchronized (trackerMutex)
        {
            auto state = path in states;
            if (state is null)
            {
                auto error = new IOError(
                    path,
                    "File not tracked",
                    ErrorCode.FileNotFound
                );
                return Result!BuildError.err(error);
            }
            
            state.contentHash = contentHash;
            return Ok!BuildError();
        }
    }
    
    /// Remove file from tracking
    void untrack(string path) @system
    {
        synchronized (trackerMutex)
        {
            states.remove(path);
        }
    }
    
    /// Get all tracked files
    string[] getTrackedFiles() @system
    {
        synchronized (trackerMutex)
        {
            return states.keys;
        }
    }
    
    /// Clear all tracking state
    void clear() @system
    {
        synchronized (trackerMutex)
        {
            states.clear();
            metadataChecks = 0;
            contentHashChecks = 0;
            changesDetected = 0;
        }
    }
    
    /// Get statistics
    struct Stats
    {
        size_t trackedFiles;
        size_t metadataChecks;
        size_t contentHashChecks;
        size_t changesDetected;
        float fastPathRate;  // Percentage of checks resolved by metadata
    }
    
    Stats getStats() const @system
    {
        synchronized (cast(Mutex)trackerMutex)
        {
            Stats stats;
            stats.trackedFiles = states.length;
            stats.metadataChecks = metadataChecks;
            stats.contentHashChecks = contentHashChecks;
            stats.changesDetected = changesDetected;
            
            if (metadataChecks > 0)
            {
                immutable fastPath = metadataChecks - contentHashChecks;
                stats.fastPathRate = (fastPath * 100.0) / metadataChecks;
            }
            
            return stats;
        }
    }
    
    // Private helpers
    
    private FileState captureState(string path) @system
    {
        FileState state;
        state.path = path;
        
        if (!exists(path))
        {
            state.exists = false;
            return state;
        }
        
        state.exists = true;
        
        auto info = DirEntry(path);
        state.lastModified = info.timeLastModified;
        state.size = info.size;
        
        state.metadataHash = FastHash.hashMetadata(path);
        state.contentHash = FastHash.hashFile(path);
        
        return state;
    }
}

/// Result of change detection
struct ChangeResult
{
    bool hasChanged;
    string contentHash;
    ChangeKind kind;
}

/// Type of change detected
enum ChangeKind
{
    Unchanged,
    Modified,
    New,
    Deleted
}

