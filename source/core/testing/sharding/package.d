module core.testing.sharding;

/// Test sharding for parallel execution
/// 
/// Provides intelligent test distribution strategies:
/// - Content-based sharding (BLAKE3 consistent hashing)
/// - Adaptive sharding (historical execution time)
/// - Dynamic load balancing (work-stealing compatible)

public import core.testing.sharding.strategy;
public import core.testing.sharding.coordinator;

