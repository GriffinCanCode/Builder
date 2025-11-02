module core.distributed.worker.sandbox;

import std.process : execute, Config;
import std.datetime : Duration;
import std.file : exists, mkdirRecurse, rmdirRecurse, tempDir;
import std.path : buildPath, absolutePath;
import std.conv : to;
import std.algorithm : map;
import std.array : array;
import core.distributed.protocol.protocol;
import core.execution.hermetic;
import errors;

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
    
    this(ActionRequest request, InputArtifact[] inputs) @trusted
    {
        this.request = request;
        this.inputs = inputs;
        
        // Create temporary work directory
        import std.random : uniform;
        this.workDir = buildPath(tempDir(), "builder-sandbox-" ~ uniform!ulong().to!string);
        mkdirRecurse(workDir);
    }
    
    Result!(ExecutionOutput, DistributedError) execute(
        string command,
        string[string] env,
        Duration timeout
    ) @trusted
    {
        try
        {
            import utils.security.executor : execute;
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
        // TODO: Collect actual resource usage
        ResourceUsage usage;
        return usage;
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
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            this.request = request;
            this.inputs = inputs;
            this.spec = spec;
            this.workDir = workDir;
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            // Create hermetic executor
            auto executorResult = HermeticExecutor.create(spec, workDir);
            if (executorResult.isErr)
            {
                return Err!(ExecutionOutput, DistributedError)(
                    new ExecutionError(executorResult.unwrapErr()));
            }
            
            auto executor = executorResult.unwrap();
            
            // Parse command with proper shell quoting support
            auto cmdArray = parseCommand(command);
            
            // Execute hermetically
            auto result = executor.execute(cmdArray, workDir);
            
            if (result.isErr)
            {
                return Err!(ExecutionOutput, DistributedError)(
                    new ExecutionError(result.unwrapErr()));
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
            ResourceUsage usage;
            
            // Collect resource usage from cgroups if available
            version(linux) {
                try {
                    import std.file : readText, exists;
                    import std.conv : to;
                    import std.string : strip, lineSplitter, splitter;
                    import std.algorithm : filter;
                    import std.path : buildPath;
                    
                    // Try to read cgroup stats (best-effort)
                    immutable cgroupBase = "/sys/fs/cgroup";
                    if (exists(cgroupBase)) {
                        // Try cgroup v2 memory usage
                        auto memCurrent = buildPath(cgroupBase, "memory.current");
                        if (exists(memCurrent)) {
                            usage.memoryBytes = readText(memCurrent).strip.to!ulong;
                        }
                        
                        // Try cgroup v2 CPU usage
                        auto cpuStat = buildPath(cgroupBase, "cpu.stat");
                        if (exists(cpuStat)) {
                            foreach (line; readText(cpuStat).lineSplitter) {
                                auto parts = line.splitter(" ");
                                if (!parts.empty && parts.front == "usage_usec") {
                                    parts.popFront();
                                    if (!parts.empty) {
                                        usage.cpuTimeMs = parts.front.to!ulong / 1000;
                                    }
                                }
                            }
                        }
                    }
                } catch (Exception) {
                    // Best-effort - silently fail if cgroups unavailable
                }
            }
            
            return usage;
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
        
        this(ActionRequest request, InputArtifact[] inputs, SandboxSpec spec, string workDir) @trusted
        {
            this.request = request;
            this.inputs = inputs;
            this.spec = spec;
            this.workDir = workDir;
        }
        
        Result!(ExecutionOutput, DistributedError) execute(
            string command,
            string[string] env,
            Duration timeout
        ) @trusted
        {
            // Create hermetic executor
            auto executorResult = HermeticExecutor.create(spec, workDir);
            if (executorResult.isErr)
            {
                return Err!(ExecutionOutput, DistributedError)(
                    new ExecutionError(executorResult.unwrapErr()));
            }
            
            auto executor = executorResult.unwrap();
            
            // Parse command with proper shell quoting support
            auto cmdArray = parseCommand(command);
            
            // Execute hermetically
            auto result = executor.execute(cmdArray, workDir);
            
            if (result.isErr)
            {
                return Err!(ExecutionOutput, DistributedError)(
                    new ExecutionError(result.unwrapErr()));
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
            ResourceUsage usage;
            
            // macOS doesn't expose sandbox resource usage easily
            // Could use getrusage() for the current process tree
            version(OSX) {
                // Best-effort: not easily available from sandbox-exec
                // Would need to track process tree and aggregate rusage
            }
            
            return usage;
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
            // TODO: Implement Windows job object sandboxing
            return Err!(SandboxEnv, DistributedError)(
                new DistributedError("Windows sandbox not yet implemented"));
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



