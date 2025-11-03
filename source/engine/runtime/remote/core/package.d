module engine.runtime.remote.core;

/// Core remote execution components
/// 
/// This module contains the main service orchestrator and execution engine
/// for distributed builds using native hermetic sandboxing.

public import engine.runtime.remote.core.interface_ : 
    IRemoteExecutionService, 
    NullRemoteExecutionService,
    ServiceStatus;
public import engine.runtime.remote.core.service;
public import engine.runtime.remote.core.executor;

