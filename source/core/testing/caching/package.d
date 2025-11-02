module core.testing.caching;

/// Multi-level test result caching
/// 
/// Provides intelligent test caching with:
/// - Content-addressed storage (BLAKE3)
/// - Hermetic environment verification
/// - LRU eviction policy
/// - Binary serialization

public import core.testing.caching.cache;
public import core.testing.caching.storage;

