module engine.economics.estimator;

import std.datetime : Duration, seconds, msecs;
import std.algorithm : map, sum, max;
import std.array : array;
import std.conv : to;
import engine.economics.pricing;
import engine.graph : BuildGraph, BuildNode, BuildStatus;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

/// Build estimate (time + resource usage)
struct BuildEstimate
{
    Duration duration;
    ResourceUsageEstimate usage;
}

/// Cost estimator - predicts build time and cost from historical data
final class CostEstimator
{
    private ExecutionHistory history;
    
    this(ExecutionHistory history) @safe
    {
        this.history = history;
    }
    
    /// Estimate entire build graph
    Result!(BuildEstimate, BuildError) estimateGraph(BuildGraph graph) @trusted
    {
        try
        {
            // Sum estimates for all nodes (conservative: assume sequential)
            Duration totalTime;
            size_t totalCores;
            size_t totalMemory;
            size_t totalNetwork;
            size_t totalDiskIO;
            
            foreach (node; graph.nodes.values)
            {
                auto nodeEstimateResult = estimateNode(node);
                if (nodeEstimateResult.isErr)
                    return Err!(BuildEstimate, BuildError)(nodeEstimateResult.unwrapErr());
                
                auto nodeEstimate = nodeEstimateResult.unwrap();
                
                totalTime += nodeEstimate.duration;
                totalCores += nodeEstimate.usage.cores;
                totalMemory = max(totalMemory, nodeEstimate.usage.memoryBytes);
                totalNetwork += nodeEstimate.usage.networkBytes;
                totalDiskIO += nodeEstimate.usage.diskIOBytes;
            }
            
            // Average cores across all nodes
            immutable avgCores = graph.nodes.length > 0 ? 
                (totalCores / graph.nodes.length) : 4;
            
            BuildEstimate estimate;
            estimate.duration = totalTime;
            estimate.usage = ResourceUsageEstimate(
                avgCores,
                totalMemory,
                totalNetwork,
                totalDiskIO,
                totalTime
            );
            
            return Ok!(BuildEstimate, BuildError)(estimate);
        }
        catch (Exception e)
        {
            return Err!(BuildEstimate, BuildError)(
                new EconomicsError("Failed to estimate graph: " ~ e.msg)
            );
        }
    }
    
    /// Estimate single build node
    Result!(BuildEstimate, BuildError) estimateNode(BuildNode node) @trusted
    {
        import std.algorithm : canFind;
        
        try
        {
            // Check historical data first
            if (auto historicalData = history.lookup(node.id.toString()))
            {
                Logger.debugLog("Using historical data for " ~ node.idString);
                return Ok!(BuildEstimate, BuildError)(historicalData.estimate);
            }
            
            // Fallback to heuristics based on target type
            BuildEstimate estimate;
            
            // Base estimates by language/type (heuristics)
            immutable language = node.target.language.to!string;
            
            if (canFind(["C", "C++", "Cpp"], language))
            {
                // C/C++ compilation is typically slow
                estimate.duration = seconds(30);
                estimate.usage = ResourceUsageEstimate(
                    4,                          // 4 cores
                    2 * 1024 * 1024 * 1024,    // 2GB
                    10 * 1024 * 1024,          // 10MB network
                    100 * 1024 * 1024,         // 100MB disk I/O
                    estimate.duration
                );
            }
            else if (canFind(["Rust", "Go"], language))
            {
                // Rust/Go are moderately fast
                estimate.duration = seconds(15);
                estimate.usage = ResourceUsageEstimate(
                    4,
                    1 * 1024 * 1024 * 1024,    // 1GB
                    5 * 1024 * 1024,
                    50 * 1024 * 1024,
                    estimate.duration
                );
            }
            else if (canFind(["Python", "JavaScript", "TypeScript"], language))
            {
                // Interpreted/transpiled languages are fast
                estimate.duration = seconds(5);
                estimate.usage = ResourceUsageEstimate(
                    2,
                    512 * 1024 * 1024,         // 512MB
                    2 * 1024 * 1024,
                    20 * 1024 * 1024,
                    estimate.duration
                );
            }
            else if (language == "D")
            {
                // D compilation is fast
                estimate.duration = seconds(10);
                estimate.usage = ResourceUsageEstimate(
                    4,
                    1 * 1024 * 1024 * 1024,
                    5 * 1024 * 1024,
                    50 * 1024 * 1024,
                    estimate.duration
                );
            }
            else
            {
                // Generic fallback
                estimate.duration = seconds(10);
                estimate.usage = ResourceUsageEstimate(
                    2,
                    1 * 1024 * 1024 * 1024,
                    5 * 1024 * 1024,
                    50 * 1024 * 1024,
                    estimate.duration
                );
            }
            
            // Adjust based on source count
            immutable sourceCount = node.target.sources.length;
            if (sourceCount > 10)
            {
                // Scale duration linearly with source count
                immutable scaleFactor = 1.0f + (sourceCount - 10) * 0.1f;
                immutable scaledMs = cast(long)(estimate.duration.total!"msecs" * scaleFactor);
                estimate.duration = msecs(scaledMs);
                estimate.usage.duration = estimate.duration;
            }
            
            return Ok!(BuildEstimate, BuildError)(estimate);
        }
        catch (Exception e)
        {
            return Err!(BuildEstimate, BuildError)(
                new EconomicsError("Failed to estimate node: " ~ e.msg)
            );
        }
    }
    
    /// Estimate cache hit probability for graph
    float estimateCacheHitProbability(BuildGraph graph) @trusted
    {
        if (graph.nodes.length == 0)
            return 0.0f;
        
        size_t cacheableNodes = 0;
        float totalProb = 0.0f;
        
        foreach (node; graph.nodes.values)
        {
            immutable prob = estimateCacheHitProbabilityForNode(node);
            totalProb += prob;
            if (prob > 0.0f)
                cacheableNodes++;
        }
        
        return cacheableNodes > 0 ? (totalProb / graph.nodes.length) : 0.0f;
    }
    
    /// Estimate cache hit probability for single node
    float estimateCacheHitProbabilityForNode(BuildNode node) @trusted
    {
        // Check if node was previously cached
        if (auto hist = history.lookup(node.id.toString()))
        {
            // Historical cache hit rate
            return hist.cacheHitRate;
        }
        
        // Heuristic: stable dependencies have high cache hit rate
        // Frequently changing code has low cache hit rate
        
        // For now, use conservative estimate
        if (node.dependencyIds.length == 0)
        {
            // Leaf nodes (source files) change frequently
            return 0.1f;  // 10% cache hit rate
        }
        else
        {
            // Dependent nodes benefit from stable dependencies
            return 0.3f;  // 30% cache hit rate
        }
    }
}

/// Execution history tracking
final class ExecutionHistory
{
    private HistoryEntry[string] entries;
    
    /// Record execution
    void record(
        string targetId,
        Duration duration,
        ResourceUsageEstimate usage,
        bool cacheHit
    ) @trusted
    {
        if (auto entry = targetId in entries)
        {
            // Update exponential moving average
            entry.update(duration, usage, cacheHit);
        }
        else
        {
            // New entry
            entries[targetId] = HistoryEntry(duration, usage, cacheHit);
        }
    }
    
    /// Lookup historical estimate
    const(HistoryEntry)* lookup(string targetId) @trusted
    {
        if (auto entry = targetId in entries)
            return entry;
        return null;
    }
    
    /// Clear history
    void clear() @trusted => entries.clear();
    
    /// Export to JSON for persistence
    string toJson() const @trusted
    {
        import std.format : format;
        import std.array : join;
        
        string[] jsonEntries;
        
        foreach (targetId, entry; entries)
        {
            jsonEntries ~= format(
                `{"target":"%s","duration":%d,"cores":%d,"memory":%d,"network":%d,"diskIO":%d,"cacheHitRate":%.3f,"execCount":%d}`,
                targetId,
                entry.estimate.duration.total!"msecs",
                entry.estimate.usage.cores,
                entry.estimate.usage.memoryBytes,
                entry.estimate.usage.networkBytes,
                entry.estimate.usage.diskIOBytes,
                entry.cacheHitRate,
                entry.executionCount
            );
        }
        
        return "[" ~ jsonEntries.join(",") ~ "]";
    }
    
    /// Import from JSON
    static ExecutionHistory fromJson(string json) @trusted
    {
        import std.json : parseJSON, JSONValue, JSONType, JSONException;
        import std.datetime : msecs;
        
        auto history = new ExecutionHistory();
        
        try
        {
            JSONValue root = parseJSON(json);
            
            if (root.type != JSONType.array)
                return history;
            
            foreach (item; root.array)
            {
                if (item.type != JSONType.object)
                    continue;
                
                // Extract fields
                string targetId = item["target"].str;
                long durationMs = item["duration"].integer;
                int cores = cast(int)item["cores"].integer;
                ulong memory = cast(ulong)item["memory"].integer;
                ulong network = cast(ulong)item["network"].integer;
                ulong diskIO = cast(ulong)item["diskIO"].integer;
                float cacheHitRate = cast(float)item["cacheHitRate"].floating;
                size_t execCount = cast(size_t)item["execCount"].integer;
                
                // Reconstruct entry
                ResourceUsageEstimate usage;
                usage.cores = cores;
                usage.memoryBytes = memory;
                usage.networkBytes = network;
                usage.diskIOBytes = diskIO;
                
                HistoryEntry entry;
                entry.estimate.duration = msecs(durationMs);
                entry.estimate.usage = usage;
                entry.cacheHitRate = cacheHitRate;
                entry.executionCount = execCount;
                
                history.entries[targetId] = entry;
            }
        }
        catch (JSONException e)
        {
            // Return empty history on parse failure
            import infrastructure.utils.logging.logger;
            Logger.warning("Failed to parse execution history JSON: " ~ e.msg);
        }
        
        return history;
    }
}

/// Historical entry for a target
private struct HistoryEntry
{
    BuildEstimate estimate;
    float cacheHitRate = 0.0f;
    size_t executionCount = 0;
    
    private enum float ALPHA = 0.3f;  // Exponential moving average weight
    
    this(Duration duration, ResourceUsageEstimate usage, bool cacheHit) pure @safe nothrow @nogc
    {
        estimate.duration = duration;
        estimate.usage = usage;
        cacheHitRate = cacheHit ? 1.0f : 0.0f;
        executionCount = 1;
    }
    
    /// Update with new execution data (exponential moving average)
    void update(Duration duration, ResourceUsageEstimate usage, bool cacheHit) @safe nothrow @nogc
    {
        // Update duration (EMA)
        immutable oldMs = estimate.duration.total!"msecs";
        immutable newMs = duration.total!"msecs";
        immutable avgMs = cast(long)(oldMs * (1.0f - ALPHA) + newMs * ALPHA);
        estimate.duration = msecs(avgMs);
        
        // Update resource usage (EMA)
        estimate.usage.cores = cast(size_t)(
            estimate.usage.cores * (1.0f - ALPHA) + usage.cores * ALPHA
        );
        estimate.usage.memoryBytes = cast(size_t)(
            estimate.usage.memoryBytes * (1.0f - ALPHA) + usage.memoryBytes * ALPHA
        );
        estimate.usage.networkBytes = cast(size_t)(
            estimate.usage.networkBytes * (1.0f - ALPHA) + usage.networkBytes * ALPHA
        );
        estimate.usage.diskIOBytes = cast(size_t)(
            estimate.usage.diskIOBytes * (1.0f - ALPHA) + usage.diskIOBytes * ALPHA
        );
        estimate.usage.duration = estimate.duration;
        
        // Update cache hit rate (EMA)
        immutable hitValue = cacheHit ? 1.0f : 0.0f;
        cacheHitRate = cacheHitRate * (1.0f - ALPHA) + hitValue * ALPHA;
        
        executionCount++;
    }
}

/// Re-export EconomicsError
public import engine.economics.optimizer : EconomicsError;
