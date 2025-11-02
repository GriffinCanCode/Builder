module caching;

/// Builder caching system
/// 
/// This module provides a comprehensive multi-tier caching system for
/// build artifacts, actions, and remote distribution.
/// 
/// ## Architecture
/// 
/// The caching system is organized into components:
/// 
/// ### 1. Coordinator (`caching.coordinator`)
/// Unified orchestration of all caching tiers with event emission,
/// garbage collection, and content-addressable storage.
/// 
/// ### 2. Target-Level Caching (`caching.targets`)
/// Caches complete build outputs for each target based on source and
/// dependency hashes. Primary caching mechanism.
/// 
/// ### 3. Action-Level Caching (`caching.actions`)
/// Finer-grained caching for individual build actions (compile,
/// link, codegen, etc.). Enables partial rebuilds.
/// 
/// ### 4. Cache Policies (`caching.policies`)
/// Manages cache eviction using LRU, age-based, and size-based strategies.
/// 
/// ### 5. Distributed Caching (`caching.distributed`)
/// Coordinates local and remote cache tiers for team collaboration.
/// 
/// ### 6. Storage (`caching.storage`)
/// Content-addressable storage with deduplication and garbage collection.
/// 
/// ### 7. Metrics (`caching.metrics`)
/// Real-time cache metrics collection and statistics.
/// 
/// ### 8. Events (`caching.events`)
/// Cache events for telemetry integration.
/// 
/// ## Usage
/// 
/// ### With Coordinator (Recommended)
/// ```d
/// import core.caching;
/// 
/// auto coordinator = new CacheCoordinator(".builder-cache", publisher);
/// 
/// if (!coordinator.isCached(targetId, sources, deps)) {
///     // Perform build
///     coordinator.update(targetId, sources, deps, outputHash);
/// }
/// 
/// coordinator.flush();
/// coordinator.close();
/// ```
/// 
/// ### Direct Cache Usage
/// ```d
/// import core.caching;
/// 
/// auto cache = new BuildCache();
/// 
/// if (!cache.isCached(targetId, sources, deps)) {
///     // Perform build
///     cache.update(targetId, sources, deps, outputHash);
/// }
/// 
/// cache.flush();
/// cache.close();
/// ```

// Coordinator (new unified interface)
public import caching.coordinator;

// Core caching components
public import caching.targets;
public import caching.actions;
public import caching.policies;
public import caching.distributed;

// Storage layer
public import caching.storage;

// Metrics and events
public import caching.metrics;
public import caching.events;
