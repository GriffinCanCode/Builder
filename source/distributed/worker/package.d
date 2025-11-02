module distributed.worker;

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

public import distributed.worker.worker;
public import distributed.worker.lifecycle;
public import distributed.worker.execution;
public import distributed.worker.communication;
public import distributed.worker.peers;
public import distributed.worker.steal;

