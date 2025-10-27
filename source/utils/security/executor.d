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
    
    /// Validate a command (helper for testing)
    bool validateCommand(scope const(string)[] cmd) @safe
    {
        if (cmd.length == 0)
            return false;
        
        // Check executable
        if (!SecurityValidator.isArgumentSafe(cmd[0]))
            return false;
        
        // Check all arguments
        foreach (arg; cmd[1 .. $])
        {
            if (!SecurityValidator.isArgumentSafe(arg))
                return false;
        }
        
        return true;
    }
    
    /// Validate a single path (helper for testing)
    bool validatePath(string path) @safe
    {
        return SecurityValidator.isPathSafe(path);
    }
    
    /// Validate a working directory (helper for testing)
    bool validateWorkingDir(string dir) @safe
    {
        // Check if path is safe and not a system directory
        if (!SecurityValidator.isPathSafe(dir))
            return false;
        
        // Check for absolute system paths
        version(Posix)
        {
            immutable systemPaths = ["/etc", "/proc", "/sys", "/dev", "/boot"];
            foreach (sysPath; systemPaths)
            {
                if (dir == sysPath || dir.startsWith(sysPath ~ "/"))
                    return false;
            }
        }
        
        return true;
    }
    
    /// Set environment variable (helper for testing)
    void setEnv(string key, string value) @safe nothrow
    {
        this.environment[key] = value;
    }
    
    /// Get all environment variables (helper for testing)
    string[string] getEnv() @safe nothrow
    {
        return this.environment;
    }
    
    /// Execute command with full validation
    /// Returns: Result monad with ProcessResult or SecurityError
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Validates all arguments before execution (prevents injection)
    /// 2. Uses std.process.execute with array form (no shell interpretation)
    /// 3. SecurityValidator ensures no malicious paths or arguments
    /// 4. Exception handling converts failures to Result type
    /// 5. Audit logging for security monitoring
    /// 
    /// Invariants:
    /// - All command arguments are validated before execution
    /// - Array form prevents shell injection attacks
    /// - Working directory is validated if specified
    /// 
    /// What could go wrong:
    /// - Malicious arguments: caught by SecurityValidator (returns Err)
    /// - Process execution fails: converted to SecurityError result
    /// - Path traversal attempts: blocked by isPathSafe() validation
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
            Logger.debugLog("[AUDIT] Executing: " ~ cmd.join(" "));
            if (!workDir.empty)
                Logger.debugLog("[AUDIT]   WorkDir: " ~ workDir);
            if (environment.length > 0)
                Logger.debugLog("[AUDIT]   EnvVars: " ~ environment.keys.join(", "));
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. Delegates to trusted run() which validates all inputs
    /// 2. Additional exit code checking for convenience
    /// 3. Converts non-zero exits to errors
    /// 
    /// Invariants:
    /// - run() performs all security validation
    /// - Exit code check is performed after successful execution
    /// 
    /// What could go wrong:
    /// - Command fails validation: returned as Err from run()
    /// - Non-zero exit: converted to SecurityError (safe failure)
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

/// Drop-in replacement for std.process.execute with automatic path validation
/// This function provides the same interface as std.process.execute but with security checks
/// 
/// Safety: This function is @trusted because:
/// 1. Validates all command arguments before execution
/// 2. Validates paths to prevent traversal attacks
/// 3. Uses array form (no shell interpretation)
/// 4. Delegates to std.process.execute after validation
/// 
/// Invariants:
/// - All arguments are validated for injection patterns
/// - All path-like arguments are validated for traversal
/// - Working directory is validated if provided
/// 
/// What could go wrong:
/// - False positives: legitimate special characters in paths could be rejected
/// - TOCTOU: files could change between validation and execution
/// - Symlink attacks: validation doesn't resolve symlinks
@trusted
auto execute(
    scope const(string)[] args,
    const string[string] env = null,
    Config config = Config.none,
    size_t maxOutput = size_t.max,
    scope const(char)[] workDir = null,
    bool skipValidation = false
)
{
    import std.process : executeShell;
    import std.exception : enforce;
    
    // Critical security check: validate command is not empty
    enforce(args.length > 0, "Cannot execute empty command");
    
    // Skip validation only if explicitly requested (for trusted internal use)
    if (skipValidation)
    {
        return std.process.execute(args, env, config, maxOutput, workDir);
    }
    
    // Security Layer 1: Validate executable name
    if (!SecurityValidator.isArgumentSafe(args[0]))
    {
        throw new Exception("SECURITY: Unsafe command executable detected: " ~ args[0]);
    }
    
    // Security Layer 2: Validate all arguments
    foreach (i, arg; args[1 .. $])
    {
        // Check for command injection patterns
        if (!SecurityValidator.isArgumentSafe(arg))
        {
            throw new Exception("SECURITY: Unsafe argument detected at position " ~ 
                              to!string(i + 1) ~ ": " ~ arg);
        }
        
        // If argument contains path separators, validate as path
        if (arg.canFind('/') || arg.canFind('\\'))
        {
            // Allow flags starting with - even if they contain slashes
            if (!arg.startsWith("-") && !arg.startsWith("--"))
            {
                if (!SecurityValidator.isPathSafe(arg))
                {
                    throw new Exception("SECURITY: Unsafe path detected in argument: " ~ arg);
                }
            }
        }
    }
    
    // Security Layer 3: Validate working directory
    if (workDir !is null && workDir.length > 0)
    {
        if (!SecurityValidator.isPathSafe(workDir.idup))
        {
            throw new Exception("SECURITY: Unsafe working directory: " ~ workDir.idup);
        }
        
        // Additional check for system directories
        version(Posix)
        {
            immutable systemDirs = ["/etc", "/proc", "/sys", "/dev", "/boot", "/root"];
            foreach (sysDir; systemDirs)
            {
                if (workDir == sysDir || workDir.startsWith(sysDir ~ "/"))
                {
                    throw new Exception("SECURITY: Cannot execute in system directory: " ~ workDir.idup);
                }
            }
        }
    }
    
    // Security audit log (enabled via environment variable BUILDER_AUDIT_EXEC=1)
    version(BUILDER_AUDIT)
    {
        Logger.debugLog("[SECURITY AUDIT] execute: " ~ args.join(" "));
        if (workDir !is null && workDir.length > 0)
            Logger.debugLog("[SECURITY AUDIT]   workDir: " ~ workDir);
    }
    
    // All validation passed - execute command safely
    return std.process.execute(args, env, config, maxOutput, workDir);
}

/// Execute command in working directory with validation
@trusted
auto execute(
    scope const(string)[] args,
    scope const(char)[] workDir,
    bool skipValidation = false
)
{
    return execute(args, null, Config.none, size_t.max, workDir, skipValidation);
}

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

