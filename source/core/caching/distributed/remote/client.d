module core.caching.distributed.remote.client;

import std.datetime : Clock, Duration, dur;
import std.file : exists, read, write, remove;
import std.path : buildPath;
import std.algorithm : min;
import core.sync.mutex;
import core.caching.distributed.remote.protocol;
import core.caching.distributed.remote.transport;
import utils.files.hash : FastHash;
import utils.security.integrity : IntegrityValidator;
import utils.compression.compress;
import errors;

/// Remote cache client with connection pooling and retry logic
/// Provides high-level interface for artifact storage and retrieval
final class RemoteCacheClient
{
    private RemoteCacheConfig config;
    private HttpTransport transport;
    private RemoteCacheStats stats;
    private Mutex statsMutex;
    private IntegrityValidator validator;
    
    /// Constructor
    this(RemoteCacheConfig config) @trusted
    {
        this.config = config;
        this.transport = new HttpTransport(config);
        this.statsMutex = new Mutex();
        
        // Initialize integrity validator for workspace isolation
        import std.file : getcwd;
        this.validator = IntegrityValidator.fromEnvironment(getcwd());
    }
    
    /// Destructor
    ~this() @trusted
    {
        // Transport cleanup handled by its destructor
    }
    
    /// Fetch artifact from remote cache
    /// Returns: artifact data or error
    Result!(ubyte[], BuildError) get(string contentHash) @trusted
    {
        if (!config.enabled())
        {
            auto error = new CacheError(
                "Remote cache not configured",
                ErrorCode.CacheDisabled
            );
            return Err!(ubyte[], BuildError)(error);
        }
        
        immutable startTime = Clock.currStdTime();
        
        // Execute with retry logic
        auto result = executeWithRetry(() => transport.get(contentHash));
        
        synchronized (statsMutex)
        {
            stats.getRequests++;
            
            if (result.isOk)
            {
                stats.hits++;
                auto data = result.unwrap();
                stats.bytesDownloaded += data.length;
                
                // Decompress if needed (check first byte for compression marker)
                if (data.length > 0 && data[0] == 0xFD)  // Zstd magic number
                {
                    auto compressor = new Compressor();
                    auto decompressResult = compressor.decompress(data, CompressionAlgorithm.Zstd);
                    
                    if (decompressResult.isOk)
                        return Ok!(ubyte[], BuildError)(decompressResult.unwrap());
                    // If decompression fails, return compressed data (fallback)
                }
                else if (data.length > 0 && data[0] == 0x04)  // LZ4 magic number
                {
                    auto compressor = new Compressor();
                    auto decompressResult = compressor.decompress(data, CompressionAlgorithm.Lz4);
                    
                    if (decompressResult.isOk)
                        return Ok!(ubyte[], BuildError)(decompressResult.unwrap());
                }
            }
            else
            {
                stats.misses++;
                
                // Check if it's truly missing vs error
                auto error = result.unwrapErr();
                if (auto cacheErr = cast(CacheError)error)
                {
                    if (cacheErr.code != ErrorCode.CacheNotFound)
                        stats.errors++;
                }
                else
                {
                    stats.errors++;
                }
            }
            
            updateLatency(startTime);
            stats.compute();
        }
        
        return result;
    }
    
    /// Store artifact in remote cache
    Result!BuildError put(string contentHash, const(ubyte)[] data) @trusted
    {
        if (!config.enabled())
        {
            BuildError error = new CacheError(
                "Remote cache not configured",
                ErrorCode.CacheDisabled
            );
            return Result!BuildError.err(error);
        }
        
        // Check size limit
        if (data.length > config.maxArtifactSize)
        {
            BuildError error = new CacheError(
                "Artifact exceeds maximum size",
                ErrorCode.CacheTooLarge
            );
            return Result!BuildError.err(error);
        }
        
        immutable startTime = Clock.currStdTime();
        
        // Compress if enabled and beneficial
        ubyte[] payload = cast(ubyte[])data;
        if (config.enableCompression && data.length > 1024)
        {
            auto compressor = new Compressor(CompressionAlgorithm.Zstd, StandardLevel.Default);
            auto compressResult = compressor.compress(data);
            
            if (compressResult.isOk)
            {
                auto compressed = compressResult.unwrap();
                
                // Only use compressed version if it's significantly smaller (>5% reduction)
                if (Compressor.shouldCompress(compressed.originalSize, compressed.compressedSize))
                {
                    payload = compressed.data;
                }
            }
            // On compression failure, fallback to uncompressed (already set)
        }
        
        // Execute with retry logic
        auto result = executeWithRetry!BuildError(() @trusted {
            Result!(BuildError, BuildError) r = transport.put(contentHash, payload);
            return r;
        });
        
        synchronized (statsMutex)
        {
            stats.putRequests++;
            
            if (result.isOk)
                stats.bytesUploaded += payload.length;
            else
                stats.errors++;
            
            updateLatency(startTime);
            stats.compute();
        }
        
        return result;
    }
    
    /// Check if artifact exists in remote cache
    Result!(bool, BuildError) has(string contentHash) @trusted
    {
        if (!config.enabled())
        {
            auto error = new CacheError(
                "Remote cache not configured",
                ErrorCode.CacheDisabled
            );
            return Err!(bool, BuildError)(error);
        }
        
        immutable startTime = Clock.currStdTime();
        
        // Execute with retry logic
        auto result = executeWithRetry(() => transport.head(contentHash));
        
        synchronized (statsMutex)
        {
            stats.headRequests++;
            
            if (result.isOk)
            {
                if (result.unwrap())
                    stats.hits++;
                else
                    stats.misses++;
            }
            else
            {
                stats.errors++;
            }
            
            updateLatency(startTime);
            stats.compute();
        }
        
        return result;
    }
    
    /// Get cache statistics
    RemoteCacheStats getStats() @trusted
    {
        synchronized (statsMutex)
        {
            return stats;
        }
    }
    
    /// Reset statistics
    void resetStats() @trusted
    {
        synchronized (statsMutex)
        {
            stats = RemoteCacheStats.init;
        }
    }
    
    private void updateLatency(long startTime) nothrow
    {
        try
        {
            immutable endTime = Clock.currStdTime();
            immutable latency = (endTime - startTime) / 10_000.0; // Convert to milliseconds
            
            // Exponential moving average
            immutable alpha = 0.2;
            if (stats.averageLatency == 0.0)
                stats.averageLatency = latency;
            else
                stats.averageLatency = alpha * latency + (1.0 - alpha) * stats.averageLatency;
        }
        catch (Exception) {}
    }
    
    private Result!(T, BuildError) executeWithRetry(T)(
        Result!(T, BuildError) delegate() @trusted operation
    ) @trusted
    {
        size_t attempts = 0;
        Result!(T, BuildError) lastResult;
        
        while (attempts < config.maxRetries)
        {
            lastResult = operation();
            
            if (lastResult.isOk)
                return lastResult;
            
            // Check if error is retryable
            auto error = lastResult.unwrapErr();
            if (!isRetryable(error))
                return lastResult;
            
            attempts++;
            
            // Exponential backoff with jitter
            if (attempts < config.maxRetries)
            {
                import std.random : uniform;
                import core.thread : Thread;
                import core.time : msecs;
                
                immutable baseDelay = 100 * (1 << attempts); // 100ms, 200ms, 400ms, ...
                immutable jitter = uniform(0, baseDelay / 4);
                immutable delay = baseDelay + jitter;
                
                Thread.sleep(delay.msecs);
            }
        }
        
        return lastResult;
    }
    
    private bool isRetryable(BuildError error) pure @trusted nothrow
    {
        try
        {
            // Network errors are retryable
            if (cast(NetworkError)error !is null)
                return true;
            
            // Some cache errors are retryable
            if (auto cacheErr = cast(CacheError)error)
            {
                return cacheErr.code == ErrorCode.NetworkError ||
                       cacheErr.code == ErrorCode.CacheTimeout;
            }
            
            return false;
        }
        catch (Exception)
        {
            return false;
        }
    }
}


