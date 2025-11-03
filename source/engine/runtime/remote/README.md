# Remote Execution System

Distributed build execution leveraging Builder's native hermetic sandboxing across worker pools with intelligent autoscaling.

## Overview

The remote execution system enables distributed builds by executing actions on remote workers while maintaining Builder's hermetic guarantees. Unlike container-based systems, Builder uses native OS-level sandboxing for zero-overhead execution.

### Key Features

- **Native Hermetic Sandboxing** - No container runtime overhead
- **Bazel REAPI Compatibility** - Works with standard REAPI clients  
- **Predictive Autoscaling** - Intelligent worker pool management
- **Production-Ready** - Built-in health monitoring and metrics

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Remote Execution Service                 │
│                                                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  REAPI   │  │  Native  │  │ Metrics  │      │
│  │ Adapter  │  │   API    │  │ Exporter │      │
│  └────┬─────┘  └────┬─────┘  └──────────┘      │
│       │             │                            │
│       └─────┬───────┘                            │
│             │                                    │
│       ┌─────▼──────┐                            │
│       │ Coordinator │                            │
│       └─────┬──────┘                            │
│             │                                    │
│    ┌────────┴────────┐                          │
│    │   Worker Pool    │                          │
│    │  (Auto-scaling)  │                          │
│    └────────┬────────┘                          │
└─────────────┼──────────────────────────────────┘
              │
      ┌───────┴────────┐
      │                │
  ┌───▼───┐        ┌───▼───┐
  │Worker1│        │Worker2│
  └───────┘        └───────┘
```

## Module Structure

The remote execution system is organized into the following modules:

### `core/`
**Core execution components**

- `service.d` - Main remote execution service orchestrator
- `executor.d` - Remote execution engine and coordination logic

### `pool/`
**Worker pool management with autoscaling**

- `manager.d` - Worker pool manager with dynamic scaling
- `scaling/` - Autoscaling algorithms
  - `predictor.d` - Load predictor using exponential smoothing

### `artifacts/`
**Artifact management for remote workers**

- `manager.d` - Handles upload/download of input/output artifacts
  - Chunk-based transfer for large files (>1MB)
  - Incremental updates for changed artifacts
  - BLAKE3 content addressing

### `serialization/`
**High-performance spec serialization**

- `codec.d` - SIMD-accelerated serialization codec
- `schema.d` - Serializable sandbox specification schema

### `protocol/`
**Protocol adapters and extensions**

- `reapi.d` - Bazel Remote Execution API adapter
- `discovery.d` - Dynamic discovery integration for distributed builds

### `monitoring/`
**Health monitoring and metrics collection**

- `health.d` - Service health monitoring with automatic issue detection
- `metrics.d` - Metrics collection and aggregation

### `providers/`
**Cloud provider integrations**

- `base.d` - Cloud provider interface
- `provisioner.d` - Worker provisioning orchestrator
- `aws.d` - AWS EC2 integration
- `kubernetes.d` - Kubernetes integration
- `mock.d` - Mock provider for testing

## Usage Examples

### Basic Remote Execution

```d
import engine.runtime.remote;
import engine.runtime.hermetic;
import engine.graph.graph;

// Build service
auto service = RemoteServiceBuilder.create()
    .coordinator("0.0.0.0", 9000)
    .pool(PoolConfig(
        minWorkers: 2,
        maxWorkers: 50,
        enableAutoScale: true
    ))
    .enableReapi(9001)
    .enableMetrics()
    .build(buildGraph);

// Start service
auto result = service.start();
if (result.isErr) {
    Logger.error("Failed to start: " ~ result.unwrapErr().message());
    return;
}

// Execute action remotely
auto spec = SandboxSpecBuilder.create()
    .input("/workspace/src")
    .output("/workspace/bin")
    .temp("/tmp/build")
    .maxMemory(4.GiB)
    .maxCpu(4)
    .timeout(5.minutes)
    .build().unwrap();

auto execResult = service.execute(
    actionId,
    spec,
    ["gcc", "main.c", "-o", "main"],
    "/workspace"
);

// Cleanup
service.stop();
```

### With REAPI (Bazel Compatibility)

```d
// Build REAPI action
auto command = Command([
    "/usr/bin/gcc",
    "-c",
    "main.c",
    "-o",
    "main.o"
]);
command.platform = Platform([
    Platform.Property("OSFamily", "linux"),
    Platform.Property("Pool", "default")
]);

auto action = Action(
    commandDigest: commandDigest,
    inputRootDigest: inputDigest,
    timeout: 5.minutes,
    doNotCache: false
);

// Execute via REAPI
auto response = service.executeReapi(action);
if (response.isOk) {
    auto result = response.unwrap();
    writeln("Exit code: ", result.result.exitCode);
    writeln("From cache: ", result.cachedResult);
}
```

### Monitoring and Metrics

```d
// Get service status
auto status = service.getStatus();
writeln("Workers: ", status.poolStats.totalWorkers);
writeln("Busy: ", status.poolStats.busyWorkers);
writeln("Queue depth: ", status.coordinatorStats.pendingActions);

// Get metrics
auto metrics = service.getMetrics();
writeln("Total executions: ", metrics.totalExecutions);
writeln("Success rate: ", 
    cast(float)metrics.successfulExecutions / metrics.totalExecutions * 100, "%");
```

## Design Principles

### 1. Native Hermetic Sandboxing (Not Containers)

Workers execute using OS-native isolation:
- **Linux**: namespaces + cgroups
- **macOS**: sandbox-exec + rusage
- **Windows**: job objects

This provides:
- Zero container runtime overhead
- < 100ms startup latency (vs 1-5s for containers)
- ~5ms execution overhead (vs 50-200ms)
- Precise resource limits
- Full reproducibility

### 2. Predictive Autoscaling

The worker pool uses sophisticated algorithms:

- **Exponential Smoothing**: Forecasts load trends
  - Formula: `St = αXt + (1-α)St-1`
  - Smoothing factor α = 0.3 (configurable)
  
- **Trend Detection**: Linear regression on recent samples
  - Detects increasing/decreasing patterns
  - Enables proactive scaling
  
- **Hysteresis**: Cooldown periods prevent oscillation
  - Scale-up cooldown: 30 seconds
  - Scale-down cooldown: 2 minutes

- **Queuing Theory**: Uses Little's Law for capacity planning
  - `L = λW` (queue length = arrival rate × wait time)

### 3. Separation of Concerns

The architecture follows strict SRP (Single Responsibility Principle):

- **Service**: Orchestrates lifecycle and coordination
- **Executor**: Manages execution flow
- **ArtifactManager**: Handles I/O operations
- **WorkerPool**: Manages pool state and statistics
- **WorkerProvisioner**: Handles cloud provisioning
- **Health Monitor**: Monitors service health
- **Metrics Collector**: Aggregates metrics

Each component has a single, well-defined responsibility.

### 4. Efficient Artifact Transfer

Artifact management is optimized for performance:

- **Chunk-based Transfer**: Files >1MB use chunks
  - Typical chunk size: 256KB
  - Parallel chunk uploads/downloads
  - Resume capability for failed transfers

- **Incremental Updates**: Only transfer changed chunks
  - Uses BLAKE3 for chunk hashing
  - Can save 90%+ bandwidth for small changes
  - Automatic fallback to full transfer if needed

- **Content Addressing**: BLAKE3 for artifact IDs
  - 32-byte hashes
  - SIMD-accelerated
  - Automatic deduplication

## Performance Characteristics

| Metric | Builder (Native) | Container-Based |
|--------|------------------|-----------------|
| Startup latency | < 100ms | 1-5s |
| Execution overhead | ~5ms | 50-200ms |
| Network efficiency | Zero-copy + SIMD | Standard TCP |
| Scalability | 1000+ workers | Varies |
| Cache speedup | 100-1000x | 100-1000x |

## Configuration

### Pool Configuration

```d
PoolConfig poolConfig;
poolConfig.minWorkers = 2;              // Minimum pool size
poolConfig.maxWorkers = 100;            // Maximum pool size
poolConfig.targetWorkers = 10;          // Steady-state target
poolConfig.scaleUpThreshold = 0.75;     // Scale up at 75% utilization
poolConfig.scaleDownThreshold = 0.25;   // Scale down at 25% utilization
poolConfig.enableAutoScale = true;      // Enable autoscaling
poolConfig.enablePredictiveScaling = true;  // Use predictive algorithms
```

### Executor Configuration

```d
RemoteExecutorConfig execConfig;
execConfig.coordinatorUrl = "http://coordinator:9000";
execConfig.artifactStoreUrl = "http://cache:8080";
execConfig.enableCaching = true;
execConfig.enableCompression = true;
execConfig.maxConcurrent = 100;
execConfig.defaultTimeout = 5.minutes;
```

## Cloud Provider Integration

Pluggable cloud provider support:

```d
// AWS EC2
auto awsProvider = new AwsEc2Provider(
    "us-east-1",
    accessKey,
    secretKey
);

// Kubernetes
auto k8sProvider = new KubernetesProvider(
    "default",
    "~/.kube/config"
);

// Use with pool
auto provisioner = new WorkerProvisioner(awsProvider);
```

## Monitoring

### Health Checks

The health monitor automatically detects:
- No workers available
- High queue depth (>10x worker count)
- Failed workers
- Coordinator issues

### Metrics

Available metrics:
- Total/successful/failed executions
- Cache hit rate
- Worker utilization
- Queue depth
- Active/idle/busy workers
- Service uptime

## Testing

Mock provider for testing:

```d
auto mockProvider = new MockCloudProvider();
auto provisioner = new WorkerProvisioner(mockProvider);
auto pool = new WorkerPool(config, registry, provisioner);
```

## See Also

- `engine.runtime.hermetic` - Hermetic execution system
- `engine.distributed.coordinator` - Distributed coordination
- `engine.caching.distributed` - Remote caching
- `engine.distributed.protocol` - Distributed protocol

## License

Part of the Builder build system. See LICENSE for details.

