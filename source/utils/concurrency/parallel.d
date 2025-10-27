module utils.concurrency.parallel;

import std.parallelism : totalCPUs;
import std.algorithm;
import std.array;
import std.range;
import std.conv;
import core.atomic;
import utils.concurrency.scheduler;
import utils.concurrency.balancer;
import utils.concurrency.priority;
import utils.concurrency.pool;

@safe:

/// Execution mode for parallel operations
enum ExecutionMode
{
    Simple,          // Basic std.parallelism (backward compatible)
    WorkStealing,    // Work-stealing scheduler
    LoadBalanced,    // Dynamic load balancing
    Priority         // Priority-based scheduling
}

/// Configuration for parallel execution
struct ParallelConfig
{
    ExecutionMode mode = ExecutionMode.Simple;
    Priority basePriority = Priority.Normal;
    BalanceStrategy balanceStrategy = BalanceStrategy.Adaptive;
    size_t maxParallelism = 0;  // 0 = auto-detect
    bool enableStatistics = false;
}

/// Statistics from parallel execution
struct ExecutionStats
{
    size_t totalTasks;
    size_t totalExecuted;
    size_t totalStolen;
    float stealSuccessRate;
    float loadImbalance;
    size_t[] workerLoads;
}

/// Enhanced parallel execution utilities with work-stealing and load balancing
/// Maintains backward compatibility while adding sophisticated scheduling
struct ParallelExecutor
{
    /// Execute a function on items in parallel (simple mode - backward compatible)
    @trusted
    static R[] execute(T, R)(T[] items, R delegate(T) @safe func, size_t maxParallelism)
    {
        if (items.empty)
            return [];
        
        if (items.length == 1 || maxParallelism == 1)
        {
            // Sequential execution
            R[] results;
            foreach (item; items)
                results ~= func(item);
            return results;
        }
        
        // Parallel execution using our ThreadPool for efficiency
        auto pool = new ThreadPool(maxParallelism);
        scope(exit) pool.shutdown();
        
        return pool.map(items, func);
    }
    
    /// Execute with automatic parallelism based on CPU count (backward compatible)
    static R[] executeAuto(T, R)(T[] items, R delegate(T) @safe func)
    {
        return execute(items, func, totalCPUs);
    }
    
    /// Execute with advanced configuration (work-stealing, load balancing, priorities)
    @trusted
    static R[] executeAdvanced(T, R)(T[] items, R delegate(T) @safe func, ParallelConfig config)
    {
        if (items.empty)
            return [];
        
        if (items.length == 1)
            return [func(items[0])];
        
        immutable workerCount = config.maxParallelism == 0 ? totalCPUs : config.maxParallelism;
        
        // Dispatch to appropriate execution mode
        final switch (config.mode)
        {
            case ExecutionMode.Simple:
                return execute(items, func, workerCount);
            
            case ExecutionMode.WorkStealing:
                return executeWorkStealing(items, func, workerCount, config);
            
            case ExecutionMode.LoadBalanced:
                return executeLoadBalanced(items, func, workerCount, config);
            
            case ExecutionMode.Priority:
                return executePriority(items, func, workerCount, config);
        }
    }
    
    /// Execute with work-stealing scheduler
    @trusted
    private static R[] executeWorkStealing(T, R)(T[] items, R delegate(T) @safe func, 
                                                  size_t workerCount, ParallelConfig config)
    {
        R[] results;
        results.length = items.length;
        shared size_t[] indices;
        indices.length = items.length;
        
        auto scheduler = new WorkStealingScheduler!size_t(
            workerCount,
            (size_t idx) @trusted {
                results[idx] = func(items[idx]);
            }
        );
        
        // Submit all tasks
        foreach (i; 0 .. items.length)
            scheduler.submit(i, config.basePriority);
        
        scheduler.waitAll();
        scheduler.shutdown();
        
        return results;
    }
    
    /// Execute with dynamic load balancing
    @trusted
    private static R[] executeLoadBalanced(T, R)(T[] items, R delegate(T) @safe func,
                                                  size_t workerCount, ParallelConfig config)
    {
        R[] results;
        results.length = items.length;
        
        auto balancer = new LoadBalancer(workerCount, config.balanceStrategy);
        auto scheduler = new WorkStealingScheduler!size_t(
            workerCount,
            (size_t idx) @trusted {
                results[idx] = func(items[idx]);
            }
        );
        
        // Distribute tasks using load balancer
        foreach (i; 0 .. items.length)
        {
            immutable workerId = balancer.selectWorker();
            scheduler.submit(i, config.basePriority);
        }
        
        scheduler.waitAll();
        scheduler.shutdown();
        
        return results;
    }
    
    /// Execute with priority-based scheduling
    @trusted
    private static R[] executePriority(T, R)(T[] items, R delegate(T) @safe func,
                                             size_t workerCount, ParallelConfig config)
    {
        R[] results;
        results.length = items.length;
        
        auto scheduler = new WorkStealingScheduler!size_t(
            workerCount,
            (size_t idx) @trusted {
                results[idx] = func(items[idx]);
            }
        );
        
        // Submit with priorities (could be customized per task)
        foreach (i; 0 .. items.length)
        {
            // Example: first 10% get high priority (critical path)
            immutable priority = i < items.length / 10 ? Priority.High : config.basePriority;
            scheduler.submit(i, priority);
        }
        
        scheduler.waitAll();
        scheduler.shutdown();
        
        return results;
    }
    
    /// Execute with detailed statistics collection
    @trusted
    static ExecutionStats executeWithStats(T, R)(T[] items, R delegate(T) @safe func, 
                                                  out R[] results, ParallelConfig config)
    {
        ExecutionStats stats;
        stats.totalTasks = items.length;
        
        if (items.empty)
        {
            results = [];
            return stats;
        }
        
        results.length = items.length;
        immutable workerCount = config.maxParallelism == 0 ? totalCPUs : config.maxParallelism;
        
        auto scheduler = new WorkStealingScheduler!size_t(
            workerCount,
            (size_t idx) @trusted {
                results[idx] = func(items[idx]);
            }
        );
        
        // Submit tasks
        foreach (i; 0 .. items.length)
            scheduler.submit(i, config.basePriority);
        
        scheduler.waitAll();
        
        // Collect statistics
        auto schedulerStats = scheduler.getStats();
        stats.totalExecuted = schedulerStats.totalExecuted;
        stats.totalStolen = schedulerStats.totalStolen;
        stats.stealSuccessRate = schedulerStats.stealSuccessRate;
        stats.workerLoads = schedulerStats.workerLoads.dup;
        
        // Calculate load imbalance
        if (stats.workerLoads.length > 0)
        {
            import utils.concurrency.balancer : calculateImbalance;
            stats.loadImbalance = calculateImbalance(stats.workerLoads);
        }
        
        scheduler.shutdown();
        
        return stats;
    }
    
    /// Parallel map with work stealing (convenience function)
    static R[] mapWorkStealing(T, R)(T[] items, R delegate(T) @safe func, 
                                     size_t maxParallelism = 0)
    {
        ParallelConfig config;
        config.mode = ExecutionMode.WorkStealing;
        config.maxParallelism = maxParallelism;
        return executeAdvanced(items, func, config);
    }
    
    /// Parallel map with load balancing (convenience function)
    static R[] mapLoadBalanced(T, R)(T[] items, R delegate(T) @safe func,
                                     size_t maxParallelism = 0)
    {
        ParallelConfig config;
        config.mode = ExecutionMode.LoadBalanced;
        config.maxParallelism = maxParallelism;
        return executeAdvanced(items, func, config);
    }
    
    /// Parallel map with priority scheduling (convenience function)
    static R[] mapPriority(T, R)(T[] items, R delegate(T) @safe func,
                                 Priority priority = Priority.Normal,
                                 size_t maxParallelism = 0)
    {
        ParallelConfig config;
        config.mode = ExecutionMode.Priority;
        config.basePriority = priority;
        config.maxParallelism = maxParallelism;
        return executeAdvanced(items, func, config);
    }
}

