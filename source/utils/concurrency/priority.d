module utils.concurrency.priority;

import std.algorithm;
import std.range;
import std.traits;
import core.atomic;

@system:

/// Priority level for task scheduling
enum Priority : ubyte
{
    Lowest = 0,
    Low = 64,
    Normal = 128,
    High = 192,
    Critical = 255
}

/// Task with priority and metadata for scheduling
/// Immutable after creation for thread-safe sharing
final class PriorityTask(T)
{
    immutable Priority priority;
    immutable size_t criticalPathCost;  // Estimated time on critical path
    immutable size_t depth;              // Depth in dependency graph
    immutable size_t dependents;         // Number of dependent tasks
    T payload;                            // Actual work
    
    this(T payload, Priority priority = Priority.Normal, 
         size_t criticalPathCost = 0, size_t depth = 0, size_t dependents = 0) pure nothrow @nogc
    {
        this.payload = payload;
        this.priority = priority;
        this.criticalPathCost = criticalPathCost;
        this.depth = depth;
        this.dependents = dependents;
    }
    
    /// Calculate dynamic priority score for scheduling
    /// Higher score = higher priority = scheduled first
    /// 
    /// Factors:
    /// 1. Base priority (explicit)
    /// 2. Critical path cost (longer path = higher priority)
    /// 3. Number of dependents (more dependents = higher priority)
    /// 4. Depth (deeper = lower priority, to exploit parallelism)
    ulong score() const pure nothrow @nogc
    {
        // Weight factors for priority calculation
        enum PRIORITY_WEIGHT = 1000;
        enum COST_WEIGHT = 100;
        enum DEPENDENT_WEIGHT = 10;
        enum DEPTH_PENALTY = 1;
        
        ulong s = cast(ulong)priority * PRIORITY_WEIGHT;
        s += criticalPathCost * COST_WEIGHT;
        s += dependents * DEPENDENT_WEIGHT;
        s -= depth * DEPTH_PENALTY;  // Penalty for depth to favor parallelism
        
        return s;
    }
    
    /// Compare tasks for priority ordering
    /// Returns: negative if this < other, 0 if equal, positive if this > other
    int opCmp(const PriorityTask other) const pure nothrow @nogc
    {
        immutable s1 = score();
        immutable s2 = other.score();
        
        if (s1 < s2) return -1;
        if (s1 > s2) return 1;
        
        // Tie-break by depth (prefer shallower for better parallelism)
        if (depth < other.depth) return 1;
        if (depth > other.depth) return -1;
        
        return 0;
    }
}

/// Thread-safe priority queue using binary heap
/// Lock-free reads, synchronized writes
/// Optimized for many reads, fewer writes pattern
struct PriorityQueue(T)
{
    private PriorityTask!T[] heap;
    private shared size_t count;
    
    @disable this(this);  // Non-copyable
    
    /// Initialize with capacity hint
    @system
    this(size_t capacity)
    {
        heap.reserve(capacity);
        atomicStore(count, cast(size_t)0);
    }
    
    /// Insert task with priority
    /// Thread-safe: Use external synchronization for concurrent inserts
    @system
    void insert(PriorityTask!T task)
    {
        heap ~= task;
        atomicOp!"+="(count, 1);
        
        // Bubble up
        size_t pos = heap.length - 1;
        while (pos > 0)
        {
            immutable parent = (pos - 1) / 2;
            if (heap[pos] <= heap[parent])
                break;
            
            swap(heap[pos], heap[parent]);
            pos = parent;
        }
    }
    
    /// Extract highest priority task
    /// Thread-safe: Use external synchronization for concurrent extracts
    /// Returns: null if empty
    @system
    PriorityTask!T extractMax()
    {
        if (heap.empty)
            return null;
        
        auto maxTask = heap[0];
        atomicOp!"-="(count, 1);
        
        if (heap.length == 1)
        {
            heap.length = 0;
            return maxTask;
        }
        
        // Move last to root and bubble down
        heap[0] = heap[$ - 1];
        heap.length--;
        
        size_t pos = 0;
        while (true)
        {
            immutable left = 2 * pos + 1;
            immutable right = 2 * pos + 2;
            size_t largest = pos;
            
            if (left < heap.length && heap[left] > heap[largest])
                largest = left;
            
            if (right < heap.length && heap[right] > heap[largest])
                largest = right;
            
            if (largest == pos)
                break;
            
            swap(heap[pos], heap[largest]);
            pos = largest;
        }
        
        return maxTask;
    }
    
    /// Peek at highest priority task without removing
    @system
    const(PriorityTask!T) peek() const
    {
        return heap.empty ? null : heap[0];
    }
    
    /// Get size atomically
    @system
    size_t size() const nothrow @nogc
    {
        return atomicLoad(count);
    }
    
    /// Check if empty
    @system
    bool empty() const nothrow @nogc
    {
        return atomicLoad(count) == 0;
    }
    
    /// Build heap from array of tasks
    /// Thread-safe: Use external synchronization
    @system
    void build(PriorityTask!T[] tasks)
    {
        heap = tasks.dup;
        atomicStore(count, heap.length);
        
        // Floyd's heap construction: O(n) instead of O(n log n)
        if (heap.length <= 1)
            return;
        
        // Start from last internal node
        foreach_reverse (i; 0 .. heap.length / 2)
        {
            heapifyDown(i);
        }
    }
    
    private void heapifyDown(size_t pos) @system
    {
        while (true)
        {
            immutable left = 2 * pos + 1;
            immutable right = 2 * pos + 2;
            size_t largest = pos;
            
            if (left < heap.length && heap[left] > heap[largest])
                largest = left;
            
            if (right < heap.length && heap[right] > heap[largest])
                largest = right;
            
            if (largest == pos)
                break;
            
            swap(heap[pos], heap[largest]);
            pos = largest;
        }
    }
    
    /// Clear all tasks
    @system
    void clear()
    {
        heap.length = 0;
        atomicStore(count, cast(size_t)0);
    }
}

/// Multi-level priority queue for fine-grained scheduling
/// Separate queues per priority level for O(1) selection
struct MultiLevelQueue(T)
{
    private PriorityTask!T[][] levels;
    private shared size_t[Priority.max + 1] counts;
    
    @disable this(this);  // Non-copyable
    
    /// Initialize with priority levels
    @system
    void initialize(size_t capacityPerLevel = 64)
    {
        levels.length = Priority.max + 1;
        foreach (ref level; levels)
            level.reserve(capacityPerLevel);
        
        foreach (i; 0 .. counts.length)
            atomicStore(counts[i], cast(size_t)0);
    }
    
    /// Enqueue task to appropriate priority level
    @system
    void enqueue(PriorityTask!T task)
    {
        immutable idx = task.priority;
        levels[idx] ~= task;
        atomicOp!"+="(counts[idx], 1);
    }
    
    /// Dequeue highest priority task available
    /// Returns: null if empty
    @system
    PriorityTask!T dequeue()
    {
        // Search from highest to lowest priority
        foreach_reverse (i; 0 .. levels.length)
        {
            if (atomicLoad(counts[i]) > 0 && !levels[i].empty)
            {
                auto task = levels[i][$ - 1];
                levels[i].length--;
                atomicOp!"-="(counts[i], 1);
                return task;
            }
        }
        return null;
    }
    
    /// Get total size across all levels
    @system
    size_t size() const nothrow @nogc
    {
        size_t total = 0;
        foreach (i; 0 .. counts.length)
            total += atomicLoad(counts[i]);
        return total;
    }
    
    /// Check if completely empty
    @system
    bool empty() const nothrow @nogc
    {
        return size() == 0;
    }
    
    /// Get size at specific priority level
    @system
    size_t sizeAt(Priority p) const nothrow @nogc
    {
        return atomicLoad(counts[p]);
    }
}

/// Calculate critical path cost for dependency graph
/// Returns: Map of task ID to critical path cost
size_t[string] calculateCriticalPath(Node)(Node[] nodes, size_t delegate(Node) @system getCost, string delegate(Node) @system getId, Node[] delegate(Node) @system getDeps) @system
{
    size_t[string] costs;
    bool[string] visited;
    
    size_t visit(Node node) @system
    {
        auto id = getId(node);
        if (id in visited)
            return costs[id];
        
        visited[id] = true;
        
        // Get max cost of dependencies
        size_t maxDepCost = 0;
        foreach (dep; getDeps(node))
        {
            immutable depCost = visit(dep);
            maxDepCost = max(maxDepCost, depCost);
        }
        
        // Critical path cost = own cost + max dependency cost
        immutable cost = getCost(node) + maxDepCost;
        costs[id] = cost;
        return cost;
    }
    
    foreach (node; nodes)
        visit(node);
    
    return costs;
}

/// Test priority task comparison
unittest
{
    import std.stdio;
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.priority - Task comparison");
    
    auto t1 = new PriorityTask!int(1, Priority.Normal, 100, 1, 5);
    auto t2 = new PriorityTask!int(2, Priority.High, 50, 2, 3);
    auto t3 = new PriorityTask!int(3, Priority.Normal, 200, 1, 10);
    
    assert(t2 > t1);  // Higher base priority
    assert(t3 > t1);  // Higher critical path cost
    assert(t3 < t2);  // Base priority dominates
    
    writeln("\x1b[32m  ✓ Task comparison\x1b[0m");
}

/// Test priority queue operations
unittest
{
    import std.stdio;
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.priority - Priority queue");
    
    auto queue = PriorityQueue!int(16);
    
    queue.insert(new PriorityTask!int(1, Priority.Normal));
    queue.insert(new PriorityTask!int(2, Priority.High));
    queue.insert(new PriorityTask!int(3, Priority.Critical));
    queue.insert(new PriorityTask!int(4, Priority.Low));
    
    assert(queue.size() == 4);
    
    // Should extract in priority order
    auto t1 = queue.extractMax();
    assert(t1.payload == 3);  // Critical
    
    auto t2 = queue.extractMax();
    assert(t2.payload == 2);  // High
    
    auto t3 = queue.extractMax();
    assert(t3.payload == 1);  // Normal
    
    auto t4 = queue.extractMax();
    assert(t4.payload == 4);  // Low
    
    assert(queue.empty());
    
    writeln("\x1b[32m  ✓ Priority queue\x1b[0m");
}

/// Test multi-level queue
unittest
{
    import std.stdio;
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.priority - Multi-level queue");
    
    auto queue = MultiLevelQueue!int();
    queue.initialize(8);
    
    queue.enqueue(new PriorityTask!int(1, Priority.Normal));
    queue.enqueue(new PriorityTask!int(2, Priority.High));
    queue.enqueue(new PriorityTask!int(3, Priority.Low));
    queue.enqueue(new PriorityTask!int(4, Priority.Critical));
    
    assert(queue.size() == 4);
    assert(queue.sizeAt(Priority.Critical) == 1);
    
    // Should dequeue in priority order
    assert(queue.dequeue().payload == 4);  // Critical
    assert(queue.dequeue().payload == 2);  // High
    assert(queue.dequeue().payload == 1);  // Normal
    assert(queue.dequeue().payload == 3);  // Low
    
    assert(queue.empty());
    
    writeln("\x1b[32m  ✓ Multi-level queue\x1b[0m");
}

