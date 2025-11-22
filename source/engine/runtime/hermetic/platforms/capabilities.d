module engine.runtime.hermetic.platforms.capabilities;

import std.file : exists;
import std.process : execute;
import std.algorithm : canFind;
import std.string : strip;

/// Platform sandbox capabilities
struct SandboxCapabilities
{
    bool namespacesAvailable;      // Linux namespaces (CLONE_NEW*)
    bool cgroupV2Available;        // Linux cgroup v2
    bool cgroupV1Available;        // Linux cgroup v1
    bool sandboxExecAvailable;     // macOS sandbox-exec
    bool jobObjectsAvailable;      // Windows job objects
    bool userNamespacesAvailable;  // Linux user namespaces
    bool networkNamespacesAvailable; // Linux network namespaces
    bool pidNamespacesAvailable;   // Linux PID namespaces
    bool mountNamespacesAvailable; // Linux mount namespaces
    bool ipcNamespacesAvailable;   // Linux IPC namespaces
    bool utsNamespacesAvailable;   // Linux UTS namespaces
    
    /// Resource monitoring capabilities
    bool cgroupMonitoringAvailable; // cgroups resource tracking
    bool rusageAvailable;           // getrusage() available
    bool performanceCountersAvailable; // Windows performance counters
    bool ebpfAvailable;             // eBPF for advanced tracking
    
    /// Security capabilities
    bool seccompAvailable;          // Linux seccomp-bpf
    bool apparmorAvailable;         // AppArmor LSM
    bool selinuxAvailable;          // SELinux LSM
    
    /// Compute capabilities
    bool cpuAffinityAvailable;      // CPU pinning support
    bool numaAvailable;             // NUMA awareness
    bool memoryLimitEnforcement;    // Hard memory limits
    bool cpuTimeEnforcement;        // CPU time limits
    bool ioLimitEnforcement;        // I/O throttling
    
    /// Check if hermetic execution is possible
    bool canRunHermetic() const pure nothrow @nogc @safe
    {
        version(linux)
            return namespacesAvailable;
        else version(OSX)
            return sandboxExecAvailable;
        else version(Windows)
            return jobObjectsAvailable;
        else
            return false;
    }
    
    /// Check if resource limits can be enforced
    bool canEnforceLimits() const pure nothrow @nogc @safe
    {
        version(linux)
            return cgroupV2Available || cgroupV1Available;
        else version(OSX)
            return false; // macOS sandbox-exec doesn't enforce limits
        else version(Windows)
            return jobObjectsAvailable;
        else
            return false;
    }
    
    /// Check if resource monitoring is available
    bool canMonitorResources() const pure nothrow @nogc @safe
    {
        return cgroupMonitoringAvailable || rusageAvailable || performanceCountersAvailable;
    }
    
    /// Get best available isolation level
    IsolationLevel bestIsolationLevel() const pure nothrow @nogc @safe
    {
        if (namespacesAvailable && userNamespacesAvailable)
            return IsolationLevel.Full;
        else if (sandboxExecAvailable || jobObjectsAvailable)
            return IsolationLevel.Partial;
        else
            return IsolationLevel.None;
    }
}

/// Isolation levels
enum IsolationLevel
{
    None,      // No isolation
    Partial,   // Some isolation (filesystem only)
    Full,      // Full isolation (filesystem + network + IPC)
}

/// Detect platform capabilities at runtime
SandboxCapabilities detectCapabilities() @trusted
{
    SandboxCapabilities caps;
    
    version(linux)
    {
        caps.detectLinuxCapabilities();
    }
    else version(OSX)
    {
        caps.detectMacOSCapabilities();
    }
    else version(Windows)
    {
        caps.detectWindowsCapabilities();
    }
    
    return caps;
}

/// Linux capability detection
version(linux)
private void detectLinuxCapabilities(ref SandboxCapabilities caps) @trusted
{
    // Check for namespace support
    caps.userNamespacesAvailable = exists("/proc/self/ns/user");
    caps.networkNamespacesAvailable = exists("/proc/self/ns/net");
    caps.pidNamespacesAvailable = exists("/proc/self/ns/pid");
    caps.mountNamespacesAvailable = exists("/proc/self/ns/mnt");
    caps.ipcNamespacesAvailable = exists("/proc/self/ns/ipc");
    caps.utsNamespacesAvailable = exists("/proc/self/ns/uts");
    
    caps.namespacesAvailable = caps.userNamespacesAvailable &&
                               caps.networkNamespacesAvailable &&
                               caps.pidNamespacesAvailable &&
                               caps.mountNamespacesAvailable;
    
    // Check cgroup version
    caps.cgroupV2Available = exists("/sys/fs/cgroup/cgroup.controllers");
    caps.cgroupV1Available = exists("/sys/fs/cgroup/memory") || 
                            exists("/sys/fs/cgroup/cpu,cpuacct");
    
    caps.cgroupMonitoringAvailable = caps.cgroupV2Available || caps.cgroupV1Available;
    
    // Check for seccomp
    caps.seccompAvailable = exists("/proc/sys/kernel/seccomp");
    
    // Check for LSM
    if (exists("/sys/kernel/security/apparmor"))
        caps.apparmorAvailable = true;
    
    if (exists("/sys/fs/selinux"))
        caps.selinuxAvailable = true;
    
    // Check for eBPF
    caps.ebpfAvailable = exists("/sys/fs/bpf");
    
    // Resource capabilities
    caps.rusageAvailable = true; // Always available on POSIX
    caps.cpuAffinityAvailable = true;
    caps.numaAvailable = exists("/sys/devices/system/node");
    caps.memoryLimitEnforcement = caps.cgroupV2Available || caps.cgroupV1Available;
    caps.cpuTimeEnforcement = caps.cgroupV2Available || caps.cgroupV1Available;
    caps.ioLimitEnforcement = caps.cgroupV2Available;
}

/// macOS capability detection
version(OSX)
private void detectMacOSCapabilities(ref SandboxCapabilities caps) @trusted
{
    // Check for sandbox-exec
    try
    {
        auto result = execute(["which", "sandbox-exec"]);
        caps.sandboxExecAvailable = result.status == 0;
    }
    catch (Exception)
    {
        caps.sandboxExecAvailable = false;
    }
    
    // macOS always has getrusage
    caps.rusageAvailable = true;
    
    // No enforcement capabilities on macOS
    caps.memoryLimitEnforcement = false;
    caps.cpuTimeEnforcement = false;
    caps.ioLimitEnforcement = false;
    
    // CPU affinity available via thread_policy_set
    caps.cpuAffinityAvailable = true;
    
    // NUMA detection (Mac Pro has NUMA)
    try
    {
        auto result = execute(["sysctl", "-n", "hw.packages"]);
        if (result.status == 0)
        {
            immutable packages = result.output.strip;
            caps.numaAvailable = packages.length > 0 && packages != "1";
        }
    }
    catch (Exception) {}
}

/// Windows capability detection
version(Windows)
private void detectWindowsCapabilities(ref SandboxCapabilities caps) @trusted
{
    import core.sys.windows.windows;
    
    // Job objects always available on NT
    caps.jobObjectsAvailable = true;
    
    // Performance counters available
    caps.performanceCountersAvailable = true;
    
    // Resource enforcement via job objects
    caps.memoryLimitEnforcement = true;
    caps.cpuTimeEnforcement = true;
    caps.ioLimitEnforcement = true;
    
    // CPU affinity available
    caps.cpuAffinityAvailable = true;
    
    // Check for NUMA
    SYSTEM_INFO sysInfo;
    GetSystemInfo(&sysInfo);
    caps.numaAvailable = sysInfo.dwNumberOfProcessors > 1;
}

/// Global capability cache (initialized once)
private __gshared SandboxCapabilities _cachedCapabilities;
private __gshared bool _capabilitiesInitialized = false;

/// Get cached capabilities (thread-safe)
SandboxCapabilities getCapabilities() @trusted
{
    import core.atomic : atomicLoad, atomicStore, cas;
    
    if (atomicLoad(_capabilitiesInitialized))
        return _cachedCapabilities;
    
    // Double-checked locking pattern
    synchronized
    {
        if (!atomicLoad(_capabilitiesInitialized))
        {
            _cachedCapabilities = detectCapabilities();
            atomicStore(_capabilitiesInitialized, true);
        }
    }
    
    return _cachedCapabilities;
}

/// Check if platform supports hermetic execution
bool platformSupportsHermetic() @trusted
{
    return getCapabilities().canRunHermetic();
}

/// Check if platform can enforce resource limits
bool platformCanEnforceLimits() @trusted
{
    return getCapabilities().canEnforceLimits();
}

/// Check if platform can monitor resources
bool platformCanMonitorResources() @trusted
{
    return getCapabilities().canMonitorResources();
}

@safe unittest
{
    // Test capability detection
    auto caps = getCapabilities();
    
    // Should always be able to do something
    assert(caps.canMonitorResources() || !caps.canRunHermetic());
    
    // Check consistency
    version(linux)
    {
        if (caps.namespacesAvailable)
            assert(caps.userNamespacesAvailable);
    }
    else version(OSX)
    {
        assert(caps.rusageAvailable);
    }
}

@safe unittest
{
    // Test thread-safety of capability caching
    import std.parallelism : parallel;
    import std.range : iota;
    
    foreach (_; iota(100).parallel)
    {
        auto caps = getCapabilities();
        assert(caps.canMonitorResources() || !caps.canRunHermetic());
    }
}

