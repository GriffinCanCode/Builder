module infrastructure.resilience.policies;

/// Resilience Policies
/// 
/// This module provides policy definitions and builders for configuring
/// circuit breakers and rate limiters. Includes preset policies for
/// common scenarios and a builder pattern for custom configurations.
/// 
/// ## Presets Available
/// - critical() - Strict limits for critical services
/// - standard() - Balanced for normal services
/// - relaxed() - Tolerant for best-effort services
/// - network() - Optimized for remote cache/distributed systems
/// - highThroughput() - High capacity for worker communication
/// - none() - Disable protections (testing/debugging)

public import infrastructure.resilience.policies.policy;

