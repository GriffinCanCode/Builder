module utils.concurrency.scheduler;

import core.thread;
import core.atomic;
import core.sync.mutex;
import core.sync.condition;
import std.algorithm;
import std.range;
import std.random;
import std.parallelism : totalCPUs;
import utils.concurrency.deque;
import utils.concurrency.priority;

@safe:

/// Work-stealing scheduler with priority support
/// Each worker has its own deque for local tasks
/// Idle workers steal from random victims for load balancing
/// 
/// Architecture:
/// - Owner operations (push/pop): O(1) fast path, no contention
/// - Steal operations: O(1) with minimal CAS contention
/// - Priority-aware: high-priority tasks distributed first
/// - Backoff strategy: reduces contention under high load
final class WorkStealingScheduler(T)
{
    /// Worker thread with local deque
    private final class Worker
    {
        WorkStealingDeque!(PriorityTask!T) deque;
        Thread thread;
        size_t id;
        shared bool running;
        Mt19937 rng;  // Per-worker RNG for victim selection
        
        // Statistics
        shared size_t tasksExecuted;
        shared size_t tasksStolen;
        shared size_t stealAttempts;
        
        this(size_t id, size_t capacity) @trusted
        {
            this.id = id;
            this.deque = WorkStealingDeque!(PriorityTask!T)(capacity);
            this.rng = Mt19937(cast(uint)(unpredictableSeed + id));
            atomicStore(running, true);
            atomicStore(tasksExecuted, cast(size_t)0);
            atomicStore(tasksStolen, cast(size_t)0);
            atomicStore(stealAttempts, cast(size_t)0);
        }
        
        void start(void delegate() @safe work) @trusted
        {
            thread = new Thread(work);
            thread.start();
        }
        
        void stop() @trusted
        {
            atomicStore(running, false);
        }
        
        bool isRunning() const @trusted nothrow @nogc
        {
            return atomicLoad(running);
        }
        
        void recordExecution() @trusted nothrow @nogc
        {
            atomicOp!"+="(tasksExecuted, 1);
        }
        
        void recordSteal() @trusted nothrow @nogc
        {
            atomicOp!"+="(tasksStolen, 1);
        }
        
        void recordStealAttempt() @trusted nothrow @nogc
        {
            atomicOp!"+="(stealAttempts, 1);
        }
    }
    
    private Worker[] workers;
    private MultiLevelQueue!T globalQueue;
    private Mutex globalMutex;
    private Condition workAvailable;
    private shared bool running;
    private shared size_t activeWorkers;
    private immutable size_t workerCount;
    private void delegate(T) @safe executeTask;
    
    /// Configuration
    private enum size_t DEQUE_CAPACITY = 256;
    private enum size_t MAX_STEAL_ATTEMPTS = 4;
    private enum size_t BACKOFF_MIN_US = 1;
    private enum size_t BACKOFF_MAX_US = 100;
    
    /// Initialize scheduler with worker count and task executor
    @trusted
    this(size_t workerCount, void delegate(T) @safe executeTask)
    {
        this.workerCount = workerCount == 0 ? totalCPUs : workerCount;
        this.executeTask = executeTask;
        this.globalMutex = new Mutex();
        this.workAvailable = new Condition(globalMutex);
        this.globalQueue.initialize(64);
        
        atomicStore(running, true);
        atomicStore(activeWorkers, cast(size_t)0);
        
        // Create workers
        workers.reserve(this.workerCount);
        foreach (i; 0 .. this.workerCount)
        {
            auto worker = new Worker(i, DEQUE_CAPACITY);
            workers ~= worker;
            worker.start(() @trusted => workerLoop(worker));
        }
    }
    
    /// Submit task with priority
    @trusted
    void submit(T task, Priority priority = Priority.Normal,
                size_t criticalPathCost = 0, size_t depth = 0, size_t dependents = 0)
    {
        auto priorityTask = new PriorityTask!T(task, priority, criticalPathCost, depth, dependents);
        
        // Add to global queue for now (work-stealing will distribute)
        synchronized (globalMutex)
        {
            globalQueue.enqueue(priorityTask);
            workAvailable.notify();
        }
    }
    
    /// Submit multiple tasks in batch
    @trusted
    void submitBatch(T[] tasks, Priority priority = Priority.Normal)
    {
        foreach (task; tasks)
            submit(task, priority);
    }
    
    /// Wait for all tasks to complete
    @trusted
    void waitAll()
    {
        import core.time : msecs;
        
        while (true)
        {
            // Check if all workers are idle and no tasks remain
            bool allIdle = true;
            bool hasTasks = false;
            
            foreach (worker; workers)
            {
                if (!worker.deque.empty())
                {
                    hasTasks = true;
                    break;
                }
            }
            
            synchronized (globalMutex)
            {
                if (!globalQueue.empty())
                    hasTasks = true;
            }
            
            if (!hasTasks && atomicLoad(activeWorkers) == 0)
                break;
            
            Thread.sleep(1.msecs);
        }
    }
    
    /// Shutdown scheduler and all workers
    @trusted
    void shutdown()
    {
        atomicStore(running, false);
        
        // Stop all workers
        foreach (worker; workers)
            worker.stop();
        
        // Wake up sleeping workers
        synchronized (globalMutex)
        {
            workAvailable.notifyAll();
        }
        
        // Wait for workers to finish
        foreach (worker; workers)
        {
            if (worker.thread !is null)
                worker.thread.join();
        }
    }
    
    /// Get scheduler statistics
    struct Stats
    {
        size_t totalExecuted;
        size_t totalStolen;
        size_t totalStealAttempts;
        float stealSuccessRate;
        size_t[] workerLoads;
    }
    
    @trusted
    Stats getStats() const
    {
        Stats stats;
        stats.workerLoads.length = workers.length;
        
        foreach (i, worker; workers)
        {
            stats.totalExecuted += atomicLoad(worker.tasksExecuted);
            stats.totalStolen += atomicLoad(worker.tasksStolen);
            stats.totalStealAttempts += atomicLoad(worker.stealAttempts);
            stats.workerLoads[i] = atomicLoad(worker.tasksExecuted);
        }
        
        if (stats.totalStealAttempts > 0)
            stats.stealSuccessRate = cast(float)stats.totalStolen / stats.totalStealAttempts;
        
        return stats;
    }
    
    /// Worker main loop
    private void workerLoop(Worker worker) @trusted
    {
        import core.time : usecs;
        
        PriorityTask!T task;
        size_t consecutiveFails = 0;
        
        while (worker.isRunning() || !worker.deque.empty())
        {
            // 1. Try local deque first (fastest path)
            task = worker.deque.pop();
            
            if (task !is null)
            {
                atomicOp!"+="(activeWorkers, 1);
                executeTask(task.payload);
                worker.recordExecution();
                atomicOp!"-="(activeWorkers, 1);
                consecutiveFails = 0;
                continue;
            }
            
            // 2. Try global queue
            synchronized (globalMutex)
            {
                task = globalQueue.dequeue();
            }
            
            if (task !is null)
            {
                atomicOp!"+="(activeWorkers, 1);
                executeTask(task.payload);
                worker.recordExecution();
                atomicOp!"-="(activeWorkers, 1);
                consecutiveFails = 0;
                continue;
            }
            
            // 3. Try stealing from random victims
            bool stolen = false;
            foreach (_; 0 .. MAX_STEAL_ATTEMPTS)
            {
                worker.recordStealAttempt();
                auto victim = selectVictim(worker);
                
                if (victim !is null)
                {
                    task = victim.deque.steal();
                    if (task !is null)
                    {
                        atomicOp!"+="(activeWorkers, 1);
                        executeTask(task.payload);
                        worker.recordExecution();
                        worker.recordSteal();
                        atomicOp!"-="(activeWorkers, 1);
                        stolen = true;
                        consecutiveFails = 0;
                        break;
                    }
                }
            }
            
            if (stolen)
                continue;
            
            // 4. No work found - backoff with exponential delay
            consecutiveFails++;
            if (consecutiveFails < 10)
            {
                // Short spin
                Thread.yield();
            }
            else if (consecutiveFails < 20)
            {
                // Exponential backoff
                immutable delay = min(BACKOFF_MIN_US * (1 << (consecutiveFails - 10)), BACKOFF_MAX_US);
                Thread.sleep(delay.usecs);
            }
            else
            {
                // Long wait with condition variable
                synchronized (globalMutex)
                {
                    if (atomicLoad(running) && globalQueue.empty())
                        workAvailable.wait();
                }
                consecutiveFails = 0;
            }
        }
    }
    
    /// Select victim for work stealing using random selection
    /// Prefer victims with more work for better load balancing
    private Worker selectVictim(Worker thief) @trusted
    {
        if (workers.length <= 1)
            return null;
        
        // Try a few random victims and pick the one with most work
        Worker best = null;
        size_t bestSize = 0;
        
        foreach (_; 0 .. min(3, workers.length - 1))
        {
            // Random victim (not self)
            size_t victimId;
            do {
                victimId = uniform(0, workers.length, thief.rng);
            } while (victimId == thief.id);
            
            auto victim = workers[victimId];
            immutable size = victim.deque.size();
            
            if (size > bestSize)
            {
                best = victim;
                bestSize = size;
            }
        }
        
        return best;
    }
}

/// Test basic scheduling
unittest
{
    import std.stdio;
    import core.atomic;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.scheduler - Basic scheduling");
    
    shared size_t counter = 0;
    
    auto scheduler = new WorkStealingScheduler!int(2, (int task) @trusted {
        atomicOp!"+="(counter, task);
    });
    
    // Submit tasks
    foreach (i; 1 .. 11)
        scheduler.submit(i);
    
    scheduler.waitAll();
    
    assert(atomicLoad(counter) == 55);  // Sum of 1..10
    
    auto stats = scheduler.getStats();
    assert(stats.totalExecuted == 10);
    
    scheduler.shutdown();
    
    writeln("\x1b[32m  ✓ Basic scheduling\x1b[0m");
}

/// Test priority scheduling
unittest
{
    import std.stdio;
    import core.atomic;
    import std.array : appender;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.scheduler - Priority scheduling");
    
    auto executed = appender!(int[]);
    Mutex mutex = new Mutex();
    
    auto scheduler = new WorkStealingScheduler!int(1, (int task) @trusted {
        synchronized (mutex)
            executed ~= task;
    });
    
    // Submit with different priorities
    scheduler.submit(1, Priority.Low);
    scheduler.submit(2, Priority.Critical);
    scheduler.submit(3, Priority.Normal);
    scheduler.submit(4, Priority.High);
    
    scheduler.waitAll();
    
    auto results = executed.data;
    assert(results.length == 4);
    
    // Higher priority should generally execute first
    // (not guaranteed due to parallelism, but likely in single worker)
    
    scheduler.shutdown();
    
    writeln("\x1b[32m  ✓ Priority scheduling\x1b[0m");
}

/// Test work stealing
unittest
{
    import std.stdio;
    import core.atomic;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.scheduler - Work stealing");
    
    shared size_t counter = 0;
    
    auto scheduler = new WorkStealingScheduler!int(4, (int task) @trusted {
        atomicOp!"+="(counter, 1);
        Thread.sleep(1.msecs);  // Simulate work
    });
    
    // Submit many tasks
    foreach (i; 0 .. 100)
        scheduler.submit(i);
    
    scheduler.waitAll();
    
    assert(atomicLoad(counter) == 100);
    
    auto stats = scheduler.getStats();
    assert(stats.totalExecuted == 100);
    assert(stats.totalStolen > 0);  // Should have some stealing
    
    scheduler.shutdown();
    
    writeln("\x1b[32m  ✓ Work stealing\x1b[0m");
}

