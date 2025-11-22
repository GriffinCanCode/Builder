module engine.runtime.hermetic.platforms;

/// Platform-specific sandbox implementations
/// 
/// This module provides platform-specific sandboxing backends:
/// - Linux: namespace-based isolation with cgroups
/// - macOS: sandbox-exec with SBPL profiles  
/// - Windows: job objects with resource limits
/// 
/// Each platform provides the strongest isolation guarantees
/// available on that operating system.

// Platform capability detection (available on all platforms)
public import engine.runtime.hermetic.platforms.capabilities;

version(linux)
{
    public import engine.runtime.hermetic.platforms.linux;
}

version(OSX)
{
    public import engine.runtime.hermetic.platforms.macos;
}

version(Windows)
{
    public import engine.runtime.hermetic.platforms.windows;
}

