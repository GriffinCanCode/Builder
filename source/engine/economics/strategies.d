module engine.economics.strategies;

import std.datetime : Duration, seconds;
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
    float expectedCost() const pure @safe nothrow @nogc
    {
        return estimatedCost * (1.0f - cacheHitProbability);
    }
    
    /// Get expected time (considering cache hits)
    Duration expectedTime() const pure @safe nothrow @nogc
    {
        immutable cacheFactor = cacheHitProbability > 0.9f ? 0.1f : (1.0f - cacheHitProbability);
        immutable msecs = cast(long)(estimatedTime.total!"msecs" * cacheFactor);
        return msecs.msecs;
    }
    
    /// Check if this plan dominates another (Pareto dominance)
    bool dominates(const BuildPlan other) const pure @safe nothrow @nogc
    {
        immutable costDominates = expectedCost() <= other.expectedCost();
        immutable timeDominates = expectedTime() <= other.expectedTime();
        immutable strictlyBetter = expectedCost() < other.expectedCost() || 
                                   expectedTime() < other.expectedTime();
        return costDominates && timeDominates && strictlyBetter;
    }
    
    /// Compute combined objective (weighted cost-time)
    float objective(float alpha = 0.5f) const pure @safe nothrow @nogc
    {
        immutable normalizedCost = expectedCost() / 100.0f;  // Normalize to ~0-1 range
        immutable normalizedTime = expectedTime().total!"seconds" / 600.0f; // ~10min baseline
        return alpha * normalizedCost + (1.0f - alpha) * normalizedTime;
    }
}

/// Strategy enumerator - generates candidate execution plans
final class StrategyEnumerator
{
    /// Enumerate candidate strategies for given baseline
    BuildPlan[] enumerate(
        Duration baselineDuration,
        ResourceUsageEstimate baselineUsage,
        float cacheHitProb,
        ResourcePricing pricing
    ) @trusted
    {
        BuildPlan[] candidates;
        
        // Strategy 1: Local (free, baseline time)
        candidates ~= createLocalPlan(baselineDuration, baselineUsage, cacheHitProb);
        
        // Strategy 2: Cached (if high cache probability)
        if (cacheHitProb > 0.1f)
            candidates ~= createCachedPlan(baselineDuration, baselineUsage, cacheHitProb);
        
        // Strategy 3-5: Distributed with different worker counts
        foreach (workers; [4, 8, 16])
            candidates ~= createDistributedPlan(baselineDuration, baselineUsage, cacheHitProb, pricing, workers);
        
        // Strategy 6-7: Premium instances
        foreach (workers; [4, 8])
            candidates ~= createPremiumPlan(baselineDuration, baselineUsage, cacheHitProb, pricing, workers);
        
        return candidates;
    }
    
private:
    
    BuildPlan createLocalPlan(
        Duration baselineDuration,
        ResourceUsageEstimate baselineUsage,
        float cacheHitProb
    ) pure @safe
    {
        BuildPlan plan;
        plan.strategy = StrategyConfig(ExecutionStrategy.Local, 1, 4);
        plan.estimatedTime = baselineDuration;
        plan.estimatedCost = 0.0f; // Local is free
        plan.usage = baselineUsage;
        plan.cacheHitProbability = cacheHitProb;
        return plan;
    }
    
    BuildPlan createCachedPlan(
        Duration baselineDuration,
        ResourceUsageEstimate baselineUsage,
        float cacheHitProb
    ) pure @safe
    {
        BuildPlan plan;
        plan.strategy = StrategyConfig(ExecutionStrategy.Cached, 0, 0);
        plan.estimatedTime = seconds(cast(long)(baselineDuration.total!"seconds" * 0.05f)); // 5% of baseline
        plan.estimatedCost = 0.01f; // Minimal cache lookup cost
        plan.usage = baselineUsage;
        plan.cacheHitProbability = cacheHitProb;
        return plan;
    }
    
    BuildPlan createDistributedPlan(
        Duration baselineDuration,
        ResourceUsageEstimate baselineUsage,
        float cacheHitProb,
        ResourcePricing pricing,
        size_t workers
    ) @trusted
    {
        BuildPlan plan;
        plan.strategy = StrategyConfig(ExecutionStrategy.Distributed, workers, 4);
        
        // Estimate speedup (with diminishing returns)
        immutable speedup = estimateSpeedup(workers);
        plan.estimatedTime = seconds(cast(long)(baselineDuration.total!"seconds" / speedup));
        
        // Estimate cost
        ResourceUsageEstimate distributedUsage = baselineUsage;
        distributedUsage.cores = workers * 4;
        distributedUsage.duration = plan.estimatedTime;
        distributedUsage.networkBytes = baselineUsage.diskIOBytes / 2; // Transfer overhead
        
        plan.estimatedCost = pricing.totalCost(distributedUsage);
        plan.usage = distributedUsage;
        plan.cacheHitProbability = cacheHitProb;
        
        return plan;
    }
    
    BuildPlan createPremiumPlan(
        Duration baselineDuration,
        ResourceUsageEstimate baselineUsage,
        float cacheHitProb,
        ResourcePricing pricing,
        size_t workers
    ) @trusted
    {
        BuildPlan plan;
        plan.strategy = StrategyConfig(ExecutionStrategy.Premium, workers, 8);
        
        // Premium has better speedup (1.5x performance)
        immutable speedup = estimateSpeedup(workers) * 1.5f;
        plan.estimatedTime = seconds(cast(long)(baselineDuration.total!"seconds" / speedup));
        
        // Premium costs 2x
        ResourceUsageEstimate premiumUsage = baselineUsage;
        premiumUsage.cores = workers * 8;
        premiumUsage.duration = plan.estimatedTime;
        premiumUsage.networkBytes = baselineUsage.diskIOBytes / 2;
        
        auto premiumPricing = PricingProfile.premium.adjust(pricing);
        plan.estimatedCost = premiumPricing.totalCost(premiumUsage);
        plan.usage = premiumUsage;
        plan.cacheHitProbability = cacheHitProb;
        
        return plan;
    }
    
    /// Estimate speedup from parallelization (Amdahl's law approximation)
    float estimateSpeedup(size_t workers) const pure @safe nothrow @nogc
    {
        // Assume 80% of work is parallelizable
        immutable parallelFraction = 0.8f;
        immutable serialFraction = 1.0f - parallelFraction;
        return 1.0f / (serialFraction + parallelFraction / workers);
    }
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
        assert(plans.length > 0, "Empty Pareto frontier");
        
        BuildPlan best = plans[0];
        foreach (plan; plans[1..$])
        {
            if (plan.expectedCost() < best.expectedCost())
                best = plan;
        }
        return best;
    }
    
    /// Find plan that optimizes for time
    BuildPlan optimizeForTime() const pure @safe
    {
        assert(plans.length > 0, "Empty Pareto frontier");
        
        BuildPlan best = plans[0];
        foreach (plan; plans[1..$])
        {
            if (plan.expectedTime() < best.expectedTime())
                best = plan;
        }
        return best;
    }
    
    /// Find balanced plan (minimize combined objective)
    BuildPlan optimizeBalanced(float alpha = 0.5f) const pure @safe
    {
        assert(plans.length > 0, "Empty Pareto frontier");
        
        BuildPlan best = plans[0];
        float bestObjective = best.objective(alpha);
        
        foreach (plan; plans[1..$])
        {
            immutable obj = plan.objective(alpha);
            if (obj < bestObjective)
            {
                best = plan;
                bestObjective = obj;
            }
        }
        return best;
    }
    
    /// Find fastest plan within budget
    BuildPlan findWithinBudget(float budgetUSD) const pure @safe
    {
        assert(plans.length > 0, "Empty Pareto frontier");
        
        // Filter plans within budget
        auto affordable = plans.filter!(p => p.expectedCost() <= budgetUSD).array;
        
        if (affordable.length == 0)
        {
            // No affordable plan, return cheapest
            return optimizeForCost();
        }
        
        // Return fastest among affordable
        BuildPlan best = affordable[0];
        foreach (plan; affordable[1..$])
        {
            if (plan.expectedTime() < best.expectedTime())
                best = plan;
        }
        return best;
    }
    
    /// Find cheapest plan within time limit
    BuildPlan findWithinTime(Duration timeLimit) const pure @safe
    {
        assert(plans.length > 0, "Empty Pareto frontier");
        
        // Filter plans within time limit
        auto fast = plans.filter!(p => p.expectedTime() <= timeLimit).array;
        
        if (fast.length == 0)
        {
            // No fast enough plan, return fastest
            return optimizeForTime();
        }
        
        // Return cheapest among fast enough
        BuildPlan best = fast[0];
        foreach (plan; fast[1..$])
        {
            if (plan.expectedCost() < best.expectedCost())
                best = plan;
        }
        return best;
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
    
    if (totalSeconds < 60)
        return totalSeconds.to!string ~ "s";
    else if (totalSeconds < 3600)
        return (totalSeconds / 60).to!string ~ "m " ~ 
               (totalSeconds % 60).to!string ~ "s";
    else
        return (totalSeconds / 3600).to!string ~ "h " ~ 
               ((totalSeconds % 3600) / 60).to!string ~ "m";
}
