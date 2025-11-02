module core.distributed.coordinator;

/// Build Coordinator
/// 
/// Manages distributed build execution across worker pool.
/// 
/// Components:
/// - coordinator.d - Main coordinator implementation
/// - registry.d    - Worker pool registry
/// - scheduler.d   - Distributed scheduling logic

public import core.distributed.coordinator.coordinator;
public import core.distributed.coordinator.registry;
public import core.distributed.coordinator.scheduler;

