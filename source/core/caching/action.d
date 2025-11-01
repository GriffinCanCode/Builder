module core.caching.action;

import std.stdio;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.array;
import std.datetime;
import std.typecons : tuple, Tuple;
import core.sync.mutex;
import utils.files.hash;
import utils.simd.hash;
import core.caching.eviction;
import utils.security.integrity;
import utils.concurrency.lockfree;
import core.caching.actionstore;
import errors;

/// Action types for fine-grained caching
enum ActionType : ubyte
{
    Compile,      // Compilation step (per file or batch)
    Link,         // Linking step
    Codegen,      // Code generation (protobuf, etc)
    Test,         // Test execution
    Package,      // Packaging/bundling
    Transform,    // Asset transformation
    Custom        // Custom user-defined action
}

/// Strongly-typed action identifier
/// Composite key: targetId + actionType + inputHash
/// Provides fine-grained uniqueness for caching individual build steps
struct ActionId
{
    string targetId;      // Parent target
    ActionType type;      // Type of action
    string inputHash;     // Hash of action inputs (sources, deps, flags)
    string subId;         // Optional sub-identifier (e.g., source file name)
    
    /// Generate stable string representation for storage
    string toString() const pure @safe
    {
        import std.format : format;
        if (subId.length > 0)
            return format("%s:%s:%s:%s", targetId, type, subId, inputHash);
        return format("%s:%s:%s", targetId, type, inputHash);
    }
    
    /// Parse action ID from string
    static ActionId parse(string str) @safe
    {
        auto parts = str.split(":");
        if (parts.length < 3)
            throw new Exception("Invalid ActionId format: " ~ str);
        
        ActionId id;
        id.targetId = parts[0];
        id.type = parts[1].to!ActionType;
        
        if (parts.length == 4)
        {
            id.subId = parts[2];
            id.inputHash = parts[3];
        }
        else
        {
            id.inputHash = parts[2];
        }
        
        return id;
    }
}

/// Action cache entry with incremental build metadata
struct ActionEntry
{
    ActionId actionId;                  // Composite identifier
    string[] inputs;                    // Input files
    string[string] inputHashes;         // Input file hashes
    string[] outputs;                   // Output files
    string[string] outputHashes;        // Output file hashes
    string[string] metadata;            // Additional metadata (flags, env, etc)
    SysTime timestamp;                  // When action was performed
    SysTime lastAccess;                 // Last access time (LRU)
    string executionHash;               // Hash of execution context
    bool success;                       // Whether action succeeded
}

/// High-performance action-level cache with incremental builds
/// 
/// Design Philosophy:
/// - Finer granularity than target-level caching
/// - Cache individual compile steps, link steps, etc.
/// - Enable partial rebuilds when only some actions fail
/// - Reuse successful action results across builds
/// 
/// Thread Safety:
/// - All public methods are synchronized via internal mutex
/// - Safe for concurrent access from multiple build threads
/// 
/// Security:
/// - BLAKE3-based HMAC signatures prevent tampering
/// - Workspace-specific keys for isolation
/// - Automatic expiration (30 days default)
/// 
/// Optimizations:
/// - Lock-free hash cache for per-session memoization
/// - Two-tier hashing for fast validation
/// - Binary serialization (5-10x faster than JSON)
/// - SIMD-accelerated hash comparisons
final class ActionCache
{
    private string cacheDir;
    private immutable string cacheFilePath;
    private ActionEntry[string] entries;  // Key: ActionId.toString()
    private bool dirty;
    private EvictionPolicy eviction;
    private ActionCacheConfig config;
    private Mutex cacheMutex;
    private IntegrityValidator validator;
    private FastHashCache hashCache;
    private bool closed = false;
    
    // Statistics
    private size_t actionHits;
    private size_t actionMisses;
    
    /// Constructor: Initialize action cache
    this(string cacheDir = ".builder-cache/actions", ActionCacheConfig config = ActionCacheConfig.init) @trusted
    {
        this.cacheDir = cacheDir;
        this.cacheFilePath = buildPath(cacheDir, "actions.bin");
        this.config = config;
        this.dirty = false;
        this.eviction = EvictionPolicy(config.maxSize, config.maxEntries, config.maxAge);
        this.cacheMutex = new Mutex();
        
        // Initialize hash cache
        this.hashCache.initialize();
        
        // Initialize integrity validator
        import std.file : getcwd;
        this.validator = IntegrityValidator.fromEnvironment(getcwd());
        
        if (!exists(cacheDir))
            mkdirRecurse(cacheDir);
        
        loadCache();
    }
    
    /// Explicitly close cache and flush to disk
    void close() @trusted
    {
        synchronized (cacheMutex)
        {
            if (!closed)
            {
                if (dirty)
                    flush(false);
                closed = true;
            }
        }
    }
    
    ~this()
    {
        if (closed)
            return;
        
        import core.memory : GC;
        if (dirty && !GC.inFinalizer())
        {
            try
            {
                flush(false);
            }
            catch (Exception) {}
        }
    }
    
    /// Check if an action is cached and up-to-date
    /// 
    /// Validates:
    /// 1. Action entry exists
    /// 2. All input files unchanged (via hash)
    /// 3. All output files exist
    /// 4. No execution context changes (flags, env, etc)
    bool isCached(ActionId actionId, scope const(string)[] inputs, scope const(string[string]) metadata) @trusted
    {
        synchronized (cacheMutex)
        {
            auto key = actionId.toString();
            auto entryPtr = key in entries;
            if (entryPtr is null)
            {
                actionMisses++;
                return false;
            }
            
            // Update access time for LRU
            entryPtr.lastAccess = Clock.currTime();
            dirty = true;
            
            // Check if action succeeded previously
            if (!entryPtr.success)
            {
                actionMisses++;
                return false;
            }
            
            // Validate input files haven't changed
            foreach (input; inputs)
            {
                if (!exists(input))
                {
                    actionMisses++;
                    return false;
                }
                
                // Use hash cache for efficiency
                auto cached = hashCache.get(input);
                string currentHash;
                if (cached.found)
                {
                    currentHash = cached.contentHash;
                }
                else
                {
                    currentHash = FastHash.hashFile(input);
                    auto metaHash = FastHash.hashMetadata(input);
                    hashCache.put(input, currentHash, metaHash);
                }
                
                immutable oldHash = entryPtr.inputHashes.get(input, "");
                if (!SIMDHash.equals(currentHash, oldHash))
                {
                    actionMisses++;
                    return false;
                }
            }
            
            // Validate all output files exist
            foreach (output; entryPtr.outputs)
            {
                if (!exists(output))
                {
                    actionMisses++;
                    return false;
                }
            }
            
            // Validate execution context (metadata) unchanged
            foreach (metaKey, metaValue; metadata)
            {
                if (entryPtr.metadata.get(metaKey, "") != metaValue)
                {
                    actionMisses++;
                    return false;
                }
            }
            
            actionHits++;
            return true;
        }
    }
    
    /// Update action cache entry
    /// 
    /// Records:
    /// - Input files and their hashes
    /// - Output files and their hashes
    /// - Execution metadata (flags, env, etc)
    /// - Success status
    void update(
        ActionId actionId,
        scope const(string)[] inputs,
        scope const(string)[] outputs,
        scope const(string[string]) metadata,
        bool success
    ) @trusted
    {
        synchronized (cacheMutex)
        {
            ActionEntry entry;
            entry.actionId = actionId;
            entry.timestamp = Clock.currTime();
            entry.lastAccess = Clock.currTime();
            entry.success = success;
            entry.inputs = inputs.dup;
            entry.outputs = outputs.dup;
            
            // Hash all input files
            foreach (input; inputs)
            {
                if (exists(input))
                {
                    auto cached = hashCache.get(input);
                    if (cached.found)
                    {
                        entry.inputHashes[input] = cached.contentHash;
                    }
                    else
                    {
                        auto hash = FastHash.hashFile(input);
                        auto metaHash = FastHash.hashMetadata(input);
                        hashCache.put(input, hash, metaHash);
                        entry.inputHashes[input] = hash;
                    }
                }
            }
            
            // Hash all output files
            foreach (output; outputs)
            {
                if (exists(output))
                {
                    entry.outputHashes[output] = FastHash.hashFile(output);
                }
            }
            
            // Copy metadata
            foreach (key, value; metadata)
                entry.metadata[key] = value;
            
            // Compute execution hash from metadata
            entry.executionHash = computeExecutionHash(metadata);
            
            entries[actionId.toString()] = entry;
            dirty = true;
        }
    }
    
    /// Invalidate action cache entry
    void invalidate(ActionId actionId) @trusted nothrow
    {
        try
        {
            synchronized (cacheMutex)
            {
                entries.remove(actionId.toString());
                dirty = true;
            }
        }
        catch (Exception) {}
    }
    
    /// Clear entire action cache
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
    
    /// Flush cache to disk
    void flush(bool runEviction = true) @trusted
    {
        synchronized (cacheMutex)
        {
            if (!dirty)
                return;
            
            // Run eviction policy
            if (runEviction)
            {
                try
                {
                    immutable currentSize = eviction.calculateTotalSize(entries);
                    auto toEvict = eviction.selectEvictions(entries, currentSize);
                    
                    foreach (key; toEvict)
                        entries.remove(key);
                    
                    if (toEvict.length > 0)
                        writeln("Action cache evicted ", toEvict.length, " entries");
                }
                catch (Exception)
                {
                    writeln("Warning: Action cache eviction failed");
                }
            }
            
            saveCache();
            dirty = false;
            hashCache.clear();
        }
    }
    
    /// Get action cache statistics
    struct ActionCacheStats
    {
        size_t totalEntries;
        size_t totalSize;
        size_t hits;
        size_t misses;
        float hitRate;
        size_t successfulActions;
        size_t failedActions;
    }
    
    ActionCacheStats getStats() const @trusted
    {
        synchronized (cast(Mutex)cacheMutex)
        {
            ActionCacheStats stats;
            stats.totalEntries = entries.length;
            stats.hits = actionHits;
            stats.misses = actionMisses;
            
            immutable total = actionHits + actionMisses;
            if (total > 0)
                stats.hitRate = (actionHits * 100.0) / total;
            
            foreach (entry; entries.byValue)
            {
                if (entry.success)
                    stats.successfulActions++;
                else
                    stats.failedActions++;
            }
            
            stats.totalSize = (cast(EvictionPolicy)eviction).calculateTotalSize(cast(ActionEntry[string])entries);
            
            return stats;
        }
    }
    
    /// Get all cached actions for a target
    ActionEntry[] getActionsForTarget(string targetId) const @trusted
    {
        synchronized (cast(Mutex)cacheMutex)
        {
            ActionEntry[] result;
            foreach (entry; entries.byValue)
            {
                if (entry.actionId.targetId == targetId)
                {
                    // Create a mutable copy of the entry
                    ActionEntry copy;
                    copy.actionId = entry.actionId;
                    copy.inputs = entry.inputs.dup;
                    
                    // Manually copy associative arrays to handle const properly
                    foreach (k, v; entry.inputHashes)
                        copy.inputHashes[k] = v;
                    
                    copy.outputs = entry.outputs.dup;
                    
                    foreach (k, v; entry.outputHashes)
                        copy.outputHashes[k] = v;
                    
                    foreach (k, v; entry.metadata)
                        copy.metadata[k] = v;
                    
                    copy.timestamp = entry.timestamp;
                    copy.lastAccess = entry.lastAccess;
                    copy.executionHash = entry.executionHash;
                    copy.success = entry.success;
                    result ~= copy;
                }
            }
            return result;
        }
    }
    
    private void loadCache() @trusted
    {
        if (!exists(cacheFilePath))
            return;
        
        try
        {
            auto fileData = cast(ubyte[])std.file.read(cacheFilePath);
            auto signed = SignedData.deserialize(fileData);
            
            if (!validator.verifyWithMetadata(signed))
            {
                writeln("Warning: Action cache signature verification failed, starting fresh");
                entries.clear();
                return;
            }
            
            import core.time : days;
            if (IntegrityValidator.isExpired(signed, 30.days))
            {
                writeln("Action cache expired, starting fresh");
                entries.clear();
                return;
            }
            
            entries = ActionStorage.deserialize!ActionEntry(signed.data);
        }
        catch (Exception e)
        {
            writeln("Warning: Action cache corrupted, starting fresh: ", e.msg);
            entries.clear();
        }
    }
    
    private void saveCache() nothrow
    {
        try
        {
            auto data = ActionStorage.serialize(entries);
            auto signed = validator.signWithMetadata(data);
            auto serialized = signed.serialize();
            std.file.write(cacheFilePath, serialized);
        }
        catch (Exception e)
        {
            try { writeln("Warning: Could not save action cache: ", e.msg); }
            catch (Exception) {}
        }
    }
    
    /// Compute hash of execution context (flags, env, etc)
    private static string computeExecutionHash(scope const(string[string]) metadata) @trusted
    {
        import std.digest.sha : SHA256, toHexString;
        
        // Sort keys for deterministic hashing
        auto keys = metadata.keys.array.sort().array;
        
        SHA256 hash;
        hash.start();
        foreach (key; keys)
        {
            hash.put(cast(ubyte[])key);
            hash.put(cast(ubyte[])metadata[key]);
        }
        
        return toHexString(hash.finish()).to!string;
    }
}

/// Action cache configuration
struct ActionCacheConfig
{
    size_t maxSize = 1_073_741_824;   // 1 GB default
    size_t maxEntries = 50_000;       // 50k actions default (more than targets)
    size_t maxAge = 30;               // 30 days default
    
    static ActionCacheConfig fromEnvironment() @safe
    {
        import std.process : environment;
        
        ActionCacheConfig config;
        
        auto maxSizeEnv = environment.get("BUILDER_ACTION_CACHE_MAX_SIZE");
        if (maxSizeEnv)
            config.maxSize = maxSizeEnv.to!size_t;
        
        auto maxEntriesEnv = environment.get("BUILDER_ACTION_CACHE_MAX_ENTRIES");
        if (maxEntriesEnv)
            config.maxEntries = maxEntriesEnv.to!size_t;
        
        auto maxAgeEnv = environment.get("BUILDER_ACTION_CACHE_MAX_AGE_DAYS");
        if (maxAgeEnv)
            config.maxAge = maxAgeEnv.to!size_t;
        
        return config;
    }
}

