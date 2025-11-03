# Resilience Infrastructure

Production-grade circuit breakers and rate limiting for distributed system resilience.

## Overview

This module provides comprehensive resilience mechanisms to prevent cascading failures and resource exhaustion in distributed build systems. It combines two complementary patterns:

### Circuit Breakers

Automatically detect unhealthy services and prevent request floods using a state machine:

```
CLOSED (normal) → OPEN (failing) → HALF_OPEN (testing) → CLOSED
```

**Features:**
- Rolling window failure tracking (not simple counters)
- Adaptive thresholds based on historical data
- Per-endpoint isolation
- Health probes during recovery
- Configurable timeouts and windows

### Rate Limiters

Control request throughput using token bucket algorithm with adaptive features:

**Features:**
- Token bucket with burst capacity
- Sliding window for accurate tracking
- Priority queuing (high priority bypasses some limits)
- Adaptive rate adjustment based on service health
- Wait-with-timeout support

## Architecture

```
ResilienceService
├── CircuitBreaker (per endpoint)
│   ├── RollingWindow (failure tracking)
│   └── State Machine (CLOSED/OPEN/HALF_OPEN)
└── RateLimiter (per endpoint)
    ├── Token Bucket (rate control)
    └── Adaptive Controller (health-based adjustment)
```

## Integration Points

1. **Remote Cache Transport** (`engine.caching.distributed.remote.transport`)
   - Wraps HTTP operations
   - Network-optimized policy
   - Burst-friendly for batch operations

2. **Distributed Protocol Transport** (`engine.distributed.protocol.transport`)
   - Coordinator-worker communication
   - High-throughput policy
   - Priority for critical messages

3. **Remote Execution** (`engine.runtime.remote.executor`)
   - Action execution requests
   - Standard policy
   - Timeout coordination

4. **Worker Communication** (`engine.distributed.worker`)
   - Peer-to-peer stealing
   - Relaxed policy
   - Best-effort delivery

## Usage Examples

### Basic Usage

```d
import infrastructure.resilience;

auto resilience = new ResilienceService();

// Execute with automatic registration
auto result = resilience.execute!Data(
    "https://cache.example.com",
    () => transport.get(key),
    Priority.Normal,
    10.seconds
);
```

### Custom Policy

```d
auto policy = PolicyBuilder.fromPreset(PolicyPresets.network())
    .withBreakerThreshold(0.4)
    .withRateLimit(200)
    .adaptive(true)
    .build();

resilience.registerEndpoint("cache-server", policy);
```

### Priority Requests

```d
// Critical requests bypass rate limits when possible
auto result = resilience.execute!Data(
    endpoint,
    () => operation(),
    Priority.Critical,  // Bypass queue
    timeout
);
```

### Monitoring

```d
// Get statistics
auto stats = resilience.getAllStats();
foreach (stat; stats)
{
    writeln(stat.endpoint, ": ", stat.breakerState);
    writeln("  Failure rate: ", stat.failureRate);
    writeln("  Accept rate: ", stat.limiterMetrics.acceptanceRate());
}

// Register callback for metrics
resilience.onMetricsUpdate = (endpoint, state, metrics) {
    if (state == BreakerState.Open)
        alerting.notify("Circuit opened: " ~ endpoint);
};
```

### Health-Based Adaptation

```d
// Automatically adjust rate based on service health
float healthScore = monitorService(endpoint);  // 0.0 - 1.0
resilience.adjustRate(endpoint, healthScore);

// When health drops, rate automatically reduces
// When health recovers, rate gradually restores
```

## Policy Presets

### Critical
```d
PolicyPresets.critical()
```
- Failure threshold: 30%
- Min requests: 5
- Rate: 50 rps (burst: 75)
- Use for: Authentication, configuration services

### Standard
```d
PolicyPresets.standard()
```
- Failure threshold: 50%
- Min requests: 10
- Rate: 100 rps (burst: 200)
- Use for: General services

### Network
```d
PolicyPresets.network()
```
- Failure threshold: 40%
- Network errors only
- Rate: 150 rps (burst: 300)
- Use for: Remote cache, artifact stores

### High Throughput
```d
PolicyPresets.highThroughput()
```
- Failure threshold: 60%
- Min requests: 15
- Rate: 500 rps (burst: 1000)
- Use for: Worker coordination, internal services

### Relaxed
```d
PolicyPresets.relaxed()
```
- Failure threshold: 70%
- Min requests: 20
- Rate: 200 rps (burst: 500)
- Use for: Monitoring, telemetry, best-effort

## Design Principles

### 1. First-Principles Thinking

Rather than copying existing circuit breaker libraries, we designed from requirements:

- **Why circuit breakers?** Prevent cascading failures and give services time to recover
- **Why token bucket?** Allows controlled bursts while maintaining average rate
- **Why adaptive?** Service capacity varies with load; static limits are suboptimal
- **Why per-endpoint?** Failure in one service shouldn't affect others

### 2. Type Safety

- No `any` types - everything strongly typed
- Compile-time guarantees where possible
- Result types for error handling
- No exceptions for control flow

### 3. Observable

- Comprehensive metrics collection
- Event callbacks for state changes
- Statistics for capacity planning
- Integration with telemetry system

### 4. Testable

- Dependency injection support
- Manual state control for testing
- Deterministic jitter (reproducible tests)
- Clear separation of concerns

### 5. Thread-Safe

- Atomic operations for state
- Mutex protection for shared data
- Lock-free where possible
- Safe for concurrent access

## Performance

### Circuit Breaker Overhead

- State check: ~50ns (atomic load)
- Success path: ~200ns (rolling window update)
- Failure path: ~500ns (threshold calculation)

### Rate Limiter Overhead

- Token check: ~100ns (token refill + check)
- Acquire: ~150ns (success path)
- Wait: Variable (depends on rate and priority)

### Memory

- Per breaker: ~2KB (rolling window)
- Per limiter: ~1KB (token state + metrics)
- Shared service: ~8KB base

## Testing

```d
unittest
{
    auto service = new ResilienceService(PolicyPresets.standard());
    
    // Test circuit breaking
    foreach (i; 0..100)
    {
        auto result = service.execute!int(
            "test",
            () => Err!int(new NetworkError("Simulated failure")),
            Priority.Normal,
            1.seconds
        );
    }
    
    // Circuit should be open
    assert(service.getBreakerState("test") == BreakerState.Open);
    
    // Requests should be rejected
    auto rejected = service.execute!int(
        "test",
        () => Ok!int(42),
        Priority.Normal,
        1.seconds
    );
    
    assert(rejected.isErr);
}
```

## Future Enhancements

1. **Bulkhead Pattern**: Resource pool isolation
2. **Timeout Propagation**: Deadline-aware execution
3. **Fallback Chains**: Automatic failover to alternatives
4. **Distributed State**: Shared circuit breaker state across nodes
5. **ML-Based Prediction**: Predictive circuit breaking
6. **Quota Management**: Per-user/per-tenant limits

## References

- Netflix Hystrix: Circuit breaker pattern
- Google SRE Book: Handling overload
- Token Bucket Algorithm: RFC 2698
- GCRA (Generic Cell Rate Algorithm): ITU-T I.371

