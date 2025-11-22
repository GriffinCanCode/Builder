module engine.economics.pricing;

import std.datetime : Duration;
import std.conv : to;
import std.algorithm : map;
import std.array : array;
import infrastructure.errors;

/// Resource pricing rates (USD per unit)
/// Models actual cloud provider costs
struct ResourcePricing
{
    float costPerCoreHour = 0.04f;      // $0.04/core-hour (AWS t3.medium equivalent)
    float costPerGBHour = 0.005f;       // $0.005/GB-hour
    float costPerNetworkGB = 0.09f;     // $0.09/GB network transfer
    float costPerDiskIOGB = 0.001f;     // $0.001/GB disk I/O
    
    /// Compute cost for CPU time
    float cpuCost(size_t cores, Duration duration) const pure @safe nothrow @nogc =>
        cores * (duration.total!"msecs" / 3_600_000.0f) * costPerCoreHour;
    
    /// Compute cost for memory usage
    float memoryCost(size_t memoryBytes, Duration duration) const pure @safe nothrow @nogc =>
        (memoryBytes / (1024.0f * 1024.0f * 1024.0f)) * (duration.total!"msecs" / 3_600_000.0f) * costPerGBHour;
    
    /// Compute cost for network transfer
    float networkCost(size_t transferBytes) const pure @safe nothrow @nogc =>
        (transferBytes / (1024.0f * 1024.0f * 1024.0f)) * costPerNetworkGB;
    
    /// Compute cost for disk I/O
    float diskCost(size_t ioBytes) const pure @safe nothrow @nogc =>
        (ioBytes / (1024.0f * 1024.0f * 1024.0f)) * costPerDiskIOGB;
    
    /// Total cost for resource usage
    float totalCost(ResourceUsageEstimate usage) const pure @safe nothrow @nogc =>
        cpuCost(usage.cores, usage.duration) + memoryCost(usage.memoryBytes, usage.duration) +
        networkCost(usage.networkBytes) + diskCost(usage.diskIOBytes);
}

/// Resource usage estimate for cost calculation
struct ResourceUsageEstimate
{
    size_t cores;
    size_t memoryBytes;
    size_t networkBytes;
    size_t diskIOBytes;
    Duration duration;
}

/// Pricing tier (different cloud instance types)
enum PricingTier : ubyte
{
    Spot,       // Spot instances (cheap, interruptible)
    OnDemand,   // On-demand instances (standard)
    Reserved,   // Reserved instances (committed)
    Premium     // Dedicated/high-performance
}

/// Pricing profile for different instance tiers
struct PricingProfile
{
    PricingTier tier;
    float multiplier;      // Cost multiplier vs base pricing
    float reliability;     // Probability of completion (1.0 = guaranteed)
    float speedup;         // Performance multiplier
    
    /// Standard pricing profiles
    static immutable PricingProfile spot = PricingProfile(PricingTier.Spot, 0.3f, 0.85f, 1.0f);
    static immutable PricingProfile onDemand = PricingProfile(PricingTier.OnDemand, 1.0f, 0.99f, 1.0f);
    static immutable PricingProfile reserved = PricingProfile(PricingTier.Reserved, 0.6f, 0.99f, 1.0f);
    static immutable PricingProfile premium = PricingProfile(PricingTier.Premium, 2.0f, 0.999f, 1.5f);
    
    /// Adjust pricing for tier
    ResourcePricing adjust(ResourcePricing base) const pure @safe nothrow @nogc
    {
        ResourcePricing adjusted = base;
        adjusted.costPerCoreHour *= multiplier;
        adjusted.costPerGBHour *= multiplier;
        adjusted.costPerNetworkGB *= multiplier;
        adjusted.costPerDiskIOGB *= multiplier;
        return adjusted;
    }
}

/// Cloud provider pricing (preset configurations)
struct CloudProvider
{
    string name;
    ResourcePricing pricing;
    
    /// AWS EC2 pricing (approximate, us-east-1)
    static CloudProvider aws() pure @safe nothrow @nogc
    {
        return CloudProvider(
            "AWS",
            ResourcePricing(
                0.0416f,  // t3.medium: $0.0416/hour = $0.0416/core-hour (1 vCPU)
                0.0052f,  // $0.0052/GB-hour
                0.09f,    // $0.09/GB transfer (first 10TB)
                0.001f    // EBS I/O approximation
            )
        );
    }
    
    /// GCP Compute Engine pricing (approximate, us-central1)
    static CloudProvider gcp() pure @safe nothrow @nogc
    {
        return CloudProvider(
            "GCP",
            ResourcePricing(
                0.0475f,  // e2-medium: ~$0.0475/core-hour
                0.0064f,  // $0.0064/GB-hour
                0.085f,   // $0.085/GB network egress
                0.001f    // Disk I/O approximation
            )
        );
    }
    
    /// Azure VM pricing (approximate, East US)
    static CloudProvider azure() pure @safe nothrow @nogc
    {
        return CloudProvider(
            "Azure",
            ResourcePricing(
                0.042f,   // B2s: ~$0.042/core-hour
                0.0055f,  // $0.0055/GB-hour
                0.087f,   // $0.087/GB bandwidth
                0.001f    // Disk I/O approximation
            )
        );
    }
    
    /// Local (free - developer machine)
    static CloudProvider local() pure @safe nothrow @nogc
    {
        return CloudProvider(
            "Local",
            ResourcePricing(0.0f, 0.0f, 0.0f, 0.0f)
        );
    }
}

/// Pricing configuration
struct PricingConfig
{
    CloudProvider provider;
    PricingProfile profile;
    
    /// Enable cost estimation?
    bool enabled = true;
    
    /// Cache lookup cost (effectively zero)
    float cacheLookupCost = 0.0001f;  // $0.0001 per lookup
    
    /// Network transfer within same region (much cheaper)
    float regionalTransferCost = 0.01f;  // $0.01/GB (vs $0.09 inter-region)
    
    /// Load from environment variables
    static PricingConfig fromEnvironment() @safe
    {
        import std.process : environment;
        import std.string : toLower;
        
        PricingConfig config;
        
        // Detect provider
        immutable providerStr = environment.get("BUILDER_CLOUD_PROVIDER", "aws").toLower;
        switch (providerStr)
        {
            case "aws":
                config.provider = CloudProvider.aws();
                break;
            case "gcp":
                config.provider = CloudProvider.gcp();
                break;
            case "azure":
                config.provider = CloudProvider.azure();
                break;
            case "local":
                config.provider = CloudProvider.local();
                break;
            default:
                config.provider = CloudProvider.aws();
        }
        
        // Detect tier
        immutable tierStr = environment.get("BUILDER_PRICING_TIER", "ondemand").toLower;
        switch (tierStr)
        {
            case "spot":
                config.profile = PricingProfile.spot;
                break;
            case "ondemand":
            case "on-demand":
                config.profile = PricingProfile.onDemand;
                break;
            case "reserved":
                config.profile = PricingProfile.reserved;
                break;
            case "premium":
                config.profile = PricingProfile.premium;
                break;
            default:
                config.profile = PricingProfile.onDemand;
        }
        
        // Allow cost tracking to be disabled
        immutable costTrackingStr = environment.get("BUILDER_COST_TRACKING", "true").toLower;
        config.enabled = (costTrackingStr == "true" || costTrackingStr == "1");
        
        return config;
    }
    
    /// Get effective pricing (apply tier adjustments)
    ResourcePricing effectivePricing() const pure @safe nothrow @nogc
    {
        return profile.adjust(provider.pricing);
    }
}

/// Format cost as USD string
string formatCost(float cost) pure @safe
{
    import std.format : format;
    return cost < 0.01f ? "$0.00" : format("$%.2f", cost);
}

/// Format cost estimate with breakdown
string formatCostBreakdown(ResourceUsageEstimate usage, ResourcePricing pricing) @safe
{
    import std.format : format;
    
    immutable cpuCost = pricing.cpuCost(usage.cores, usage.duration);
    immutable memCost = pricing.memoryCost(usage.memoryBytes, usage.duration);
    immutable netCost = pricing.networkCost(usage.networkBytes);
    immutable diskCost = pricing.diskCost(usage.diskIOBytes);
    immutable total = pricing.totalCost(usage);
    
    return format(
        "Cost Breakdown:\n" ~
        "  CPU:     %s (%d cores × %s)\n" ~
        "  Memory:  %s (%.1f GB × %s)\n" ~
        "  Network: %s (%.2f GB)\n" ~
        "  Disk I/O:%s (%.2f GB)\n" ~
        "  ─────────────────────\n" ~
        "  Total:   %s",
        formatCost(cpuCost), usage.cores, formatDuration(usage.duration),
        formatCost(memCost), usage.memoryBytes / (1024.0f * 1024.0f * 1024.0f), formatDuration(usage.duration),
        formatCost(netCost), usage.networkBytes / (1024.0f * 1024.0f * 1024.0f),
        formatCost(diskCost), usage.diskIOBytes / (1024.0f * 1024.0f * 1024.0f),
        formatCost(total)
    );
}

private string formatDuration(Duration d) pure @safe
{
    import std.format : format;
    immutable totalSeconds = d.total!"seconds";
    if (totalSeconds < 60) return format("%ds", totalSeconds);
    if (totalSeconds < 3600) return format("%dm %ds", totalSeconds / 60, totalSeconds % 60);
    return format("%dh %dm", totalSeconds / 3600, (totalSeconds % 3600) / 60);
}

