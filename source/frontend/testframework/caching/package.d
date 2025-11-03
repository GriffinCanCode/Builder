module frontend.testframework.caching;

/// Multi-level test result caching
/// 
/// Provides intelligent test caching with:
/// - Content-addressed storage (BLAKE3)
/// - Hermetic environment verification
/// - LRU eviction policy
/// - Binary serialization

public import frontend.testframework.caching.cache;
public import frontend.testframework.caching.storage;

