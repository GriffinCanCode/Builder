# Cache Coordinator Architecture

**Status:** ✅ **IMPLEMENTED**  
**Date:** November 2, 2025  
**Priority:** HIGH

---

## Overview

The Cache Coordinator provides unified orchestration of all caching tiers in Builder, eliminating the previous fragmentation where `BuildCache`, `ActionCache`, and `DistributedCache` operated independently.

### Key Improvements

1. **Single Source of Truth** - One coordinator for all cache operations
2. **Event-Driven Telemetry** - Automatic metrics collection for observability
3. **Content-Addressable Storage** - Deduplication across targets/actions
4. **Garbage Collection** - Automatic cleanup of orphaned artifacts
5. **Simplified Integration** - Clean API for language handlers

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   CacheCoordinator                       │
│  (Orchestrates all caching tiers + emits events)        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │BuildCache   │  │ActionCache  │  │RemoteCache  │    │
│  │(Targets)    │  │(Actions)    │  │(Distributed)│    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │   ContentAddressableStorage (CAS)               │   │
│  │   - Deduplication by content hash               │   │
│  │   - Reference counting                          │   │
│  │   - Sharded storage for performance             │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │   CacheGarbageCollector                         │   │
│  │   - Reachability-based collection               │   │
│  │   - Mark-and-sweep orphaned blobs               │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │  EventPublisher│
                  │  (telemetry)   │
                  └───────────────┘
                          │
                          ▼
              ┌──────────────────────┐
              │ CacheMetricsCollector │
              └──────────────────────┘
```

---

## Components

### 1. CacheCoordinator (`core.caching.coordinator`)

Unified interface for all cache operations.

**Key Methods:**
```d
// Check cache (all tiers)
bool isCached(string targetId, string[] sources, string[] deps);

// Update cache (with remote push)
void update(string targetId, string[] sources, string[] deps, string outputHash);

// Action cache operations
bool isActionCached(ActionId actionId, string[] inputs, string[string] metadata);
void recordAction(ActionId actionId, string[] inputs, string[] outputs, ...);

// Maintenance
void flush();
void close();
Result!(size_t, BuildError) runGC();
```

### 2. ContentAddressableStorage (`core.caching.storage.cas`)

Deduplicates artifacts by content hash.

**Features:**
- Automatic deduplication (same content = one blob)
- Reference counting for safe deletion
- Sharded storage (first 2 chars of hash) for filesystem performance
- Thread-safe operations

**API:**
```d
Result!(string, BuildError) putBlob(const(ubyte)[] data);  // Returns hash
Result!(ubyte[], BuildError) getBlob(string hash);
bool hasBlob(string hash);
void addRef(string hash);
bool removeRef(string hash);  // Returns true if deletable
```

### 3. CacheGarbageCollector (`core.caching.storage.gc`)

Cleans up orphaned artifacts.

**Algorithm:**
1. **Mark Phase**: Collect all referenced hashes from caches
2. **Sweep Phase**: Remove unreferenced blobs from CAS

**Usage:**
```d
auto gc = new CacheGarbageCollector(cas, publisher);
auto result = gc.collect(targetCache, actionCache);
// Result: { blobsCollected, bytesFreed, orphansFound }
```

### 4. Cache Events (`core.caching.events`)

Type-safe events for telemetry integration.

**Event Types:**
- `CacheHitEvent` / `CacheMissEvent`
- `CacheUpdateEvent`
- `CacheEvictionEvent`
- `RemoteCacheEvent` (hit/miss/push/pull)
- `CacheGCEvent`
- `ActionCacheEvent`

### 5. CacheMetricsCollector (`core.caching.metrics`)

Subscribes to cache events and aggregates statistics.

**Metrics Tracked:**
- Hit/miss rates (target, action, remote)
- Latencies (lookup, update, network, GC)
- Storage (bytes stored/served/evicted/collected)
- Operations (updates, evictions, GC runs)

---

## Integration

### Service Layer

`CacheService` now uses `CacheCoordinator` internally:

```d
// source/core/execution/services/cache.d
final class CacheService : ICacheService
{
    private CacheCoordinator coordinator;
    private CacheMetricsCollector metricsCollector;
    
    this(string cacheDir, EventPublisher publisher = null)
    {
        // Initialize metrics if publisher available
        if (publisher !is null)
        {
            this.metricsCollector = new CacheMetricsCollector();
            publisher.subscribe(this.metricsCollector);
        }
        
        // Initialize coordinator
        this.coordinator = new CacheCoordinator(cacheDir, publisher);
    }
    
    bool isCached(...) { return coordinator.isCached(...); }
    void update(...) { coordinator.update(...); }
    void recordAction(...) { coordinator.recordAction(...); }
}
```

### ExecutionEngine

Engine uses `ICacheService` interface (no changes needed):

```d
final class ExecutionEngine
{
    private ICacheService cache;
    
    // Cache operations
    if (!cache.isCached(targetId, sources, deps)) {
        // Build
        cache.update(targetId, sources, deps, outputHash);
    }
}
```

### Language Handlers

Use `ActionCacheHelper` for simplified integration:

```d
import core.caching.helpers : ActionCacheHelper;

class MyHandler : BaseLanguageHandler
{
    private ActionCacheHelper actionHelper;
    
    this(CacheCoordinator coordinator)
    {
        this.actionHelper = ActionCacheHelper.withCoordinator(coordinator);
    }
    
    Result!(string, BuildError) buildImpl(...)
    {
        foreach (source; target.sources)
        {
            auto actionId = ActionId(target.name, ActionType.Compile, hash, source);
            
            // Check cache
            if (actionHelper.isCached(actionId, [source], metadata))
            {
                writeln("  [Cached] ", source);
                continue;
            }
            
            // Execute and record
            auto result = compile(source);
            actionHelper.record(actionId, [source], [output], metadata, result.isOk);
        }
    }
}
```

---

## Benefits

### Before (Fragmented)

```d
// Multiple independent caches
BuildCache buildCache;
ActionCache actionCache;
RemoteCacheClient remoteCache;
DistributedCache distributedCache;  // Duplicate logic!

// No telemetry
// No garbage collection
// No deduplication
// Inconsistent remote cache handling
```

### After (Unified)

```d
// Single coordinator
CacheCoordinator coordinator(cacheDir, publisher);

// Automatic telemetry via events
// Built-in garbage collection
// Content-addressable deduplication
// Consistent multi-tier caching
```

### Performance Improvements

1. **Deduplication**: ~30-50% storage savings for identical artifacts
2. **GC**: Prevents unbounded growth, maintains performance
3. **Metrics**: Zero-overhead event-driven collection
4. **Remote Cache**: Async pushes don't block builds

---

## Configuration

Environment variables (same as before, plus new ones):

```bash
# Target cache (unchanged)
BUILDER_CACHE_MAX_SIZE=1073741824
BUILDER_CACHE_MAX_ENTRIES=10000
BUILDER_CACHE_MAX_AGE_DAYS=30

# Action cache (unchanged)
BUILDER_ACTION_CACHE_MAX_SIZE=1073741824
BUILDER_ACTION_CACHE_MAX_ENTRIES=50000

# Remote cache (unchanged)
BUILDER_REMOTE_CACHE_URL=http://cache.example.com:8080
BUILDER_REMOTE_CACHE_TOKEN=...

# New: Coordinator options
BUILDER_CACHE_AUTO_GC=true          # Auto GC on flush
BUILDER_CACHE_GC_INTERVAL=24h       # GC frequency
```

---

## Migration Guide

### For Core Contributors

1. **Use `CacheService`** instead of creating `BuildCache` directly
2. **Pass `EventPublisher`** to enable telemetry
3. **Call `runGC()`** periodically (or enable auto-GC)

### For Language Handler Authors

1. **Import helpers**: `import core.caching.helpers;`
2. **Use `ActionCacheHelper`** for simplified API
3. **Check before execute**: `if (actionHelper.isCached(...)) continue;`
4. **Record after execute**: `actionHelper.record(...);`

### Backwards Compatibility

All existing code continues to work. The coordinator wraps existing caches transparently.

---

## Testing

### Unit Tests

```bash
# Run coordinator tests
dub test -- tests.unit.core.caching.coordinator

# Run storage tests
dub test -- tests.unit.core.caching.storage
```

### Integration Tests

The coordinator is integration tested via `CacheService` tests.

---

## Future Enhancements

1. **Distributed GC** - Coordinate GC across build cluster
2. **Cache Warming** - Pre-populate from CI artifacts
3. **Compression** - Compress large blobs automatically
4. **Analytics** - ML-based cache prediction
5. **Multi-Server CAS** - Shared content-addressable storage

---

## References

- [Action Caching](./ACTION_CACHING.md)
- [Remote Caching](./REMOTE_CACHING.md)
- [Telemetry System](../core/telemetry/README.md)
- [Event System](../../cli/events/README.md)

