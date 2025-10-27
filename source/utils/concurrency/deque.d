module utils.concurrency.deque;

import core.atomic;
import std.algorithm;
import std.range;
import std.traits;

@safe:

/// Lock-free work-stealing deque using Chase-Lev algorithm
/// Optimized for single-producer (owner) and multiple-consumer (stealers) pattern
/// 
/// Thread Safety:
/// - Owner thread: can push/pop from bottom (local end) without locks
/// - Stealer threads: can steal from top (remote end) using lock-free CAS
/// - All operations are wait-free for the owner, lock-free for stealers
/// 
/// Performance:
/// - Zero contention on owner operations (most common case)
/// - Minimal CAS contention on steal operations
/// - Dynamic circular buffer with automatic resizing
/// - Cache-friendly: owner operations access bottom, stealers access top
/// 
/// References:
/// - Chase & Lev: "Dynamic Circular Work-Stealing Deque" (2005)
/// - Morrison & Afek: "Fast Concurrent Queues for x86 Processors" (2013)
struct WorkStealingDeque(T) if (is(T == class) || is(T == interface))
{
    private struct CircularArray
    {
        shared T[] buffer;
        immutable size_t logSize;  // log2(capacity) for fast modulo
        
        @disable this(this);  // Non-copyable
        
        this(size_t capacity) @trusted nothrow
        {
            import std.math : isPowerOf2;
            assert(isPowerOf2(capacity), "Capacity must be power of 2");
            
            buffer.length = capacity;
            
            // Calculate log2(capacity)
            size_t temp = capacity;
            size_t log = 0;
            while (temp > 1)
            {
                temp >>= 1;
                log++;
            }
            logSize = log;
        }
        
        @property size_t capacity() const pure nothrow @nogc @trusted
        {
            return cast(size_t)1 << logSize;
        }
        
        T get(size_t index) @trusted nothrow @nogc
        {
            immutable mask = capacity - 1;
            return cast(T)atomicLoad(buffer[index & mask]);
        }
        
        void put(size_t index, T item) @trusted nothrow @nogc
        {
            immutable mask = capacity - 1;
            atomicStore(buffer[index & mask], cast(shared)item);
        }
        
        CircularArray grow(size_t bottom, size_t top) @trusted
        {
            auto newArray = CircularArray(capacity * 2);
            foreach (i; top .. bottom)
                newArray.put(i, get(i));
            return newArray;
        }
    }
    
    private shared CircularArray* array;
    private shared long bottom;  // Bottom index (owner side)
    private shared long top;     // Top index (stealer side)
    
    @disable this(this);  // Non-copyable
    
    /// Initialize deque with initial capacity (must be power of 2)
    this(size_t capacity) @trusted
    {
        import std.math : isPowerOf2;
        assert(isPowerOf2(capacity), "Capacity must be power of 2");
        
        auto arr = new CircularArray(capacity);
        atomicStore(array, cast(shared)arr);
        atomicStore(bottom, cast(long)0);
        atomicStore(top, cast(long)0);
    }
    
    /// Push task to bottom (owner only)
    /// Owner can push without CAS - fastest path
    /// 
    /// Safety: @trusted because:
    /// 1. Only owner thread calls this (by design contract)
    /// 2. Atomic loads for top, relaxed for bottom (owner exclusive)
    /// 3. Array access is bounds-checked via capacity
    /// 4. Automatic growth when needed
    @trusted
    void push(T task) nothrow
    {
        auto b = atomicLoad!(MemoryOrder.raw)(bottom);
        auto t = atomicLoad!(MemoryOrder.acq)(top);
        auto arr = cast(CircularArray*)atomicLoad(array);
        
        immutable size = b - t;
        if (size >= arr.capacity)
        {
            // Grow array (rare path)
            auto newArray = arr.grow(b, t);
            atomicStore(array, cast(shared)&newArray);
            arr = &newArray;
        }
        
        arr.put(b, task);
        atomicFence!(MemoryOrder.rel)();
        atomicStore!(MemoryOrder.raw)(bottom, b + 1);
    }
    
    /// Pop task from bottom (owner only)
    /// Owner's fast path - no CAS in common case
    /// Returns null if empty
    /// 
    /// Safety: @trusted because:
    /// 1. Only owner thread calls this (by design contract)
    /// 2. Atomic operations ensure proper ordering
    /// 3. CAS only when racing with stealers
    /// 4. Bounds checking via capacity
    @trusted
    T pop() nothrow
    {
        auto b = atomicLoad!(MemoryOrder.raw)(bottom) - 1;
        auto arr = cast(CircularArray*)atomicLoad(array);
        atomicStore!(MemoryOrder.raw)(bottom, b);
        atomicFence!(MemoryOrder.seq)();
        
        auto t = atomicLoad!(MemoryOrder.raw)(top);
        
        if (b < t)
        {
            // Deque is empty
            atomicStore!(MemoryOrder.raw)(bottom, t);
            return null;
        }
        
        auto task = arr.get(b);
        
        if (b > t)
        {
            // More than one element, no race with stealers
            return task;
        }
        
        // Last element - race with stealers
        if (!cas(&top, t, t + 1))
        {
            // Lost race to stealer
            task = null;
        }
        
        atomicStore!(MemoryOrder.raw)(bottom, t + 1);
        return task;
    }
    
    /// Steal task from top (stealers only)
    /// Lock-free CAS-based stealing for multiple threads
    /// Returns null if empty or lost race
    /// 
    /// Safety: @trusted because:
    /// 1. Multiple stealers can call concurrently
    /// 2. CAS ensures only one stealer succeeds
    /// 3. Atomic loads ensure memory ordering
    /// 4. Array access is bounds-checked
    @trusted
    T steal() nothrow
    {
        auto t = atomicLoad!(MemoryOrder.acq)(top);
        atomicFence!(MemoryOrder.seq)();
        auto b = atomicLoad!(MemoryOrder.acq)(bottom);
        
        if (t >= b)
        {
            // Empty
            return null;
        }
        
        auto arr = cast(CircularArray*)atomicLoad(array);
        auto task = arr.get(t);
        
        if (!cas(&top, t, t + 1))
        {
            // Lost race to another stealer or owner
            return null;
        }
        
        return task;
    }
    
    /// Get approximate size (may be stale immediately)
    /// Used for load balancing heuristics
    @trusted
    size_t size() const nothrow @nogc
    {
        auto b = atomicLoad!(MemoryOrder.raw)(bottom);
        auto t = atomicLoad!(MemoryOrder.raw)(top);
        immutable diff = b - t;
        return diff < 0 ? 0 : cast(size_t)diff;
    }
    
    /// Check if approximately empty (may be stale)
    @trusted
    bool empty() const nothrow @nogc
    {
        auto b = atomicLoad!(MemoryOrder.raw)(bottom);
        auto t = atomicLoad!(MemoryOrder.raw)(top);
        return b <= t;
    }
    
    /// Get approximate capacity
    @trusted
    size_t capacity() const nothrow @nogc
    {
        auto arr = cast(CircularArray*)atomicLoad(array);
        return arr.capacity;
    }
}

/// Test basic push/pop operations
unittest
{
    import std.stdio;
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.deque - Basic push/pop");
    
    class Task
    {
        int value;
        this(int v) { value = v; }
    }
    
    auto deque = WorkStealingDeque!Task(4);
    
    // Push tasks
    deque.push(new Task(1));
    deque.push(new Task(2));
    deque.push(new Task(3));
    
    assert(deque.size() == 3);
    assert(!deque.empty());
    
    // Pop tasks (LIFO from owner)
    auto t3 = deque.pop();
    assert(t3 !is null && t3.value == 3);
    
    auto t2 = deque.pop();
    assert(t2 !is null && t2.value == 2);
    
    auto t1 = deque.pop();
    assert(t1 !is null && t1.value == 1);
    
    assert(deque.empty());
    assert(deque.pop() is null);
    
    writeln("\x1b[32m  ✓ Basic push/pop\x1b[0m");
}

/// Test stealing operations
unittest
{
    import std.stdio;
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.deque - Stealing");
    
    class Task
    {
        int value;
        this(int v) { value = v; }
    }
    
    auto deque = WorkStealingDeque!Task(4);
    
    // Push tasks
    deque.push(new Task(1));
    deque.push(new Task(2));
    deque.push(new Task(3));
    
    // Steal from top (FIFO from stealers)
    auto t1 = deque.steal();
    assert(t1 !is null && t1.value == 1);
    
    auto t2 = deque.steal();
    assert(t2 !is null && t2.value == 2);
    
    // Pop from bottom
    auto t3 = deque.pop();
    assert(t3 !is null && t3.value == 3);
    
    assert(deque.empty());
    assert(deque.steal() is null);
    
    writeln("\x1b[32m  ✓ Stealing\x1b[0m");
}

/// Test automatic growth
unittest
{
    import std.stdio;
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.deque - Growth");
    
    class Task
    {
        int value;
        this(int v) { value = v; }
    }
    
    auto deque = WorkStealingDeque!Task(2);
    assert(deque.capacity() == 2);
    
    // Push beyond capacity
    deque.push(new Task(1));
    deque.push(new Task(2));
    deque.push(new Task(3));  // Triggers growth
    
    assert(deque.capacity() == 4);
    assert(deque.size() == 3);
    
    // Verify all tasks intact
    assert(deque.steal() !is null);
    assert(deque.steal() !is null);
    assert(deque.pop() !is null);
    
    writeln("\x1b[32m  ✓ Growth\x1b[0m");
}

