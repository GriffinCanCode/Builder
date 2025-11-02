module core.execution.hermetic.monitor;

import std.datetime : Duration, msecs;
import core.time : MonoTime;
import core.execution.hermetic.spec : ResourceLimits;
import core.distributed.protocol.protocol : ResourceUsage;

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
    }
    
    void stop() @safe
    {
        stopTime = MonoTime.currTime;
        stopped = true;
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
        import core.execution.hermetic.monitor.linux : LinuxMonitor;
        return new LinuxMonitor(limits);
    }
    else version(OSX)
    {
        import core.execution.hermetic.monitor.macos : MacOSMonitor;
        return new MacOSMonitor(limits);
    }
    else version(Windows)
    {
        import core.execution.hermetic.monitor.windows : WindowsMonitor;
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

