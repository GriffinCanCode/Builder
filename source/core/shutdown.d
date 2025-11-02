module core.shutdown;

import std.stdio;
import core.sync.mutex;
import core.stdc.signal;
import core.caching.cache : BuildCache;
import core.caching.action : ActionCache;

/// Shutdown coordinator for explicit resource cleanup
/// 
/// Design Philosophy:
/// - Never rely on destructors for critical cleanup (GC timing is unpredictable)
/// - Explicit is better than implicit
/// - Idempotent operations (safe to call multiple times)
/// - Signal-safe cleanup for abnormal termination
/// 
/// Usage:
/// ```d
/// auto coordinator = ShutdownCoordinator.instance();
/// coordinator.registerCache(myCache);
/// // ... do work ...
/// coordinator.shutdown(); // Explicit cleanup
/// ```
final class ShutdownCoordinator
{
    private static __gshared ShutdownCoordinator _instance;
    private static __gshared Mutex _instanceMutex;
    
    private Mutex mutex;
    private bool isShutdown = false;
    private BuildCache[] buildCaches;
    private ActionCache[] actionCaches;
    private void delegate()[] cleanupCallbacks;
    
    /// Shared static constructor: Initialize singleton
    shared static this()
    {
        _instanceMutex = new Mutex();
    }
    
    /// Get singleton instance (thread-safe double-checked locking)
    static ShutdownCoordinator instance() @trusted nothrow
    {
        if (_instance is null)
        {
            try
            {
                synchronized (_instanceMutex)
                {
                    if (_instance is null)
                    {
                        _instance = new ShutdownCoordinator();
                    }
                }
            }
            catch (Exception)
            {
                // Fallback: create new instance (shouldn't happen)
                try
                {
                    _instance = new ShutdownCoordinator();
                }
                catch (Exception)
                {
                    // Fatal: can't create coordinator
                }
            }
        }
        return _instance;
    }
    
    private this() nothrow
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
    
    /// Register a BuildCache for cleanup
    void registerCache(BuildCache cache) @trusted nothrow
    {
        if (cache is null)
            return;
        
        try
        {
            synchronized (mutex)
            {
                if (!isShutdown)
                {
                    buildCaches ~= cache;
                }
            }
        }
        catch (Exception)
        {
            // Best effort
        }
    }
    
    /// Register an ActionCache for cleanup
    void registerCache(ActionCache cache) @trusted nothrow
    {
        if (cache is null)
            return;
        
        try
        {
            synchronized (mutex)
            {
                if (!isShutdown)
                {
                    actionCaches ~= cache;
                }
            }
        }
        catch (Exception)
        {
            // Best effort
        }
    }
    
    /// Register a custom cleanup callback
    void registerCleanup(void delegate() callback) @trusted nothrow
    {
        if (callback is null)
            return;
        
        try
        {
            synchronized (mutex)
            {
                if (!isShutdown)
                {
                    cleanupCallbacks ~= callback;
                }
            }
        }
        catch (Exception)
        {
            // Best effort
        }
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
                {
                    if (cache !is null)
                    {
                        try
                        {
                            cache.close();
                        }
                        catch (Exception e)
                        {
                            try
                            {
                                writeln("Warning: Failed to close BuildCache: ", e.msg);
                            }
                            catch (Exception) {}
                        }
                    }
                }
                
                // Close all ActionCache instances
                foreach (cache; actionCaches)
                {
                    if (cache !is null)
                    {
                        try
                        {
                            cache.close();
                        }
                        catch (Exception e)
                        {
                            try
                            {
                                writeln("Warning: Failed to close ActionCache: ", e.msg);
                            }
                            catch (Exception) {}
                        }
                    }
                }
                
                // Execute custom cleanup callbacks
                foreach (callback; cleanupCallbacks)
                {
                    if (callback !is null)
                    {
                        try
                        {
                            callback();
                        }
                        catch (Exception e)
                        {
                            try
                            {
                                writeln("Warning: Cleanup callback failed: ", e.msg);
                            }
                            catch (Exception) {}
                        }
                    }
                }
                
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
            synchronized (mutex)
            {
                return isShutdown;
            }
        }
        catch (Exception)
        {
            return true; // Assume shut down if we can't check
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

/// Shared static destructor: ensure cleanup on program exit
/// This is a last-resort fallback - explicit shutdown() is preferred
shared static ~this()
{
    try
    {
        auto coordinator = ShutdownCoordinator.instance();
        if (coordinator !is null)
        {
            coordinator.shutdown();
        }
    }
    catch (Exception)
    {
        // Best effort - ignore errors during program termination
    }
}

/// RAII guard for automatic shutdown coordination
/// Ensures cleanup even with early returns or exceptions
struct ShutdownGuard
{
    private ShutdownCoordinator coordinator;
    private bool released = false;
    
    @disable this(this); // No copying
    
    /// Create guard and register with coordinator
    static ShutdownGuard create() @trusted nothrow
    {
        ShutdownGuard guard;
        guard.coordinator = ShutdownCoordinator.instance();
        return guard;
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

