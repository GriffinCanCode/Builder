module engine.distributed.worker.sandbox_base;

import std.datetime : Duration;
import std.file : exists, mkdirRecurse, rmdirRecurse, tempDir;
import std.path : buildPath;
import std.conv : to;
import std.uuid : randomUUID;
import engine.distributed.protocol.protocol;
import engine.runtime.hermetic.monitoring;
import engine.runtime.hermetic.core.spec : ResourceLimits, SandboxSpec, SandboxSpecBuilder;
import infrastructure.errors;

/// Input artifact (for sandbox mounting)
struct InputArtifact
{
    ArtifactId id;
    ubyte[] data;
    string path;
    bool executable;
}

/// Execution output
struct ExecutionOutput
{
    string stdout;      // Captured stdout
    string stderr;      // Captured stderr
    int exitCode;       // Process exit code
}

/// Sandbox environment interface (forward declaration for SandboxEnvBase)
interface ISandboxEnv
{
    ResourceUsage resourceUsage();
    ResourceMonitor monitor();
    void cleanup();
}

/// Base sandbox environment implementation
/// Extracts common patterns shared across all platform-specific sandbox environments
abstract class SandboxEnvBase : ISandboxEnv
{
    protected ActionRequest request;
    protected InputArtifact[] inputs;
    protected string workDir;
    protected ResourceMonitor _monitor;
    protected bool _cleaned;
    
    /// Constructor for platform-specific implementations
    protected this(ActionRequest request, InputArtifact[] inputs, ResourceMonitor monitor) @trusted
    {
        this.request = request;
        this.inputs = inputs;
        this._monitor = monitor;
        this._cleaned = false;
        
        // Create work directory
        this.workDir = createWorkDirectory();
    }
    
    /// Create unique work directory
    protected static string createWorkDirectory() @trusted
    {
        immutable dir = buildPath(tempDir(), "builder-sandbox-" ~ randomUUID().toString());
        mkdirRecurse(dir);
        return dir;
    }
    
    /// Get resource usage
    final ResourceUsage resourceUsage() @safe
    {
        return _monitor.snapshot();
    }
    
    /// Get resource monitor
    final ResourceMonitor monitor() @safe
    {
        return _monitor;
    }
    
    /// Cleanup sandbox (final to ensure consistent cleanup pattern)
    final void cleanup() @trusted
    {
        if (_cleaned)
            return;
        
        _cleaned = true;
        
        // Platform-specific cleanup
        doCleanup();
        
        // Clean work directory
        cleanupWorkDirectory();
    }
    
    /// Platform-specific cleanup hook
    protected void doCleanup() @trusted
    {
        // Override in subclasses if needed
    }
    
    /// Cleanup work directory
    protected final void cleanupWorkDirectory() @trusted
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
    
    /// Execute command with standard monitoring pattern
    protected final Result!(ExecutionOutput, DistributedError) executeWithMonitoring(
        scope Result!(ExecutionOutput, DistributedError) delegate() @trusted executeFunc
    ) @trusted
    {
        _monitor.start();
        scope(exit) _monitor.stop();
        
        auto result = executeFunc();
        
        // Check for resource violations
        if (_monitor.isViolated())
        {
            auto violations = _monitor.violations();
            if (violations.length > 0)
            {
                return Err!(ExecutionOutput, DistributedError)(
                    new ResourceLimitError(violations[0].message)
                );
            }
        }
        
        return result;
    }
    
    /// Get work directory
    final string getWorkDir() const pure nothrow @nogc @safe
    {
        return workDir;
    }
}

/// Base sandbox factory implementation
/// Provides common preparation patterns
abstract class SandboxBase
{
    /// Common spec building logic for inputs
    protected final void addInputsToSpec(ref SandboxSpecBuilder builder, InputArtifact[] inputs) @safe
    {
        foreach (input; inputs)
        {
            if (input.path.length > 0)
                builder.input(input.path);
        }
    }
    
    /// Create work directory and add to spec
    protected final string createAndAddWorkDir(ref SandboxSpecBuilder builder) @trusted
    {
        immutable workDir = buildPath(tempDir(), "builder-sandbox-" ~ randomUUID().toString());
        mkdirRecurse(workDir);
        builder.temp(workDir);
        return workDir;
    }
    
    /// Add platform-specific standard paths
    protected abstract void addStandardPaths(ref SandboxSpecBuilder builder) @safe;
    
    /// Build sandbox spec from action request
    protected final Result!(SandboxSpec, DistributedError) buildSpec(
        ActionRequest request,
        InputArtifact[] inputs,
        out string workDir
    ) @trusted
    {
        auto specBuilder = SandboxSpecBuilder.create();
        
        // Add inputs
        addInputsToSpec(specBuilder, inputs);
        
        // Create and add work directory
        workDir = createAndAddWorkDir(specBuilder);
        
        // Platform-specific paths
        addStandardPaths(specBuilder);
        
        // Build spec
        auto specResult = specBuilder.build();
        if (specResult.isErr)
        {
            return Err!(SandboxSpec, DistributedError)(
                new DistributedError("Failed to build spec: " ~ specResult.unwrapErr())
            );
        }
        
        return Ok!(SandboxSpec, DistributedError)(specResult.unwrap());
    }
}

/// Parse command string with shell quoting support
/// Handles single quotes, double quotes, and escaped spaces
string[] parseCommand(string command) @safe
{
    import std.array : appender;
    
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

@safe unittest
{
    // Test simple command
    assert(parseCommand("gcc main.c") == ["gcc", "main.c"]);
    
    // Test quoted arguments
    assert(parseCommand("gcc \"main file.c\"") == ["gcc", "main file.c"]);
    assert(parseCommand("gcc 'main file.c'") == ["gcc", "main file.c"]);
    
    // Test escaped spaces
    assert(parseCommand("gcc main\\ file.c") == ["gcc", "main file.c"]);
    
    // Test complex command
    assert(parseCommand("sh -c 'echo \"hello world\"'") == ["sh", "-c", "echo \"hello world\""]);
}

/// Resource limit violation error
class ResourceLimitError : DistributedError
{
    this(string message, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(message, file, line);
    }
}

