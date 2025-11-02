module caching.policies;

/// Cache eviction policies
/// 
/// This module provides cache eviction strategies to manage cache size
/// and prevent unbounded growth. The eviction policy uses a hybrid
/// approach combining LRU, age-based, and size-based eviction.
/// 
/// Key Features:
/// - LRU (Least Recently Used) eviction
/// - Age-based expiration (configurable max age)
/// - Size-based limits (max bytes and max entries)
/// - Hybrid strategy for optimal cache management
/// - Configurable via environment variables
/// 
/// Eviction Strategy:
/// 1. Remove entries older than maxAge
/// 2. Remove least recently used if count exceeds maxEntries
/// 3. Remove least recently used if size exceeds maxSize
/// 
/// Usage:
/// ```d
/// auto policy = EvictionPolicy(
///     maxSize: 1_073_741_824,    // 1 GB
///     maxEntries: 10_000,         // 10k entries
///     maxAge: 30                  // 30 days
/// );
/// 
/// auto currentSize = policy.calculateTotalSize(entries);
/// auto toEvict = policy.selectEvictions(entries, currentSize);
/// ```

public import caching.policies.eviction;

