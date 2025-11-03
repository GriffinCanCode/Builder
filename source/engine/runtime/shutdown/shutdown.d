module engine.runtime.shutdown.shutdown;

import std.stdio;
import core.sync.mutex;
import core.stdc.signal;
import engine.caching.targets.cache : BuildCache;
import engine.caching.actions.action : ActionCache;

/// Shutdown coordinator for explicit resource cleanup
/// 
/// Design Philosophy:
/// - Never rely on destructors for critical cleanup (GC timing is unpredictable)
/// - Explicit is better than implicit
/// - Idempotent operations (safe to call multiple times)
/// - Signal-safe cleanup for abnormal termination
/// - Dependency injection through BuildServices
/// 
/// Usage:
/// ```d
/// // Get from BuildServices:
/// auto coordinator = services.shutdownCoordinator;
/// 
/// // Register resources:
/// coordinator.registerCache(myCache);
/// 
/// // Explicit cleanup:
/// coordinator.shutdown();
/// ```
final class ShutdownCoordinator
{
    private Mutex mutex;
    private bool isShutdown = false;
    private BuildCache[] buildCaches;
    private ActionCache[] actionCaches;
    private void delegate()[] cleanupCallbacks;
    
    /// Constructor for dependency injection
    this() nothrow
    {
        try
        {
            this.mutex = new Mutex();
        }
        catch (Exception)
        {
            // Fatal: can't create mutex
        }
    }
    
    /// Register caches for cleanup (overloaded for BuildCache and ActionCache)
    void registerCache(BuildCache cache) @trusted nothrow
    {
        registerResource(cache, buildCaches);
    }
    
    void registerCache(ActionCache cache) @trusted nothrow
    {
        registerResource(cache, actionCaches);
    }
    
    /// Generic resource registration helper
    private void registerResource(T)(T resource, ref T[] container) @trusted nothrow
    {
        if (resource is null) return;
        
        try
        {
            synchronized (mutex)
            {
                if (!isShutdown) container ~= resource;
            }
        }
        catch (Exception) { /* Best effort */ }
    }
    
    /// Register a custom cleanup callback
    void registerCleanup(void delegate() callback) @trusted nothrow
    {
        registerResource(callback, cleanupCallbacks);
    }
    
    /// Explicit shutdown - flushes all registered caches
    /// Idempotent: safe to call multiple times
    void shutdown() @trusted nothrow
    {
        try
        {
            synchronized (mutex)
            {
                if (isShutdown)
                    return;
                
                isShutdown = true;
                
                // Close all BuildCache instances
                foreach (cache; buildCaches)
                    closeResource(cache, "BuildCache");
                
                // Close all ActionCache instances
                foreach (cache; actionCaches)
                    closeResource(cache, "ActionCache");
                
                // Execute custom cleanup callbacks
                foreach (callback; cleanupCallbacks)
                    executeCallback(callback);
                
                // Clear all registrations
                buildCaches = [];
                actionCaches = [];
                cleanupCallbacks = [];
            }
        }
        catch (Exception)
        {
            // Even if synchronization fails, we tried
        }
    }
    
    /// Check if already shut down
    bool isShutDown() @trusted nothrow
    {
        try
        {
            synchronized (mutex) { return isShutdown; }
        }
        catch (Exception) { return true; }
    }
    
    /// Helper to close a resource with error handling
    private void closeResource(T)(T resource, string resourceType) @trusted nothrow
    {
        if (resource is null) return;
        
        try { resource.close(); }
        catch (Exception e)
        {
            try { writeln("Warning: Failed to close ", resourceType, ": ", e.msg); }
            catch (Exception) {}
        }
    }
    
    /// Helper to execute callback with error handling
    private void executeCallback(void delegate() callback) @trusted nothrow
    {
        if (callback is null) return;
        
        try { callback(); }
        catch (Exception e)
        {
            try { writeln("Warning: Cleanup callback failed: ", e.msg); }
            catch (Exception) {}
        }
    }
}

/// Signal handler for abnormal termination (SIGINT, SIGTERM, etc)
extern(C) void signalHandler(int sig) nothrow @nogc @system
{
    // Import write for direct system call (printf not async-signal-safe)
    import core.sys.posix.unistd : write;
    
    // Note: Cannot flush caches here as signal handlers must be @nogc
    // Best effort shutdown will happen automatically via destructors
    
    // Re-raise signal for default handler
    import core.stdc.signal : signal, SIG_DFL, raise;
    signal(sig, SIG_DFL);
    raise(sig);
}

/// Initialize signal handlers for graceful shutdown
void installSignalHandlers() @trusted nothrow
{
    import core.stdc.signal : signal, SIGINT, SIGTERM;
    
    try
    {
        signal(SIGINT, &signalHandler);
        signal(SIGTERM, &signalHandler);
        
        version(Posix)
        {
            import core.sys.posix.signal : SIGHUP;
            signal(SIGHUP, &signalHandler);
        }
    }
    catch (Exception)
    {
        // Best effort - continue without signal handlers
    }
}

/// RAII guard for automatic shutdown coordination
/// Ensures cleanup even with early returns or exceptions
struct ShutdownGuard
{
    private ShutdownCoordinator coordinator;
    private bool released = false;
    
    @disable this(this); // No copying
    
    /// Create guard with coordinator from BuildServices
    this(ShutdownCoordinator coordinator) @safe nothrow @nogc
    {
        this.coordinator = coordinator;
    }
    
    /// Destructor: ensure cleanup
    ~this() @trusted nothrow
    {
        if (!released && coordinator !is null)
        {
            coordinator.shutdown();
        }
    }
    
    /// Manual release (prevents destructor cleanup)
    void release() @safe nothrow @nogc
    {
        released = true;
    }
}


