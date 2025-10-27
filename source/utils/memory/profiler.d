module utils.memory.profiler;

import std.datetime : Duration, SysTime, Clock, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import std.conv : to;
import std.algorithm : max;
import std.format : format;
import core.memory : GC;

/// Snapshot of memory usage at a point in time
struct MemorySnapshot
{
    /// Time when snapshot was taken
    SysTime timestamp;
    
    /// Heap memory in use (bytes)
    size_t heapUsed;
    
    /// Free memory in heap (bytes)
    size_t heapFree;
    
    /// Total heap size (used + free)
    size_t heapTotal;
    
    /// Number of GC collections performed
    size_t gcCollections;
    
    /// Name/label for this snapshot
    string label;
    
    /// Create a snapshot of current memory state
    /// 
    /// Safety: This function is @trusted because:
    /// 1. GC.stats() is @system but read-only query of GC state
    /// 2. No memory is allocated or modified
    /// 3. Clock.currTime() is safe time query
    /// 4. All operations are read-only information gathering
    /// 
    /// Invariants:
    /// - heapTotal = heapUsed + heapFree (maintained by GC.stats())
    /// - gcCollections is monotonically increasing
    /// - timestamp is always valid SysTime
    /// 
    /// What could go wrong:
    /// - GC.stats() returning invalid data: GC maintains invariants
    /// - Clock.currTime() failing: would throw (caught by caller)
    static MemorySnapshot take(string label = "") @trusted
    {
        auto stats = GC.stats();
        
        MemorySnapshot snap;
        snap.timestamp = Clock.currTime();
        snap.heapUsed = stats.usedSize;
        snap.heapFree = stats.freeSize;
        snap.heapTotal = stats.usedSize + stats.freeSize;
        snap.gcCollections = stats.numCollections;
        snap.label = label;
        
        return snap;
    }
    
    /// Format memory size as human-readable string
    string formatSize(size_t bytes) const pure nothrow @safe
    {
        if (bytes < 1024)
            return format("%d B", bytes);
        else if (bytes < 1024 * 1024)
            return format("%.2f KB", bytes / 1024.0);
        else if (bytes < 1024 * 1024 * 1024)
            return format("%.2f MB", bytes / (1024.0 * 1024.0));
        else
            return format("%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0));
    }
    
    /// Get heap utilization percentage
    double heapUtilization() const pure nothrow @safe
    {
        if (heapTotal == 0)
            return 0.0;
        return (heapUsed * 100.0) / heapTotal;
    }
    
    /// Display formatted snapshot
    string toString() const pure @safe
    {
        string result;
        if (label.length > 0)
            result ~= format("[%s]\n", label);
        result ~= format("  Heap Used:     %s\n", formatSize(heapUsed));
        result ~= format("  Heap Free:     %s\n", formatSize(heapFree));
        result ~= format("  Heap Total:    %s\n", formatSize(heapTotal));
        result ~= format("  Utilization:   %.1f%%\n", heapUtilization());
        result ~= format("  GC Collections: %d\n", gcCollections);
        return result;
    }
}

/// Difference between two memory snapshots
struct MemoryDelta
{
    long heapUsedDelta;      // Positive = growth, negative = shrinkage
    long heapFreeDelta;
    long heapTotalDelta;
    long gcCollectionsDelta;
    Duration elapsed;
    string fromLabel;
    string toLabel;
    
    /// Calculate delta between two snapshots
    static MemoryDelta between(const MemorySnapshot before, const MemorySnapshot after) pure nothrow @safe
    {
        MemoryDelta delta;
        delta.heapUsedDelta = cast(long)after.heapUsed - cast(long)before.heapUsed;
        delta.heapFreeDelta = cast(long)after.heapFree - cast(long)before.heapFree;
        delta.heapTotalDelta = cast(long)after.heapTotal - cast(long)before.heapTotal;
        delta.gcCollectionsDelta = cast(long)after.gcCollections - cast(long)before.gcCollections;
        delta.elapsed = after.timestamp - before.timestamp;
        delta.fromLabel = before.label;
        delta.toLabel = after.label;
        return delta;
    }
    
    /// Format delta as human-readable string with sign
    private string formatDelta(long bytes) const pure @safe
    {
        string sign = bytes >= 0 ? "+" : "";
        if (bytes < 0) bytes = -bytes;
        
        if (bytes < 1024)
            return format("%s%d B", sign, bytes);
        else if (bytes < 1024 * 1024)
            return format("%s%.2f KB", sign, bytes / 1024.0);
        else if (bytes < 1024 * 1024 * 1024)
            return format("%s%.2f MB", sign, bytes / (1024.0 * 1024.0));
        else
            return format("%s%.2f GB", sign, bytes / (1024.0 * 1024.0 * 1024.0));
    }
    
    /// Display formatted delta
    string toString() const pure @safe
    {
        string result;
        result ~= format("Memory Delta [%s → %s] (%.2fs):\n", 
                        fromLabel.length > 0 ? fromLabel : "start",
                        toLabel.length > 0 ? toLabel : "end",
                        elapsed.total!"msecs" / 1000.0);
        result ~= format("  Used:    %s\n", formatDelta(heapUsedDelta));
        result ~= format("  Free:    %s\n", formatDelta(heapFreeDelta));
        result ~= format("  Total:   %s\n", formatDelta(heapTotalDelta));
        result ~= format("  GC Runs: %+d\n", gcCollectionsDelta);
        return result;
    }
}

/// Memory profiler for tracking memory usage over time
struct MemoryProfiler
{
    private MemorySnapshot[] snapshots;
    private StopWatch timer;
    private bool running;
    
    @disable this(this); // Non-copyable
    
    /// Start profiling
    void start(string label = "start") @trusted
    {
        snapshots = [];
        snapshots ~= MemorySnapshot.take(label);
        timer = StopWatch(AutoStart.yes);
        running = true;
    }
    
    /// Take a snapshot at current point
    void snapshot(string label = "") @trusted
    {
        if (!running)
            return;
        snapshots ~= MemorySnapshot.take(label);
    }
    
    /// Stop profiling and return final snapshot
    MemorySnapshot stop(string label = "end") @trusted
    {
        if (!running)
            return MemorySnapshot.init;
        
        auto lastSnapshot = MemorySnapshot.take(label);
        snapshots ~= lastSnapshot;
        timer.stop();
        running = false;
        return lastSnapshot;
    }
    
    /// Get all snapshots
    const(MemorySnapshot)[] getSnapshots() const pure nothrow @safe
    {
        return snapshots;
    }
    
    /// Get snapshot by label
    MemorySnapshot getSnapshot(string label) const pure @safe
    {
        foreach (snap; snapshots)
        {
            if (snap.label == label)
                return snap;
        }
        return MemorySnapshot.init;
    }
    
    /// Calculate delta between two snapshots by label
    MemoryDelta delta(string fromLabel, string toLabel) const pure @safe
    {
        auto from = getSnapshot(fromLabel);
        auto to = getSnapshot(toLabel);
        return MemoryDelta.between(from, to);
    }
    
    /// Calculate delta from first to last snapshot
    MemoryDelta totalDelta() const pure nothrow @safe
    {
        if (snapshots.length < 2)
            return MemoryDelta.init;
        return MemoryDelta.between(snapshots[0], snapshots[$-1]);
    }
    
    /// Get peak memory usage
    size_t peakHeapUsed() const pure nothrow @safe
    {
        size_t peak = 0;
        foreach (snap; snapshots)
            peak = max(peak, snap.heapUsed);
        return peak;
    }
    
    /// Get peak heap total
    size_t peakHeapTotal() const pure nothrow @safe
    {
        size_t peak = 0;
        foreach (snap; snapshots)
            peak = max(peak, snap.heapTotal);
        return peak;
    }
    
    /// Get total GC collections during profiling
    size_t totalGCCollections() const pure nothrow @safe
    {
        if (snapshots.length < 2)
            return 0;
        return snapshots[$-1].gcCollections - snapshots[0].gcCollections;
    }
    
    /// Check if profiler is currently running
    bool isRunning() const pure nothrow @safe
    {
        return running;
    }
    
    /// Display full profiling report
    string report() const pure @safe
    {
        if (snapshots.length == 0)
            return "No memory snapshots recorded\n";
        
        string result;
        result ~= "=== Memory Profile Report ===\n\n";
        
        // Show all snapshots
        foreach (snap; snapshots)
        {
            result ~= snap.toString() ~ "\n";
        }
        
        // Show total delta
        if (snapshots.length >= 2)
        {
            result ~= "\n" ~ totalDelta().toString();
        }
        
        // Show statistics
        result ~= "\n=== Statistics ===\n";
        result ~= format("Peak Heap Used:   %s\n", 
                        MemorySnapshot.init.formatSize(peakHeapUsed()));
        result ~= format("Peak Heap Total:  %s\n",
                        MemorySnapshot.init.formatSize(peakHeapTotal()));
        result ~= format("Total GC Runs:    %d\n", totalGCCollections());
        result ~= format("Total Duration:   %.2fs\n", 
                        timer.peek().total!"msecs" / 1000.0);
        
        return result;
    }
}

/// Track memory usage for a specific operation
/// 
/// Safety: This function is @trusted because:
/// 1. Delegates to MemorySnapshot.take() which is trusted
/// 2. Function execution is @safe by D's type system
/// 3. Exception handling is memory-safe
/// 4. Delta calculation is pure and safe
/// 
/// Invariants:
/// - before is taken before func executes
/// - after is taken after func executes (even if exception thrown)
/// - Delta is calculated from valid snapshots
/// 
/// What could go wrong:
/// - func throws exception: handled with try/finally pattern
/// - Memory allocation during snapshot: accepted (small overhead)
/// - GC running during measurement: accepted (real-world behavior)
MemoryDelta trackMemory(T)(T delegate() func, string label = "operation") @trusted
{
    auto before = MemorySnapshot.take(label ~ " (before)");
    
    try
    {
        func();
    }
    finally
    {
        auto after = MemorySnapshot.take(label ~ " (after)");
        return MemoryDelta.between(before, after);
    }
}

/// Overload for void functions
MemoryDelta trackMemory(void delegate() func, string label = "operation") @trusted
{
    auto before = MemorySnapshot.take(label ~ " (before)");
    
    try
    {
        func();
    }
    finally
    {
        auto after = MemorySnapshot.take(label ~ " (after)");
        return MemoryDelta.between(before, after);
    }
}

unittest
{
    import std.stdio : writeln;
    
    // Test MemorySnapshot
    {
        auto snap = MemorySnapshot.take("test");
        assert(snap.label == "test");
        assert(snap.heapUsed > 0);
        assert(snap.heapTotal >= snap.heapUsed);
        assert(snap.heapTotal == snap.heapUsed + snap.heapFree);
    }
    
    // Test MemoryDelta
    {
        auto before = MemorySnapshot.take("before");
        
        // Allocate some memory
        auto data = new ubyte[1024 * 1024]; // 1MB
        
        auto after = MemorySnapshot.take("after");
        auto delta = MemoryDelta.between(before, after);
        
        assert(delta.heapUsedDelta >= 0); // Should have grown
        assert(delta.fromLabel == "before");
        assert(delta.toLabel == "after");
    }
    
    // Test MemoryProfiler
    {
        MemoryProfiler profiler;
        profiler.start("start");
        
        // Simulate some work with allocations
        profiler.snapshot("alloc1");
        auto data1 = new ubyte[512 * 1024];
        
        profiler.snapshot("alloc2");
        auto data2 = new ubyte[512 * 1024];
        
        auto lastSnapshot = profiler.stop("end");
        
        assert(profiler.getSnapshots().length == 4);
        assert(profiler.totalGCCollections() >= 0);
        assert(profiler.peakHeapUsed() > 0);
        
        auto delta = profiler.totalDelta();
        assert(delta.heapUsedDelta >= 0); // Should have grown
    }
    
    // Test trackMemory
    {
        auto delta = trackMemory({
            auto data = new ubyte[256 * 1024]; // 256KB
        }, "allocation test");
        
        assert(delta.heapUsedDelta >= 0);
        assert(delta.fromLabel.length > 0);
    }
}

