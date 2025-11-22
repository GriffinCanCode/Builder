module engine.runtime.hermetic.monitoring.macos;

version(OSX):

import engine.runtime.hermetic.monitoring;
import engine.runtime.hermetic.core.spec : ResourceLimits;
import engine.distributed.protocol.protocol : ResourceUsage;
import std.datetime : Duration, msecs;
import std.conv : to;

/// macOS resource monitor using getrusage
/// 
/// Design: Uses getrusage() for process tree resource accounting
/// Note: macOS sandbox-exec doesn't provide resource usage directly,
/// so we use getrusage() to track the process tree
/// 
/// Limitations:
/// - Only tracks current process, not full sandbox
/// - No built-in limit enforcement (sandbox-exec doesn't support it)
final class MacOSMonitor : BaseMonitor
{
    private pid_t pid;
    private ulong initialUserTime;
    private ulong initialSystemTime;
    
    this(ResourceLimits limits) @trusted
    {
        super(limits);
        pid = getpid();
    }
    
    override void start() @safe
    {
        super.start(); // Calls recordInitialCounters()
    }
    
    override void stop() @safe
    {
        super.stop(); // Calls checkAllLimits()
    }
    
    /// Record initial counters (override base method)
    protected override void recordInitialCounters() @safe
    {
        auto initial = getRusage();
        initialUserTime = timevalToMs(initial.ru_utime);
        initialSystemTime = timevalToMs(initial.ru_stime);
        
        // I/O tracking via rusage (blocks, not bytes)
        initialDiskRead = initial.ru_inblock * 512;
        initialDiskWrite = initial.ru_oublock * 512;
    }
    
    override ResourceUsage snapshot() @safe
    {
        ResourceUsage usage;
        
        if (!started)
            return usage;
        
        auto rusage = getRusage();
        
        // Calculate CPU time (user + system)
        immutable userTime = timevalToMs(rusage.ru_utime) - initialUserTime;
        immutable systemTime = timevalToMs(rusage.ru_stime) - initialSystemTime;
        usage.cpuTime = msecs(userTime + systemTime);
        
        // Peak memory (maxrss is in bytes on macOS)
        usage.peakMemory = rusage.ru_maxrss;
        
        // I/O operations (block I/O, not byte count)
        // Convert blocks to bytes (assuming 512 byte blocks)
        usage.diskRead = rusage.ru_inblock * 512;
        usage.diskWrite = rusage.ru_oublock * 512;
        
        // No network tracking via rusage
        usage.networkRx = 0;
        usage.networkTx = 0;
        
        return usage;
    }
    
    /// Get resource usage for current process
    private rusage getRusage() @trusted
    {
        rusage usage;
        if (getrusage(RUSAGE_SELF, &usage) != 0)
        {
            // Return zero-initialized on error
            return rusage.init;
        }
        return usage;
    }
    
    /// Convert timeval to milliseconds
    private static ulong timevalToMs(timeval tv) @safe pure nothrow
    {
        return tv.tv_sec * 1000 + tv.tv_usec / 1000;
    }
}

// POSIX rusage bindings
extern(C) nothrow @nogc:

import core.sys.posix.sys.types : pid_t;

struct timeval
{
    c_long tv_sec;
    c_long tv_usec;
}

struct rusage
{
    timeval ru_utime;       // User CPU time
    timeval ru_stime;       // System CPU time
    c_long ru_maxrss;       // Maximum resident set size
    c_long ru_ixrss;        // Integral shared memory size
    c_long ru_idrss;        // Integral unshared data size
    c_long ru_isrss;        // Integral unshared stack size
    c_long ru_minflt;       // Page reclaims (soft page faults)
    c_long ru_majflt;       // Page faults (hard page faults)
    c_long ru_nswap;        // Swaps
    c_long ru_inblock;      // Block input operations
    c_long ru_oublock;      // Block output operations
    c_long ru_msgsnd;       // IPC messages sent
    c_long ru_msgrcv;       // IPC messages received
    c_long ru_nsignals;     // Signals received
    c_long ru_nvcsw;        // Voluntary context switches
    c_long ru_nivcsw;       // Involuntary context switches
}

enum
{
    RUSAGE_SELF = 0,
    RUSAGE_CHILDREN = -1,
}

int getrusage(int who, rusage* usage);
pid_t getpid();

import core.stdc.config : c_long;
