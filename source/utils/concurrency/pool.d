module utils.concurrency.pool;

import core.thread;
import core.sync.mutex;
import core.sync.condition;
import core.atomic;
import std.algorithm;
import std.range;
import std.exception;
import std.conv : to;
import std.parallelism : totalCPUs;

@safe:

/// Persistent thread pool for reusable parallel execution
/// Thread-safe: All shared state is protected by mutex or atomic operations
final class ThreadPool
{
    private Worker[] workers;
    private Job[] jobs;
    private Mutex jobMutex;  // Protects jobs array access
    private Condition jobAvailable;
    private Condition jobComplete;
    private shared bool running;  // Atomic access
    private shared size_t pendingJobs;  // Atomic access
    private shared size_t nextJobIndex;  // Atomic access (work stealing)
    
    @trusted // Thread creation and atomic operations
    this(size_t workerCount = 0)
    {
        if (workerCount == 0)
            workerCount = totalCPUs;
        
        enforce(workerCount > 0, "Worker count must be positive");
        
        jobMutex = new Mutex();
        jobAvailable = new Condition(jobMutex);
        jobComplete = new Condition(jobMutex);
        atomicStore(running, true);
        
        workers.reserve(workerCount);
        workers.length = workerCount;
        foreach (i; 0 .. workerCount)
        {
            workers[i] = new Worker(i, this);
            workers[i].start();
        }
    }
    
    /// Execute function on items in parallel
    @trusted // Thread synchronization and atomic operations
    R[] map(T, R)(scope T[] items, scope R delegate(T) func)
    {
        if (items.empty)
            return [];
        
        if (items.length == 1)
            return [func(items[0])];
        
        R[] results;
        results.length = items.length;
        
        synchronized (jobMutex)
        {
            jobs.reserve(items.length);
            jobs.length = items.length;
            atomicStore(pendingJobs, items.length);
            atomicStore(nextJobIndex, cast(size_t)0);
            
            foreach (i, ref item; items)
            {
                jobs[i].id = i;
                // Use a helper function to properly capture by value
                jobs[i].work = makeWork(i, item, results, func);
                atomicStore(jobs[i].completed, false);
            }
            
            jobAvailable.notifyAll();
        }
        
        synchronized (jobMutex)
        {
            while (atomicLoad(pendingJobs) > 0)
                jobComplete.wait();
        }
        
        return results;
    }
    
    /// Helper to create work delegate with proper value capture
    @trusted // Delegate creation with captured variables - returns @safe delegate wrapped in @trusted context
    private void delegate() @safe makeWork(T, R)(size_t index, T item, ref R[] results, scope R delegate(T) func)
    {
        void delegate() @safe safeDel = () @trusted {
            results[index] = func(item);
        };
        return safeDel;
    }
    
    /// Shutdown pool and wait for workers
    @trusted // Thread synchronization
    void shutdown()
    {
        atomicStore(running, false);
        
        synchronized (jobMutex)
        {
            jobAvailable.notifyAll();
        }
        
        foreach (ref worker; workers)
            worker.join();
    }
    
    package:
    
    @trusted // Thread synchronization and atomic operations
    Job* nextJob()
    {
        synchronized (jobMutex)
        {
            while (atomicLoad(running))
            {
                immutable idx = atomicLoad(nextJobIndex);
                
                if (idx >= jobs.length)
                {
                    // All jobs claimed or no jobs available, wait for more work
                    jobAvailable.wait();
                    continue;
                }
                
                // Try to claim this job
                if (cas(&nextJobIndex, idx, idx + 1))
                {
                    if (!atomicLoad(jobs[idx].completed))
                        return &jobs[idx];
                }
            }
            
            return null; // Shutdown
        }
    }
    
    @trusted // Thread synchronization and atomic operations
    void completeJob()
    {
        synchronized (jobMutex)
        {
            immutable remaining = atomicOp!"-="(pendingJobs, 1);
            
            if (remaining == 0)
                jobComplete.notify();
        }
    }
    
    @trusted // Atomic load operation
    bool isRunning() const nothrow @nogc
    {
        return atomicLoad(running);
    }
}

private final class Worker
{
    private immutable size_t id;
    private ThreadPool pool;
    private Thread thread;
    
    @trusted // Thread creation
    this(size_t id, ThreadPool pool)
    {
        this.id = id;
        this.pool = pool;
        this.thread = new Thread(&run);
    }
    
    @trusted // Thread operations
    void start()
    {
        thread.start();
    }
    
    @trusted // Thread operations
    void join()
    {
        thread.join();
    }
    
    @trusted // Thread execution and atomic operations
    private void run()
    {
        while (pool.isRunning())
        {
            scope job = pool.nextJob();
            
            if (job is null)
                break;
            
            try
            {
                job.work();
                atomicStore(job.completed, true);
            }
            catch (Exception e)
            {
                // Log error but continue
                atomicStore(job.completed, true);
            }
            
            pool.completeJob();
        }
    }
}

/// Job structure for work distribution
/// Thread-safe: completed flag is accessed atomically
private struct Job
{
    size_t id;
    void delegate() work;
    shared bool completed;  // Atomic access for thread-safe completion checking
}


