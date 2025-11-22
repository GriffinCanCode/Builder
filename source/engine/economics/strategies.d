module engine.economics.strategies;

import std.datetime : Duration, seconds, dur;
import std.algorithm : map, filter, sort;
import std.array : array;
import std.conv : to;
import std.format : format;
import engine.economics.pricing;

/// Execution strategy enumeration
enum ExecutionStrategy : ubyte
{
    Local,       // Local execution ($0 cost, slower)
    Cached,      // Cache hit (~$0 cost, very fast)
    Distributed, // Distributed execution (variable cost, fast)
    Premium      // Premium instances (high cost, fastest)
}

/// Strategy configuration
struct StrategyConfig
{
    ExecutionStrategy strategy;
    size_t workers = 1;      // Number of workers
    size_t cores = 4;        // Cores per worker
    
    this(ExecutionStrategy strategy, size_t workers, size_t cores) @safe pure nothrow @nogc
    {
        this.strategy = strategy;
        this.workers = workers;
        this.cores = cores;
    }
}

/// Build plan with estimated cost and time
struct BuildPlan
{
    StrategyConfig strategy;
    Duration estimatedTime;
    float estimatedCost;
    ResourceUsageEstimate usage;
    float cacheHitProbability = 0.0f;
    
    /// Get expected cost (considering cache hits)
    float expectedCost() const pure @safe nothrow @nogc =>
        estimatedCost * (1.0f - cacheHitProbability);
    
    /// Get expected time (considering cache hits)
    Duration expectedTime() const pure @safe nothrow @nogc =>
        dur!"msecs"(cast(long)(estimatedTime.total!"msecs" * 
            (cacheHitProbability > 0.9f ? 0.1f : 1.0f - cacheHitProbability)));
    
    /// Check if this plan dominates another (Pareto dominance)
    bool dominates(const BuildPlan other) const pure @safe nothrow @nogc =>
        expectedCost() <= other.expectedCost() && expectedTime() <= other.expectedTime() &&
        (expectedCost() < other.expectedCost() || expectedTime() < other.expectedTime());
    
    /// Compute combined objective (weighted cost-time)
    float objective(float alpha = 0.5f) const pure @safe nothrow @nogc =>
        alpha * (expectedCost() / 100.0f) + (1.0f - alpha) * (expectedTime().total!"seconds" / 600.0f);
}

/// Strategy enumerator - generates candidate execution plans
final class StrategyEnumerator
{
    /// Enumerate candidate strategies for given baseline
    BuildPlan[] enumerate(Duration baselineDuration, ResourceUsageEstimate baselineUsage,
                         float cacheHitProb, ResourcePricing pricing) @trusted
    {
        BuildPlan[] candidates = [createLocalPlan(baselineDuration, baselineUsage, cacheHitProb)];
        
        if (cacheHitProb > 0.1f)
            candidates ~= createCachedPlan(baselineDuration, baselineUsage, cacheHitProb);
        
        foreach (workers; [4, 8, 16])
            candidates ~= createDistributedPlan(baselineDuration, baselineUsage, cacheHitProb, pricing, workers);
        
        foreach (workers; [4, 8])
            candidates ~= createPremiumPlan(baselineDuration, baselineUsage, cacheHitProb, pricing, workers);
        
        return candidates;
    }
    
private:
    
    BuildPlan createLocalPlan(Duration baselineDuration, ResourceUsageEstimate baselineUsage, float cacheHitProb) pure @safe =>
        BuildPlan(StrategyConfig(ExecutionStrategy.Local, 1, 4), baselineDuration, 0.0f, baselineUsage, cacheHitProb);
    
    BuildPlan createCachedPlan(Duration baselineDuration, ResourceUsageEstimate baselineUsage, float cacheHitProb) pure @safe =>
        BuildPlan(StrategyConfig(ExecutionStrategy.Cached, 0, 0),
                 seconds(cast(long)(baselineDuration.total!"seconds" * 0.05f)), 0.01f, baselineUsage, cacheHitProb);
    
    BuildPlan createDistributedPlan(Duration baselineDuration, ResourceUsageEstimate baselineUsage,
                                   float cacheHitProb, ResourcePricing pricing, size_t workers) @trusted
    {
        immutable speedup = estimateSpeedup(workers);
        immutable estimatedTime = seconds(cast(long)(baselineDuration.total!"seconds" / speedup));
        
        auto distributedUsage = ResourceUsageEstimate(workers * 4, baselineUsage.memoryBytes, 
            baselineUsage.diskIOBytes / 2, baselineUsage.diskIOBytes, estimatedTime);
        
        return BuildPlan(StrategyConfig(ExecutionStrategy.Distributed, workers, 4),
                        estimatedTime, pricing.totalCost(distributedUsage), distributedUsage, cacheHitProb);
    }
    
    BuildPlan createPremiumPlan(Duration baselineDuration, ResourceUsageEstimate baselineUsage,
                               float cacheHitProb, ResourcePricing pricing, size_t workers) @trusted
    {
        immutable speedup = estimateSpeedup(workers) * 1.5f;
        immutable estimatedTime = seconds(cast(long)(baselineDuration.total!"seconds" / speedup));
        
        auto premiumUsage = ResourceUsageEstimate(workers * 8, baselineUsage.memoryBytes,
            baselineUsage.diskIOBytes / 2, baselineUsage.diskIOBytes, estimatedTime);
        
        return BuildPlan(StrategyConfig(ExecutionStrategy.Premium, workers, 8), estimatedTime,
                        PricingProfile.premium.adjust(pricing).totalCost(premiumUsage), premiumUsage, cacheHitProb);
    }
    
    /// Estimate speedup from parallelization (Amdahl's law approximation)
    float estimateSpeedup(size_t workers) const pure @safe nothrow @nogc =>
        1.0f / (0.2f + 0.8f / workers);
}

/// Pareto frontier - set of non-dominated plans
struct ParetoFrontier
{
    BuildPlan[] plans;
    
    /// Compute Pareto frontier from candidates
    static ParetoFrontier compute(BuildPlan[] candidates) @trusted
    {
        BuildPlan[] frontier;
        
        foreach (candidate; candidates)
        {
            bool dominated = false;
            
            // Check if candidate is dominated by any plan in frontier
            foreach (plan; frontier)
            {
                if (plan.dominates(candidate))
                {
                    dominated = true;
                    break;
                }
            }
            
            if (!dominated)
            {
                // Remove plans from frontier that are dominated by candidate
                frontier = frontier.filter!(p => !candidate.dominates(p)).array;
                frontier ~= candidate;
            }
        }
        
        // Sort by cost
        frontier.sort!((a, b) => a.expectedCost() < b.expectedCost());
        
        return ParetoFrontier(frontier);
    }
    
    /// Find plan that optimizes for cost
    BuildPlan optimizeForCost() const pure @safe
    {
        import std.algorithm : minElement;
        assert(plans.length > 0, "Empty Pareto frontier");
        return plans.minElement!(p => p.expectedCost());
    }
    
    /// Find plan that optimizes for time
    BuildPlan optimizeForTime() const pure @safe
    {
        import std.algorithm : minElement;
        assert(plans.length > 0, "Empty Pareto frontier");
        return plans.minElement!(p => p.expectedTime());
    }
    
    /// Find balanced plan (minimize combined objective)
    BuildPlan optimizeBalanced(float alpha = 0.5f) const pure @safe
    {
        import std.algorithm : minElement;
        assert(plans.length > 0, "Empty Pareto frontier");
        return plans.minElement!(p => p.objective(alpha));
    }
    
    /// Find fastest plan within budget
    BuildPlan findWithinBudget(float budgetUSD) const pure @safe
    {
        import std.algorithm : minElement;
        assert(plans.length > 0, "Empty Pareto frontier");
        
        auto affordable = plans.filter!(p => p.expectedCost() <= budgetUSD).array;
        return affordable.length > 0 ? affordable.minElement!(p => p.expectedTime()) : optimizeForCost();
    }
    
    /// Find cheapest plan within time limit
    BuildPlan findWithinTime(Duration timeLimit) const pure @safe
    {
        import std.algorithm : minElement;
        assert(plans.length > 0, "Empty Pareto frontier");
        
        auto fast = plans.filter!(p => p.expectedTime() <= timeLimit).array;
        return fast.length > 0 ? fast.minElement!(p => p.expectedCost()) : optimizeForTime();
    }
}

/// Format build plan for display
string formatPlan(const BuildPlan plan) @safe
{
    import engine.economics.pricing : formatCost;
    
    string strategyName;
    string strategyDetails;
    
    final switch (plan.strategy.strategy)
    {
        case ExecutionStrategy.Local:
            strategyName = "Local Execution";
            strategyDetails = format("  Cores: %d", plan.strategy.cores);
            break;
        case ExecutionStrategy.Cached:
            strategyName = "Cached (Cache Hit)";
            strategyDetails = format("  Cache hit probability: %.0f%%", 
                                   plan.cacheHitProbability * 100);
            break;
        case ExecutionStrategy.Distributed:
            strategyName = "Distributed Execution";
            strategyDetails = format("  Workers: %d\n  Cores per worker: %d\n  Total cores: %d",
                                   plan.strategy.workers,
                                   plan.strategy.cores,
                                   plan.strategy.workers * plan.strategy.cores);
            break;
        case ExecutionStrategy.Premium:
            strategyName = "Premium Execution";
            strategyDetails = format("  Workers: %d (premium)\n  Cores per worker: %d\n  Total cores: %d",
                                   plan.strategy.workers,
                                   plan.strategy.cores,
                                   plan.strategy.workers * plan.strategy.cores);
            break;
    }
    
    immutable timeStr = formatDuration(plan.expectedTime());
    immutable costStr = formatCost(plan.expectedCost());
    
    return format("Strategy: %s\n%s\nEstimated time: %s\nEstimated cost: %s",
                 strategyName, strategyDetails, timeStr, costStr);
}

/// Format duration for display
private string formatDuration(Duration d) pure @safe
{
    immutable totalSeconds = d.total!"seconds";
    if (totalSeconds < 60) return totalSeconds.to!string ~ "s";
    if (totalSeconds < 3600) return (totalSeconds / 60).to!string ~ "m " ~ (totalSeconds % 60).to!string ~ "s";
    return (totalSeconds / 3600).to!string ~ "h " ~ ((totalSeconds % 3600) / 60).to!string ~ "m";
}
