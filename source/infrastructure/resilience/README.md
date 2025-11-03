# Resilience Infrastructure

Production-grade circuit breakers and rate limiting for distributed system resilience.

## Overview

This module provides comprehensive resilience mechanisms to prevent cascading failures and resource exhaustion in distributed build systems. It combines two complementary patterns with a modular architecture.

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

## Module Organization

```
infrastructure.resilience/
├── core/                   # Fundamental resilience components
│   ├── breaker.d          # Circuit breaker implementation
│   ├── limiter.d          # Rate limiter implementation
│   └── package.d          # Core barrel exports
├── policies/              # Configuration and policy management
│   ├── policy.d           # Policy presets and builder
│   └── package.d          # Policy barrel exports
├── coordination/          # High-level orchestration
│   ├── network.d          # NetworkResilience coordinator
│   └── package.d          # Coordination barrel exports
├── integrations/          # Pre-built integration wrappers
│   ├── cache.d            # Remote cache transport wrapper
│   ├── protocol.d         # Distributed protocol wrapper
│   ├── executor.d         # Remote executor wrapper
│   └── package.d          # Integration barrel exports
├── package.d              # Root barrel exports
└── README.md              # This file
```

## Architecture

```
NetworkResilience (coordination layer)
├── CircuitBreaker (per endpoint, from core)
│   ├── RollingWindow (failure tracking)
│   └── State Machine (CLOSED/OPEN/HALF_OPEN)
└── RateLimiter (per endpoint, from core)
    ├── Token Bucket (rate control)
    └── Adaptive Controller (health-based adjustment)
```

## Module Descriptions

### core/

The `core` module provides the fundamental building blocks:

- **breaker.d**: Circuit breaker implementation with rolling window tracking, state machine, and configurable thresholds
- **limiter.d**: Token bucket and sliding window rate limiters with priority support and adaptive control

These components can be used standalone for fine-grained control or composed through the coordination layer.

### policies/

The `policies` module provides configuration management:

- **policy.d**: ResiliencePolicy struct, PolicyPresets, and PolicyBuilder
- Preset policies for common scenarios (critical, standard, relaxed, network, highThroughput)
- Builder pattern for custom policy configuration

### coordination/

The `coordination` module provides high-level orchestration:

- **network.d**: NetworkResilience class that manages circuit breakers and rate limiters as a unified system
- Per-endpoint policy management
- Automatic adaptive rate adjustment based on circuit breaker state
- Comprehensive metrics aggregation and monitoring

### integrations/

The `integrations` module provides pre-built wrappers:

- **cache.d**: Remote cache HTTP transport wrapper
- **protocol.d**: Distributed protocol transport wrapper  
- **executor.d**: Remote executor wrapper

These wrappers integrate resilience at the highest levels for proper cascading behavior.

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

// Create network resilience coordinator
auto resilience = new NetworkResilience();

// Execute with automatic registration and default policy
auto result = resilience.execute!Data(
    "https://cache.example.com",
    () => transport.get(key),
    Priority.Normal,
    10.seconds
);
```

### Using Core Components Directly

```d
import infrastructure.resilience.core;

// Create standalone circuit breaker
auto breaker = new CircuitBreaker("my-service", BreakerConfig.init);
auto result = breaker.execute!Data(() => operation());

// Create standalone rate limiter
auto limiter = new RateLimiter("my-service", LimiterConfig.init);
auto acquireResult = limiter.acquire(Priority.Normal, 5.seconds);
if (acquireResult.isOk)
{
    // Proceed with operation
}
```

### Using Policies

```d
import infrastructure.resilience.policies;

// Use a preset policy
auto policy = PolicyPresets.network();
resilience.registerEndpoint("cache-server", policy);

// Build a custom policy
auto customPolicy = PolicyBuilder.fromPreset(PolicyPresets.network())
    .withBreakerThreshold(0.4)
    .withRateLimit(200)
    .adaptive(true)
    .build();

resilience.registerEndpoint("custom-service", customPolicy);
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

## Importing Specific Modules

You can import specific modules based on your needs:

```d
// Import everything (recommended for most use cases)
import infrastructure.resilience;

// Import only core components
import infrastructure.resilience.core;

// Import only policies
import infrastructure.resilience.policies;

// Import only coordination layer
import infrastructure.resilience.coordination;

// Import only integrations
import infrastructure.resilience.integrations;
```

## Design Principles

### Modularity

Each module has a single responsibility:
- `core` provides primitive resilience mechanisms
- `policies` provides configuration management
- `coordination` provides orchestration
- `integrations` provides ready-to-use wrappers

This allows you to use just what you need without unnecessary dependencies.

### Type Safety

- No `any` types - everything strongly typed
- Compile-time guarantees where possible
- Result types for error handling
- No exceptions for control flow

### Observable

- Comprehensive metrics collection
- Event callbacks for state changes
- Statistics for capacity planning
- Integration with telemetry system

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

