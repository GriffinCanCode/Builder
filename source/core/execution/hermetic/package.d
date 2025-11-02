module core.execution.hermetic;

/// Hermetic build execution system
/// 
/// Provides platform-specific sandboxing for reproducible builds:
/// - Linux: namespace-based isolation (mount, PID, network, IPC, UTS, user)
/// - macOS: sandbox-exec with SBPL profiles
/// - Windows: (future) job objects
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
/// ```

public import core.execution.hermetic.spec;
public import core.execution.hermetic.executor;
public import core.execution.hermetic.audit;

version(linux)
{
    public import core.execution.hermetic.linux;
}

version(OSX)
{
    public import core.execution.hermetic.macos;
}

version(Windows)
{
    public import core.execution.hermetic.windows;
}

