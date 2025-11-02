module core.caching;

/// Builder caching system
/// 
/// This module provides a comprehensive multi-tier caching system for
/// build artifacts, actions, and remote distribution.
/// 
/// ## Architecture
/// 
/// The caching system is organized into four main components:
/// 
/// ### 1. Target-Level Caching (`core.caching.targets`)
/// Caches complete build outputs for each target based on source and
/// dependency hashes. This is the primary caching mechanism.
/// 
/// ### 2. Action-Level Caching (`core.caching.actions`)
/// Provides finer-grained caching for individual build actions (compile,
/// link, codegen, etc.). Enables partial rebuilds when only some actions fail.
/// 
/// ### 3. Cache Policies (`core.caching.policies`)
/// Manages cache eviction using LRU, age-based, and size-based strategies
/// to prevent unbounded growth.
/// 
/// ### 4. Distributed Caching (`core.caching.distributed`)
/// Coordinates local and remote cache tiers for team collaboration and
/// CI/CD pipelines. Provides transparent remote artifact sharing.
/// 
/// ## Usage
/// 
/// ### Basic Target Caching
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
/// cache.flush();  // Write to disk
/// cache.close();  // Clean shutdown
/// ```
/// 
/// ### Action-Level Caching
/// ```d
/// import core.caching;
/// 
/// auto actionCache = new ActionCache();
/// auto actionId = ActionId("target", ActionType.Compile, inputHash);
/// 
/// if (!actionCache.isCached(actionId, inputs, metadata)) {
///     // Perform action
///     actionCache.update(actionId, inputs, outputs, metadata, success);
/// }
/// ```
/// 
/// ### Distributed Caching
/// ```d
/// import core.caching;
/// 
/// auto remoteConfig = RemoteCacheConfig.fromEnvironment();
/// auto remoteClient = new RemoteCacheClient(remoteConfig);
/// auto distCache = new DistributedCache(
///     localCache, actionCache, remoteClient, ".builder-cache"
/// );
/// 
/// // Use like regular cache - remote is transparent
/// if (!distCache.isCached(targetId, sources, deps)) {
///     distCache.update(targetId, sources, deps, outputHash);
/// }
/// ```
/// 
/// ## Performance Features
/// 
/// - **SIMD-accelerated** hash comparisons (2-3x faster)
/// - **Two-tier hashing** (metadata + content) for 1000x speedup on unchanged files
/// - **Binary serialization** (5-10x faster than JSON, 30% smaller)
/// - **Lock-free hash caching** for per-session memoization
/// - **Parallel hashing** with work-stealing for large source sets
/// - **Connection pooling** for remote cache operations
/// 
/// ## Security Features
/// 
/// - **BLAKE3-based HMAC** signatures prevent cache tampering
/// - **Workspace isolation** via workspace-specific keys
/// - **Automatic expiration** (30 days default)
/// - **Constant-time verification** to prevent timing attacks
/// 
/// ## Configuration
/// 
/// Cache behavior can be configured via environment variables:
/// 
/// ```bash
/// # Target cache
/// export BUILDER_CACHE_MAX_SIZE=1073741824      # 1 GB
/// export BUILDER_CACHE_MAX_ENTRIES=10000         # 10k entries
/// export BUILDER_CACHE_MAX_AGE_DAYS=30           # 30 days
/// 
/// # Action cache
/// export BUILDER_ACTION_CACHE_MAX_SIZE=1073741824
/// export BUILDER_ACTION_CACHE_MAX_ENTRIES=50000
/// export BUILDER_ACTION_CACHE_MAX_AGE_DAYS=30
/// 
/// # Remote cache
/// export BUILDER_REMOTE_CACHE_URL=http://cache.example.com:8080
/// export BUILDER_REMOTE_CACHE_TIMEOUT=30
/// ```

public import core.caching.targets;
public import core.caching.actions;
public import core.caching.policies;
public import core.caching.distributed;

