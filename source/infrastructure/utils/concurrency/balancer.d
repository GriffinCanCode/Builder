module infrastructure.utils.concurrency.balancer;

import core.atomic;
import core.sync.mutex;
import std.algorithm;
import std.range;
import std.math;
import infrastructure.utils.concurrency.priority;


/// Load balancing strategy for work distribution
enum BalanceStrategy
{
    RoundRobin,      // Simple round-robin distribution
    LeastLoaded,     // Assign to worker with least work
    WorkStealing,    // Distributed + stealing on demand
    CriticalPath,    // Prioritize critical path tasks
    Adaptive         // Dynamically adjust based on metrics
}

/// Load balancer metrics for decision making
struct LoadMetrics
{
    size_t queueSize;           // Current queue size
    size_t tasksExecuted;       // Total tasks executed
    size_t tasksStolen;         // Tasks stolen from others
    size_t stealAttempts;       // Steal attempts made
    float utilizationRate;      // CPU utilization (0-1)
    float stealSuccessRate;     // Successful steals / attempts
    
    /// Calculate load score (higher = more loaded)
    float loadScore() const pure nothrow @nogc
    {
        // Weight factors
        enum QUEUE_WEIGHT = 10.0;
        enum UTIL_WEIGHT = 5.0;
        enum STEAL_PENALTY = 2.0;
        
        float score = queueSize * QUEUE_WEIGHT;
        score += utilizationRate * UTIL_WEIGHT;
        
        // Penalty for being a frequent steal target
        if (stealAttempts > 0)
            score += (cast(float)tasksStolen / stealAttempts) * STEAL_PENALTY;
        
        return score;
    }
}

/// Dynamic load balancer with adaptive strategies
final class LoadBalancer
{
    private LoadMetrics[] workerMetrics;
    private Mutex metricsMutex;
    private shared size_t nextWorker;  // For round-robin
    private BalanceStrategy strategy;
    private immutable size_t workerCount;
    
    /// Configuration thresholds
    private enum float IMBALANCE_THRESHOLD = 2.0;  // Ratio for rebalancing
    private enum size_t MIN_WORK_FOR_STEAL = 4;    // Min queue size to steal
    private enum float HIGH_LOAD_THRESHOLD = 0.8;  // 80% utilization
    
    /// Initialize with worker count and strategy
    @system
    this(size_t workerCount, BalanceStrategy strategy = BalanceStrategy.Adaptive)
    {
        this.workerCount = workerCount;
        this.strategy = strategy;
        this.metricsMutex = new Mutex();
        this.workerMetrics.length = workerCount;
        atomicStore(nextWorker, cast(size_t)0);
        
        // Initialize metrics
        foreach (i; 0 .. workerCount)
        {
            workerMetrics[i] = LoadMetrics.init;
        }
    }
    
    /// Select worker for new task assignment
    @system
    size_t selectWorker(PriorityTask!int task = null)
    {
        final switch (strategy)
        {
            case BalanceStrategy.RoundRobin:
                return selectRoundRobin();
            
            case BalanceStrategy.LeastLoaded:
                return selectLeastLoaded();
            
            case BalanceStrategy.WorkStealing:
                return selectForWorkStealing();
            
            case BalanceStrategy.CriticalPath:
                return selectForCriticalPath(task);
            
            case BalanceStrategy.Adaptive:
                return selectAdaptive(task);
        }
    }
    
    /// Select victim worker for work stealing
    /// Returns: Worker ID with most work, or -1 if none suitable
    @system
    long selectVictim(size_t thiefId)
    {
        synchronized (metricsMutex)
        {
            size_t bestVictim = size_t.max;
            size_t maxWork = MIN_WORK_FOR_STEAL;
            
            foreach (i; 0 .. workerCount)
            {
                if (i == thiefId)
                    continue;
                
                if (workerMetrics[i].queueSize > maxWork)
                {
                    maxWork = workerMetrics[i].queueSize;
                    bestVictim = i;
                }
            }
            
            return bestVictim == size_t.max ? -1 : cast(long)bestVictim;
        }
    }
    
    /// Check if system is imbalanced and needs rebalancing
    @system
    bool needsRebalancing()
    {
        if (workerCount < 2)
            return false;
        
        synchronized (metricsMutex)
        {
            float minLoad = float.max;
            float maxLoad = 0.0;
            
            foreach (i; 0 .. workerCount)
            {
                immutable load = workerMetrics[i].loadScore();
                minLoad = min(minLoad, load);
                maxLoad = max(maxLoad, load);
            }
            
            // Check if imbalance exceeds threshold
            if (minLoad > 0)
                return (maxLoad / minLoad) > IMBALANCE_THRESHOLD;
            
            return maxLoad > HIGH_LOAD_THRESHOLD * 10;
        }
    }
    
    /// Update metrics for a worker
    @system
    void updateMetrics(size_t workerId, LoadMetrics metrics)
    {
        if (workerId >= workerCount)
            return;
        
        synchronized (metricsMutex)
        {
            workerMetrics[workerId] = metrics;
        }
    }
    
    /// Get current metrics for a worker
    @system
    LoadMetrics getMetrics(size_t workerId) const
    {
        if (workerId >= workerCount)
            return LoadMetrics.init;
        
        synchronized (metricsMutex)
        {
            return workerMetrics[workerId];
        }
    }
    
    /// Get aggregate metrics across all workers
    struct AggregateMetrics
    {
        size_t totalQueueSize;
        size_t totalExecuted;
        size_t totalStolen;
        float avgUtilization;
        float avgStealSuccess;
        float loadImbalance;
    }
    
    @system
    AggregateMetrics getAggregateMetrics() const
    {
        synchronized (metricsMutex)
        {
            AggregateMetrics agg;
            float minLoad = float.max;
            float maxLoad = 0.0;
            
            foreach (i; 0 .. workerCount)
            {
                auto m = workerMetrics[i];
                agg.totalQueueSize += m.queueSize;
                agg.totalExecuted += m.tasksExecuted;
                agg.totalStolen += m.tasksStolen;
                agg.avgUtilization += m.utilizationRate;
                agg.avgStealSuccess += m.stealSuccessRate;
                
                immutable load = m.loadScore();
                minLoad = min(minLoad, load);
                maxLoad = max(maxLoad, load);
            }
            
            if (workerCount > 0)
            {
                agg.avgUtilization /= workerCount;
                agg.avgStealSuccess /= workerCount;
            }
            
            if (minLoad > 0)
                agg.loadImbalance = maxLoad / minLoad;
            
            return agg;
        }
    }
    
    /// Strategy implementations
    
    private size_t selectRoundRobin() @system
    {
        immutable id = atomicLoad(nextWorker);
        atomicStore(nextWorker, (id + 1) % workerCount);
        return id;
    }
    
    private size_t selectLeastLoaded() @system
    {
        synchronized (metricsMutex)
        {
            size_t best = 0;
            float minLoad = float.max;
            
            foreach (i; 0 .. workerCount)
            {
                immutable load = workerMetrics[i].loadScore();
                
                if (load < minLoad)
                {
                    minLoad = load;
                    best = i;
                }
            }
            
            return best;
        }
    }
    
    private size_t selectForWorkStealing() @system
    {
        // For work-stealing, prefer round-robin to distribute initially
        // Workers will steal as needed
        return selectRoundRobin();
    }
    
    private size_t selectForCriticalPath(PriorityTask!int task) @system
    {
        // Critical path tasks go to least loaded worker
        // Regular tasks use round-robin
        if (task !is null && task.priority >= Priority.High)
            return selectLeastLoaded();
        
        return selectRoundRobin();
    }
    
    private size_t selectAdaptive(PriorityTask!int task) @system
    {
        // Adaptive strategy based on current system state
        auto agg = getAggregateMetrics();
        
        // High imbalance - use least loaded
        if (agg.loadImbalance > IMBALANCE_THRESHOLD)
            return selectLeastLoaded();
        
        // High priority task - use least loaded
        if (task !is null && task.priority >= Priority.High)
            return selectLeastLoaded();
        
        // Normal case - use round-robin for good distribution
        return selectRoundRobin();
    }
}

/// Calculate work imbalance coefficient (0 = perfect, higher = more imbalanced)
float calculateImbalance(size_t[] workloads) pure nothrow @system
{
    if (workloads.length < 2)
        return 0.0;
    
    immutable avg = workloads.sum / cast(float)workloads.length;
    if (avg == 0)
        return 0.0;
    
    // Coefficient of variation
    float variance = 0.0;
    foreach (load; workloads)
        variance += (load - avg) * (load - avg);
    
    variance /= workloads.length;
    immutable stddev = sqrt(variance);
    
    return stddev / avg;
}

/// Generate optimal work partitioning for static load balancing
/// Uses greedy algorithm for bin packing with priority
struct WorkPartition
{
    size_t workerId;
    size_t[] taskIndices;
    size_t totalCost;
}

WorkPartition[] partitionWork(T)(T[] tasks, size_t workerCount, 
                                  size_t delegate(T) @system getCost) @system
{
    if (tasks.empty || workerCount == 0)
        return [];
    
    // Initialize partitions
    auto partitions = new WorkPartition[workerCount];
    foreach (i; 0 .. workerCount)
    {
        partitions[i].workerId = i;
        partitions[i].totalCost = 0;
    }
    
    // Sort tasks by cost descending (greedy heuristic)
    auto indices = iota(tasks.length).array;
    indices.sort!((a, b) => getCost(tasks[a]) > getCost(tasks[b]));
    
    // Assign each task to least loaded worker
    foreach (idx; indices)
    {
        // Find partition with minimum cost
        size_t minPartition = 0;
        size_t minCost = size_t.max;
        
        foreach (i, ref partition; partitions)
        {
            if (partition.totalCost < minCost)
            {
                minCost = partition.totalCost;
                minPartition = i;
            }
        }
        
        // Assign task to this partition
        partitions[minPartition].taskIndices ~= idx;
        partitions[minPartition].totalCost += getCost(tasks[idx]);
    }
    
    return partitions;
}

/// Test load balancer selection
unittest
{
    import std.stdio;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.balancer - Worker selection");
    
    auto balancer = new LoadBalancer(4, BalanceStrategy.RoundRobin);
    
    // Round-robin should cycle through workers
    assert(balancer.selectWorker() == 0);
    assert(balancer.selectWorker() == 1);
    assert(balancer.selectWorker() == 2);
    assert(balancer.selectWorker() == 3);
    assert(balancer.selectWorker() == 0);
    
    writeln("\x1b[32m  ✓ Worker selection\x1b[0m");
}

/// Test least loaded selection
unittest
{
    import std.stdio;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.balancer - Least loaded");
    
    auto balancer = new LoadBalancer(4, BalanceStrategy.LeastLoaded);
    
    // Set different loads
    LoadMetrics m0; m0.queueSize = 10;
    LoadMetrics m1; m1.queueSize = 5;
    LoadMetrics m2; m2.queueSize = 15;
    LoadMetrics m3; m3.queueSize = 8;
    
    balancer.updateMetrics(0, m0);
    balancer.updateMetrics(1, m1);
    balancer.updateMetrics(2, m2);
    balancer.updateMetrics(3, m3);
    
    // Should select worker 1 (least loaded)
    assert(balancer.selectWorker() == 1);
    
    writeln("\x1b[32m  ✓ Least loaded\x1b[0m");
}

/// Test victim selection
unittest
{
    import std.stdio;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.balancer - Victim selection");
    
    auto balancer = new LoadBalancer(4, BalanceStrategy.WorkStealing);
    
    // Set loads
    LoadMetrics m0; m0.queueSize = 2;
    LoadMetrics m1; m1.queueSize = 20;
    LoadMetrics m2; m2.queueSize = 5;
    LoadMetrics m3; m3.queueSize = 10;
    
    balancer.updateMetrics(0, m0);
    balancer.updateMetrics(1, m1);
    balancer.updateMetrics(2, m2);
    balancer.updateMetrics(3, m3);
    
    // Worker 0 should steal from worker 1 (most work)
    assert(balancer.selectVictim(0) == 1);
    
    writeln("\x1b[32m  ✓ Victim selection\x1b[0m");
}

/// Test imbalance calculation
unittest
{
    import std.stdio;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.balancer - Imbalance");
    
    // Perfectly balanced
    assert(calculateImbalance([10, 10, 10, 10]) < 0.01);
    
    // Moderately imbalanced
    auto imb1 = calculateImbalance([5, 10, 15, 20]);
    assert(imb1 > 0.4);
    
    // Highly imbalanced
    auto imb2 = calculateImbalance([1, 1, 1, 100]);
    assert(imb2 > 1.0);
    
    writeln("\x1b[32m  ✓ Imbalance\x1b[0m");
}

/// Test work partitioning
unittest
{
    import std.stdio;
    
    writeln("\x1b[36m[TEST]\x1b[0m utils.concurrency.balancer - Work partitioning");
    
    struct Task { size_t cost; }
    
    auto tasks = [
        Task(10), Task(5), Task(8), Task(3),
        Task(12), Task(7), Task(4), Task(6)
    ];
    
    auto partitions = partitionWork(tasks, 3, (Task t) => t.cost);
    
    assert(partitions.length == 3);
    assert(partitions[0].taskIndices.length > 0);
    assert(partitions[1].taskIndices.length > 0);
    assert(partitions[2].taskIndices.length > 0);
    
    // Total tasks should be preserved
    size_t totalTasks = 0;
    foreach (p; partitions)
        totalTasks += p.taskIndices.length;
    assert(totalTasks == tasks.length);
    
    writeln("\x1b[32m  ✓ Work partitioning\x1b[0m");
}
