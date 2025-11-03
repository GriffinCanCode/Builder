module engine.runtime;

/// Execution System
/// 
/// Complete build execution infrastructure with:
/// - Core: Main execution engine
/// - Services: Modular service architecture (scheduling, caching, observability, resilience, registry)
/// - Watch Mode: Continuous file watching and incremental builds
/// - Recovery: Checkpoint/resume and retry logic

public import engine.runtime.core;
public import engine.runtime.services;
public import engine.runtime.watchmode;
public import engine.runtime.recovery;

