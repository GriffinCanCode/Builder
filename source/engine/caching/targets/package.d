module engine.caching.targets;

/// Target-level caching for build outputs
/// 
/// This module provides the core build cache that operates at the target level.
/// Each target's outputs are cached based on the hash of its sources and
/// dependencies, enabling fast incremental builds.
/// 
/// Key Features:
/// - Target-level caching with dependency tracking
/// - Two-tier hashing (metadata + content) for fast validation
/// - SIMD-accelerated hash comparisons
/// - LRU eviction policy
/// - Binary serialization (5-10x faster than JSON)
/// - BLAKE3-based integrity signatures
/// - Automatic expiration (30 days default)
/// 
/// Usage:
/// ```d
/// auto cache = new BuildCache(".builder-cache");
/// 
/// if (!cache.isCached(targetId, sources, deps)) {
///     // Build target
///     cache.update(targetId, sources, deps, outputHash);
/// }
/// 
/// cache.flush(); // Write to disk
/// cache.close(); // Explicitly close before exit
/// ```

public import engine.caching.targets.cache;
public import engine.caching.targets.storage;
public import engine.caching.targets.schema;

