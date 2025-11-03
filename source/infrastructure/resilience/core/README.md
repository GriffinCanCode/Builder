# Core Resilience Components

This module provides the fundamental building blocks for resilience patterns in distributed systems.

## Components

### CircuitBreaker (`breaker.d`)

Implements the circuit breaker pattern to prevent cascading failures by detecting unhealthy services and temporarily blocking requests.

**Key Features:**
- Three-state machine: CLOSED (normal) → OPEN (failing) → HALF_OPEN (testing)
- Rolling window failure tracking for accurate metrics
- Configurable failure thresholds and timeouts
- Automatic recovery testing
- Per-endpoint isolation
- Network error filtering

**Configuration:**
```d
struct BreakerConfig
{
    float failureThreshold = 0.5;        // 50% failure rate opens circuit
    size_t minRequests = 10;             // Min requests before considering rate
    Duration windowSize = 30.seconds;    // Rolling window for tracking
    Duration timeout = 60.seconds;       // Time before testing recovery
    size_t halfOpenMaxRequests = 3;      // Test requests in HALF_OPEN
    float successThreshold = 0.8;        // 80% success to close circuit
    bool onlyCountNetworkErrors = true;  // Filter error types
}
```

**Usage:**
```d
auto breaker = new CircuitBreaker("my-service", config);

auto result = breaker.execute!Data(() {
    return Ok!Data(fetchFromService());
});
```

### RateLimiter (`limiter.d`)

Implements token bucket rate limiting with priority support and adaptive control.

**Key Features:**
- Token bucket algorithm with burst capacity
- Priority-based request handling
- Adaptive rate adjustment based on service health
- Wait-with-timeout support
- Comprehensive metrics tracking

**Configuration:**
```d
struct LimiterConfig
{
    size_t ratePerSecond = 100;       // Base rate limit
    size_t burstCapacity = 200;       // Max burst tokens
    bool adaptive = true;             // Enable adaptive control
    float minRate = 0.1;              // Min rate when throttled (10%)
    float maxRate = 1.5;              // Max rate when healthy (150%)
    float adjustmentSpeed = 0.05;     // Rate of adaptation
    ubyte priorityThreshold = 200;    // Priority bypass threshold
}
```

**Usage:**
```d
auto limiter = new RateLimiter("my-service", config);

// Acquire permission
auto result = limiter.acquire(Priority.Normal, 5.seconds);
if (result.isOk)
{
    // Execute operation
}

// Or use execute wrapper
auto result = limiter.execute!Data(
    () => Ok!Data(operation()),
    Priority.High,
    10.seconds
);
```

### Alternative: SlidingWindowLimiter

A more accurate but higher-overhead rate limiter using sliding windows instead of token buckets. Useful when you need exact rate guarantees rather than burst tolerance.

## Priority System

Both components support a priority system:

```d
enum Priority : ubyte
{
    Low = 0,
    Normal = 100,
    High = 200,
    Critical = 255
}
```

High-priority requests can bypass certain limits and get preferential treatment.

## Metrics

Both components provide comprehensive metrics:

**CircuitBreaker:**
- Current state (CLOSED/OPEN/HALF_OPEN)
- Total requests and failures
- Failure rate
- State change events

**RateLimiter:**
- Total, accepted, and rejected requests
- Current effective rate
- Average wait time
- High-priority acceptance rate

## Thread Safety

Both components are fully thread-safe:
- Atomic operations for state
- Mutex protection for metrics
- Safe for concurrent access from multiple threads

## Examples

### Standalone Circuit Breaker

```d
import infrastructure.resilience.core.breaker;

auto config = BreakerConfig.init;
config.failureThreshold = 0.3;  // Open at 30% failure rate
config.timeout = 45.seconds;

auto breaker = new CircuitBreaker("critical-service", config);

// Register state change callback
breaker.onStateChange = (BreakerEvent event) {
    logger.warn("Circuit " ~ event.endpoint ~ " changed to " ~ event.newState.to!string);
};

// Execute operations
foreach (i; 0..100)
{
    auto result = breaker.execute!string(() {
        return callExternalService();
    });
    
    if (result.isErr)
        handleError(result.unwrapErr());
}
```

### Standalone Rate Limiter

```d
import infrastructure.resilience.core.limiter;

auto config = LimiterConfig.init;
config.ratePerSecond = 50;
config.burstCapacity = 100;

auto limiter = new RateLimiter("api-endpoint", config);

// Register rate limit callback
limiter.onRateLimitHit = (string endpoint, Priority priority) {
    logger.debug("Rate limited: " ~ endpoint);
};

// Execute with rate limiting
auto result = limiter.execute!Response(
    () => makeApiCall(),
    Priority.Normal,
    10.seconds
);
```

### Adaptive Rate Control

```d
// Adjust rate based on service health
float healthScore = monitorService();  // 0.0 - 1.0

limiter.adjustRate(healthScore);
// When health = 1.0: rate = maxRate * ratePerSecond
// When health = 0.0: rate = minRate * ratePerSecond
// Linear interpolation in between
```

## Design Considerations

### When to Use CircuitBreaker

- Protecting against cascading failures
- Dealing with external services that may fail
- Need automatic recovery detection
- Want to fail fast when service is known to be down

### When to Use RateLimiter

- Preventing resource exhaustion
- Controlling throughput to protect services
- Need burst capacity for batching
- Want priority-based request handling

### When to Use Both

Most production systems benefit from using both patterns together. The `coordination` module provides `NetworkResilience` which combines both patterns with automatic coordination.

