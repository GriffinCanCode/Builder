module core.distributed.worker;

/// Build Worker
/// 
/// Executes build actions in hermetic sandbox.
/// 
/// Components:
/// - worker.d  - Worker implementation
/// - sandbox.d - Hermetic execution environment

public import core.distributed.worker.worker;
public import core.distributed.worker.sandbox;

