module frontend.cli.output.progress;

import std.datetime : Duration, dur;
import std.datetime.stopwatch : StopWatch, AutoStart;
import core.atomic;
import std.algorithm : min, max;
import std.conv : to;
import std.format : format;

/// Lock-free progress tracker using atomic operations
/// Designed for high-performance concurrent updates from build threads

struct ProgressTracker
{
    private shared size_t _total;
    private shared size_t _completed;
    private shared size_t _failed;
    private shared size_t _cached;
    private shared size_t _active;
    private StopWatch timer;
    
    @disable this(this); // Non-copyable
    
    this(size_t total)
    {
        atomicStore(_total, total);
        atomicStore(_completed, cast(size_t)0);
        atomicStore(_failed, cast(size_t)0);
        atomicStore(_cached, cast(size_t)0);
        atomicStore(_active, cast(size_t)0);
        timer = StopWatch(AutoStart.yes);
    }
    
    /// Increment completed count (thread-safe)
    void incrementCompleted()
    {
        atomicOp!"+="(_completed, cast(size_t)1);
    }
    
    /// Increment failed count (thread-safe)
    void incrementFailed()
    {
        atomicOp!"+="(_failed, cast(size_t)1);
    }
    
    /// Increment cached count (thread-safe)
    void incrementCached()
    {
        atomicOp!"+="(_cached, cast(size_t)1);
    }
    
    /// Set active count (thread-safe)
    void setActive(size_t count)
    {
        atomicStore(_active, count);
    }
    
    /// Increment active count
    void incrementActive()
    {
        atomicOp!"+="(_active, cast(size_t)1);
    }
    
    /// Decrement active count
    void decrementActive()
    {
        atomicOp!"-="(_active, cast(size_t)1);
    }
    
    /// Get snapshot of current progress (lock-free read)
    ProgressSnapshot snapshot() const
    {
        ProgressSnapshot snap;
        snap.total = atomicLoad(_total);
        snap.completed = atomicLoad(_completed);
        snap.failed = atomicLoad(_failed);
        snap.cached = atomicLoad(_cached);
        snap.active = atomicLoad(_active);
        snap.elapsed = (cast(StopWatch)timer).peek();
        return snap;
    }
    
    /// Reset progress
    void reset()
    {
        atomicStore(_completed, cast(size_t)0);
        atomicStore(_failed, cast(size_t)0);
        atomicStore(_cached, cast(size_t)0);
        atomicStore(_active, cast(size_t)0);
        timer.reset();
        timer.start();
    }
}

/// Immutable snapshot of progress state
struct ProgressSnapshot
{
    size_t total;
    size_t completed;
    size_t failed;
    size_t cached;
    size_t active;
    Duration elapsed;
    
    /// Total finished (completed + failed + cached)
    @property size_t finished() const pure nothrow
    {
        return completed + failed + cached;
    }
    
    /// Remaining targets
    @property size_t remaining() const pure nothrow
    {
        return total > finished ? total - finished : 0;
    }
    
    /// Completion percentage (0.0 to 1.0)
    @property double percentage() const pure nothrow
    {
        if (total == 0) return 1.0;
        return cast(double)finished / cast(double)total;
    }
    
    /// Is build complete?
    @property bool isComplete() const pure nothrow
    {
        return finished >= total;
    }
    
    /// Has build failed?
    @property bool hasFailed() const pure nothrow
    {
        return failed > 0;
    }
    
    /// Estimated time remaining (based on current rate)
    Duration estimatedRemaining() const pure nothrow
    {
        if (finished == 0 || isComplete)
            return dur!"seconds"(0);
        
        auto elapsedSecs = elapsed.total!"seconds";
        if (elapsedSecs == 0)
            return dur!"seconds"(0);
        
        auto rate = cast(double)finished / cast(double)elapsedSecs;
        auto remainingSecs = cast(long)(remaining / rate);
        
        return dur!"seconds"(remainingSecs);
    }
    
    /// Targets per second
    @property double targetsPerSecond() const pure nothrow
    {
        auto secs = elapsed.total!"seconds";
        if (secs == 0) return 0.0;
        return cast(double)finished / cast(double)secs;
    }
}

/// Progress bar renderer
struct ProgressBar
{
    private ushort width = 40;
    private char fillChar = '=';
    private char emptyChar = ' ';
    private string prefix;
    private string suffix;
    
    /// Render progress bar for given percentage (0.0 to 1.0)
    string render(double percentage) const
    {
        percentage = min(1.0, max(0.0, percentage));
        
        auto filled = cast(size_t)(percentage * width);
        auto empty = width - filled;
        
        char[] bar = new char[width + 2];
        bar[0] = '[';
        bar[width + 1] = ']';
        
        foreach (i; 1 .. filled + 1)
            bar[i] = fillChar;
        
        foreach (i; filled + 1 .. width + 1)
            bar[i] = emptyChar;
        
        return cast(string)bar;
    }
    
    /// Render with percentage text
    string renderWithPercent(double percentage) const
    {
        auto percentText = format("%3d%%", cast(int)(percentage * 100));
        return render(percentage) ~ " " ~ percentText;
    }
    
    /// Render complete progress line with stats
    string renderComplete(ProgressSnapshot snap) const
    {
        auto bar = renderWithPercent(snap.percentage);
        auto stats = format("[%d/%d]", snap.finished, snap.total);
        
        if (snap.active > 0)
            stats ~= format(" %d active", snap.active);
        
        if (snap.cached > 0)
            stats ~= format(" (%d cached)", snap.cached);
        
        auto eta = snap.estimatedRemaining();
        if (!snap.isComplete && eta.total!"seconds" > 0)
            stats ~= format(" ETA %s", formatDuration(eta));
        
        return stats ~ " " ~ bar;
    }
    
    /// Format duration nicely
    private static string formatDuration(Duration d) pure
    {
        auto secs = d.total!"seconds";
        
        if (secs < 60)
            return format("%ds", secs);
        
        auto mins = secs / 60;
        secs = secs % 60;
        
        if (mins < 60)
            return format("%dm%ds", mins, secs);
        
        auto hours = mins / 60;
        mins = mins % 60;
        
        return format("%dh%dm", hours, mins);
    }
}

/// Target-level progress tracking
struct TargetProgress
{
    string targetId;
    string phase;
    double progress; // 0.0 to 1.0
    Duration elapsed;
    
    this(string targetId, string phase, double progress, Duration elapsed)
    {
        this.targetId = targetId;
        this.phase = phase;
        this.progress = min(1.0, max(0.0, progress));
        this.elapsed = elapsed;
    }
}

/// Progress aggregator for multiple targets
struct ProgressAggregator
{
    private TargetProgress[string] targets;
    private ProgressTracker tracker;
    
    this(size_t totalTargets)
    {
        tracker = ProgressTracker(totalTargets);
    }
    
    /// Update target progress
    void updateTarget(string targetId, string phase, double progress)
    {
        auto timer = StopWatch(AutoStart.yes);
        targets[targetId] = TargetProgress(targetId, phase, progress, timer.peek());
    }
    
    /// Complete target
    void completeTarget(string targetId, bool cached = false)
    {
        if (cached)
            tracker.incrementCached();
        else
            tracker.incrementCompleted();
        
        targets.remove(targetId);
    }
    
    /// Fail target
    void failTarget(string targetId)
    {
        tracker.incrementFailed();
        targets.remove(targetId);
    }
    
    /// Get overall progress
    ProgressSnapshot snapshot() const
    {
        return tracker.snapshot();
    }
    
    /// Get active targets
    const(TargetProgress[string]) activeTargets() const
    {
        return targets;
    }
}

