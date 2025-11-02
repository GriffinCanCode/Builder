module core.execution.hermetic;

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

public import core.execution.hermetic.spec;
public import core.execution.hermetic.executor;
public import core.execution.hermetic.audit;
public import core.execution.hermetic.monitor;
public import core.execution.hermetic.timeout;

version(linux)
{
    public import core.execution.hermetic.linux;
    public import core.execution.hermetic.monitor.linux;
}

version(OSX)
{
    public import core.execution.hermetic.macos;
    public import core.execution.hermetic.monitor.macos;
}

version(Windows)
{
    public import core.execution.hermetic.windows;
    public import core.execution.hermetic.monitor.windows;
}

