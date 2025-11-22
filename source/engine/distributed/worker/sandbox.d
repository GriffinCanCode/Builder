module engine.distributed.worker.sandbox;

import std.process : execute, Config;
import std.datetime : Duration;
import std.file : exists, mkdirRecurse, rmdirRecurse, tempDir;
import std.path : buildPath, absolutePath;
import std.conv : to;
import std.algorithm : map;
import std.array : array;
import engine.distributed.protocol.protocol;
import engine.runtime.hermetic;
import engine.runtime.hermetic.monitoring;
import engine.runtime.hermetic.platforms.capabilities;
import infrastructure.errors;

// Import base classes
public import engine.distributed.worker.sandbox_base;

/// Sandbox environment interface
interface SandboxEnv
{
    /// Execute command in sandbox
    Result!(ExecutionOutput, DistributedError) execute(
        string command,
        string[string] env,
        Duration timeout
    );
    
    /// Get resource usage
    ResourceUsage resourceUsage();
    
    /// Get resource monitor (if available)
    ResourceMonitor monitor();
    
    /// Cleanup sandbox
    void cleanup();
}

/// Sandbox factory (platform-specific)
interface Sandbox
{
    /// Prepare isolated execution environment
    Result!(SandboxEnv, DistributedError) prepare(
        ActionRequest request,
        InputArtifact[] inputs
    );
}

/// No-op sandbox (for development/testing)
final class NoSandbox : Sandbox
{
    Result!(SandboxEnv, DistributedError) prepare(
        ActionRequest request,
        InputArtifact[] inputs
    ) @trusted
    {
        return Ok!(SandboxEnv, DistributedError)(
            cast(SandboxEnv)(new NoSandboxEnv(request, inputs))
        );
    }
}

/// No-op sandbox environment
final class NoSandboxEnv : SandboxEnvBase, SandboxEnv
{
    this(ActionRequest request, InputArtifact[] inputs) @trusted
    {
        import engine.runtime.hermetic.monitoring : NoOpMonitor;
        super(request, inputs, new NoOpMonitor());
    }
    
    Result!(ExecutionOutput, DistributedError) execute(
        string command,
        string[string] env,
        Duration timeout
    ) @trusted
    {
        return executeWithMonitoring({
            try
            {
                import infrastructure.utils.security.executor : execute;
                // Execute command directly (no sandboxing)
                auto result = execute(
                    ["sh", "-c", command],
                    env,
                    Config.none,
                    size_t.max,
                    workDir
                );
                
                ExecutionOutput output;
                output.stdout = result.output;
                output.exitCode = result.status;
                
                return Ok!(ExecutionOutput, DistributedError)(output);
            }
            catch (Exception e)
            {
                return Err!(ExecutionOutput, DistributedError)(
                    new ExecutionError(e.msg));
            }
        });
    }
}

version(linux)
{
    /// Linux sandbox using namespaces
    final class LinuxSandbox : SandboxBase, Sandbox
    {
        protected override void addStandardPaths(ref SandboxSpecBuilder builder) @safe
        {
            builder.input("/usr/lib");
            builder.input("/usr/include");
            builder.input("/lib");
            builder.input("/lib64");
        }
        
        Result!(SandboxEnv, DistributedError) prepare(
            ActionRequest request,
            InputArtifact[] inputs
        ) @trusted
        {
            string workDir;
            auto specResult = buildSpec(request, inputs, workDir);
            if (specResult.isErr)
                return Err!(SandboxEnv, DistributedError)(specResult.unwrapErr());
            
            return Ok!(SandboxEnv, DistributedError)(
                cast(SandboxEnv)(new LinuxSandboxEnv(request, inputs, specResult.unwrap(), workDir))
            );
        }
    }
    
    /// Linux sandbox environment using hermetic execution
    final class LinuxSandboxEnv : SandboxEnvBase, SandboxEnv
    {
        private SandboxSpec spec;
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            import engine.runtime.hermetic.monitoring : createMonitor;
            this.spec = spec;
            super(request, inputs, createMonitor(spec.resources));
            this.workDir = workDir; // Override with passed workDir
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            return executeWithMonitoring({
                // Create hermetic executor
                auto executorResult = HermeticExecutor.create(spec, workDir);
                if (executorResult.isErr)
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError(executorResult.unwrapErr().message()));
                }
                
                auto executor = executorResult.unwrap();
                
                // Parse command with proper shell quoting support
                auto cmdArray = parseCommand(command);
                
                // Execute hermetically with timeout
                import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
                auto timeoutEnforcer = createTimeoutEnforcer();
                if (timeout > Duration.zero)
                {
                    timeoutEnforcer.start(timeout);
                }
                scope(exit)
                {
                    if (timeout > Duration.zero)
                        timeoutEnforcer.stop();
                }
                
                auto result = executor.execute(cmdArray, workDir);
                
                if (result.isErr)
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError(result.unwrapErr().message()));
                }
                
                // Check for timeout
                if (timeoutEnforcer.isTimedOut())
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError("Execution timed out"));
                }
                
                auto output = result.unwrap();
                ExecutionOutput execOutput;
                execOutput.stdout = output.stdout;
                execOutput.stderr = output.stderr;
                execOutput.exitCode = output.exitCode;
                
                return Ok!(ExecutionOutput, DistributedError)(execOutput);
            });
        }
    }
}

version(OSX)
{
    /// macOS sandbox using sandbox-exec
    final class MacOSSandbox : SandboxBase, Sandbox
    {
        protected override void addStandardPaths(ref SandboxSpecBuilder builder) @safe
        {
            builder.input("/usr/lib");
            builder.input("/usr/include");
            builder.input("/System/Library");
            builder.input("/Library");
        }
        
        Result!(SandboxEnv, DistributedError) prepare(
            ActionRequest request,
            InputArtifact[] inputs
        ) @trusted
        {
            string workDir;
            auto specResult = buildSpec(request, inputs, workDir);
            if (specResult.isErr)
                return Err!(SandboxEnv, DistributedError)(specResult.unwrapErr());
            
            return Ok!(SandboxEnv, DistributedError)(
                cast(SandboxEnv)(new MacOSSandboxEnv(request, inputs, specResult.unwrap(), workDir))
            );
        }
    }
    
    /// macOS sandbox environment using hermetic execution
    final class MacOSSandboxEnv : SandboxEnvBase, SandboxEnv
    {
        private SandboxSpec spec;
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            import engine.runtime.hermetic.monitoring : createMonitor;
            this.spec = spec;
            super(request, inputs, createMonitor(spec.resources));
            this.workDir = workDir; // Override with passed workDir
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            return executeWithMonitoring({
                // Create hermetic executor
                auto executorResult = HermeticExecutor.create(spec, workDir);
                if (executorResult.isErr)
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError(executorResult.unwrapErr().message()));
                }
                
                auto executor = executorResult.unwrap();
                
                // Parse command with proper shell quoting support
                auto cmdArray = parseCommand(command);
                
                // Execute hermetically with timeout
                import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
                auto timeoutEnforcer = createTimeoutEnforcer();
                if (timeout > Duration.zero)
                {
                    timeoutEnforcer.start(timeout);
                }
                scope(exit)
                {
                    if (timeout > Duration.zero)
                        timeoutEnforcer.stop();
                }
                
                auto result = executor.execute(cmdArray, workDir);
                
                if (result.isErr)
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError(result.unwrapErr().message()));
                }
                
                // Check for timeout
                if (timeoutEnforcer.isTimedOut())
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError("Execution timed out"));
                }
                
                auto output = result.unwrap();
                ExecutionOutput execOutput;
                execOutput.stdout = output.stdout;
                execOutput.stderr = output.stderr;
                execOutput.exitCode = output.exitCode;
                
                return Ok!(ExecutionOutput, DistributedError)(execOutput);
            });
        }
    }
}

version(Windows)
{
    /// Windows sandbox using job objects
    final class WindowsSandbox : SandboxBase, Sandbox
    {
        protected override void addStandardPaths(ref SandboxSpecBuilder builder) @safe
        {
            // Windows typically doesn't need standard paths added
            // System directories are automatically available
        }
        
        Result!(SandboxEnv, DistributedError) prepare(
            ActionRequest request,
            InputArtifact[] inputs
        ) @trusted
        {
            string workDir;
            auto specResult = buildSpec(request, inputs, workDir);
            if (specResult.isErr)
                return Err!(SandboxEnv, DistributedError)(specResult.unwrapErr());
            
            return Ok!(SandboxEnv, DistributedError)(
                cast(SandboxEnv)(new WindowsSandboxEnv(request, inputs, specResult.unwrap(), workDir))
            );
        }
    }
    
    /// Windows sandbox environment using job objects
    final class WindowsSandboxEnv : SandboxEnvBase, SandboxEnv
    {
        private SandboxSpec spec;
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            import engine.runtime.hermetic.monitoring : createMonitor;
            this.spec = spec;
            super(request, inputs, createMonitor(spec.resources));
            this.workDir = workDir; // Override with passed workDir
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            return executeWithMonitoring({
                // Create hermetic executor
                auto executorResult = HermeticExecutor.create(spec, workDir);
                if (executorResult.isErr)
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError(executorResult.unwrapErr().message()));
                }
                
                auto executor = executorResult.unwrap();
                
                // Parse command with proper shell quoting support
                auto cmdArray = parseCommand(command);
                
                // Execute hermetically with timeout
                import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
                auto timeoutEnforcer = createTimeoutEnforcer();
                if (timeout > Duration.zero)
                {
                    timeoutEnforcer.start(timeout);
                }
                scope(exit)
                {
                    if (timeout > Duration.zero)
                        timeoutEnforcer.stop();
                }
                
                auto result = executor.execute(cmdArray, workDir);
                
                if (result.isErr)
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError(result.unwrapErr().message()));
                }
                
                // Check for timeout
                if (timeoutEnforcer.isTimedOut())
                {
                    return Err!(ExecutionOutput, DistributedError)(
                        new ExecutionError("Execution timed out"));
                }
                
                auto output = result.unwrap();
                ExecutionOutput execOutput;
                execOutput.stdout = output.stdout;
                execOutput.stderr = output.stderr;
                execOutput.exitCode = output.exitCode;
                
                return Ok!(ExecutionOutput, DistributedError)(execOutput);
            });
        }
    }
}

/// Create platform-appropriate sandbox
Sandbox createSandbox(bool hermetic = true) @trusted
{
    if (!hermetic)
        return new NoSandbox();
    
    // Use capability detection to determine best sandbox
    auto caps = getCapabilities();
    
    if (!caps.canRunHermetic())
        return new NoSandbox();
    
    version(linux)
    {
        if (caps.namespacesAvailable)
            return new LinuxSandbox();
        else
            return new NoSandbox();
    }
    else version(OSX)
    {
        if (caps.sandboxExecAvailable)
            return new MacOSSandbox();
        else
            return new NoSandbox();
    }
    else version(Windows)
    {
        if (caps.jobObjectsAvailable)
            return new WindowsSandbox();
        else
            return new NoSandbox();
    }
    else
    {
        return new NoSandbox();
    }
}



