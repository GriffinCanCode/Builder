module infrastructure.resilience.core;

/// Core Resilience Components
/// 
/// This module provides the fundamental building blocks for resilience:
/// - Circuit breakers to prevent cascading failures
/// - Rate limiters to control request throughput
/// 
/// These components can be used standalone or composed through
/// the coordination layer for comprehensive resilience.

public import infrastructure.resilience.core.breaker;
public import infrastructure.resilience.core.limiter;

