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
import infrastructure.errors;

/// Execution output
struct ExecutionOutput
{
    string stdout;      // Captured stdout
    string stderr;      // Captured stderr
    int exitCode;       // Process exit code
}

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

/// Input artifact (for sandbox mounting)
struct InputArtifact
{
    ArtifactId id;
    ubyte[] data;
    string path;
    bool executable;
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
final class NoSandboxEnv : SandboxEnv
{
    private ActionRequest request;
    private InputArtifact[] inputs;
    private string workDir;
    private ResourceMonitor _monitor;
    
    this(ActionRequest request, InputArtifact[] inputs) @trusted
    {
        this.request = request;
        this.inputs = inputs;
        
        // Create temporary work directory
        import std.random : uniform;
        this.workDir = buildPath(tempDir(), "builder-sandbox-" ~ uniform!ulong().to!string);
        mkdirRecurse(workDir);
        
        // Create no-op monitor
        import engine.runtime.hermetic.monitoring : NoOpMonitor;
        _monitor = new NoOpMonitor();
    }
    
    Result!(ExecutionOutput, DistributedError) execute(
        string command,
        string[string] env,
        Duration timeout
    ) @trusted
    {
        _monitor.start();
        scope(exit) _monitor.stop();
        
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
    }
    
    ResourceUsage resourceUsage() @safe
    {
        return _monitor.snapshot();
    }
    
    ResourceMonitor monitor() @safe
    {
        return _monitor;
    }
    
    void cleanup() @trusted
    {
        if (exists(workDir))
        {
            try
            {
                rmdirRecurse(workDir);
            }
            catch (Exception) {}
        }
    }
}

version(linux)
{
    /// Linux sandbox using namespaces
    final class LinuxSandbox : Sandbox
    {
        Result!(SandboxEnv, DistributedError) prepare(
            ActionRequest request,
            InputArtifact[] inputs
        ) @trusted
        {
            // Build hermetic spec from action request
            auto specBuilder = SandboxSpecBuilder.create();
            
            // Add input artifacts as inputs
            foreach (input; inputs)
            {
                if (input.path.length > 0)
                    specBuilder.input(input.path);
            }
            
            // Create work directory
            import std.random : uniform;
            import std.uuid : randomUUID;
            immutable workDir = buildPath(tempDir(), "builder-sandbox-" ~ randomUUID().toString());
            mkdirRecurse(workDir);
            
            // Add work directory as temp
            specBuilder.temp(workDir);
            
            // Add standard system paths
            specBuilder.input("/usr/lib");
            specBuilder.input("/usr/include");
            specBuilder.input("/lib");
            specBuilder.input("/lib64");
            
            // Build spec
            auto specResult = specBuilder.build();
            if (specResult.isErr)
            {
                return Err!(SandboxEnv, DistributedError)(
                    new DistributedError("Failed to build spec: " ~ specResult.unwrapErr()));
            }
            
            return Ok!(SandboxEnv, DistributedError)(
                cast(SandboxEnv)(new LinuxSandboxEnv(request, inputs, specResult.unwrap(), workDir))
            );
        }
    }
    
    /// Linux sandbox environment using hermetic execution
    final class LinuxSandboxEnv : SandboxEnv
    {
        private ActionRequest request;
        private InputArtifact[] inputs;
        private SandboxSpec spec;
        private string workDir;
        private ResourceMonitor _monitor;
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            this.request = request;
            this.inputs = inputs;
            this.spec = spec;
            this.workDir = workDir;
            
            // Create Linux resource monitor
            import engine.runtime.hermetic.monitoring : createMonitor;
            _monitor = createMonitor(spec.resources);
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            // Start monitoring
            _monitor.start();
            scope(exit) _monitor.stop();
            
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
        }
        
        ResourceUsage resourceUsage() @safe
        {
            return _monitor.snapshot();
        }
        
        ResourceMonitor monitor() @safe
        {
            return _monitor;
        }
        
        void cleanup() @trusted
        {
            if (exists(workDir))
            {
                try
                {
                    rmdirRecurse(workDir);
                }
                catch (Exception) {}
            }
        }
    }
}

version(OSX)
{
    /// macOS sandbox using sandbox-exec
    final class MacOSSandbox : Sandbox
    {
        Result!(SandboxEnv, DistributedError) prepare(
            ActionRequest request,
            InputArtifact[] inputs
        ) @trusted
        {
            // Build hermetic spec from action request
            auto specBuilder = SandboxSpecBuilder.create();
            
            // Add input artifacts as inputs
            foreach (input; inputs)
            {
                if (input.path.length > 0)
                    specBuilder.input(input.path);
            }
            
            // Create work directory
            import std.random : uniform;
            import std.uuid : randomUUID;
            immutable workDir = buildPath(tempDir(), "builder-sandbox-" ~ randomUUID().toString());
            mkdirRecurse(workDir);
            
            // Add work directory as temp
            specBuilder.temp(workDir);
            
            // Add standard system paths
            specBuilder.input("/usr/lib");
            specBuilder.input("/usr/include");
            specBuilder.input("/System/Library");
            specBuilder.input("/Library");
            
            // Build spec
            auto specResult = specBuilder.build();
            if (specResult.isErr)
            {
                return Err!(SandboxEnv, DistributedError)(
                    new DistributedError("Failed to build spec: " ~ specResult.unwrapErr()));
            }
            
            return Ok!(SandboxEnv, DistributedError)(
                cast(SandboxEnv)(new MacOSSandboxEnv(request, inputs, specResult.unwrap(), workDir))
            );
        }
    }
    
    /// macOS sandbox environment using hermetic execution
    final class MacOSSandboxEnv : SandboxEnv
    {
        private ActionRequest request;
        private InputArtifact[] inputs;
        private SandboxSpec spec;
        private string workDir;
        private ResourceMonitor _monitor;
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            this.request = request;
            this.inputs = inputs;
            this.spec = spec;
            this.workDir = workDir;
            
            // Create macOS resource monitor
            import engine.runtime.hermetic.monitoring : createMonitor;
            _monitor = createMonitor(spec.resources);
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            // Start monitoring
            _monitor.start();
            scope(exit) _monitor.stop();
            
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
        }
        
        ResourceUsage resourceUsage() @safe
        {
            return _monitor.snapshot();
        }
        
        ResourceMonitor monitor() @safe
        {
            return _monitor;
        }
        
        void cleanup() @trusted
        {
            if (exists(workDir))
            {
                try
                {
                    rmdirRecurse(workDir);
                }
                catch (Exception) {}
            }
        }
    }
}

version(Windows)
{
    /// Windows sandbox using job objects
    final class WindowsSandbox : Sandbox
    {
        Result!(SandboxEnv, DistributedError) prepare(
            ActionRequest request,
            InputArtifact[] inputs
        ) @trusted
        {
            // Build hermetic spec from action request
            auto specBuilder = SandboxSpecBuilder.create();
            
            // Add input artifacts as inputs
            foreach (input; inputs)
            {
                if (input.path.length > 0)
                    specBuilder.input(input.path);
            }
            
            // Create work directory
            import std.random : uniform;
            import std.uuid : randomUUID;
            immutable workDir = buildPath(tempDir(), "builder-sandbox-" ~ randomUUID().toString());
            mkdirRecurse(workDir);
            
            // Add work directory as temp
            specBuilder.temp(workDir);
            
            // Build spec
            auto specResult = specBuilder.build();
            if (specResult.isErr)
            {
                return Err!(SandboxEnv, DistributedError)(
                    new DistributedError("Failed to build spec: " ~ specResult.unwrapErr()));
            }
            
            return Ok!(SandboxEnv, DistributedError)(
                cast(SandboxEnv)(new WindowsSandboxEnv(request, inputs, specResult.unwrap(), workDir))
            );
        }
    }
    
    /// Windows sandbox environment using job objects
    final class WindowsSandboxEnv : SandboxEnv
    {
        private ActionRequest request;
        private InputArtifact[] inputs;
        private SandboxSpec spec;
        private string workDir;
        private ResourceMonitor _monitor;
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            this.request = request;
            this.inputs = inputs;
            this.spec = spec;
            this.workDir = workDir;
            
            // Create Windows resource monitor
            import engine.runtime.hermetic.monitoring : createMonitor;
            _monitor = createMonitor(spec.resources);
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            // Start monitoring
            _monitor.start();
            scope(exit) _monitor.stop();
            
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
        }
        
        ResourceUsage resourceUsage() @safe
        {
            return _monitor.snapshot();
        }
        
        ResourceMonitor monitor() @safe
        {
            return _monitor;
        }
        
        void cleanup() @trusted
        {
            if (exists(workDir))
            {
                try
                {
                    rmdirRecurse(workDir);
                }
                catch (Exception) {}
            }
        }
    }
}

/// Parse command string with shell quoting support
/// Handles single quotes, double quotes, and escaped spaces
private string[] parseCommand(string command) @safe
{
    import std.array : appender;
    import std.string : strip;
    
    auto result = appender!(string[]);
    auto current = appender!string;
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool escaped = false;
    
    foreach (char c; command)
    {
        if (escaped)
        {
            current ~= c;
            escaped = false;
            continue;
        }
        
        if (c == '\\' && !inSingleQuote)
        {
            escaped = true;
            continue;
        }
        
        if (c == '\'' && !inDoubleQuote)
        {
            inSingleQuote = !inSingleQuote;
            continue;
        }
        
        if (c == '"' && !inSingleQuote)
        {
            inDoubleQuote = !inDoubleQuote;
            continue;
        }
        
        if (c == ' ' && !inSingleQuote && !inDoubleQuote)
        {
            if (current.data.length > 0)
            {
                result ~= current.data;
                current = appender!string;
            }
            continue;
        }
        
        current ~= c;
    }
    
    // Add final token
    if (current.data.length > 0)
        result ~= current.data;
    
    return result.data;
}

/// Create platform-appropriate sandbox
Sandbox createSandbox(bool hermetic = true) @trusted
{
    if (!hermetic)
        return new NoSandbox();
    
    version(linux)
    {
        // Check if running in environment that supports namespaces
        import std.file : exists;
        if (exists("/proc/self/ns/user"))
            return new LinuxSandbox();
        else
            return new NoSandbox();  // Fallback if namespaces not available
    }
    else version(OSX)
    {
        // Check if sandbox-exec is available
        import std.process : execute;
        auto result = execute(["which", "sandbox-exec"]);
        if (result.status == 0)
            return new MacOSSandbox();
        else
            return new NoSandbox();  // Fallback if sandbox-exec not available
    }
    else version(Windows)
    {
        // Windows job objects - future implementation
        return new WindowsSandbox();
    }
    else
    {
        return new NoSandbox();
    }
}



