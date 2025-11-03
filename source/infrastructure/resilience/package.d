module infrastructure.resilience;

/// Resilience Infrastructure
/// 
/// Provides circuit breakers and rate limiting for distributed system resilience.
/// 
/// ## Architecture
/// 
/// The resilience system combines two complementary patterns:
/// 
/// **Circuit Breakers**: Prevent cascading failures by detecting unhealthy services
/// and temporarily blocking requests. Uses a state machine (CLOSED → OPEN → HALF_OPEN)
/// with rolling windows for failure tracking.
/// 
/// **Rate Limiters**: Control request rate to prevent overwhelming services. Uses
/// token bucket algorithm with adaptive rate adjustment based on service health.
/// 
/// ## Usage
/// 
/// ### Quick Start
/// 
/// ```d
/// import infrastructure.resilience;
/// 
/// // Create network resilience coordinator with default policies
/// auto resilience = new NetworkResilience(PolicyPresets.standard());
/// 
/// // Register endpoint with custom policy
/// resilience.registerEndpoint(
///     "cache-server",
///     PolicyPresets.network()
/// );
/// 
/// // Execute operation with resilience
/// auto result = resilience.execute!bool(
///     "cache-server",
///     () => remoteCache.get(key),
///     Priority.High,
///     10.seconds
/// );
/// ```
/// 
/// ### Policy Presets
/// 
/// - `PolicyPresets.critical()` - Strict limits for critical services
/// - `PolicyPresets.standard()` - Balanced for normal services  
/// - `PolicyPresets.relaxed()` - Tolerant for best-effort services
/// - `PolicyPresets.network()` - Optimized for remote cache/distributed
/// - `PolicyPresets.highThroughput()` - High capacity for worker communication
/// 
/// ### Custom Policies
/// 
/// ```d
/// auto policy = PolicyBuilder.create()
///     .withBreakerThreshold(0.4)
///     .withRateLimit(150)
///     .withBurstCapacity(300)
///     .adaptive(true)
///     .build();
/// 
/// resilience.registerEndpoint("custom-service", policy);
/// ```
/// 
/// ### Adaptive Rate Control
/// 
/// Rate limiters automatically adjust based on circuit breaker state:
/// 
/// - Circuit OPEN: Reduce to 20% of normal rate
/// - Circuit HALF_OPEN: Reduce to 50% of normal rate  
/// - Circuit CLOSED: Restore to 100%
/// 
/// Manual adjustment based on external health metrics:
/// 
/// ```d
/// resilience.adjustRate("service", healthScore); // 0.0 - 1.0
/// ```
/// 
/// ## Integration
/// 
/// Designed to wrap transport layers at the highest level:
/// 
/// - Remote cache HTTP transport
/// - Distributed protocol transport
/// - Remote execution client
/// - Worker-to-coordinator communication
/// 
/// See individual integration modules for details.

public import infrastructure.resilience.breaker;
public import infrastructure.resilience.limiter;
public import infrastructure.resilience.policy;
public import infrastructure.resilience.network;

