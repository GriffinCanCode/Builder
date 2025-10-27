module utils.security.executor;

import std.process;
import std.algorithm;
import std.array;
import std.string;
import utils.security.validation;
import utils.logging.logger;
import errors;

@safe:

/// Type-safe command execution with comprehensive security validation
/// Prevents command injection, validates paths, enforces array-form execution
struct SecureExecutor
{
    private string workDir;
    private string[string] environment;
    private bool validatePaths = true;
    private bool auditLog = false;
    
    /// Builder pattern for configuration
    static SecureExecutor create() @safe nothrow
    {
        return SecureExecutor.init;
    }
    
    /// Set working directory
    ref typeof(this) in_(string dir) @safe return nothrow
    {
        this.workDir = dir;
        return this;
    }
    
    /// Set environment variables (replaces all)
    ref typeof(this) env(string[string] vars) @safe return nothrow
    {
        this.environment = vars;
        return this;
    }
    
    /// Add single environment variable
    ref typeof(this) withEnv(string key, string value) @safe return nothrow
    {
        this.environment[key] = value;
        return this;
    }
    
    /// Disable path validation (use with extreme caution)
    ref typeof(this) unsafeNoValidation() @safe return nothrow
    {
        this.validatePaths = false;
        return this;
    }
    
    /// Enable audit logging of all commands
    ref typeof(this) audit() @safe return nothrow
    {
        this.auditLog = true;
        return this;
    }
    
    /// Execute command with full validation
    /// Returns: Result monad with ProcessResult or SecurityError
    auto run(scope const(string)[] cmd) @trusted
    {
        // Validation layer
        if (cmd.length == 0)
            return Err!(ProcessResult, SecurityError)(
                SecurityError("Empty command", SecurityCode.InvalidCommand));
        
        // Validate command executable
        if (!SecurityValidator.isArgumentSafe(cmd[0]))
            return Err!(ProcessResult, SecurityError)(
                SecurityError("Unsafe command: " ~ cmd[0], SecurityCode.InjectionAttempt));
        
        // Validate all arguments
        foreach (arg; cmd[1 .. $])
        {
            if (!SecurityValidator.isArgumentSafe(arg))
                return Err!(ProcessResult, SecurityError)(
                    SecurityError("Unsafe argument: " ~ arg, SecurityCode.InjectionAttempt));
            
            // Validate paths if enabled
            if (validatePaths && (arg.canFind('/') || arg.canFind('\\')))
            {
                if (!SecurityValidator.isPathSafe(arg))
                    return Err!(ProcessResult, SecurityError)(
                        SecurityError("Unsafe path: " ~ arg, SecurityCode.PathTraversal));
            }
        }
        
        // Audit log if enabled
        if (auditLog)
        {
            Logger.debug_("[AUDIT] Executing: " ~ cmd.join(" "));
            if (!workDir.empty)
                Logger.debug_("[AUDIT]   WorkDir: " ~ workDir);
            if (environment.length > 0)
                Logger.debug_("[AUDIT]   EnvVars: " ~ environment.keys.join(", "));
        }
        
        // Execute with std.process.execute (safe array form)
        try
        {
            auto res = execute(
                cast(string[])cmd,
                environment.length > 0 ? environment : null,
                Config.none,
                size_t.max,
                workDir.empty ? null : workDir
            );
            
            return Ok!(ProcessResult, SecurityError)(
                ProcessResult(res.status, res.output));
        }
        catch (Exception e)
        {
            return Err!(ProcessResult, SecurityError)(
                SecurityError("Execution failed: " ~ e.msg, SecurityCode.ExecutionFailure));
        }
    }
    
    /// Execute command and check success (throws on non-zero exit)
    auto runChecked(scope const(string)[] cmd) @trusted
    {
        auto result = run(cmd);
        if (result.isErr)
            return result;
        
        auto proc = result.unwrap();
        if (proc.status != 0)
        {
            return Err!(ProcessResult, SecurityError)(
                SecurityError(
                    "Command failed with exit " ~ proc.status.to!string ~ ": " ~ proc.output,
                    SecurityCode.ExecutionFailure));
        }
        
        return Ok!(ProcessResult, SecurityError)(proc);
    }
}

/// Process execution result
struct ProcessResult
{
    int status;
    string output;
    
    bool success() const @safe pure nothrow @nogc
    {
        return status == 0;
    }
}

/// Security error types
struct SecurityError
{
    string message;
    SecurityCode code;
    
    this(string msg, SecurityCode c = SecurityCode.Unknown) @safe pure nothrow @nogc
    {
        this.message = msg;
        this.code = c;
    }
}

/// Security error codes
enum SecurityCode
{
    Unknown,
    InvalidCommand,
    InjectionAttempt,
    PathTraversal,
    ExecutionFailure,
    AccessDenied
}

/// Result monad for type-safe error handling
struct Result(T, E)
{
    private bool _isOk;
    private T _value;
    private E _error;
    
    static Result ok(T val) @safe
    {
        Result r;
        r._isOk = true;
        r._value = val;
        return r;
    }
    
    static Result err(E error) @safe
    {
        Result r;
        r._isOk = false;
        r._error = error;
        return r;
    }
    
    bool isOk() const @safe pure nothrow @nogc { return _isOk; }
    bool isErr() const @safe pure nothrow @nogc { return !_isOk; }
    
    T unwrap() @safe
    {
        if (!_isOk)
            throw new Exception("Called unwrap on error result: " ~ _error.message);
        return _value;
    }
    
    E unwrapErr() @safe
    {
        if (_isOk)
            throw new Exception("Called unwrapErr on ok result");
        return _error;
    }
    
    T unwrapOr(T default_) @safe
    {
        return _isOk ? _value : default_;
    }
}

/// Helper functions
auto Ok(T, E)(T val) @safe
{
    return Result!(T, E).ok(val);
}

auto Err(T, E)(E error) @safe
{
    return Result!(T, E).err(error);
}

// Import for string conversion
private import std.conv : to;

@safe unittest
{
    // Test safe execution
    auto exec = SecureExecutor.create();
    auto result = exec.run(["echo", "hello"]);
    assert(result.isOk);
    assert(result.unwrap().success);
    
    // Test injection prevention
    auto badResult = exec.run(["echo", "hello; rm -rf /"]);
    assert(badResult.isErr);
    assert(badResult.unwrapErr().code == SecurityCode.InjectionAttempt);
    
    // Test builder pattern
    auto configured = SecureExecutor.create()
        .in_("/tmp")
        .withEnv("TEST", "value")
        .audit();
    
    // Test path validation
    auto pathResult = exec.run(["cat", "../../../etc/passwd"]);
    assert(pathResult.isErr);
}

