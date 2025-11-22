module engine.distributed.worker.sandbox;

import std.process : execute, Config;
import std.datetime : Duration;
import std.file : exists, mkdirRecurse, rmdirRecurse, tempDir;
import std.path : buildPath, absolutePath;
import std.conv : to;
import std.algorithm : map;
import std.array : array;
import engine.distributed.protocol.protocol;
import infrastructure.errors;

// Import base classes (includes ExecutionOutput and ISandboxEnv)
public import engine.distributed.worker.sandbox_base;

// Import hermetic execution (hide ExecutionOutput to avoid conflict)
static import engine.runtime.hermetic;
import engine.runtime.hermetic.monitoring;
import engine.runtime.hermetic.platforms.capabilities;

// Bring hermetic symbols into scope except ExecutionOutput
alias HermeticExecutor = engine.runtime.hermetic.HermeticExecutor;
alias HermeticSpecBuilder = engine.runtime.hermetic.HermeticSpecBuilder;
alias SandboxSpec = engine.runtime.hermetic.SandboxSpec;
alias SandboxSpecBuilder = engine.runtime.hermetic.SandboxSpecBuilder;

/// Sandbox environment interface
interface SandboxEnv : ISandboxEnv
{
    /// Execute command in sandbox
    Result!(ExecutionOutput, DistributedError) execute(
        string command,
        string[string] env,
        Duration timeout
    );
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
    
    Result!(ExecutionOutput, DistributedError) execute(string command, string[string] env, Duration timeout) @trusted
    {
        return executeWithMonitoring(() @trusted {
            try
            {
                import infrastructure.utils.security.executor : execute;
                auto result = execute(["sh", "-c", command], env, Config.none, size_t.max, workDir);
                return Ok!(ExecutionOutput, DistributedError)(ExecutionOutput(result.output, "", result.status));
            }
            catch (Exception e) { return Err!(ExecutionOutput, DistributedError)(new ExecutionError(e.msg)); }
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
            this.workDir = workDir;
        }
        
        Result!(ExecutionOutput, DistributedError) execute(string command, string[string] env, Duration timeout) @trusted
        {
            return executeWithMonitoring(() @trusted {
                auto executorResult = HermeticExecutor.create(spec, workDir);
                if (executorResult.isErr) return Err!(ExecutionOutput, DistributedError)(new ExecutionError(executorResult.unwrapErr().message()));
                
                import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
                auto timeoutEnforcer = createTimeoutEnforcer();
                if (timeout > Duration.zero) timeoutEnforcer.start(timeout);
                scope(exit) if (timeout > Duration.zero) timeoutEnforcer.stop();
                
                auto result = executorResult.unwrap().execute(parseCommand(command), workDir);
                if (result.isErr) return Err!(ExecutionOutput, DistributedError)(new ExecutionError(result.unwrapErr().message()));
                if (timeoutEnforcer.isTimedOut()) return Err!(ExecutionOutput, DistributedError)(new ExecutionError("Execution timed out"));
                
                auto output = result.unwrap();
                return Ok!(ExecutionOutput, DistributedError)(ExecutionOutput(output.stdout, output.stderr, output.exitCode));
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
            this.workDir = workDir;
        }
        
        Result!(ExecutionOutput, DistributedError) execute(string command, string[string] env, Duration timeout) @trusted
        {
            return executeWithMonitoring(() @trusted {
                auto executorResult = HermeticExecutor.create(spec, workDir);
                if (executorResult.isErr) return Err!(ExecutionOutput, DistributedError)(new ExecutionError(executorResult.unwrapErr().message()));
                
                import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
                auto timeoutEnforcer = createTimeoutEnforcer();
                if (timeout > Duration.zero) timeoutEnforcer.start(timeout);
                scope(exit) if (timeout > Duration.zero) timeoutEnforcer.stop();
                
                auto result = executorResult.unwrap().execute(parseCommand(command), workDir);
                if (result.isErr) return Err!(ExecutionOutput, DistributedError)(new ExecutionError(result.unwrapErr().message()));
                if (timeoutEnforcer.isTimedOut()) return Err!(ExecutionOutput, DistributedError)(new ExecutionError("Execution timed out"));
                
                auto output = result.unwrap();
                return Ok!(ExecutionOutput, DistributedError)(ExecutionOutput(output.stdout, output.stderr, output.exitCode));
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
            this.workDir = workDir;
        }
        
        Result!(ExecutionOutput, DistributedError) execute(string command, string[string] env, Duration timeout) @trusted
        {
            return executeWithMonitoring(() @trusted {
                auto executorResult = HermeticExecutor.create(spec, workDir);
                if (executorResult.isErr) return Err!(ExecutionOutput, DistributedError)(new ExecutionError(executorResult.unwrapErr().message()));
                
                import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
                auto timeoutEnforcer = createTimeoutEnforcer();
                if (timeout > Duration.zero) timeoutEnforcer.start(timeout);
                scope(exit) if (timeout > Duration.zero) timeoutEnforcer.stop();
                
                auto result = executorResult.unwrap().execute(parseCommand(command), workDir);
                if (result.isErr) return Err!(ExecutionOutput, DistributedError)(new ExecutionError(result.unwrapErr().message()));
                if (timeoutEnforcer.isTimedOut()) return Err!(ExecutionOutput, DistributedError)(new ExecutionError("Execution timed out"));
                
                auto output = result.unwrap();
                return Ok!(ExecutionOutput, DistributedError)(ExecutionOutput(output.stdout, output.stderr, output.exitCode));
            });
        }
    }
}

/// Create platform-appropriate sandbox
Sandbox createSandbox(bool hermetic = true) @trusted
{
    if (!hermetic) return new NoSandbox();
    auto caps = getCapabilities();
    if (!caps.canRunHermetic()) return new NoSandbox();
    
    version(linux) return caps.namespacesAvailable ? new LinuxSandbox() : new NoSandbox();
    else version(OSX) return caps.sandboxExecAvailable ? new MacOSSandbox() : new NoSandbox();
    else version(Windows) return caps.jobObjectsAvailable ? new WindowsSandbox() : new NoSandbox();
    else return new NoSandbox();
}



