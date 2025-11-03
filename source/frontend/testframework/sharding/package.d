module frontend.testframework.sharding;

/// Test sharding for parallel execution
/// 
/// Provides intelligent test distribution strategies:
/// - Content-based sharding (BLAKE3 consistent hashing)
/// - Adaptive sharding (historical execution time)
/// - Dynamic load balancing (work-stealing compatible)

public import frontend.testframework.sharding.strategy;
public import frontend.testframework.sharding.coordinator;

