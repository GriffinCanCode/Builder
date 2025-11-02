module distributed.metrics.steal;

import std.datetime : Duration, MonoTime, msecs;
import core.atomic;
import core.sync.mutex : Mutex;
import distributed.protocol.protocol;

/// Work-stealing telemetry and observability
/// Thread-safe metrics collection for distributed work-stealing
final class StealTelemetry
{
    private Mutex mutex;
    
    // Counters
    private shared size_t totalAttempts;
    private shared size_t successfulSteals;
    private shared size_t failedSteals;
    private shared size_t timeouts;
    private shared size_t networkErrors;
    private shared size_t rejections;
    
    // Timing
    private shared long totalLatencyUs;     // Microseconds
    private shared long minLatencyUs;
    private shared long maxLatencyUs;
    
    // Histogram buckets (microseconds)
    private shared size_t[10] latencyBuckets;
    private immutable long[10] bucketBounds = [
        100, 500, 1_000, 5_000, 10_000,     // 0.1ms to 10ms
        50_000, 100_000, 500_000, 1_000_000, // 50ms to 1s
        long.max
    ];
    
    // Peer-specific metrics
    private PeerMetrics[WorkerId] peerMetrics;
    
    this() @trusted
    {
        mutex = new Mutex();
        atomicStore(minLatencyUs, long.max);
        atomicStore(maxLatencyUs, cast(long)0);
    }
    
    /// Record steal attempt
    void recordAttempt(WorkerId victim, Duration latency, bool success) @trusted
    {
        atomicOp!"+="(totalAttempts, 1);
        
        if (success)
            atomicOp!"+="(successfulSteals, 1);
        else
            atomicOp!"+="(failedSteals, 1);
        
        // Update latency stats
        immutable latencyUs = latency.total!"usecs";
        atomicOp!"+="(totalLatencyUs, latencyUs);
        
        // Update min/max
        updateMin(minLatencyUs, latencyUs);
        updateMax(maxLatencyUs, latencyUs);
        
        // Update histogram
        updateHistogram(latencyUs);
        
        // Update peer metrics
        synchronized (mutex)
        {
            if (victim !in peerMetrics)
                peerMetrics[victim] = PeerMetrics.init;
            
            peerMetrics[victim].attempts++;
            if (success)
                peerMetrics[victim].successes++;
            peerMetrics[victim].totalLatencyUs += latencyUs;
        }
    }
    
    /// Record timeout
    void recordTimeout(WorkerId victim) @trusted
    {
        atomicOp!"+="(timeouts, 1);
        atomicOp!"+="(failedSteals, 1);
        
        synchronized (mutex)
        {
            if (victim !in peerMetrics)
                peerMetrics[victim] = PeerMetrics.init;
            
            peerMetrics[victim].timeouts++;
        }
    }
    
    /// Record network error
    void recordNetworkError(WorkerId victim) @trusted
    {
        atomicOp!"+="(networkErrors, 1);
        atomicOp!"+="(failedSteals, 1);
        
        synchronized (mutex)
        {
            if (victim !in peerMetrics)
                peerMetrics[victim] = PeerMetrics.init;
            
            peerMetrics[victim].networkErrors++;
        }
    }
    
    /// Record rejection (victim has no work)
    void recordRejection(WorkerId victim) @trusted
    {
        atomicOp!"+="(rejections, 1);
        atomicOp!"+="(failedSteals, 1);
        
        synchronized (mutex)
        {
            if (victim !in peerMetrics)
                peerMetrics[victim] = PeerMetrics.init;
            
            peerMetrics[victim].rejections++;
        }
    }
    
    /// Get aggregate statistics
    StealStats getStats() @trusted
    {
        StealStats stats;
        
        stats.totalAttempts = atomicLoad(totalAttempts);
        stats.successfulSteals = atomicLoad(successfulSteals);
        stats.failedSteals = atomicLoad(failedSteals);
        stats.timeouts = atomicLoad(timeouts);
        stats.networkErrors = atomicLoad(networkErrors);
        stats.rejections = atomicLoad(rejections);
        
        // Calculate success rate
        if (stats.totalAttempts > 0)
            stats.successRate = cast(float)stats.successfulSteals / stats.totalAttempts;
        
        // Calculate average latency
        if (stats.successfulSteals > 0)
        {
            immutable total = atomicLoad(totalLatencyUs);
            stats.avgLatencyUs = total / stats.successfulSteals;
        }
        
        stats.minLatencyUs = atomicLoad(minLatencyUs);
        stats.maxLatencyUs = atomicLoad(maxLatencyUs);
        
        // Copy histogram
        foreach (i; 0 .. latencyBuckets.length)
            stats.latencyBuckets[i] = atomicLoad(latencyBuckets[i]);
        
        return stats;
    }
    
    /// Get per-peer statistics
    PeerMetrics getPeerStats(WorkerId peer) @trusted
    {
        synchronized (mutex)
        {
            if (auto metrics = peer in peerMetrics)
                return *metrics;
            
            return PeerMetrics.init;
        }
    }
    
    /// Get all peer statistics
    PeerMetrics[WorkerId] getAllPeerStats() @trusted
    {
        synchronized (mutex)
        {
            return peerMetrics.dup;
        }
    }
    
    /// Reset all metrics
    void reset() @trusted
    {
        atomicStore(totalAttempts, cast(size_t)0);
        atomicStore(successfulSteals, cast(size_t)0);
        atomicStore(failedSteals, cast(size_t)0);
        atomicStore(timeouts, cast(size_t)0);
        atomicStore(networkErrors, cast(size_t)0);
        atomicStore(rejections, cast(size_t)0);
        atomicStore(totalLatencyUs, cast(long)0);
        atomicStore(minLatencyUs, long.max);
        atomicStore(maxLatencyUs, cast(long)0);
        
        foreach (i; 0 .. latencyBuckets.length)
            atomicStore(latencyBuckets[i], cast(size_t)0);
        
        synchronized (mutex)
        {
            peerMetrics.clear();
        }
    }
    
    private:
    
    /// Atomic min update
    void updateMin(ref shared long current, long value) @trusted nothrow @nogc
    {
        long oldValue = atomicLoad(current);
        while (value < oldValue)
        {
            if (cas(&current, oldValue, value))
                break;
            oldValue = atomicLoad(current);
        }
    }
    
    /// Atomic max update
    void updateMax(ref shared long current, long value) @trusted nothrow @nogc
    {
        long oldValue = atomicLoad(current);
        while (value > oldValue)
        {
            if (cas(&current, oldValue, value))
                break;
            oldValue = atomicLoad(current);
        }
    }
    
    /// Update latency histogram
    void updateHistogram(long latencyUs) @trusted nothrow @nogc
    {
        foreach (i, bound; bucketBounds)
        {
            if (latencyUs <= bound)
            {
                atomicOp!"+="(latencyBuckets[i], 1);
                break;
            }
        }
    }
}

/// Aggregate steal statistics
struct StealStats
{
    size_t totalAttempts;
    size_t successfulSteals;
    size_t failedSteals;
    size_t timeouts;
    size_t networkErrors;
    size_t rejections;
    
    float successRate;
    long avgLatencyUs;
    long minLatencyUs;
    long maxLatencyUs;
    
    size_t[10] latencyBuckets;
    
    /// Format for display
    string toString() const
    {
        import std.format : format;
        import std.algorithm : sum;
        
        immutable totalOps = latencyBuckets[].sum;
        
        string result = format(
            "Steal Statistics:\n" ~
            "  Attempts:    %d\n" ~
            "  Successes:   %d (%.1f%%)\n" ~
            "  Failures:    %d\n" ~
            "    Timeouts:  %d\n" ~
            "    NetErrors: %d\n" ~
            "    Rejections:%d\n" ~
            "  Latency:\n" ~
            "    Avg: %.2f ms\n" ~
            "    Min: %.2f ms\n" ~
            "    Max: %.2f ms\n",
            totalAttempts,
            successfulSteals, successRate * 100,
            failedSteals,
            timeouts,
            networkErrors,
            rejections,
            avgLatencyUs / 1000.0,
            minLatencyUs == long.max ? 0 : minLatencyUs / 1000.0,
            maxLatencyUs / 1000.0
        );
        
        // Latency histogram
        if (totalOps > 0)
        {
            result ~= "  Latency Distribution:\n";
            immutable string[10] labels = [
                "<100us", "<500us", "<1ms", "<5ms", "<10ms",
                "<50ms", "<100ms", "<500ms", "<1s", ">=1s"
            ];
            
            foreach (i, count; latencyBuckets)
            {
                if (count > 0)
                {
                    immutable pct = (count * 100.0) / totalOps;
                    result ~= format("    %8s: %5d (%.1f%%)\n", 
                        labels[i], count, pct);
                }
            }
        }
        
        return result;
    }
}

/// Per-peer metrics
struct PeerMetrics
{
    size_t attempts;
    size_t successes;
    size_t timeouts;
    size_t networkErrors;
    size_t rejections;
    long totalLatencyUs;
    
    /// Success rate for this peer
    float successRate() const pure @safe nothrow @nogc
    {
        if (attempts == 0)
            return 0.0;
        return cast(float)successes / attempts;
    }
    
    /// Average latency for this peer
    long avgLatencyUs() const pure @safe nothrow @nogc
    {
        if (successes == 0)
            return 0;
        return totalLatencyUs / successes;
    }
}



