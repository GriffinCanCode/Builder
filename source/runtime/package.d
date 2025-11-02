module runtime;

/// Execution System
/// 
/// Complete build execution infrastructure with:
/// - Core: Main execution engine
/// - Services: Modular service architecture (scheduling, caching, observability, resilience, registry)
/// - Watch Mode: Continuous file watching and incremental builds
/// - Recovery: Checkpoint/resume and retry logic

public import runtime.core;
public import runtime.services;
public import runtime.watchmode;
public import runtime.recovery;

