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

/// Persistent thread pool for reusable parallel execution
final class ThreadPool
{
    private Worker[] workers;
    private Job[] jobs;
    private Mutex jobMutex;
    private Condition jobAvailable;
    private Condition jobComplete;
    private shared bool running;
    private shared size_t pendingJobs;
    private shared size_t nextJobIndex;
    
    this(size_t workerCount = 0) @trusted
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
    R[] map(T, R)(scope T[] items, scope R delegate(T) func) @trusted
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
                jobs[i].completed = false;
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
    private void delegate() makeWork(T, R)(size_t index, T item, ref R[] results, scope R delegate(T) func) @trusted
    {
        return () {
            results[index] = func(item);
        };
    }
    
    /// Shutdown pool and wait for workers
    void shutdown() @trusted
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
    
    Job* nextJob() @trusted
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
                    if (!jobs[idx].completed)
                        return &jobs[idx];
                }
            }
            
            return null; // Shutdown
        }
    }
    
    void completeJob() @trusted
    {
        synchronized (jobMutex)
        {
            immutable remaining = atomicOp!"-="(pendingJobs, 1);
            
            if (remaining == 0)
                jobComplete.notify();
        }
    }
    
    bool isRunning() const nothrow @trusted @nogc
    {
        return atomicLoad(running);
    }
}

private final class Worker
{
    private immutable size_t id;
    private ThreadPool pool;
    private Thread thread;
    
    this(size_t id, ThreadPool pool) @safe
    {
        this.id = id;
        this.pool = pool;
        this.thread = new Thread(&run);
    }
    
    void start() @trusted
    {
        thread.start();
    }
    
    void join() @trusted
    {
        thread.join();
    }
    
    private void run() @trusted
    {
        while (pool.isRunning())
        {
            scope job = pool.nextJob();
            
            if (job is null)
                break;
            
            try
            {
                job.work();
                job.completed = true;
            }
            catch (Exception e)
            {
                // Log error but continue
                job.completed = true;
            }
            
            pool.completeJob();
        }
    }
}

private struct Job
{
    size_t id;
    void delegate() work;
    bool completed;
}


