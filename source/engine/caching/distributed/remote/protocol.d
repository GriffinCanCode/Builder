module engine.caching.distributed.remote.protocol;

import std.datetime : SysTime, Duration;
import core.time : seconds;
import std.conv : to;
import infrastructure.errors;

/// Remote cache protocol version
enum ProtocolVersion : ubyte
{
    V1 = 1  // Initial version
}

/// Cache artifact metadata
struct ArtifactMetadata
{
    string contentHash;     // BLAKE3 hash
    size_t size;            // Uncompressed size
    size_t compressedSize;  // Compressed size (0 if not compressed)
    SysTime timestamp;      // Creation time
    string workspace;       // Workspace identifier
    bool compressed;        // Whether artifact is compressed
    
    /// Serialize to binary format
    ubyte[] serialize() const pure @trusted
    {
        import std.bitmanip : write;
        import std.utf : toUTF8;
        
        ubyte[] buffer;
        buffer.reserve(256);
        
        // Content hash (length-prefixed string)
        immutable hashBytes = contentHash.toUTF8();
        buffer.write!uint(cast(uint)hashBytes.length, buffer.length);
        buffer ~= hashBytes;
        
        // Sizes
        buffer.write!ulong(size, buffer.length);
        buffer.write!ulong(compressedSize, buffer.length);
        
        // Timestamp (stdTime)
        buffer.write!long(timestamp.stdTime, buffer.length);
        
        // Workspace (length-prefixed string)
        immutable wsBytes = workspace.toUTF8();
        buffer.write!uint(cast(uint)wsBytes.length, buffer.length);
        buffer ~= wsBytes;
        
        // Flags
        buffer.write!ubyte(compressed ? 1 : 0, buffer.length);
        
        return buffer;
    }
    
    /// Deserialize from binary format
    static Result!(ArtifactMetadata, BuildError) deserialize(const(ubyte)[] data) @system
    {
        import std.bitmanip : read;
        import std.utf : toUTF16;
        
        if (data.length < 8)
        {
            auto error = new CacheError(
                "Invalid artifact metadata: insufficient data",
                ErrorCode.CacheCorrupted
            );
            return Err!(ArtifactMetadata, BuildError)(error);
        }
        
        ArtifactMetadata meta;
        size_t offset = 0;
        
        // Make a mutable copy for read operations
        ubyte[] mutableData = cast(ubyte[])data.dup;
        
        try
        {
            // Content hash
            auto hashSlice = mutableData[offset .. offset + 4];
            immutable hashLen = hashSlice.read!uint();
            offset += 4;
            if (offset + hashLen > data.length)
                throw new Exception("Invalid hash length");
            meta.contentHash = cast(string)data[offset .. offset + hashLen];
            offset += hashLen;
            
            // Sizes
            auto sizeSlice = mutableData[offset .. offset + 8];
            meta.size = sizeSlice.read!ulong();
            offset += 8;
            auto compSizeSlice = mutableData[offset .. offset + 8];
            meta.compressedSize = compSizeSlice.read!ulong();
            offset += 8;
            
            // Timestamp
            auto timeSlice = mutableData[offset .. offset + 8];
            immutable stdTime = timeSlice.read!long();
            offset += 8;
            meta.timestamp = SysTime(stdTime);
            
            // Workspace
            auto wsLenSlice = mutableData[offset .. offset + 4];
            immutable wsLen = wsLenSlice.read!uint();
            offset += 4;
            if (offset + wsLen > data.length)
                throw new Exception("Invalid workspace length");
            meta.workspace = cast(string)data[offset .. offset + wsLen];
            offset += wsLen;
            
            // Flags
            if (offset >= data.length)
                throw new Exception("Missing flags");
            meta.compressed = data[offset] != 0;
            
            return Ok!(ArtifactMetadata, BuildError)(meta);
        }
        catch (Exception e)
        {
            auto error = new CacheError(
                "Failed to deserialize artifact metadata: " ~ e.msg,
                ErrorCode.CacheCorrupted
            );
            return Err!(ArtifactMetadata, BuildError)(error);
        }
    }
}

/// Remote cache request types
enum RequestType : ubyte
{
    Get = 1,      // Fetch artifact
    Put = 2,      // Store artifact
    Head = 3,     // Check existence
    Delete = 4,   // Remove artifact
    Stats = 5     // Get cache statistics
}

/// Remote cache response status
enum ResponseStatus : ubyte
{
    Ok = 0,              // Success
    NotFound = 1,        // Artifact not found
    Unauthorized = 2,    // Authentication failed
    TooLarge = 3,        // Artifact exceeds size limit
    ServerError = 4,     // Internal server error
    InvalidRequest = 5   // Malformed request
}

/// Remote cache configuration
struct RemoteCacheConfig
{
    string url;                      // Server URL (http://host:port)
    string authToken;                // Authentication token
    Duration timeout = 30.seconds;   // Request timeout
    size_t maxRetries = 3;           // Retry attempts
    size_t maxConnections = 4;       // Connection pool size
    size_t maxArtifactSize = 100_000_000;  // 100 MB max per artifact
    bool enableCompression = true;   // Enable zstd compression
    bool enableMetrics = true;       // Track request metrics
    
    /// Load configuration from environment
    static RemoteCacheConfig fromEnvironment() @system
    {
        import std.process : environment;
        import std.algorithm : startsWith;
        import core.time : seconds;
        
        RemoteCacheConfig config;
        
        // Required: URL
        config.url = environment.get("BUILDER_REMOTE_CACHE_URL", "");
        
        // Optional: Auth token
        config.authToken = environment.get("BUILDER_REMOTE_CACHE_TOKEN", "");
        
        // Optional: Timeout (seconds)
        immutable timeoutStr = environment.get("BUILDER_REMOTE_CACHE_TIMEOUT");
        if (timeoutStr.length > 0)
            config.timeout = timeoutStr.to!size_t.seconds;
        
        // Optional: Max retries
        immutable retriesStr = environment.get("BUILDER_REMOTE_CACHE_RETRIES");
        if (retriesStr.length > 0)
            config.maxRetries = retriesStr.to!size_t;
        
        // Optional: Max connections
        immutable connsStr = environment.get("BUILDER_REMOTE_CACHE_CONNECTIONS");
        if (connsStr.length > 0)
            config.maxConnections = connsStr.to!size_t;
        
        // Optional: Max artifact size (bytes)
        immutable sizeStr = environment.get("BUILDER_REMOTE_CACHE_MAX_SIZE");
        if (sizeStr.length > 0)
            config.maxArtifactSize = sizeStr.to!size_t;
        
        // Optional: Compression
        immutable compressStr = environment.get("BUILDER_REMOTE_CACHE_COMPRESS");
        if (compressStr.length > 0)
            config.enableCompression = compressStr != "false" && compressStr != "0";
        
        return config;
    }
    
    /// Check if remote cache is enabled
    bool enabled() const pure @safe nothrow
    {
        return url.length > 0;
    }
}

/// Remote cache statistics
struct RemoteCacheStats
{
    size_t getRequests;      // Number of GET requests
    size_t putRequests;      // Number of PUT requests
    size_t headRequests;     // Number of HEAD requests
    size_t hits;             // Cache hits
    size_t misses;           // Cache misses
    size_t errors;           // Request errors
    size_t bytesUploaded;    // Total bytes sent
    size_t bytesDownloaded;  // Total bytes received
    float hitRate;           // Hit rate percentage
    float averageLatency;    // Average request latency (ms)
    
    /// Compute derived statistics
    void compute() pure @safe nothrow
    {
        immutable total = hits + misses;
        if (total > 0)
            hitRate = (hits * 100.0) / total;
        else
            hitRate = 0.0;
    }
}


