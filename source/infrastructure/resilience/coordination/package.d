module infrastructure.resilience.coordination;

/// Resilience Coordination
/// 
/// This module provides high-level coordination of circuit breakers
/// and rate limiters across multiple endpoints. The NetworkResilience
/// class combines both patterns and manages them as a unified system.
/// 
/// Features:
/// - Per-endpoint isolation
/// - Automatic policy application
/// - Adaptive rate adjustment based on circuit breaker state
/// - Comprehensive metrics and monitoring
/// - Thread-safe concurrent access

public import infrastructure.resilience.coordination.network;

