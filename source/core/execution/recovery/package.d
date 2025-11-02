module core.execution.recovery;

/// Build Recovery & Resilience
/// 
/// Checkpoint/resume functionality and retry logic for resilient builds.
/// Enables resuming interrupted builds and automatic retry of transient failures.

public import core.execution.recovery.checkpoint;
public import core.execution.recovery.resume;
public import core.execution.recovery.retry;

