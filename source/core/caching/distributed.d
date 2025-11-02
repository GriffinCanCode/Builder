module core.caching.distributed;

import std.file : exists, read, write, mkdirRecurse;
import std.path : buildPath, dirName;
import std.algorithm : min;
import core.caching.cache : BuildCache;
import core.caching.action : ActionCache, ActionId;
import core.caching.remote.client : RemoteCacheClient;
import utils.files.hash : FastHash;
import errors;

/// Distributed cache coordinator
/// Manages local and remote cache tiers with fallback logic
/// 
/// Strategy:
/// - Read: Local first, then remote (pull on miss)
/// - Write: Local immediately, remote async (push in background)
/// - Transparency: Handlers don't need to know about distribution
final class DistributedCache
{
    private BuildCache localCache;
    private ActionCache actionCache;
    private RemoteCacheClient remoteCache;
    private string cacheDir;
    
    /// Constructor
    this(BuildCache localCache, ActionCache actionCache, RemoteCacheClient remoteCache, string cacheDir) @safe
    {
        this.localCache = localCache;
        this.actionCache = actionCache;
        this.remoteCache = remoteCache;
        this.cacheDir = cacheDir;
    }
    
    /// Check if target is cached (local or remote)
    bool isCached(string targetId, scope const(string)[] sources, scope const(string)[] deps) @trusted
    {
        // Check local cache first (fast path)
        if (localCache.isCached(targetId, sources, deps))
            return true;
        
        // Check remote cache if available
        if (remoteCache is null)
            return false;
        
        // Compute target hash for remote lookup
        auto hashResult = computeTargetHash(targetId, sources, deps);
        if (hashResult.isErr)
            return false;
        
        auto targetHash = hashResult.unwrap();
        
        // Check if remote has this artifact
        auto hasResult = remoteCache.has(targetHash);
        if (hasResult.isErr || !hasResult.unwrap())
            return false;
        
        // Pull from remote and store locally
        auto pullResult = pullFromRemote(targetHash, targetId);
        if (pullResult.isErr)
            return false;
        
        // Update local cache with pulled data
        // Note: This doesn't update BuildCache directly, but stores the artifact
        // The actual build won't need to execute since we have the artifact
        
        return true;
    }
    
    /// Update cache after successful build
    void update(string targetId, scope const(string)[] sources, scope const(string)[] deps, string outputHash) @trusted
    {
        // Update local cache immediately
        localCache.update(targetId, sources, deps, outputHash);
        
        // Push to remote cache asynchronously if available
        if (remoteCache !is null)
        {
            // Compute target hash
            auto hashResult = computeTargetHash(targetId, sources, deps);
            if (hashResult.isOk)
            {
                auto targetHash = hashResult.unwrap();
                
                // Read artifact data
                // Note: This is simplified - real implementation would need to know artifact location
                // For now, we'll skip the actual push implementation
                // TODO: Implement artifact serialization and push
            }
        }
    }
    
    /// Record action for fine-grained caching
    void recordAction(ActionId actionId, string[] inputs, string[] outputs,
                     string[string] metadata, bool success) @trusted
    {
        // Update local action cache
        actionCache.update(actionId, inputs, outputs, metadata, success);
        
        // TODO: Push action artifacts to remote cache
        // This would require serializing action outputs
    }
    
    /// Flush all caches
    void flush() @trusted
    {
        localCache.flush();
        actionCache.flush();
    }
    
    /// Close all caches
    void close() @trusted
    {
        if (localCache !is null)
            localCache.close();
        if (actionCache !is null)
            actionCache.close();
    }
    
    private Result!(string, BuildError) computeTargetHash(
        string targetId,
        scope const(string)[] sources,
        scope const(string)[] deps
    ) @trusted
    {
        import std.digest.sha : SHA256, toHexString;
        import std.conv : to;
        
        try
        {
            SHA256 hash;
            hash.start();
            
            // Hash target ID
            hash.put(cast(ubyte[])targetId);
            
            // Hash all sources
            foreach (source; sources)
            {
                if (exists(source))
                {
                    auto sourceHash = FastHash.hashFile(source);
                    hash.put(cast(ubyte[])sourceHash);
                }
            }
            
            // Hash dependencies
            foreach (dep; deps)
            {
                hash.put(cast(ubyte[])dep);
            }
            
            auto result = toHexString(hash.finish()).to!string;
            return Ok!(string, BuildError)(result);
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Failed to compute target hash: " ~ e.msg,
                ErrorCode.CacheLoadFailed
            );
            return Err!(string, BuildError)(error);
        }
    }
    
    private Result!(void, BuildError) pullFromRemote(string targetHash, string targetId) @trusted
    {
        try
        {
            // Fetch artifact from remote
            auto fetchResult = remoteCache.get(targetHash);
            if (fetchResult.isErr)
                return Err!(void, BuildError)(fetchResult.unwrapErr());
            
            auto artifactData = fetchResult.unwrap();
            
            // Store artifact locally
            immutable artifactPath = buildPath(cacheDir, "artifacts", targetHash);
            immutable artifactDir = dirName(artifactPath);
            
            if (!exists(artifactDir))
                mkdirRecurse(artifactDir);
            
            write(artifactPath, artifactData);
            
            return Ok!(void, BuildError)();
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Failed to pull from remote cache: " ~ e.msg,
                ErrorCode.CacheLoadFailed
            );
            return Err!(void, BuildError)(error);
        }
    }
}


