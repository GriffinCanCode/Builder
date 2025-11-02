module core.execution;

/// Execution System
/// 
/// Complete build execution infrastructure with:
/// - Core: Main execution engine
/// - Services: Modular service architecture (scheduling, caching, observability, resilience, registry)
/// - Watch Mode: Continuous file watching and incremental builds
/// - Recovery: Checkpoint/resume and retry logic

public import core.execution.core;
public import core.execution.services;
public import core.execution.watchmode;
public import core.execution.recovery;

