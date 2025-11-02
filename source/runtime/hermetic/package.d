module runtime.hermetic;

/// Hermetic build execution system
/// 
/// Provides platform-specific sandboxing for reproducible builds:
/// - Linux: namespace-based isolation (mount, PID, network, IPC, UTS, user) + cgroup v2
/// - macOS: sandbox-exec with SBPL profiles + rusage monitoring
/// - Windows: job objects with resource limits + I/O accounting
/// 
/// Usage:
/// ```d
/// auto spec = HermeticSpecBuilder.forBuild(
///     workspaceRoot,
///     sources,
///     outputDir,
///     tempDir
/// );
/// 
/// auto executor = HermeticExecutor.create(spec.unwrap());
/// auto result = executor.unwrap().execute(["gcc", "main.c", "-o", "main"]);
/// 
/// // With monitoring
/// auto monitor = createMonitor(spec.unwrap().resources);
/// monitor.start();
/// // ... execute ...
/// auto usage = monitor.snapshot();
/// monitor.stop();
/// ```

public import runtime.hermetic.spec;
public import runtime.hermetic.executor;
public import runtime.hermetic.audit;
public import runtime.hermetic.monitor;
public import runtime.hermetic.timeout;

version(linux)
{
    public import runtime.hermetic.linux;
    public import runtime.hermetic.monitor.linux;
}

version(OSX)
{
    public import runtime.hermetic.macos;
    public import runtime.hermetic.monitor.macos;
}

version(Windows)
{
    public import runtime.hermetic.windows;
    public import runtime.hermetic.monitor.windows;
}

