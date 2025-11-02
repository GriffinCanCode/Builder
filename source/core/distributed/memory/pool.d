module core.distributed.memory.pool;

import core.sync.mutex : Mutex;
import core.atomic;
import std.algorithm : min;

/// Object pool for reusable allocations
/// Reduces GC pressure by reusing objects
/// 
/// Design:
/// - Free-list based
/// - Thread-safe acquire/release
/// - Configurable max size
/// - Auto-growing up to limit
/// 
/// Use Cases:
/// - ActionRequest reuse
/// - Message buffer reuse
/// - Temporary data structures
template ObjectPool(T)
{
    final class ObjectPool
    {
        private T[] available;
        private Mutex mutex;
        private size_t maxSize;
        private shared size_t totalCreated;
        private shared size_t currentlyActive;
        
        /// Create pool with max size
        this(size_t maxSize = 256) @trusted
        {
            this.maxSize = maxSize;
            this.mutex = new Mutex();
            atomicStore(totalCreated, cast(size_t)0);
            atomicStore(currentlyActive, cast(size_t)0);
        }
        
        /// Acquire object from pool
        T acquire() @trusted
        {
            synchronized (mutex)
            {
                if (available.length > 0)
                {
                    auto obj = available[$ - 1];
                    available = available[0 .. $ - 1];
                    atomicOp!"+="(currentlyActive, 1);
                    return obj;
                }
            }
            
            // Create new object
            auto obj = createNew();
            atomicOp!"+="(totalCreated, 1);
            atomicOp!"+="(currentlyActive, 1);
            
            return obj;
        }
        
        /// Release object back to pool
        void release(T obj) @trusted
        {
            if (obj is null)
                return;
            
            // Reset object state
            static if (__traits(hasMember, T, "reset"))
                obj.reset();
            
            synchronized (mutex)
            {
                if (available.length < maxSize)
                {
                    available ~= obj;
                }
                // else: let it be GC'd
            }
            
            atomicOp!"-="(currentlyActive, 1);
        }
        
        /// Preallocate objects
        void preallocate(size_t count) @trusted
        {
            count = min(count, maxSize);
            
            synchronized (mutex)
            {
                while (available.length < count)
                {
                    auto obj = createNew();
                    atomicOp!"+="(totalCreated, 1);
                    available ~= obj;
                }
            }
        }
        
        /// Get pool statistics
        struct PoolStats
        {
            size_t available;
            size_t totalCreated;
            size_t currentlyActive;
            size_t maxSize;
        }
        
        PoolStats getStats() @trusted
        {
            synchronized (mutex)
            {
                return PoolStats(
                    available.length,
                    atomicLoad(totalCreated),
                    atomicLoad(currentlyActive),
                    maxSize
                );
            }
        }
        
        private:
        
        /// Create new instance
        static if (is(T == class))
        {
            T createNew() @trusted
            {
                return new T();
            }
        }
        else
        {
            T createNew() @trusted
            {
                return new T;
            }
        }
    }
}

/// RAII wrapper for pooled object
struct Pooled(T)
{
    private T obj;
    private ObjectPool!T pool;
    
    @disable this(this);  // Non-copyable
    
    this(ObjectPool!T pool) @trusted
    {
        this.pool = pool;
        this.obj = pool.acquire();
    }
    
    ~this() @trusted
    {
        if (pool !is null && obj !is null)
        {
            pool.release(obj);
        }
    }
    
    /// Get underlying object
    T get() @safe nothrow @nogc
    {
        return obj;
    }
    
    /// Convenience: forward to object
    alias get this;
}

/// Specialized: Byte buffer pool for network I/O
final class BufferPool
{
    private ubyte[][] available;
    private Mutex mutex;
    private size_t bufferSize;
    private size_t maxBuffers;
    private shared size_t totalCreated;
    
    this(size_t bufferSize = 64 * 1024, size_t maxBuffers = 128) @trusted
    {
        this.bufferSize = bufferSize;
        this.maxBuffers = maxBuffers;
        this.mutex = new Mutex();
        atomicStore(totalCreated, cast(size_t)0);
    }
    
    /// Acquire buffer
    ubyte[] acquire() @trusted
    {
        synchronized (mutex)
        {
            if (available.length > 0)
            {
                auto buffer = available[$ - 1];
                available = available[0 .. $ - 1];
                return buffer;
            }
        }
        
        // Allocate new buffer
        auto buffer = new ubyte[bufferSize];
        atomicOp!"+="(totalCreated, 1);
        
        return buffer;
    }
    
    /// Release buffer back to pool
    void release(ubyte[] buffer) @trusted
    {
        if (buffer is null || buffer.length != bufferSize)
            return;
        
        // Zero out buffer (security)
        buffer[] = 0;
        
        synchronized (mutex)
        {
            if (available.length < maxBuffers)
            {
                available ~= buffer;
            }
        }
    }
    
    /// Preallocate buffers
    void preallocate(size_t count) @trusted
    {
        count = min(count, maxBuffers);
        
        synchronized (mutex)
        {
            while (available.length < count)
            {
                auto buffer = new ubyte[bufferSize];
                atomicOp!"+="(totalCreated, 1);
                available ~= buffer;
            }
        }
    }
    
    struct PoolStats
    {
        size_t available;
        size_t totalCreated;
        size_t bufferSize;
        size_t maxBuffers;
        size_t totalMemory;
    }
    
    PoolStats getStats() @trusted
    {
        synchronized (mutex)
        {
            return PoolStats(
                available.length,
                atomicLoad(totalCreated),
                bufferSize,
                maxBuffers,
                atomicLoad(totalCreated) * bufferSize
            );
        }
    }
}



