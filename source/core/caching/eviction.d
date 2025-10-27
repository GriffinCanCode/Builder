module core.caching.eviction;

import std.algorithm;
import std.array;
import std.datetime;
import std.range;

/// LRU cache eviction policy with configurable size limits
struct EvictionPolicy
{
    size_t maxSize = 1_073_741_824;   // Maximum cache size in bytes (1 GB default)
    size_t maxEntries = 10_000;       // Maximum number of entries (10k default)
    size_t maxAge = 30;               // Maximum age in days (30 days default)
    
    /// Determine which entries to evict
    /// Uses hybrid strategy: LRU + age-based + size-based
    string[] selectEvictions(T)(T[string] entries, size_t currentSize)
    {
        string[] toEvict;
        auto now = Clock.currTime();
        
        // 1. Remove entries older than maxAge
        if (maxAge > 0)
        {
            foreach (key, entry; entries)
            {
                auto age = now - entry.timestamp;
                if (age.total!"days" > maxAge)
                    toEvict ~= key;
            }
        }
        
        // 2. Remove entries if count exceeds limit (LRU)
        if (entries.length > maxEntries)
        {
            auto sorted = entries.byKeyValue
                .array
                .sort!((a, b) => a.value.lastAccess < b.value.lastAccess);
            
            auto excess = entries.length - maxEntries;
            foreach (i; 0 .. excess)
            {
                if (!toEvict.canFind(sorted[i].key))
                    toEvict ~= sorted[i].key;
            }
        }
        
        // 3. Remove entries if size exceeds limit (LRU)
        if (currentSize > maxSize)
        {
            auto sorted = entries.byKeyValue
                .array
                .sort!((a, b) => a.value.lastAccess < b.value.lastAccess);
            
            size_t removed = 0;
            foreach (kv; sorted)
            {
                if (currentSize - removed <= maxSize)
                    break;
                
                if (!toEvict.canFind(kv.key))
                {
                    toEvict ~= kv.key;
                    removed += estimateEntrySize(kv.value);
                }
            }
        }
        
        return toEvict;
    }
    
    /// Estimate the size of a cache entry in bytes
    private size_t estimateEntrySize(T)(T entry) pure @nogc
    {
        size_t size = 0;
        
        // Fixed overhead
        size += 100; // Entry structure overhead
        
        // Strings
        size += entry.targetId.length;
        size += entry.buildHash.length;
        size += entry.metadataHash.length;
        
        // Maps
        foreach (source, hash; entry.sourceHashes)
            size += source.length + hash.length;
        
        foreach (dep, hash; entry.depHashes)
            size += dep.length + hash.length;
        
        return size;
    }
    
    /// Calculate total cache size
    size_t calculateTotalSize(T)(T[string] entries) pure @nogc
    {
        size_t total = 0;
        foreach (entry; entries.byValue)
        {
            total += estimateEntrySize(entry);
        }
        return total;
    }
    
    /// Get eviction statistics
    struct EvictionStats
    {
        size_t totalEntries;
        size_t totalSize;
        size_t entriesAboveLimit;
        size_t sizeAboveLimit;
        size_t expiredEntries;
    }
    
    EvictionStats getStats(T)(T[string] entries, size_t currentSize)
    {
        EvictionStats stats;
        stats.totalEntries = entries.length;
        stats.totalSize = currentSize;
        
        if (entries.length > maxEntries)
            stats.entriesAboveLimit = entries.length - maxEntries;
        
        if (currentSize > maxSize)
            stats.sizeAboveLimit = currentSize - maxSize;
        
        if (maxAge > 0)
        {
            auto now = Clock.currTime();
            foreach (entry; entries.values)
            {
                auto age = now - entry.timestamp;
                if (age.total!"days" > maxAge)
                    stats.expiredEntries++;
            }
        }
        
        return stats;
    }
}

