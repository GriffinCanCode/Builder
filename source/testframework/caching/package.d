module testframework.caching;

/// Multi-level test result caching
/// 
/// Provides intelligent test caching with:
/// - Content-addressed storage (BLAKE3)
/// - Hermetic environment verification
/// - LRU eviction policy
/// - Binary serialization

public import testframework.caching.cache;
public import testframework.caching.storage;

