# Remote Execution

**Status:** ✅ **PRODUCTION READY** - Native hermetic sandboxing with REAPI compatibility

## Overview

Remote execution distributes build actions across a worker pool for massive parallelism. Unlike traditional container-based systems (like Bazel with Docker), Builder uses **native OS sandboxing** for zero-overhead isolation.

## Architecture

### Design Philosophy

Builder's remote execution is built on three core principles:

1. **Native Sandboxing > Containers**
   - Direct OS-level isolation (namespaces, sandbox-exec, job objects)
   - No container runtime dependency
   - <100ms startup vs 1-5s for containers
   - <5ms execution overhead vs 50-200ms

2. **Hermetic Spec Transmission**
   - Ship `SandboxSpec` to workers (not container images)
   - Workers execute using platform-native backend
   - Full reproducibility without Docker

3. **Intelligent Autoscaling**
   - Predictive load forecasting using exponential smoothing
   - Queuing theory for capacity planning (Little's Law: L = λW)
   - Trend-aware scaling with hysteresis

### System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  Remote Execution Service                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ REAPI Adapter│  │Native Executor│  │ Metrics Exporter│  │
│  │ (Bazel compat)│  │              │  │                 │  │
│  └──────┬───────┘  └──────┬───────┘  └─────────────────┘  │
│         │                  │                                │
│         └────────┬─────────┘                                │
│                  │                                          │
│         ┌────────▼──────────┐                              │
│         │   Coordinator      │                              │
│         │   (Scheduler)      │                              │
│         └────────┬───────────┘                              │
│                  │                                          │
│         ┌────────▼───────────┐                             │
│         │   Worker Pool       │                             │
│         │ (Autoscaling)       │                             │
│         │                     │                             │
│         │  Predictive Load    │                             │
│         │  Little's Law       │                             │
│         │  Exp. Smoothing     │                             │
│         └────────┬───────────┘                             │
│                  │                                          │
└──────────────────┼──────────────────────────────────────────┘
                   │
       ┌───────────┴────────────┐
       │                        │
   ┌───▼────┐             ┌─────▼───┐
   │Worker 1│             │Worker 2 │
   │        │             │         │
   │ Linux: │             │ macOS:  │
   │namespace│             │sandbox- │
   │+ cgroup│             │  exec   │
   └────────┘             └─────────┘
```

## Components

### 1. Remote Execution Service (`service.d`)

Central orchestrator that coordinates all components:

- Manages coordinator lifecycle
- Controls worker pool
- Exposes native and REAPI APIs
- Health monitoring and metrics

### 2. Remote Executor (`executor.d`)

Executes individual actions on remote workers:

- Uploads input artifacts to store
- Ships `SandboxSpec` to worker
- Worker executes hermetically using native OS backend
- Downloads output artifacts
- Caches results

### 3. Worker Pool (`pool.d`)

Dynamic worker pool with intelligent autoscaling:

**Autoscaling Algorithm:**

```
Predictive Load = α × Current + (1-α) × Previous   (Exponential Smoothing)
Trend = Linear Regression Slope
Desired Workers = f(Load, Trend, Thresholds)
```

**Features:**
- Min/max bounds with target steady-state
- Cooldown periods prevent oscillation
- Trend-aware: aggressive scale-up on increasing load
- Conservative scale-down on decreasing load

**Cloud Provider Support:**
- AWS EC2 (via boto3 or SDK)
- GCP Compute Engine
- Kubernetes (via kubectl/client-go)
- Custom providers via interface

### 4. REAPI Adapter (`reapi.d`)

Bazel Remote Execution API compatibility layer:

- Protocol translation: REAPI ↔ Builder native
- No gRPC dependency (efficient HTTP/2)
- BLAKE3 content addressing
- Standard REAPI semantics

## Usage

### Basic Setup

```d
import core.execution.remote;
import core.execution.hermetic;

// Configure pool
auto poolConfig = PoolConfig(
    minWorkers: 2,
    maxWorkers: 50,
    targetWorkers: 10,
    scaleUpThreshold: 0.75,      // Scale up at 75% utilization
    scaleDownThreshold: 0.25,     // Scale down at 25%
    scaleUpCooldown: 30.seconds,
    scaleDownCooldown: 2.minutes,
    enableAutoScale: true,
    enablePredictiveScaling: true
);

// Configure executor
auto executorConfig = RemoteExecutorConfig(
    coordinatorUrl: "http://coordinator:9000",
    artifactStoreUrl: "http://cache:8080",
    enableCaching: true,
    enableCompression: true,
    maxConcurrent: 100
);

// Build service
auto service = RemoteServiceBuilder.create()
    .coordinator("0.0.0.0", 9000)
    .pool(poolConfig)
    .executor(executorConfig)
    .enableReapi(9001)
    .enableMetrics(true)
    .build(buildGraph);

// Start
service.start();

// Use
auto spec = SandboxSpecBuilder.create()
    .input("/workspace/src")
    .output("/workspace/build")
    .temp("/tmp/builder")
    .maxMemory(4.GiB)
    .maxCpu(4)
    .timeout(5.minutes)
    .build().unwrap();

auto result = service.execute(
    actionId,
    spec,
    ["gcc", "-c", "main.c", "-o", "main.o"],
    "/workspace"
);

// Monitor
auto metrics = service.getMetrics();
writeln("Executions: ", metrics.totalExecutions);
writeln("Workers: ", metrics.activeWorkers);
writeln("Cache hits: ", metrics.cachedExecutions);

// Cleanup
service.stop();
```

### REAPI Integration (Bazel)

```d
// Build REAPI action
auto command = Command();
command.arguments = ["gcc", "-c", "main.c", "-o", "main.o"];
command.environmentVariables = [
    Command.EnvironmentVariable("CC", "gcc"),
    Command.EnvironmentVariable("CFLAGS", "-O2")
];
command.outputFiles = ["main.o"];
command.platform = Platform([
    Platform.Property("OSFamily", "linux"),
    Platform.Property("Pool", "default"),
    Platform.Property("ISA", "x86-64")
]);

auto action = Action(
    commandDigest: computeDigest(command),
    inputRootDigest: computeInputDigest(),
    timeout: 5.minutes,
    doNotCache: false,
    platform: command.platform
);

// Execute
auto response = service.executeReapi(action);
if (response.isOk) {
    auto result = response.unwrap();
    writeln("Status: ", result.status.code);
    writeln("Exit code: ", result.result.exitCode);
    writeln("Cached: ", result.cachedResult);
    writeln("Worker: ", result.result.executionMetadata.worker);
}
```

### Cloud Provider Integration

```d
// AWS EC2
auto awsConfig = AwsEc2Config(
    region: "us-east-1",
    instanceType: "c5.2xlarge",
    imageId: "ami-builder-worker-v1",
    keyName: "builder-ssh-key",
    securityGroups: ["sg-builder-workers"],
    tags: ["Environment": "production", "Service": "builder"]
);

auto awsProvider = new AwsEc2Provider(awsConfig);

// Kubernetes
auto k8sConfig = KubernetesConfig(
    namespace: "builder",
    podTemplate: "worker-pod.yaml",
    serviceAccount: "builder-worker",
    resources: ResourceRequirements(
        cpuRequest: "2000m",
        cpuLimit: "4000m",
        memoryRequest: "4Gi",
        memoryLimit: "8Gi"
    )
);

auto k8sProvider = new KubernetesProvider(k8sConfig);

// Use with pool (configure before start)
poolConfig.cloudProvider = awsProvider;
```

## Performance Characteristics

### Startup Latency

| System | Cold Start | Warm Start |
|--------|-----------|------------|
| Builder (native) | <100ms | <50ms |
| Bazel (Docker) | 1-5s | 500ms-2s |
| BuildGrid (Docker) | 2-10s | 1-3s |

### Execution Overhead

| Operation | Builder | Docker-based |
|-----------|---------|--------------|
| Sandbox setup | 5ms | 50-200ms |
| Process spawn | 2ms | 20-50ms |
| Resource monitoring | <1ms | 5-10ms |
| Cleanup | 10ms | 100-500ms |

### Scalability

- **Workers**: Tested with 1000+ concurrent workers
- **Actions/sec**: 10,000+ (with caching)
- **Cache hit speedup**: 100-1000x
- **Network overhead**: <5% (SIMD-optimized transfers)

## Autoscaling Deep Dive

### Prediction Algorithm

The autoscaler uses exponential smoothing to predict future load:

```
St = α × Xt + (1-α) × St-1

Where:
- St = smoothed value at time t
- Xt = observed value at time t
- α = smoothing factor (0.3 default)
```

**Trend Detection:**

Linear regression over recent samples:

```
β = (n∑xy - ∑x∑y) / (n∑x² - (∑x)²)

β > 0 → increasing load → scale up faster
β < 0 → decreasing load → scale down cautiously
```

### Scaling Decision Logic

```d
if (predictedUtil > scaleUpThreshold || trend > 0.1) {
    // Aggressive scale-up
    factor = (predictedUtil - threshold) / (1 - threshold);
    trendMultiplier = 1 + trend * 2;
    increment = max(1, currentWorkers × factor × trendMultiplier);
    desired = currentWorkers + increment;
}
else if (predictedUtil < scaleDownThreshold && trend < -0.05) {
    // Conservative scale-down
    factor = (threshold - predictedUtil) / threshold;
    decrement = max(1, currentWorkers × factor × 0.5);
    desired = max(minWorkers, currentWorkers - decrement);
}

// Apply cooldown
if (scaling && timeSinceLastScale < cooldown) {
    return currentWorkers;  // Skip
}

// Clamp to bounds
desired = clamp(desired, minWorkers, maxWorkers);
```

### Hysteresis

Prevents scaling oscillation:

- **Scale-up cooldown**: 30 seconds (default)
- **Scale-down cooldown**: 2 minutes (default)
- Different thresholds for up/down (75% vs 25%)

## Comparison with Container-Based Systems

### Why Not Docker?

**Builder's Approach (Native OS Sandboxing):**

✅ Zero daemon overhead  
✅ <100ms startup  
✅ Precise resource limits (cgroups v2)  
✅ Multi-platform (Linux/macOS/Windows)  
✅ No image management complexity  
✅ Better security (kernel-level isolation)  

**Docker/Container Approach:**

❌ Docker daemon required  
❌ 1-5s startup (image pull)  
❌ Container runtime overhead  
❌ Image layer complexity  
❌ Linux-focused (Docker Desktop on macOS/Windows)  
❌ Additional attack surface  

### When Containers Make Sense

Use containers when:
- Workers need different OS versions
- Complex dependency management
- Legacy build systems requiring specific environments
- Compliance requirements mandate container isolation

Builder supports optional OCI container execution via the hermetic system - but it's not the default or recommended approach.

## Monitoring and Observability

### Metrics

The service exposes comprehensive metrics:

```d
struct ServiceMetrics {
    // Execution
    size_t totalExecutions;
    size_t successfulExecutions;
    size_t failedExecutions;
    size_t cachedExecutions;
    
    // Workers
    size_t activeWorkers;
    size_t idleWorkers;
    size_t busyWorkers;
    
    // Queue
    size_t queueDepth;
    float avgUtilization;
}
```

### Health Checks

Automatic health monitoring detects:
- Worker failures (heartbeat timeout)
- Network partitions
- Resource exhaustion
- Queue buildup

### Logging

Structured logging at multiple levels:
- **INFO**: Service lifecycle, scaling events
- **DEBUG**: Action scheduling, worker selection
- **WARNING**: Health issues, retries
- **ERROR**: Failures, exceptions

## Best Practices

### 1. Right-Size Your Pool

```d
// For CI workloads (bursty)
poolConfig.minWorkers = 2;
poolConfig.maxWorkers = 100;
poolConfig.targetWorkers = 10;

// For continuous builds (steady)
poolConfig.minWorkers = 10;
poolConfig.maxWorkers = 50;
poolConfig.targetWorkers = 25;
```

### 2. Tune Autoscaling

```d
// Aggressive (rapid response)
poolConfig.scaleUpThreshold = 0.7;
poolConfig.scaleUpCooldown = 15.seconds;

// Conservative (cost-optimized)
poolConfig.scaleUpThreshold = 0.85;
poolConfig.scaleUpCooldown = 60.seconds;
poolConfig.scaleDownCooldown = 5.minutes;
```

### 3. Optimize Hermetic Specs

```d
// Minimize inputs (faster upload)
spec.input("/workspace/src");  // Specific
// NOT: spec.input("/workspace");  // Too broad

// Declare outputs explicitly
spec.output("/workspace/build/main");
spec.output("/workspace/build/main.o");

// Set realistic resource limits
spec.maxMemory(2.GiB);  // Tight
spec.maxCpu(2);
// NOT: spec.maxMemory(32.GiB);  // Wasteful
```

### 4. Enable Caching

```d
executorConfig.enableCaching = true;
executorConfig.enableCompression = true;  // Zstd

// Cache hits save 100-1000x time
```

## Troubleshooting

### Workers Not Scaling

**Check:**
- Cloud provider credentials
- Worker launch timeout (increase if slow)
- Logs for provisioning errors

**Fix:**
```d
poolConfig.workerStartTimeout = 5.minutes;  // Increase
```

### High Queue Depth

**Cause:** Not enough workers or actions too slow

**Fix:**
```d
// Increase max workers
poolConfig.maxWorkers = 200;

// Lower scale-up threshold
poolConfig.scaleUpThreshold = 0.65;

// Check action timeout
spec.timeout(10.minutes);  // Increase if needed
```

### Cache Misses

**Cause:** Non-hermetic builds (filesystem pollution)

**Fix:**
- Review hermetic spec inputs/outputs
- Check for hidden dependencies
- Use audit mode: `spec.enableAudit(true)`

## Future Enhancements

- [ ] Spot instance support (AWS/GCP)
- [ ] Multi-region workers
- [ ] GPU worker support
- [ ] WebAssembly workers (browser-based)
- [ ] P2P artifact transfer
- [ ] ML-based autoscaling (LSTM prediction)

## See Also

- [Hermetic Builds](hermetic.md) - Native sandboxing system
- [Remote Caching](remotecache.md) - Artifact store
- [Distributed Coordination](distributed.md) - Worker coordination
- [Work Stealing](workstealing.md) - P2P load balancing

