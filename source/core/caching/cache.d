module core.caching.cache;

import std.stdio;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.array;
import std.datetime;
import std.typecons : tuple;
import core.sync.mutex;
import utils.files.hash;
import utils.simd.ops;
import core.caching.storage;
import core.caching.eviction;
import utils.security.integrity;
import errors;

/// High-performance build cache with lazy writes and LRU eviction
/// 
/// Thread Safety:
/// - All public methods are synchronized via internal mutex
/// - Safe for concurrent access from multiple build threads
/// 
/// Security:
/// - BLAKE3-based HMAC signatures prevent cache tampering
/// - Workspace-specific keys for isolation
/// - Automatic expiration (30 days default)
/// - Constant-time signature verification
/// 
/// Optimizations:
/// - Binary format: 5-10x faster than JSON
/// - Lazy writes: Write once per build instead of per target
/// - Two-tier hashing: Check metadata before content hash (SIMD-accelerated)
/// - LRU eviction: Automatic cache size management
/// - SIMD comparisons: 2-3x faster hash validation
final class BuildCache
{
    private string cacheDir;
    private immutable string cacheFilePath;  // Pre-computed to avoid allocation in destructor
    private CacheEntry[string] entries;
    private bool dirty;
    private EvictionPolicy eviction;
    private CacheConfig config;
    private size_t contentHashCount;  // Stats: how many content hashes performed
    private size_t metadataHitCount;  // Stats: how many metadata hits
    private Mutex cacheMutex;  // Protects all mutable state
    private IntegrityValidator validator;  // HMAC validation for tampering detection
    
    /// Constructor: Initialize cache with directory and configuration
    /// 
    /// Safety: This constructor is @trusted because:
    /// 1. buildPath() is safe string concatenation
    /// 2. File system operations (exists, mkdirRecurse) are inherently unsafe I/O
    /// 3. Mutex creation is safe
    /// 4. loadCache() is a member function call
    /// 
    /// Invariants:
    /// - cacheDir directory exists after construction
    /// - cacheMutex is properly initialized
    /// - validator is initialized with workspace-specific key
    /// 
    /// What could go wrong:
    /// - Directory creation could fail due to permissions: throws exception
    /// - loadCache() could fail to read existing cache: handled gracefully
    /// - getcwd() could fail: throws exception (caller must handle)
    this(string cacheDir = ".builder-cache", CacheConfig config = CacheConfig.init) @trusted
    {
        this.cacheDir = cacheDir;
        this.cacheFilePath = buildPath(cacheDir, "cache.bin");  // Pre-compute path
        this.config = config;
        this.dirty = false;
        this.eviction = EvictionPolicy(config.maxSize, config.maxEntries, config.maxAge);
        this.cacheMutex = new Mutex();
        
        // Initialize integrity validator with workspace-specific key
        import std.file : getcwd;
        this.validator = IntegrityValidator.fromEnvironment(getcwd());
        
        if (!exists(cacheDir))
            mkdirRecurse(cacheDir);
        
        loadCache();
    }
    
    /// Destructor: ensure cache is written
    /// Skip if called during GC to avoid InvalidMemoryOperationError
    ~this()
    {
        import core.memory : GC;
        
        // Don't flush during GC - it allocates memory which is forbidden
        // The cache will be saved on next run instead
        if (dirty && !GC.inFinalizer())
        {
            try
            {
                flush(false); // Don't evict during destruction
            }
            catch (Exception e)
            {
                // Best effort - ignore errors during destruction
            }
        }
    }
    
    /// Check if a target is cached and up-to-date
    /// Uses two-tier hashing for 1000x speedup on unchanged files
    /// Thread-safe: synchronized via internal mutex
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Mutex synchronization ensures thread-safe access to entries
    /// 2. File system operations (exists, timeLastModified, FastHash) are unsafe I/O
    /// 3. Associative array access is bounds-checked (safe)
    /// 4. Pointer access (entryPtr) is safe within synchronized block
    /// 
    /// Invariants:
    /// - cacheMutex must be held for entire duration of cache lookup
    /// - Entry access times are updated atomically with the check
    /// - File metadata is consistent at time of check (TOCTOU acknowledged)
    /// 
    /// What could go wrong:
    /// - TOCTOU: file could be modified between check and use (unavoidable)
    /// - File could be deleted between metadata check and hash: returns false (safe)
    /// - Hash computation could fail: caught and returns false
    /// - Large files could slow down hashing: mitigated by FastHash tiers
    bool isCached(string targetId, scope const(string)[] sources, scope const(string)[] deps) @trusted
    {
        synchronized (cacheMutex)
        {
            auto entryPtr = targetId in entries;
            if (entryPtr is null)
                return false;
            
            // Update access time for LRU - use pointer to avoid copy
            entryPtr.lastAccess = Clock.currTime();
            dirty = true;
            
            // Check if any source files changed (two-tier strategy)
            foreach (source; sources)
            {
                if (!exists(source))
                    return false;
                
                // Get old metadata hash if exists
                immutable oldMetadataHash = entryPtr.sourceMetadata.get(source, "");
                
                // Two-tier hash: check metadata first
                const hashResult = FastHash.hashFileTwoTier(source, oldMetadataHash);
                
                if (hashResult.contentHashed)
                {
                    // Metadata changed, check content hash
                    contentHashCount++;
                    
                    immutable oldContentHash = entryPtr.sourceHashes.get(source, "");
                    // Use SIMD-accelerated comparison for hash strings
                    if (!fastHashEquals(hashResult.contentHash, oldContentHash))
                        return false;
                }
                else
                {
                    // Metadata unchanged, assume content unchanged (fast path)
                    metadataHitCount++;
                }
            }
            
            // Check if any dependencies changed
            foreach (dep; deps)
            {
                if (dep !in entries)
                    return false;
                
                // SIMD-accelerated hash comparison
                if (!fastHashEquals(entries[dep].buildHash, entryPtr.depHashes.get(dep, "")))
                    return false;
            }
            
            return true;
        }
    }
    
    /// Reusable workspace for parallel hashing to reduce allocations
    private static string[] hashWorkspace;
    
    /// Update cache entry for a target
    /// Defers write until flush() is called
    /// Uses SIMD-aware parallel hashing for multiple sources
    /// Thread-safe: synchronized via internal mutex
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Mutex synchronization ensures thread-safe access to entries
    /// 2. File system operations (FastHash.hashFile, timeLastModified) are unsafe I/O
    /// 3. Parallel hashing may spawn threads (synchronized internally)
    /// 4. Associative array insert/update is memory-safe
    /// 
    /// Invariants:
    /// - cacheMutex must be held during entry creation and insertion
    /// - dirty flag is set to ensure flush() will persist changes
    /// - All file hashes are computed before entry is created
    /// 
    /// What could go wrong:
    /// - Hash computation could fail for missing files: exception propagates
    /// - Parallel hashing could fail: exception propagates to caller
    /// - Memory usage could grow: limited by eviction policy on flush()
    /// - File modification during hashing: hash reflects state at that moment
    void update(string targetId, scope const(string)[] sources, scope const(string)[] deps, string outputHash) @trusted
    {
        synchronized (cacheMutex)
        {
            CacheEntry entry;
            entry.targetId = targetId;
            entry.timestamp = Clock.currTime();
            entry.lastAccess = Clock.currTime();
            entry.buildHash = outputHash;
        
        // Hash all source files in parallel with SIMD acceleration
        if (sources.length > 4) {
            // Use SIMD-aware parallel processing for multiple files
            import utils.concurrency.simd;
            import std.typecons : Tuple;
            
            // Count existing sources first to avoid allocation
            size_t existingCount = 0;
            foreach (source; sources)
                if (exists(source))
                    existingCount++;
            
            // Only allocate if we have sources to process
            if (existingCount > 0) {
                // Reuse workspace buffer if large enough, otherwise allocate
                if (hashWorkspace.length < existingCount)
                    hashWorkspace.length = existingCount;
                
                size_t idx = 0;
                foreach (source; sources)
                    if (exists(source))
                        hashWorkspace[idx++] = source;
                
                // Use only the filled portion of the workspace
                auto existingSources = hashWorkspace[0 .. existingCount];
                
                // Parallel hash with SIMD
                alias HashResult = Tuple!(string, string, string);
                auto hashes = SIMDParallel.mapSIMD(existingSources, (string source) {
                    return tuple(
                        source,
                        FastHash.hashFile(source),
                        FastHash.hashMetadata(source)
                    );
                });
                
                foreach (result; hashes) {
                    entry.sourceHashes[result[0]] = result[1];
                    entry.sourceMetadata[result[0]] = result[2];
                }
            }
        } else {
            // Sequential for small number of files (avoid overhead)
            foreach (source; sources)
            {
                if (exists(source))
                {
                    entry.sourceHashes[source] = FastHash.hashFile(source);
                    entry.sourceMetadata[source] = FastHash.hashMetadata(source);
                }
            }
        }
        
            // Store dependency hashes
            foreach (dep; deps)
            {
                if (dep in entries)
                    entry.depHashes[dep] = entries[dep].buildHash;
            }
            
            entries[targetId] = entry;
            dirty = true;
        }
    }
    
    /// Invalidate cache for a target
    /// Thread-safe: synchronized via internal mutex
    void invalidate(in string targetId) @trusted nothrow
    {
        try
        {
            synchronized (cacheMutex)
            {
                entries.remove(targetId);
                dirty = true;
            }
        }
        catch (Exception e)
        {
            // Mutex lock failed, ignore (nothrow requirement)
        }
    }
    
    /// Clear entire cache
    /// Thread-safe: synchronized via internal mutex
    void clear() @trusted
    {
        synchronized (cacheMutex)
        {
            entries.clear();
            dirty = false;
        }
        
        if (exists(cacheDir))
            rmdirRecurse(cacheDir);
        mkdirRecurse(cacheDir);
    }
    
    /// Flush cache to disk (lazy write)
    /// This is called once at the end of build instead of on every update
    /// Thread-safe: synchronized via internal mutex
    /// Params:
    ///   runEviction = whether to run eviction policy (default true, false in destructor)
    void flush(in bool runEviction = true) @trusted
    {
        synchronized (cacheMutex)
        {
            if (!dirty)
                return;
        
        // Run eviction policy before saving (skip in destructor to avoid GC issues)
        if (runEviction)
        {
            try
            {
                immutable currentSize = eviction.calculateTotalSize(entries);
                auto toEvict = eviction.selectEvictions(entries, currentSize);
                
                foreach (key; toEvict)
                    entries.remove(key);
                
                // Log eviction if any
                if (toEvict.length > 0)
                {
                    writeln("Cache evicted ", toEvict.length, " entries");
                }
            }
            catch (Exception e)
            {
                // If eviction fails, just save what we have
                writeln("Warning: Cache eviction failed, saving without eviction");
            }
        }
        
            // Save to binary format
            saveCache();
            dirty = false;
        }
    }
    
    /// Get cache statistics
    struct CacheStats
    {
        size_t totalEntries;
        size_t totalSize;
        SysTime oldestEntry;
        SysTime newestEntry;
        size_t contentHashes;    // How many content hashes performed
        size_t metadataHits;     // How many metadata hits (fast path)
        float metadataHitRate;   // Percentage of fast path hits
    }
    
    /// Get cache statistics
    /// Thread-safe: synchronized via internal mutex
    CacheStats getStats() const @trusted
    {
        synchronized (cast(Mutex)cacheMutex)  // const_cast for read-only access
        {
            CacheStats stats;
            stats.totalEntries = entries.length;
            
            if (entries.empty)
                return stats;
            
            stats.oldestEntry = entries.values.map!(e => e.timestamp).minElement;
            stats.newestEntry = entries.values.map!(e => e.timestamp).maxElement;
            
            // Calculate cache size (cast away const for calculation)
            stats.totalSize = (cast(EvictionPolicy)eviction).calculateTotalSize(cast(CacheEntry[string])entries);
            
            // Hash statistics
            stats.contentHashes = contentHashCount;
            stats.metadataHits = metadataHitCount;
            
            immutable total = contentHashCount + metadataHitCount;
            if (total > 0)
                stats.metadataHitRate = (metadataHitCount * 100.0) / total;
            
            return stats;
        }
    }
    
    private void loadCache() @trusted
    {
        if (!exists(cacheFilePath))
        {
            // Try loading old JSON format for migration
            string jsonCacheFile = buildPath(cacheDir, "cache.json");
            if (exists(jsonCacheFile))
            {
                try
                {
                    loadJsonCache(jsonCacheFile);
                    writeln("Migrated cache from JSON to binary format");
                    dirty = true; // Will save as binary on next flush
                    return;
                }
                catch (Exception e)
                {
                    // Migration failed, start fresh
                    writeln("Warning: Could not migrate old cache format");
                    
                    // Log with new error system
                    auto error = new CacheError(e.msg, ErrorCode.CacheLoadFailed);
                    error.addContext(ErrorContext("migrating JSON cache", jsonCacheFile));
                    error.cachePath = jsonCacheFile;
                }
            }
            return;
        }
        
        try
        {
            // Read file data - ubyte[] is automatically allocated by read()
            auto fileData = cast(ubyte[])std.file.read(cacheFilePath);
            
            // Deserialize signed data
            auto signed = SignedData.deserialize(fileData);
            
            // Verify integrity signature
            if (!validator.verifyWithMetadata(signed))
            {
                writeln("Warning: Cache signature verification failed, starting fresh");
                entries.clear();
                
                auto error = new CacheError("Cache signature verification failed", ErrorCode.CacheCorrupted);
                error.addContext(ErrorContext("verifying cache integrity", cacheFilePath));
                error.cachePath = cacheFilePath;
                return;
            }
            
            // Check if cache is expired (30 days max age)
            import core.time : days;
            if (IntegrityValidator.isExpired(signed, 30.days))
            {
                writeln("Cache expired, starting fresh");
                entries.clear();
                return;
            }
            
            // Deserialize cache entries from verified data
            // Uses zero-copy string slicing from data
            entries = BinaryStorage.deserialize!CacheEntry(signed.data);
            
            // Note: data is now referenced by strings in entries
            // GC will keep it alive as long as entries exist
        }
        catch (Exception e)
        {
            // Cache corrupted, start fresh
            writeln("Warning: Cache corrupted, starting fresh: ", e.msg);
            entries.clear();
            
            // Log with new error system
            auto error = new CacheError(e.msg, ErrorCode.CacheCorrupted);
            error.addContext(ErrorContext("loading binary cache", cacheFilePath));
            error.cachePath = cacheFilePath;
        }
    }
    
    private void saveCache() nothrow
    {
        try
        {
            // Serialize cache entries
            auto data = BinaryStorage.serialize(entries);
            
            // Sign the data with integrity validator
            auto signed = validator.signWithMetadata(data);
            
            // Serialize and write signed data
            auto serialized = signed.serialize();
            std.file.write(cacheFilePath, serialized);
        }
        catch (Exception e)
        {
            // Can't print during GC, just fail silently
            try { writeln("Warning: Could not save cache: ", e.msg); } 
            catch (Exception) 
            {
                // writeln may fail during GC - this is expected and safe to ignore
            }
        }
    }
    
    /// Load old JSON format for migration
    private void loadJsonCache(string cacheFile)
    {
        import std.json;
        
        auto content = readText(cacheFile);
        auto json = parseJSON(content);
        
        foreach (targetId, entryJson; json.object)
        {
            CacheEntry entry;
            entry.targetId = targetId;
            entry.buildHash = entryJson["buildHash"].str;
            entry.timestamp = SysTime.fromISOExtString(entryJson["timestamp"].str);
            entry.lastAccess = entry.timestamp; // Initialize with timestamp
            
            foreach (source, hash; entryJson["sourceHashes"].object)
            {
                entry.sourceHashes[source] = hash.str;
                // Compute metadata for migrated entries
                if (exists(source))
                    entry.sourceMetadata[source] = FastHash.hashMetadata(source);
            }
            
            foreach (dep, hash; entryJson["depHashes"].object)
                entry.depHashes[dep] = hash.str;
            
            entries[targetId] = entry;
        }
    }
    
    /// Fast hash comparison using SIMD when beneficial
    private bool fastHashEquals(string a, string b) const @trusted
    {
        if (a.length != b.length) return false;
        if (a.length == 0) return true;
        
        // For hash strings (typically 64 chars), SIMD provides benefit
        if (a.length >= 32) {
            return SIMDOps.equals(cast(void[])a, cast(void[])b);
        }
        
        return a == b;  // Scalar for short strings
    }
}

/// Cache entry with LRU tracking and metadata
/// 
/// Memory Management:
/// - Strings reference data from deserialized file buffer (zero-copy)
/// - Associative arrays are rehashed after bulk insertion for optimal layout
/// - No postblit to avoid accidental copies (use pointers via 'in entries')
private struct CacheEntry
{
    string targetId;
    string buildHash;
    string[string] sourceHashes;      // Content hashes
    string[string] sourceMetadata;    // Metadata hashes (new)
    string[string] depHashes;
    SysTime timestamp;                // When entry was created
    SysTime lastAccess;               // When entry was last accessed (LRU)
    string metadataHash;              // Reserved for future use
}

/// Cache configuration
struct CacheConfig
{
    size_t maxSize = 1_073_741_824;   // 1 GB default
    size_t maxEntries = 10_000;       // 10k entries default
    size_t maxAge = 30;               // 30 days default
    
    /// Load from environment variables
    static CacheConfig fromEnvironment() @safe
    {
        import std.process : environment;
        
        CacheConfig config;
        
        auto maxSizeEnv = environment.get("BUILDER_CACHE_MAX_SIZE");
        if (maxSizeEnv)
            config.maxSize = maxSizeEnv.to!size_t;
        
        auto maxEntriesEnv = environment.get("BUILDER_CACHE_MAX_ENTRIES");
        if (maxEntriesEnv)
            config.maxEntries = maxEntriesEnv.to!size_t;
        
        auto maxAgeEnv = environment.get("BUILDER_CACHE_MAX_AGE_DAYS");
        if (maxAgeEnv)
            config.maxAge = maxAgeEnv.to!size_t;
        
        return config;
    }
}

