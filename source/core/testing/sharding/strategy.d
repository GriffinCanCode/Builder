module core.testing.sharding.strategy;

import std.algorithm : sort, sum, map;
import std.array : array;
import std.conv : to;
import utils.crypto.blake3;
import core.testing.results : TestCase;

/// Sharding strategy for distributing tests across workers
enum ShardStrategy
{
    RoundRobin,    // Simple round-robin distribution
    ContentBased,  // Content-addressed using BLAKE3 (consistent)
    Adaptive,      // Historical execution time based (optimal)
    LoadBased      // Dynamic load balancing
}

/// Shard assignment for a test
struct TestShard
{
    size_t shardId;        // Shard identifier
    string testId;         // Test identifier
    size_t estimatedMs;    // Estimated execution time (ms)
    string contentHash;    // Content hash for consistency
}

/// Historical test execution data
struct TestHistory
{
    string testId;
    size_t avgDurationMs;    // Average duration
    size_t runCount;         // Number of executions
    size_t failCount;        // Failure count
    double flakinessScore;   // Flakiness probability
    
    /// Check if test has sufficient history
    bool hasHistory() const pure nothrow @nogc
    {
        return runCount >= 3;
    }
}

/// Test sharding configuration
struct ShardConfig
{
    size_t shardCount = 4;              // Number of shards
    ShardStrategy strategy = ShardStrategy.Adaptive;
    size_t minTestsPerShard = 1;        // Minimum tests per shard
    size_t maxTestsPerShard = 100;      // Maximum tests per shard
    bool balanceByDuration = true;      // Balance by execution time
}

/// Test sharding engine
/// Distributes tests across workers optimally
final class ShardEngine
{
    private ShardConfig config;
    private TestHistory[string] history;
    
    this(ShardConfig config) pure nothrow @safe @nogc
    {
        this.config = config;
    }
    
    /// Load historical test data
    void loadHistory(TestHistory[string] history) nothrow @safe
    {
        this.history = history;
    }
    
    /// Compute shards for test suite
    TestShard[] computeShards(string[] testIds) @safe
    {
        final switch (config.strategy)
        {
            case ShardStrategy.RoundRobin:
                return shardRoundRobin(testIds);
            
            case ShardStrategy.ContentBased:
                return shardContentBased(testIds);
            
            case ShardStrategy.Adaptive:
                return shardAdaptive(testIds);
            
            case ShardStrategy.LoadBased:
                return shardLoadBased(testIds);
        }
    }
    
    /// Round-robin sharding (simple but predictable)
    private TestShard[] shardRoundRobin(string[] testIds) @safe
    {
        TestShard[] shards;
        shards.reserve(testIds.length);
        
        foreach (i, testId; testIds)
        {
            TestShard shard;
            shard.shardId = i % config.shardCount;
            shard.testId = testId;
            shard.estimatedMs = estimateDuration(testId);
            shards ~= shard;
        }
        
        return shards;
    }
    
    /// Content-based sharding (consistent across runs)
    /// Uses BLAKE3 for deterministic distribution
    private TestShard[] shardContentBased(string[] testIds) @safe
    {
        TestShard[] shards;
        shards.reserve(testIds.length);
        
        foreach (testId; testIds)
        {
            // Hash test ID to shard consistently
            immutable hash = BLAKE3.hashString(testId);
            immutable shardId = hashToShardId(hash);
            
            TestShard shard;
            shard.shardId = shardId;
            shard.testId = testId;
            shard.estimatedMs = estimateDuration(testId);
            shard.contentHash = hash;
            shards ~= shard;
        }
        
        return shards;
    }
    
    /// Adaptive sharding (optimal load distribution)
    /// Uses historical execution times for balanced shards
    private TestShard[] shardAdaptive(string[] testIds) @safe
    {
        // Estimate duration for each test
        struct TestWithDuration
        {
            string testId;
            size_t durationMs;
        }
        
        TestWithDuration[] tests;
        tests.reserve(testIds.length);
        
        foreach (testId; testIds)
        {
            tests ~= TestWithDuration(testId, estimateDuration(testId));
        }
        
        // Sort by duration descending (longest first)
        tests.sort!((a, b) => a.durationMs > b.durationMs);
        
        // Greedy bin packing: assign to least loaded shard
        size_t[] shardLoads = new size_t[config.shardCount];
        TestShard[] shards;
        shards.reserve(testIds.length);
        
        foreach (test; tests)
        {
            // Find shard with minimum load
            size_t minLoadShardId = 0;
            size_t minLoad = shardLoads[0];
            
            foreach (i, load; shardLoads)
            {
                if (load < minLoad)
                {
                    minLoad = load;
                    minLoadShardId = i;
                }
            }
            
            // Assign test to this shard
            TestShard shard;
            shard.shardId = minLoadShardId;
            shard.testId = test.testId;
            shard.estimatedMs = test.durationMs;
            shard.contentHash = BLAKE3.hashString(test.testId);
            shards ~= shard;
            
            // Update shard load
            shardLoads[minLoadShardId] += test.durationMs;
        }
        
        return shards;
    }
    
    /// Load-based sharding (dynamic, work-stealing compatible)
    private TestShard[] shardLoadBased(string[] testIds) @safe
    {
        // Similar to adaptive but marks all as eligible for stealing
        return shardAdaptive(testIds);
    }
    
    /// Estimate test duration from history or default
    private size_t estimateDuration(string testId) const nothrow @safe
    {
        auto historyPtr = testId in history;
        if (historyPtr is null)
            return 1000; // Default: 1 second
        
        return historyPtr.avgDurationMs;
    }
    
    /// Convert hash to shard ID consistently
    private size_t hashToShardId(string hash) const pure nothrow @safe
    {
        if (hash.length < 8)
            return 0;
        
        // Use first 8 bytes as uint64
        ulong value = 0;
        foreach (i; 0 .. 8)
        {
            value = (value << 8) | cast(ubyte)hash[i];
        }
        
        return cast(size_t)(value % config.shardCount);
    }
    
    /// Get statistics for sharding plan
    struct ShardStats
    {
        size_t totalTests;
        size_t totalDurationMs;
        size_t minTestsPerShard;
        size_t maxTestsPerShard;
        size_t minDurationMs;
        size_t maxDurationMs;
        double loadBalance;  // 0.0 (perfect) to 1.0 (imbalanced)
    }
    
    ShardStats computeStats(const TestShard[] shards) const pure nothrow @safe
    {
        if (shards.length == 0)
            return ShardStats.init;
        
        ShardStats stats;
        stats.totalTests = shards.length;
        
        // Compute per-shard statistics
        size_t[] shardCounts = new size_t[config.shardCount];
        size_t[] shardDurations = new size_t[config.shardCount];
        
        foreach (shard; shards)
        {
            shardCounts[shard.shardId]++;
            shardDurations[shard.shardId] += shard.estimatedMs;
        }
        
        // Find min/max
        stats.minTestsPerShard = size_t.max;
        stats.maxTestsPerShard = 0;
        stats.minDurationMs = size_t.max;
        stats.maxDurationMs = 0;
        
        foreach (i; 0 .. config.shardCount)
        {
            if (shardCounts[i] < stats.minTestsPerShard)
                stats.minTestsPerShard = shardCounts[i];
            if (shardCounts[i] > stats.maxTestsPerShard)
                stats.maxTestsPerShard = shardCounts[i];
            
            if (shardDurations[i] < stats.minDurationMs)
                stats.minDurationMs = shardDurations[i];
            if (shardDurations[i] > stats.maxDurationMs)
                stats.maxDurationMs = shardDurations[i];
            
            stats.totalDurationMs += shardDurations[i];
        }
        
        // Compute load balance (coefficient of variation)
        if (stats.maxDurationMs > 0)
        {
            immutable avgDuration = stats.totalDurationMs / config.shardCount;
            if (avgDuration > 0)
                stats.loadBalance = cast(double)(stats.maxDurationMs - stats.minDurationMs) / avgDuration;
        }
        
        return stats;
    }
}

