module engine.economics.integration;

import std.datetime : Duration, seconds;
import std.conv : to;
import std.string : toLower;
import engine.economics.pricing;
import engine.economics.optimizer;
import engine.economics.estimator;
import engine.economics.strategies;
import engine.economics.tracking;
import engine.graph : BuildGraph;
import infrastructure.config.schema.schema : EconomicsConfig;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

/// Economic optimizer integration with build system
/// Wraps optimizer with configuration and provides simple API
final class EconomicsIntegration
{
    private CostOptimizer optimizer;
    private CostTracker tracker;
    private PricingConfig pricingConfig;
    private bool enabled;
    
    this(EconomicsConfig config, string cacheDir) @safe
    {
        this.enabled = config.enabled;
        
        if (!enabled)
            return;
        
        // Initialize pricing configuration
        this.pricingConfig = PricingConfig();
        this.pricingConfig.enabled = true;
        
        // Set cloud provider
        switch (config.provider.toLower)
        {
            case "aws":
                this.pricingConfig.provider = CloudProvider.aws();
                break;
            case "gcp":
                this.pricingConfig.provider = CloudProvider.gcp();
                break;
            case "azure":
                this.pricingConfig.provider = CloudProvider.azure();
                break;
            case "local":
                this.pricingConfig.provider = CloudProvider.local();
                break;
            default:
                this.pricingConfig.provider = CloudProvider.aws();
        }
        
        // Set pricing tier
        switch (config.pricingTier.toLower)
        {
            case "spot":
                this.pricingConfig.profile = PricingProfile.spot;
                break;
            case "ondemand":
            case "on-demand":
                this.pricingConfig.profile = PricingProfile.onDemand;
                break;
            case "reserved":
                this.pricingConfig.profile = PricingProfile.reserved;
                break;
            case "premium":
                this.pricingConfig.profile = PricingProfile.premium;
                break;
            default:
                this.pricingConfig.profile = PricingProfile.onDemand;
        }
        
        // Initialize history and tracker
        auto history = new ExecutionHistory();
        this.tracker = new CostTracker(history, cacheDir);
        
        // Try to load historical data
        auto loadResult = tracker.load();
        if (loadResult.isErr)
        {
            Logger.warning("Could not load execution history: " ~ 
                          loadResult.unwrapErr().message());
        }
        
        // Initialize estimator and optimizer
        auto estimator = new CostEstimator(history);
        this.optimizer = new CostOptimizer(estimator, pricingConfig);
        
        Logger.info("Economic optimizer initialized");
        Logger.info("  Provider: " ~ pricingConfig.provider.name);
        Logger.info("  Tier: " ~ pricingConfig.profile.tier.to!string);
    }
    
    /// Check if economics is enabled
    bool isEnabled() const pure @safe nothrow @nogc => enabled;
    
    /// Compute optimal build plan for graph
    Result!(BuildPlan, BuildError) computePlan(
        BuildGraph graph,
        EconomicsConfig config
    ) @trusted
    {
        if (!enabled)
        {
            // Return default local plan
            BuildPlan defaultPlan;
            defaultPlan.strategy = StrategyConfig(ExecutionStrategy.Local, 1, 4);
            defaultPlan.estimatedTime = seconds(0);
            defaultPlan.estimatedCost = 0.0f;
            return Ok!(BuildPlan, BuildError)(defaultPlan);
        }
        
        // Build constraints from config
        OptimizationConstraints constraints;
        
        // Parse optimization mode
        switch (config.optimize.toLower)
        {
            case "cost":
                constraints.objective = OptimizationObjective.MinimizeCost;
                break;
            case "time":
                constraints.objective = OptimizationObjective.MinimizeTime;
                break;
            case "balanced":
                constraints.objective = OptimizationObjective.Balanced;
                break;
            default:
                constraints.objective = OptimizationObjective.Balanced;
        }
        
        // Apply constraints
        constraints.budgetUSD = config.budgetUSD;
        if (config.timeLimit != float.infinity)
        {
            constraints.timeLimit = seconds(cast(long)config.timeLimit);
        }
        
        // If budget or time limit specified, override objective
        if (config.budgetUSD != float.infinity)
        {
            constraints.objective = OptimizationObjective.Budget;
        }
        else if (config.timeLimit != float.infinity)
        {
            constraints.objective = OptimizationObjective.TimeLimit;
        }
        
        // Optimize
        return optimizer.optimize(graph, constraints);
    }
    
    /// Get cost tracker for recording actual costs
    CostTracker getTracker() @safe nothrow @nogc => tracker;
    
    /// Display plan to user
    void displayPlan(const BuildPlan plan) const @trusted
    {
        import std.stdio : writeln;
        
        if (!enabled)
            return;
        
        writeln("\n" ~ "━".repeat(60).to!string);
        writeln("Economic Build Plan");
        writeln("━".repeat(60).to!string);
        writeln(formatPlan(plan));
        writeln("━".repeat(60).to!string ~ "\n");
    }
    
    /// Save execution history on shutdown
    Result!BuildError shutdown() @trusted
    {
        if (!enabled)
            return Ok!BuildError();
        
        // Display cost summary
        immutable summary = tracker.getSummary();
        
        Logger.info("\n" ~ summary.format());
        
        // Save history
        return tracker.save();
    }
}

/// Helper: repeat string N times
private string repeat(string s, size_t n) pure @safe
{
    import std.array : join, array;
    import std.range : iota, map;
    
    return iota(n).map!(_ => s).join;
}

