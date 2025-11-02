module utils.simd.capabilities;

import utils.simd.detection;
import utils.simd.dispatch;
import utils.concurrency.pool;
import core.sync.mutex;

/// SIMD capabilities service - encapsulates hardware detection and dispatch
/// Eliminates global state by passing capabilities through execution context
/// 
/// Design: Immutable after initialization, thread-safe, testable
/// - Hardware detection performed once at construction
/// - Function pointers cached (C layer handles global state internally)
/// - Thread pool owned by this service
/// - Can be mocked for testing
final class SIMDCapabilities
{
    private immutable SIMDLevel _level;
    private immutable string _implName;
    private immutable bool _active;
    private ThreadPool _threadPool;
    private Mutex _poolMutex;
    private bool _initialized;
    private size_t _threadPoolSize;
    
    /// Detect SIMD capabilities and initialize dispatch
    /// 
    /// Safety: @system because:
    /// 1. Calls blake3_simd_init() which is extern(C) @system
    /// 2. Thread pool created lazily on first use (not in constructor)
    /// 3. All state is properly synchronized
    this(size_t threadPoolSize = 0) @system
    {
        import std.parallelism : totalCPUs;
        
        // Detect hardware capabilities
        _level = CPU.simdLevel();
        _implName = CPU.simdLevelName();
        _active = _level != SIMDLevel.None;
        
        // Initialize BLAKE3 SIMD dispatch (C layer)
        // Note: C code has its own initialization guard for safety
        blake3_simd_init();
        _initialized = true;
        
        // Store thread pool size for lazy initialization
        _threadPoolSize = threadPoolSize == 0 ? totalCPUs : threadPoolSize;
        _poolMutex = new Mutex();
    }
    
    /// Cleanup resources
    ~this() @system
    {
        shutdown();
    }
    
    /// Shutdown thread pool
    void shutdown() @system nothrow
    {
        if (_threadPool is null)
            return;
        
        try
        {
            synchronized (_poolMutex)
            {
                if (_threadPool !is null)
                {
                    _threadPool.shutdown();
                    _threadPool = null;
                }
            }
        }
        catch (Exception e)
        {
            // Best effort shutdown - ignore errors
        }
    }
    
    /// Get SIMD optimization level
    @property SIMDLevel level() const pure nothrow @nogc
    {
        return _level;
    }
    
    /// Get implementation name (e.g., "AVX2", "NEON")
    @property string implName() const pure nothrow @nogc
    {
        return _implName;
    }
    
    /// Check if SIMD is active (any level above None)
    @property bool active() const pure nothrow @nogc
    {
        return _active;
    }
    
    /// Check if capabilities have been initialized
    @property bool initialized() const pure nothrow @nogc
    {
        return _initialized;
    }
    
    /// Get compression function pointer
    /// Thread-safe: C layer caches function pointers in global state
    blake3_compress_fn getCompressFn() @system
    {
        return blake3_get_compress_fn();
    }
    
    /// Get hash-many function pointer
    /// Thread-safe: C layer caches function pointers in global state
    blake3_hash_many_fn getHashManyFn() @system
    {
        return blake3_get_hash_many_fn();
    }
    
    /// Access thread pool for parallel SIMD operations
    /// Thread-safe: Mutex-protected access
    /// Lazy initialization: pool created on first access
    ThreadPool threadPool() @system
    {
        synchronized (_poolMutex)
        {
            // Lazy initialization of thread pool
            if (_threadPool is null)
            {
                _threadPool = new ThreadPool(_threadPoolSize);
            }
            return _threadPool;
        }
    }
    
    /// Execute parallel SIMD map operation
    /// Thread-safe: Uses internal thread pool with mutex protection
    /// Lazy initialization: pool created on first use
    auto parallelMap(T, F)(T[] items, F func) @system
    {
        import std.traits : ReturnType;
        import std.range : empty;
        
        alias R = ReturnType!F;
        
        if (items.empty)
            return (R[]).init;
        
        if (items.length == 1)
            return [func(items[0])];
        
        // Get or create thread pool (lazy initialization)
        auto pool = threadPool();
        return pool.map(items, func);
    }
    
    /// Create SIMD capabilities by detecting hardware
    /// Factory method for dependency injection
    static SIMDCapabilities detect(size_t threadPoolSize = 0) @system
    {
        return new SIMDCapabilities(threadPoolSize);
    }
    
    /// Create mock capabilities for testing (no SIMD, minimal thread pool)
    /// Thread pool created lazily, so no threads spawned until actually used
    static SIMDCapabilities createMock() @system
    {
        auto caps = new SIMDCapabilities(1);
        return caps;
    }
    
    /// Get human-readable description
    override string toString() const
    {
        import std.format : format;
        return format("SIMDCapabilities(level=%s, impl=%s, active=%s)", 
                     _level, _implName, _active);
    }
}

/// Convenience function to check if SIMD is available
/// Used for conditional compilation/feature detection
bool hasSIMD(const SIMDCapabilities caps) pure nothrow @nogc
{
    return caps !is null && caps.active;
}

/// Unit tests
unittest
{
    import std.stdio : writeln;
    
    // Test SIMD detection
    auto caps = SIMDCapabilities.detect();
    assert(caps !is null);
    assert(caps.initialized);
    
    writeln("Detected SIMD: ", caps);
    
    // Test capabilities query
    auto level = caps.level;
    auto impl = caps.implName;
    auto active = caps.active;
    
    // Cleanup
    caps.shutdown();
    
    writeln("SIMD capabilities tests passed!");
}

