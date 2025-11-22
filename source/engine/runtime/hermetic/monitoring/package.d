module engine.runtime.hermetic.monitoring;

import std.datetime : Duration, msecs;
import core.time : MonoTime;
import engine.runtime.hermetic.core.spec : ResourceLimits;
import engine.distributed.protocol.protocol : ResourceUsage;

/// Resource monitoring abstraction
/// Platform-agnostic interface for tracking execution resources
/// 
/// Design: Monitor as a functional pipeline
/// - Accumulates metrics during execution
/// - Enforces limits declaratively
/// - Reports violations as structured data
/// 
/// This enables resource governance across platforms without coupling
/// to platform-specific APIs at the business logic layer
interface ResourceMonitor
{
    /// Start monitoring (called before execution)
    void start() @safe;
    
    /// Stop monitoring (called after execution)
    void stop() @safe;
    
    /// Get current resource usage snapshot
    ResourceUsage snapshot() @safe;
    
    /// Check if any limits have been exceeded
    bool isViolated() @safe;
    
    /// Get list of limit violations
    Violation[] violations() @safe;
    
    /// Check if resource limit would be exceeded
    bool wouldExceed(ResourceLimits limits) @safe;
}

/// Resource limit violation
struct Violation
{
    ViolationType type;
    ulong actual;      // Actual usage
    ulong limit;       // Configured limit
    string message;    // Human-readable description
}

/// Types of resource violations
enum ViolationType
{
    Memory,      // Memory limit exceeded
    CpuTime,     // CPU time limit exceeded
    Processes,   // Process count limit exceeded
    FileSize,    // File size limit exceeded
    DiskIO,      // Disk I/O limit exceeded
    NetworkIO,   // Network I/O limit exceeded
}

/// Base monitor implementation with shared logic
abstract class BaseMonitor : ResourceMonitor
{
    protected ResourceLimits limits;
    protected MonoTime startTime;
    protected MonoTime stopTime;
    protected Violation[] _violations;
    protected bool started = false;
    protected bool stopped = false;
    
    // Tracking state for delta calculations
    protected ulong initialDiskRead;
    protected ulong initialDiskWrite;
    protected ulong initialNetworkRx;
    protected ulong initialNetworkTx;
    
    this(ResourceLimits limits) @safe
    {
        this.limits = limits;
    }
    
    void start() @safe
    {
        startTime = MonoTime.currTime;
        started = true;
        stopped = false;
        _violations = [];
        
        // Record initial I/O counters for delta calculation
        recordInitialCounters();
    }
    
    void stop() @safe
    {
        stopTime = MonoTime.currTime;
        stopped = true;
        
        // Check limits on stop
        checkAllLimits();
    }
    
    bool isViolated() @safe
    {
        return _violations.length > 0;
    }
    
    Violation[] violations() @safe
    {
        return _violations;
    }
    
    bool wouldExceed(ResourceLimits newLimits) @safe
    {
        auto current = snapshot();
        
        if (newLimits.maxMemoryBytes > 0 && current.peakMemory > newLimits.maxMemoryBytes)
            return true;
        
        if (newLimits.maxCpuTimeMs > 0 && current.cpuTime.total!"msecs" > newLimits.maxCpuTimeMs)
            return true;
        
        return false;
    }
    
    /// Record a violation
    protected void recordViolation(ViolationType type, ulong actual, ulong limit, string message) @safe
    {
        _violations ~= Violation(type, actual, limit, message);
    }
    
    /// Get elapsed time since start
    protected Duration elapsed() @safe
    {
        if (!started)
            return Duration.zero;
        
        immutable end = stopped ? stopTime : MonoTime.currTime;
        immutable diff = end - startTime;
        return msecs(diff.total!"msecs");
    }
    
    /// Record initial I/O counters (override in platform implementations)
    protected void recordInitialCounters() @safe
    {
        // Default: no-op, override in platform-specific implementations
        initialDiskRead = 0;
        initialDiskWrite = 0;
        initialNetworkRx = 0;
        initialNetworkTx = 0;
    }
    
    /// Check all resource limits (common pattern across platforms)
    protected void checkAllLimits() @safe
    {
        auto usage = snapshot();
        
        checkMemoryLimit(usage);
        checkCpuTimeLimit(usage);
        checkDiskIOLimit(usage);
        checkNetworkIOLimit(usage);
    }
    
    /// Check memory limit
    protected void checkMemoryLimit(ResourceUsage usage) @safe
    {
        if (limits.maxMemoryBytes > 0 && usage.peakMemory > limits.maxMemoryBytes)
        {
            recordViolation(
                ViolationType.Memory,
                usage.peakMemory,
                limits.maxMemoryBytes,
                formatViolation("Memory", usage.peakMemory, limits.maxMemoryBytes)
            );
        }
    }
    
    /// Check CPU time limit
    protected void checkCpuTimeLimit(ResourceUsage usage) @safe
    {
        if (limits.maxCpuTimeMs > 0)
        {
            immutable cpuTimeMs = usage.cpuTime.total!"msecs";
            if (cpuTimeMs > limits.maxCpuTimeMs)
            {
                recordViolation(
                    ViolationType.CpuTime,
                    cpuTimeMs,
                    limits.maxCpuTimeMs,
                    formatViolation("CPU time", cpuTimeMs, limits.maxCpuTimeMs, "ms")
                );
            }
        }
    }
    
    /// Check disk I/O limit
    protected void checkDiskIOLimit(ResourceUsage usage) @safe
    {
        if (limits.maxDiskIO > 0)
        {
            immutable totalIO = usage.diskRead + usage.diskWrite;
            if (totalIO > limits.maxDiskIO)
            {
                recordViolation(
                    ViolationType.DiskIO,
                    totalIO,
                    limits.maxDiskIO,
                    formatViolation("Disk I/O", totalIO, limits.maxDiskIO, "bytes")
                );
            }
        }
    }
    
    /// Check network I/O limit
    protected void checkNetworkIOLimit(ResourceUsage usage) @safe
    {
        if (limits.maxNetworkIO > 0)
        {
            immutable totalIO = usage.networkRx + usage.networkTx;
            if (totalIO > limits.maxNetworkIO)
            {
                recordViolation(
                    ViolationType.NetworkIO,
                    totalIO,
                    limits.maxNetworkIO,
                    formatViolation("Network I/O", totalIO, limits.maxNetworkIO, "bytes")
                );
            }
        }
    }
    
    /// Format violation message
    protected static string formatViolation(
        string resource,
        ulong actual,
        ulong limit,
        string unit = "bytes"
    ) @safe
    {
        import std.format : format;
        return format!"%s exceeded: %s %s (limit: %s %s)"(
            resource,
            formatSize(actual),
            unit,
            formatSize(limit),
            unit
        );
    }
    
    /// Format size with units
    protected static string formatSize(ulong bytes) @safe
    {
        import std.format : format;
        
        if (bytes < 1024)
            return format!"%d"(bytes);
        else if (bytes < 1024 * 1024)
            return format!"%.1f KB"(bytes / 1024.0);
        else if (bytes < 1024 * 1024 * 1024)
            return format!"%.1f MB"(bytes / (1024.0 * 1024.0));
        else
            return format!"%.1f GB"(bytes / (1024.0 * 1024.0 * 1024.0));
    }
    
    /// Calculate delta from initial value
    protected static ulong calculateDelta(ulong current, ulong initial) @safe pure nothrow @nogc
    {
        return current > initial ? current - initial : 0;
    }
}

/// No-op monitor (for testing or when monitoring is disabled)
final class NoOpMonitor : BaseMonitor
{
    this() @safe
    {
        super(ResourceLimits.defaults());
    }
    
    override ResourceUsage snapshot() @safe
    {
        ResourceUsage usage;
        usage.cpuTime = elapsed();
        return usage;
    }
}

/// Create platform-appropriate monitor
ResourceMonitor createMonitor(ResourceLimits limits) @safe
{
    version(linux)
    {
        import engine.runtime.hermetic.monitoring.linux : LinuxMonitor;
        return new LinuxMonitor(limits);
    }
    else version(OSX)
    {
        import engine.runtime.hermetic.monitoring.macos : MacOSMonitor;
        return new MacOSMonitor(limits);
    }
    else version(Windows)
    {
        import engine.runtime.hermetic.monitoring.windows : WindowsMonitor;
        return new WindowsMonitor(limits);
    }
    else
    {
        return new NoOpMonitor();
    }
}

@safe unittest
{
    // Test NoOpMonitor
    auto monitor = new NoOpMonitor();
    monitor.start();
    
    auto usage = monitor.snapshot();
    assert(usage.peakMemory == 0);
    
    assert(!monitor.isViolated());
    assert(monitor.violations().length == 0);
    
    monitor.stop();
}

