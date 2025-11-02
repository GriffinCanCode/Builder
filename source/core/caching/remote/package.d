module core.caching.remote;

/// Remote caching module
/// Provides distributed cache for build artifacts across teams and CI/CD
/// 
/// Architecture:
/// - Content-addressable storage (BLAKE3)
/// - HTTP/1.1 transport (no external dependencies)
/// - LRU eviction with configurable limits
/// - Workspace isolation via HMAC
/// - Connection pooling and retry logic
/// 
/// Usage:
/// ```d
/// // Client
/// auto config = RemoteCacheConfig.fromEnvironment();
/// auto client = new RemoteCacheClient(config);
/// auto result = client.get(contentHash);
/// 
/// // Server
/// auto server = new CacheServer("0.0.0.0", 8080);
/// server.start();
/// ```

public import core.caching.remote.protocol;
public import core.caching.remote.transport;
public import core.caching.remote.client;
public import core.caching.remote.server;


