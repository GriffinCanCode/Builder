module core.distributed.worker;

/// Worker components for distributed builds
/// 
/// Components:
/// - worker.d - Main worker implementation
/// - peers.d  - Peer discovery and management
/// - steal.d  - Work-stealing protocol
/// - sandbox.d - Hermetic execution environment
/// 
/// Architecture:
/// - Workers execute build actions in isolation
/// - Peer-to-peer work-stealing for load balancing
/// - Content-addressable artifact storage
/// - Metrics and observability

public import core.distributed.worker.worker;
public import core.distributed.worker.peers;
public import core.distributed.worker.steal;

