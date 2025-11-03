module engine.distributed;

/// Distributed Build System
/// Coordinates build execution across multiple workers for massive speedups.
/// 
/// Features: Work-stealing, hermetic sandboxing, fault tolerance, zero-config

public import engine.distributed.protocol;
public import engine.distributed.coordinator;
public import engine.distributed.worker;
public import engine.distributed.storage;
