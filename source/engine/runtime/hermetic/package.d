module engine.runtime.hermetic;

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

public import engine.runtime.hermetic.spec;
public import engine.runtime.hermetic.executor;
public import engine.runtime.hermetic.audit;
public import engine.runtime.hermetic.monitor;
public import engine.runtime.hermetic.timeout;

version(linux)
{
    public import engine.runtime.hermetic.linux;
    public import engine.runtime.hermetic.monitor.linux;
}

version(OSX)
{
    public import engine.runtime.hermetic.macos;
    public import engine.runtime.hermetic.monitor.macos;
}

version(Windows)
{
    public import engine.runtime.hermetic.windows;
    public import engine.runtime.hermetic.monitor.windows;
}

