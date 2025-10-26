module core.cache;

import std.stdio;
import std.file;
import std.path;
import std.digest.sha;
import std.conv;
import std.algorithm;
import std.array;
import std.datetime;
import utils.hash;

/// Build cache for incremental builds
class BuildCache
{
    private string cacheDir;
    private CacheEntry[string] entries;
    
    this(string cacheDir = ".builder-cache")
    {
        this.cacheDir = cacheDir;
        
        if (!exists(cacheDir))
            mkdirRecurse(cacheDir);
        
        loadCache();
    }
    
    /// Check if a target is cached and up-to-date
    bool isCached(string targetId, string[] sources, string[] deps)
    {
        if (targetId !in entries)
            return false;
        
        auto entry = entries[targetId];
        
        // Check if any source files changed
        foreach (source; sources)
        {
            if (!exists(source))
                return false;
            
            auto currentHash = FastHash.hashFile(source);
            if (source !in entry.sourceHashes || entry.sourceHashes[source] != currentHash)
                return false;
        }
        
        // Check if any dependencies changed
        foreach (dep; deps)
        {
            if (dep !in entries)
                return false;
            
            if (entries[dep].buildHash != entry.depHashes.get(dep, ""))
                return false;
        }
        
        return true;
    }
    
    /// Update cache entry for a target
    void update(string targetId, string[] sources, string[] deps, string outputHash)
    {
        CacheEntry entry;
        entry.targetId = targetId;
        entry.timestamp = Clock.currTime();
        entry.buildHash = outputHash;
        
        // Hash all source files
        foreach (source; sources)
        {
            if (exists(source))
                entry.sourceHashes[source] = FastHash.hashFile(source);
        }
        
        // Store dependency hashes
        foreach (dep; deps)
        {
            if (dep in entries)
                entry.depHashes[dep] = entries[dep].buildHash;
        }
        
        entries[targetId] = entry;
        saveCache();
    }
    
    /// Invalidate cache for a target
    void invalidate(string targetId)
    {
        entries.remove(targetId);
        saveCache();
    }
    
    /// Clear entire cache
    void clear()
    {
        entries.clear();
        if (exists(cacheDir))
            rmdirRecurse(cacheDir);
        mkdirRecurse(cacheDir);
    }
    
    /// Get cache statistics
    struct CacheStats
    {
        size_t totalEntries;
        size_t totalSize;
        SysTime oldestEntry;
        SysTime newestEntry;
    }
    
    CacheStats getStats()
    {
        CacheStats stats;
        stats.totalEntries = entries.length;
        
        if (entries.empty)
            return stats;
        
        stats.oldestEntry = entries.values.map!(e => e.timestamp).minElement;
        stats.newestEntry = entries.values.map!(e => e.timestamp).maxElement;
        
        // Calculate cache size
        if (exists(cacheDir))
        {
            foreach (entry; dirEntries(cacheDir, SpanMode.depth))
            {
                if (entry.isFile)
                    stats.totalSize += entry.size;
            }
        }
        
        return stats;
    }
    
    private void loadCache()
    {
        string cacheFile = buildPath(cacheDir, "cache.json");
        
        if (!exists(cacheFile))
            return;
        
        try
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
                
                foreach (source, hash; entryJson["sourceHashes"].object)
                    entry.sourceHashes[source] = hash.str;
                
                foreach (dep, hash; entryJson["depHashes"].object)
                    entry.depHashes[dep] = hash.str;
                
                entries[targetId] = entry;
            }
        }
        catch (Exception e)
        {
            // Cache corrupted, start fresh
            entries.clear();
        }
    }
    
    private void saveCache()
    {
        import std.json;
        
        JSONValue json = JSONValue.emptyObject;
        
        foreach (targetId, entry; entries)
        {
            JSONValue entryJson = JSONValue.emptyObject;
            entryJson["buildHash"] = entry.buildHash;
            entryJson["timestamp"] = entry.timestamp.toISOExtString();
            
            JSONValue sourceHashes = JSONValue.emptyObject;
            foreach (source, hash; entry.sourceHashes)
                sourceHashes[source] = hash;
            entryJson["sourceHashes"] = sourceHashes;
            
            JSONValue depHashes = JSONValue.emptyObject;
            foreach (dep, hash; entry.depHashes)
                depHashes[dep] = hash;
            entryJson["depHashes"] = depHashes;
            
            json[targetId] = entryJson;
        }
        
        string cacheFile = buildPath(cacheDir, "cache.json");
        std.file.write(cacheFile, json.toPrettyString());
    }
}

private struct CacheEntry
{
    string targetId;
    string buildHash;
    string[string] sourceHashes;
    string[string] depHashes;
    SysTime timestamp;
}

