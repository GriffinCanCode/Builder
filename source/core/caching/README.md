# Builder Caching System

High-performance multi-tier caching for incremental builds, distributed builds, and CI/CD optimization.

## Directory Structure

```
caching/
├── package.d              # Root module with overview
├── README.md              # This file
│
├── targets/               # Target-level caching
│   ├── package.d          # Target caching overview
│   ├── cache.d            # BuildCache implementation
│   └── storage.d          # Binary serialization for targets
│
├── actions/               # Action-level caching (fine-grained)
│   ├── package.d          # Action caching overview
│   ├── action.d           # ActionCache, ActionId, ActionEntry
│   └── storage.d          # Binary serialization for actions
│
├── policies/              # Cache eviction policies
│   ├── package.d          # Eviction policy overview
│   └── eviction.d         # LRU + age + size-based eviction
│
└── distributed/           # Distributed caching
    ├── package.d          # Distributed caching overview
    ├── coordinator.d      # DistributedCache coordinator
    └── remote/            # Remote cache client/server
        ├── package.d      # Remote caching overview
        ├── client.d       # HTTP client for remote cache
        ├── server.d       # HTTP server for cache hosting
        ├── protocol.d     # Cache protocol definitions
        └── transport.d    # HTTP transport implementation
```

## Module Organization

### `core.caching.targets`

Target-level caching is the primary caching mechanism. It caches complete build outputs for each target based on hashes of sources and dependencies.

**Key Types:**
- `BuildCache` - Main cache class
- `CacheEntry` - Cache entry with metadata
- `CacheConfig` - Configuration structure
- `BinaryStorage` - Binary serialization

### `core.caching.actions`

Action-level caching provides finer-grained caching for individual build steps. Each action (compile, link, codegen, etc.) can be cached independently.

**Key Types:**
- `ActionCache` - Action-level cache
- `ActionId` - Composite action identifier
- `ActionEntry` - Action cache entry
- `ActionType` - Enum of action types
- `ActionCacheConfig` - Configuration structure
- `ActionStorage` - Binary serialization

### `core.caching.policies`

Cache eviction policies manage cache size and prevent unbounded growth.

**Key Types:**
- `EvictionPolicy` - Hybrid LRU + age + size eviction

### `core.caching.distributed`

Distributed caching coordinates local and remote cache tiers for team collaboration.

**Key Types:**
- `DistributedCache` - Multi-tier cache coordinator
- `RemoteCacheClient` - HTTP client
- `CacheServer` - HTTP server
- `RemoteCacheConfig` - Remote cache configuration

## Performance Characteristics

### Target Cache
- **Hit check**: O(1) lookup + O(n) hash validation (SIMD-accelerated)
- **Update**: O(n) parallel hashing with work-stealing
- **Flush**: O(n log n) for LRU sorting + O(n) serialization
- **Memory**: ~256 bytes per entry (estimated)

### Action Cache
- **Hit check**: O(1) lookup + O(n) hash validation
- **Update**: O(n) hashing with memoization
- **Flush**: O(n log n) for LRU sorting + O(n) serialization
- **Memory**: ~512 bytes per entry (estimated)

### Remote Cache
- **Fetch**: Network RTT + transfer time + HTTP overhead
- **Push**: Async (non-blocking build)
- **Connection pooling**: Reuses TCP connections
- **Compression**: Optional zstd compression

## Implementation Notes

### Thread Safety
- All cache operations are synchronized via internal mutexes
- Safe for concurrent access from multiple build threads
- Lock-free hash caching for per-session memoization

### Security
- BLAKE3-based HMAC signatures prevent tampering
- Workspace-specific keys for isolation
- Automatic expiration (30 days default)
- Constant-time signature verification

### Memory Management
- Buffer pooling to reduce GC pressure
- Zero-copy string slicing from deserialized data
- Scoped parameters to prevent escaping references
- Explicit `close()` for clean shutdown

### Error Handling
- Corrupted cache files: Start fresh (no fatal errors)
- Signature verification failures: Clear and rebuild
- Remote cache errors: Fall back to local only
- Eviction failures: Save without eviction

## Configuration

All caches can be configured via environment variables or programmatically:

```bash
# Target cache limits
export BUILDER_CACHE_MAX_SIZE=1073741824        # 1 GB
export BUILDER_CACHE_MAX_ENTRIES=10000          # 10k entries
export BUILDER_CACHE_MAX_AGE_DAYS=30            # 30 days

# Action cache limits
export BUILDER_ACTION_CACHE_MAX_SIZE=1073741824
export BUILDER_ACTION_CACHE_MAX_ENTRIES=50000   # More than targets
export BUILDER_ACTION_CACHE_MAX_AGE_DAYS=30

# Remote cache configuration
export BUILDER_REMOTE_CACHE_URL=http://cache.example.com:8080
export BUILDER_REMOTE_CACHE_TIMEOUT=30
export BUILDER_REMOTE_CACHE_RETRY_COUNT=3
export BUILDER_REMOTE_CACHE_COMPRESSION=true
```

## Testing

See `tests/unit/caching/` for comprehensive unit tests covering:
- Cache hit/miss behavior
- Eviction policy correctness
- Binary serialization round-trip
- Remote cache operations
- Security (signature verification)
- Concurrent access patterns

## New: Unified Cache Coordinator (v2.0)

**Status:** ✅ Implemented

The Cache Coordinator provides centralized orchestration:

### `core.caching.coordinator`

Single source of truth for all caching operations:
- Multi-tier caching (local target, action, remote)
- Event-driven telemetry integration
- Automatic garbage collection
- Content-addressable storage with deduplication

**Usage:**
```d
auto coordinator = new CacheCoordinator(cacheDir, publisher);

// Check all tiers automatically
if (!coordinator.isCached(targetId, sources, deps)) {
    coordinator.update(targetId, sources, deps, outputHash);
}

// Action caching
if (!coordinator.isActionCached(actionId, inputs, metadata)) {
    coordinator.recordAction(actionId, inputs, outputs, metadata, true);
}

// Maintenance
coordinator.runGC();  // Clean orphaned artifacts
coordinator.flush();
coordinator.close();
```

### `core.caching.storage`

Content-addressable storage with deduplication:
- Automatic dedup by content hash
- Reference counting for safe deletion
- Sharded filesystem layout for performance

### `core.caching.metrics`

Real-time metrics collection:
- Event-driven (zero overhead when disabled)
- Comprehensive statistics (hit rates, latencies, storage)
- Integrates with telemetry system

See [CACHE_COORDINATOR.md](../../../docs/implementation/CACHE_COORDINATOR.md) for details.

## Future Enhancements

Potential improvements for future versions:
- **Compression**: Compress large artifacts before storage (in progress)
- **Cache warming**: Pre-populate from CI artifacts
- **Distributed GC**: Coordinate cleanup across build cluster
- **ML-based prediction**: Intelligent cache pre-fetching

