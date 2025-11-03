module engine.distributed.worker;

/// Worker components for distributed builds
/// 
/// Components:
/// - worker.d       - Main worker implementation (facade)
/// - lifecycle.d    - Worker lifecycle management
/// - execution.d    - Action execution
/// - communication.d - Coordinator and peer communication
/// - peers.d        - Peer discovery and management
/// - steal.d        - Work-stealing protocol
/// - sandbox.d      - Hermetic execution environment
/// 
/// Architecture:
/// - Workers execute build actions in isolation
/// - Peer-to-peer work-stealing for load balancing
/// - Content-addressable artifact storage
/// - Metrics and observability

public import engine.distributed.worker.worker;
public import engine.distributed.worker.lifecycle;
public import engine.distributed.worker.execution;
public import engine.distributed.worker.communication;
public import engine.distributed.worker.peers;
public import engine.distributed.worker.steal;

