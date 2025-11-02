module core.execution.hermetic.monitor.linux;

version(linux):

import core.execution.hermetic.monitor;
import core.execution.hermetic.spec : ResourceLimits;
import core.distributed.protocol.protocol : ResourceUsage;
import std.datetime : Duration, msecs;
import std.file : exists, readText, writeText;
import std.path : buildPath;
import std.string : strip, lineSplitter, splitter;
import std.conv : to;
import std.algorithm : canFind;

/// Linux resource monitor using cgroups v2
/// 
/// Design: Leverages Linux unified cgroup hierarchy for accurate resource tracking
/// - memory.current: Current memory usage
/// - memory.peak: Peak memory usage  
/// - memory.max: Memory limit
/// - cpu.stat: CPU usage statistics
/// - pids.current: Active process count
/// - io.stat: Disk I/O statistics
/// 
/// Enforces limits via cgroup controllers, not polling
final class LinuxMonitor : BaseMonitor
{
    private string cgroupPath;
    private bool useCgroupV2;
    private ulong initialDiskRead;
    private ulong initialDiskWrite;
    
    this(ResourceLimits limits) @safe
    {
        super(limits);
        
        // Detect cgroup version
        useCgroupV2 = exists("/sys/fs/cgroup/cgroup.controllers");
    }
    
    override void start() @safe
    {
        super.start();
        
        // Create dedicated cgroup for this execution
        if (useCgroupV2)
        {
            setupCgroupV2();
        }
        else
        {
            setupCgroupV1();
        }
        
        // Record initial I/O for delta calculation
        recordInitialIO();
    }
    
    override void stop() @safe
    {
        super.stop();
        
        // Check for violations before cleanup
        checkLimits();
        
        // Cleanup cgroup
        cleanupCgroup();
    }
    
    override ResourceUsage snapshot() @safe
    {
        ResourceUsage usage;
        
        if (!started)
            return usage;
        
        usage.cpuTime = readCpuTime();
        usage.peakMemory = readPeakMemory();
        usage.diskRead = readDiskRead() - initialDiskRead;
        usage.diskWrite = readDiskWrite() - initialDiskWrite;
        
        // Network I/O would require netfilter or eBPF
        // Not implemented for simplicity
        usage.networkRx = 0;
        usage.networkTx = 0;
        
        return usage;
    }
    
    /// Setup cgroup v2 hierarchy
    private void setupCgroupV2() @safe
    {
        import std.random : uniform;
        import std.uuid : randomUUID;
        import std.file : mkdirRecurse;
        
        immutable base = "/sys/fs/cgroup/builder";
        cgroupPath = buildPath(base, randomUUID().toString());
        
        try
        {
            // Create cgroup directory
            mkdirRecurse(cgroupPath);
            
            // Enable controllers
            auto subtree = buildPath(dirName(cgroupPath), "cgroup.subtree_control");
            if (exists(subtree))
            {
                writeText(subtree, "+cpu +memory +pids +io");
            }
            
            // Set memory limit
            if (limits.maxMemoryBytes > 0)
            {
                auto memMax = buildPath(cgroupPath, "memory.max");
                writeText(memMax, limits.maxMemoryBytes.to!string);
            }
            
            // Set CPU weight
            if (limits.cpuShares > 0)
            {
                auto cpuWeight = buildPath(cgroupPath, "cpu.weight");
                writeText(cpuWeight, limits.cpuShares.to!string);
            }
            
            // Set process limit
            if (limits.maxProcesses > 0)
            {
                auto pidsMax = buildPath(cgroupPath, "pids.max");
                writeText(pidsMax, limits.maxProcesses.to!string);
            }
            
            // Add current process to cgroup
            auto procs = buildPath(cgroupPath, "cgroup.procs");
            import core.sys.posix.unistd : getpid;
            writeText(procs, getpid().to!string);
        }
        catch (Exception e)
        {
            // Cgroup setup failed - continue without it
            cgroupPath = "";
        }
    }
    
    /// Setup cgroup v1 hierarchy (legacy)
    private void setupCgroupV1() @safe
    {
        import std.random : uniform;
        import std.uuid : randomUUID;
        import std.file : mkdirRecurse;
        
        // For simplicity, only setup memory cgroup in v1
        immutable base = "/sys/fs/cgroup/memory/builder";
        cgroupPath = buildPath(base, randomUUID().toString());
        
        try
        {
            mkdirRecurse(cgroupPath);
            
            if (limits.maxMemoryBytes > 0)
            {
                auto memLimit = buildPath(cgroupPath, "memory.limit_in_bytes");
                writeText(memLimit, limits.maxMemoryBytes.to!string);
            }
            
            // Add current process
            auto tasks = buildPath(cgroupPath, "tasks");
            import core.sys.posix.unistd : getpid;
            writeText(tasks, getpid().to!string);
        }
        catch (Exception)
        {
            cgroupPath = "";
        }
    }
    
    /// Cleanup cgroup after execution
    private void cleanupCgroup() @safe
    {
        if (cgroupPath.length == 0 || !exists(cgroupPath))
            return;
        
        try
        {
            import std.file : rmdirRecurse;
            rmdirRecurse(cgroupPath);
        }
        catch (Exception)
        {
            // Best effort cleanup
        }
    }
    
    /// Read CPU time from cgroup
    private Duration readCpuTime() @safe
    {
        if (cgroupPath.length == 0)
            return elapsed();
        
        try
        {
            immutable cpuStat = buildPath(cgroupPath, "cpu.stat");
            if (!exists(cpuStat))
                return elapsed();
            
            foreach (line; readText(cpuStat).lineSplitter)
            {
                auto parts = line.splitter(" ");
                if (!parts.empty && parts.front == "usage_usec")
                {
                    parts.popFront();
                    if (!parts.empty)
                    {
                        immutable usec = parts.front.to!ulong;
                        return msecs(usec / 1000);
                    }
                }
            }
        }
        catch (Exception) {}
        
        return elapsed();
    }
    
    /// Read peak memory from cgroup
    private size_t readPeakMemory() @safe
    {
        if (cgroupPath.length == 0)
            return 0;
        
        try
        {
            immutable memPeak = buildPath(cgroupPath, "memory.peak");
            if (exists(memPeak))
            {
                return readText(memPeak).strip.to!size_t;
            }
            
            // Fallback to current memory
            immutable memCurrent = buildPath(cgroupPath, "memory.current");
            if (exists(memCurrent))
            {
                return readText(memCurrent).strip.to!size_t;
            }
        }
        catch (Exception) {}
        
        return 0;
    }
    
    /// Read disk read bytes
    private ulong readDiskRead() @safe
    {
        if (cgroupPath.length == 0)
            return 0;
        
        return readIOStat("rbytes");
    }
    
    /// Read disk write bytes
    private ulong readDiskWrite() @safe
    {
        if (cgroupPath.length == 0)
            return 0;
        
        return readIOStat("wbytes");
    }
    
    /// Read I/O statistics from cgroup
    private ulong readIOStat(string key) @safe
    {
        try
        {
            immutable ioStat = buildPath(cgroupPath, "io.stat");
            if (!exists(ioStat))
                return 0;
            
            ulong total = 0;
            foreach (line; readText(ioStat).lineSplitter)
            {
                // Format: device_id rbytes=N wbytes=M ...
                auto parts = line.splitter(" ");
                if (parts.empty)
                    continue;
                
                parts.popFront(); // Skip device ID
                
                foreach (pair; parts)
                {
                    auto kv = pair.splitter("=");
                    if (!kv.empty && kv.front == key)
                    {
                        kv.popFront();
                        if (!kv.empty)
                        {
                            total += kv.front.to!ulong;
                        }
                    }
                }
            }
            
            return total;
        }
        catch (Exception) {}
        
        return 0;
    }
    
    /// Record initial I/O for delta calculation
    private void recordInitialIO() @safe
    {
        initialDiskRead = readDiskRead();
        initialDiskWrite = readDiskWrite();
    }
    
    /// Check if any limits have been exceeded
    private void checkLimits() @safe
    {
        auto usage = snapshot();
        
        // Check memory limit
        if (limits.maxMemoryBytes > 0 && usage.peakMemory > limits.maxMemoryBytes)
        {
            recordViolation(
                ViolationType.Memory,
                usage.peakMemory,
                limits.maxMemoryBytes,
                "Peak memory exceeded limit"
            );
        }
        
        // Check CPU time limit
        if (limits.maxCpuTimeMs > 0 && usage.cpuTime.total!"msecs" > limits.maxCpuTimeMs)
        {
            recordViolation(
                ViolationType.CpuTime,
                usage.cpuTime.total!"msecs",
                limits.maxCpuTimeMs,
                "CPU time exceeded limit"
            );
        }
        
        // Check process count (if cgroup exists)
        if (limits.maxProcesses > 0 && cgroupPath.length > 0)
        {
            try
            {
                immutable pidsCurrent = buildPath(cgroupPath, "pids.current");
                if (exists(pidsCurrent))
                {
                    immutable count = readText(pidsCurrent).strip.to!uint;
                    if (count > limits.maxProcesses)
                    {
                        recordViolation(
                            ViolationType.Processes,
                            count,
                            limits.maxProcesses,
                            "Process count exceeded limit"
                        );
                    }
                }
            }
            catch (Exception) {}
        }
    }
}

private import std.path : dirName;

