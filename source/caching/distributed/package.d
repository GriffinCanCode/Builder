module caching.distributed;

/// Distributed caching across teams and CI/CD
/// 
/// This module coordinates local and remote cache tiers to enable
/// distributed builds across teams and CI/CD pipelines. It provides
/// transparent fallback from local to remote cache, with automatic
/// artifact pulling and pushing.
/// 
/// Key Features:
/// - Two-tier caching (local + remote)
/// - Automatic pull from remote on local miss
/// - Asynchronous push to remote on local update
/// - HTTP/1.1 transport (no external dependencies)
/// - Content-addressable storage
/// - Workspace isolation via HMAC signatures
/// - Connection pooling and retry logic
/// 
/// Architecture:
/// - Read: Local first, then remote (pull on miss)
/// - Write: Local immediately, remote async (push in background)
/// - Transparency: Build handlers don't need to know about distribution
/// 
/// Usage:
/// ```d
/// auto remoteConfig = RemoteCacheConfig.fromEnvironment();
/// auto remoteClient = new RemoteCacheClient(remoteConfig);
/// auto distCache = new DistributedCache(localCache, actionCache, remoteClient, cacheDir);
/// 
/// if (!distCache.isCached(targetId, sources, deps)) {
///     // Build target
///     distCache.update(targetId, sources, deps, outputHash);
/// }
/// ```

public import caching.distributed.coordinator;
public import caching.distributed.remote;

