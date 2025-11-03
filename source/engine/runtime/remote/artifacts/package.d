module engine.runtime.remote.artifacts;

/// Artifact management for remote execution
/// 
/// Handles upload/download of input and output artifacts to/from remote workers
/// using chunk-based transfer for large files with incremental updates.

public import engine.runtime.remote.artifacts.manager;

