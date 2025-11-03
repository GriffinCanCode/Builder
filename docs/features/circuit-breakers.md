# Circuit Breakers and Rate Limiting

Production-grade resilience mechanisms for Builder's distributed system.

## Overview

Builder includes sophisticated circuit breakers and rate limiting to prevent cascading failures and resource exhaustion in distributed builds. These mechanisms are transparently integrated at the highest levels of the system.

## Key Concepts

### Circuit Breakers

Circuit breakers prevent cascading failures by detecting unhealthy services and temporarily blocking requests:

```
        failure rate
            high
             ↓
    ┌────────────┐
    │   CLOSED   │ ← normal operation
    │ (allowing) │
    └─────┬──────┘
          │ failures exceed threshold
          ↓
    ┌────────────┐
    │    OPEN    │ ← failing, reject requests
    │ (blocking) │
    └─────┬──────┘
          │ timeout elapsed
          ↓
    ┌────────────┐
    │ HALF_OPEN  │ ← testing recovery
    │  (testing) │
    └─────┬──────┘
          │ recovery confirmed
          └───→ back to CLOSED
```

**When circuit is OPEN**:
- Requests fail immediately (no network call)
- Service gets time to recover
- Prevents request pile-up

**When circuit is HALF_OPEN**:
- Limited test requests allowed
- If successful: circuit closes
- If failed: circuit reopens

### Rate Limiting

Rate limiters control request throughput using token bucket algorithm:

```
Token Bucket:
┌─────────────────┐
│ ●●●●●●●○○○      │ ← tokens (● = available, ○ = used)
│                 │
│ refill rate:    │
│ 100 tokens/sec  │
│                 │
│ burst capacity: │
│ 200 tokens max  │
└─────────────────┘

Request arrives → consume 1 token
No tokens? → wait or reject
```

**Adaptive Control**:
- Rate adjusts based on service health
- Healthy service: increase rate
- Unhealthy service: decrease rate
- Prevents overwhelming struggling services

## Architecture

```
Application Layer
    ↓ (uses)
ResilientTransport/Executor (integration wrappers)
    ↓ (coordinates)
ResilienceService
    ├── CircuitBreaker (per endpoint)
    │   ├── RollingWindow (tracks failures)
    │   └── StateMachine (CLOSED/OPEN/HALF_OPEN)
    └── RateLimiter (per endpoint)
        ├── TokenBucket (rate control)
        └── AdaptiveController (health-based)
```

### Per-Endpoint Isolation

Each remote endpoint gets its own circuit breaker and rate limiter:

```
cache-server-1:
  Circuit: CLOSED
  Rate: 100 rps

cache-server-2:
  Circuit: OPEN  ← isolated failure
  Rate: 20 rps (throttled)

coordinator:
  Circuit: CLOSED
  Rate: 500 rps
```

Failure in one service doesn't affect others.

## Integration

### Remote Cache

Remote cache operations are automatically protected:

```d
// Before: direct transport
auto transport = new HttpTransport(config);
auto result = transport.get(key);

// After: resilient transport
auto resilience = new ResilienceService(PolicyPresets.network());
auto transport = new ResilientCacheTransport(config, resilience);
auto result = transport.get(key);  // Same API!
```

Benefits:
- GET requests: normal priority
- PUT requests: low priority (don't block reads)
- HEAD requests: high priority (lightweight)
- Automatic retry with backoff
- Circuit breaking on sustained failures

### Distributed Protocol

Worker communication is protected:

```d
auto transportResult = ResilientTransportFactory.create(
    workerUrl,
    resilience
);
auto transport = transportResult.unwrap();

// Protected operations
transport.sendHeartBeat(workerId, heartbeat);      // High priority
transport.sendStealRequest(victimId, request);      // Normal priority
transport.sendStealResponse(thiefId, response);     // High priority
```

Benefits:
- Prevents overwhelming busy workers
- Fast failure detection (no timeout waiting)
- Graceful degradation under load
- Priority-based queuing

### Remote Execution

Action execution is protected:

```d
auto executor = new RemoteExecutor(config);
auto resilientExecutor = new ResilientRemoteExecutor(
    executor,
    coordinatorUrl,
    resilience
);

// Execute with protection
auto result = resilientExecutor.execute(
    actionId,
    spec,
    command,
    workDir
);
```

Benefits:
- Prevents coordinator overload
- Fast failure when coordinator down
- Automatic rate adjustment
- Per-action priority support

## Policy Presets

### Critical Services

```d
auto policy = PolicyPresets.critical();
```

For: Authentication, configuration, critical infrastructure

Settings:
- Failure threshold: 30%
- Min requests: 5
- Window: 15 seconds
- Rate: 50 rps (burst: 75)

Behavior: Fail fast, low tolerance, conservative limits

### Standard Services

```d
auto policy = PolicyPresets.standard();
```

For: General services, most use cases

Settings:
- Failure threshold: 50%
- Min requests: 10
- Window: 30 seconds
- Rate: 100 rps (burst: 200)

Behavior: Balanced protection and throughput

### Network Services

```d
auto policy = PolicyPresets.network();
```

For: Remote cache, artifact stores, external services

Settings:
- Failure threshold: 40%
- Only network errors count
- Window: 20 seconds
- Rate: 150 rps (burst: 300)

Behavior: Tolerant of transient network issues, burst-friendly

### High Throughput

```d
auto policy = PolicyPresets.highThroughput();
```

For: Worker coordination, internal high-traffic services

Settings:
- Failure threshold: 60%
- Min requests: 15
- Window: 45 seconds
- Rate: 500 rps (burst: 1000)

Behavior: High capacity, tolerant of brief spikes

### Relaxed

```d
auto policy = PolicyPresets.relaxed();
```

For: Monitoring, telemetry, best-effort services

Settings:
- Failure threshold: 70%
- Min requests: 20
- Window: 60 seconds
- Rate: 200 rps (burst: 500)

Behavior: Very tolerant, high limits

## Custom Policies

Build policies from scratch:

```d
auto policy = PolicyBuilder.create()
    .withBreakerThreshold(0.35)      // Open at 35% failures
    .withBreakerWindow(25.seconds)   // Track last 25 seconds
    .withBreakerTimeout(45.seconds)  // Retest after 45 seconds
    .withRateLimit(175)              // 175 rps
    .withBurstCapacity(350)          // Burst to 350
    .adaptive(true)                  // Enable adaptive rate
    .build();

resilience.registerEndpoint("my-service", policy);
```

## Adaptive Rate Control

Rate automatically adjusts based on health:

```d
// Health monitoring callback
healthMonitor.onUpdate = (endpoint, health) {
    // health: 0.0 (unhealthy) to 1.0 (healthy)
    resilience.adjustRate(endpoint, health.score);
};
```

Effect:
- Health 1.0 → 150% of nominal rate (150 rps → 225 rps)
- Health 0.5 → 80% of nominal rate (150 rps → 120 rps)
- Health 0.0 → 10% of nominal rate (150 rps → 15 rps)

**Automatic adjustment from circuit breaker state**:
- Circuit CLOSED → 100% rate
- Circuit HALF_OPEN → 50% rate
- Circuit OPEN → 20% rate

## Priority Queuing

Requests can bypass rate limits based on priority:

```d
// Low priority - queued normally
auto result1 = resilience.execute!Data(
    endpoint,
    () => operation(),
    Priority.Low,
    timeout
);

// High priority - bypasses queue when tokens available
auto result2 = resilience.execute!Data(
    endpoint,
    () => criticalOperation(),
    Priority.High,
    timeout
);

// Critical priority - highest preference
auto result3 = resilience.execute!Data(
    endpoint,
    () => emergencyOperation(),
    Priority.Critical,
    timeout
);
```

Priority levels:
- `Priority.Low` (0) - Best effort, queued last
- `Priority.Normal` (100) - Standard operations
- `Priority.High` (200) - Important operations, bypass queue
- `Priority.Critical` (255) - Emergency operations, highest preference

## Monitoring

### Get Statistics

```d
// Per-endpoint stats
auto stats = resilience.getAllStats();

foreach (stat; stats)
{
    writeln("Endpoint: ", stat.endpoint);
    writeln("  Circuit: ", stat.breakerState);
    writeln("  Requests: ", stat.totalRequests);
    writeln("  Failures: ", stat.failures);
    writeln("  Failure rate: ", stat.failureRate * 100, "%");
    
    auto limiter = stat.limiterMetrics;
    writeln("  Rate limit:");
    writeln("    Accepted: ", limiter.accepted);
    writeln("    Rejected: ", limiter.rejected);
    writeln("    Accept rate: ", limiter.acceptanceRate() * 100, "%");
    writeln("    Current rate: ", limiter.currentRate, " rps");
}
```

### Event Callbacks

```d
// Register callbacks
resilience.onMetricsUpdate = (endpoint, state, metrics) {
    if (state == BreakerState.Open)
    {
        Logger.error("Circuit opened: " ~ endpoint);
        alerting.notify("Service failure: " ~ endpoint);
    }
    
    if (metrics.rejectionRate() > 0.1)
    {
        Logger.warn("High rejection rate for " ~ endpoint);
    }
};
```

### Metrics Export

```d
// Export to Prometheus/Grafana
void exportMetrics(ResilienceService resilience)
{
    auto stats = resilience.getAllStats();
    
    foreach (stat; stats)
    {
        metrics.gauge("circuit_breaker_state",
            stat.breakerState.to!int,
            ["endpoint": stat.endpoint]
        );
        
        metrics.gauge("failure_rate",
            stat.failureRate,
            ["endpoint": stat.endpoint]
        );
        
        metrics.counter("rate_limit_rejections",
            stat.limiterMetrics.rejected,
            ["endpoint": stat.endpoint]
        );
    }
}
```

## Configuration

### Environment Variables

```bash
# Enable strict resilience for production
export BUILDER_STRICT_RESILIENCE=1

# Relax resilience for development
export BUILDER_RELAXED_RESILIENCE=1

# Disable resilience for debugging
export BUILDER_DISABLE_RESILIENCE=1
```

### Configuration File

```yaml
# .builderconfig
resilience:
  enabled: true
  default_policy: standard
  
  endpoints:
    cache-server:
      policy: network
      rate_limit: 200
      burst: 400
      
    coordinator:
      policy: high_throughput
      circuit_breaker:
        threshold: 0.4
        window: 30s
        timeout: 60s
```

## Performance

### Overhead

Per-request overhead:
- Circuit breaker check: ~50ns
- Rate limiter check: ~100ns
- Rolling window update: ~200ns
- **Total: ~350ns**

For typical network calls (1-100ms), this is **0.035% - 0.0035% overhead**.

### Memory

Per endpoint:
- Circuit breaker: ~2KB (rolling window)
- Rate limiter: ~1KB (token bucket + metrics)
- **Total: ~3KB per endpoint**

For 100 endpoints: ~300KB

## Troubleshooting

### Circuit keeps opening

**Symptoms**:
- Circuit frequently transitions CLOSED → OPEN
- Many failed requests

**Diagnosis**:
```d
size_t total, failures;
float rate;
resilience.getBreakerStatistics(endpoint, total, failures, rate);

writeln("Total requests: ", total);
writeln("Failures: ", failures);
writeln("Failure rate: ", rate * 100, "%");
```

**Solutions**:
1. Check service health (is it actually failing?)
2. Increase failure threshold if false positives
3. Increase minimum requests to reduce noise
4. Increase window size for smoother tracking

### Rate limiting too aggressive

**Symptoms**:
- High rejection rate
- Slow builds due to queuing

**Diagnosis**:
```d
auto metrics = resilience.getLimiterMetrics(endpoint);

writeln("Accepted: ", metrics.accepted);
writeln("Rejected: ", metrics.rejected);
writeln("Current rate: ", metrics.currentRate);
writeln("Avg wait: ", metrics.avgWaitTimeMs, "ms");
```

**Solutions**:
1. Increase rate per second
2. Increase burst capacity
3. Check health scores (may be throttled)
4. Use priority for critical requests

### Memory growing

**Symptoms**:
- Gradual memory increase over time

**Diagnosis**:
```d
auto stats = resilience.getAllStats();
writeln("Total endpoints: ", stats.length);
```

**Solutions**:
1. Unregister unused endpoints
2. Reduce rolling window size
3. Periodically reset metrics:
   ```d
   resilience.resetStats(endpoint);
   ```

## Best Practices

### 1. Use Shared ResilienceService

Create one service instance, share across transports:

```d
// Good
auto resilience = new ResilienceService();
auto cache = new ResilientCacheTransport(cacheConfig, resilience);
auto executor = new ResilientRemoteExecutor(exec, url, resilience);

// Bad - creates duplicate circuit breakers
auto cache = new ResilientCacheTransport(cacheConfig, null);
auto executor = new ResilientRemoteExecutor(exec, url, null);
```

### 2. Choose Appropriate Policies

Match policy to service characteristics:

- External services → `network`
- Critical path → `critical`
- High traffic → `highThroughput`
- Best effort → `relaxed`

### 3. Monitor and Adjust

Start conservative, relax based on observations:

```d
// Start strict
resilience.registerEndpoint("new-service", PolicyPresets.critical());

// Monitor for false positives
// Adjust if needed
resilience.registerEndpoint("new-service", PolicyPresets.standard());
```

### 4. Use Priority Wisely

Reserve `Critical` for true emergencies:

```d
// Good
auto heartbeat = resilience.execute!Data(
    endpoint,
    () => sendHeartbeat(),
    Priority.High,      // Important but not critical
    timeout
);

// Bad - everything critical defeats the purpose
auto request = resilience.execute!Data(
    endpoint,
    () => normalRequest(),
    Priority.Critical,  // Overuse
    timeout
);
```

### 5. Integrate with Health Monitoring

Connect resilience to health system:

```d
// Update rate based on actual service health
healthMonitor.subscribe((endpoint, health) {
    resilience.adjustRate(endpoint, health.score);
});
```

## See Also

- [Distributed Builds](distributed.md)
- [Remote Execution](remote-execution.md)
- [Remote Cache](remotecache.md)
- [Health Monitoring](health.md)
- [Observability](observability.md)

