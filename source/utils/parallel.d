module utils.parallel;

import std.parallelism;
import std.algorithm;
import std.array;
import std.range;

/// Parallel execution utilities
struct ParallelExecutor
{
    /// Execute a function on items in parallel
    static R[] execute(T, R)(T[] items, R delegate(T) func, size_t maxParallelism)
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
        
        // Parallel execution using task pool
        auto pool = new TaskPool(maxParallelism);
        scope(exit) pool.finish();
        
        R[] results;
        results.length = items.length;
        
        foreach (i, item; parallel(items))
        {
            results[i] = func(item);
        }
        
        return results;
    }
    
    /// Execute with automatic parallelism based on CPU count
    static R[] executeAuto(T, R)(T[] items, R delegate(T) func)
    {
        return execute(items, func, totalCPUs);
    }
}

