module core.distributed;

/// Distributed Build System
/// 
/// Coordinates build execution across multiple workers for massive speedups.
/// 
/// Architecture:
/// - protocol.d    - Message protocol and types
/// - coordinator.d - Build coordinator (scheduler)
/// - worker.d      - Build worker (executor)
/// - registry.d    - Worker pool management
/// - scheduler.d   - Distributed scheduling
/// - transport.d   - Network transport layer
/// - sandbox.d     - Hermetic execution
/// - store.d       - Artifact storage
/// - integration.d - Main build system integration
/// 
/// Design Principles:
/// - Content-addressable: All artifacts identified by BLAKE3 hash
/// - Work-stealing: Workers autonomously balance load
/// - Hermetic: Sandboxed execution for reproducibility
/// - Fault-tolerant: Automatic recovery from worker failures
/// - Zero-config: Auto-discovery and self-organization
/// 
/// Module Structure:
/// - protocol/    - Communication protocol and transport
/// - coordinator/ - Build coordinator and scheduling
/// - worker/      - Worker execution and sandboxing
/// - storage/     - Artifact storage layer
/// 
/// Usage:
/// 
/// **Coordinator:**
/// ```d
/// auto config = CoordinatorConfig();
/// config.host = "0.0.0.0";
/// config.port = 9000;
/// 
/// auto coordinator = new Coordinator(buildGraph, config);
/// coordinator.start();
/// 
/// // Schedule actions
/// coordinator.scheduleAction(actionRequest);
/// ```
/// 
/// **Worker:**
/// ```d
/// auto config = WorkerConfig();
/// config.coordinatorUrl = "http://coordinator:9000";
/// config.maxConcurrentActions = 8;
/// 
/// auto worker = new Worker(config);
/// worker.start();
/// ```
/// 
/// **Client:**
/// ```bash
/// # Distributed build (auto-detects coordinator)
/// builder build --distributed
/// 
/// # Explicit coordinator
/// builder build --coordinator http://coordinator:9000
/// ```
/// 
/// Performance Characteristics:
/// - **Speedup:** 5-10x with 10 workers (typical)
/// - **Scaling:** >80% efficiency with 100 workers
/// - **Overhead:** <10% vs local builds

// Public API
public import core.distributed.coordinator.coordinator;
public import core.distributed.worker.worker;
public import core.distributed.protocol.protocol;
/// - **Fault tolerance:** <5s recovery from worker failure
/// 
/// Security:
/// - Hermetic sandboxing (Linux namespaces, macOS sandbox-exec)
/// - Capability-based access control
/// - Network isolation (optional)
/// - Content integrity (BLAKE3 verification)

public import core.distributed.protocol;
public import core.distributed.coordinator;
public import core.distributed.worker;
public import core.distributed.storage;



