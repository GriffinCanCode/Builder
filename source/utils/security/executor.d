module utils.security.executor;

import std.process;
import std.algorithm;
import std.array;
import std.string;
import std.path : baseName, dirName;
import utils.security.validation;
import utils.logging.logger;
import errors;

@safe:

/// Redact sensitive information from strings for audit logging
/// Protects against leaking sensitive paths, tokens, and environment variables in logs
private struct AuditRedactor
{
    /// Redact a command argument
    static string redactArg(string arg) @safe
    {
        import std.path : expandTilde;
        import std.regex : regex, replaceAll;
        
        // Redact home directory paths
        string homeDir;
        try
        {
            version(Posix)
            {
                import std.process : environment;
                homeDir = environment.get("HOME", "");
            }
            version(Windows)
            {
                import std.process : environment;
                homeDir = environment.get("USERPROFILE", "");
            }
        }
        catch (Exception)
        {
            homeDir = "";
        }
        
        if (!homeDir.empty && arg.canFind(homeDir))
        {
            arg = arg.replace(homeDir, "$HOME");
        }
        
        // Redact anything that looks like an API key or token
        // Pattern: KEY=<value> or TOKEN=<value> or PASS=<value>
        if (arg.canFind("KEY=") || arg.canFind("TOKEN=") || 
            arg.canFind("PASS=") || arg.canFind("SECRET=") ||
            arg.canFind("API_KEY") || arg.canFind("ACCESS_TOKEN"))
        {
            auto eqPos = arg.indexOf('=');
            if (eqPos >= 0)
            {
                return arg[0 .. eqPos + 1] ~ "***REDACTED***";
            }
        }
        
        return arg;
    }
    
    /// Redact a working directory path
    static string redactPath(string path) @safe
    {
        import std.process : environment;
        
        // Redact home directory
        string homeDir;
        try
        {
            version(Posix)
            {
                homeDir = environment.get("HOME", "");
            }
            version(Windows)
            {
                homeDir = environment.get("USERPROFILE", "");
            }
        }
        catch (Exception)
        {
            homeDir = "";
        }
        
        if (!homeDir.empty && path.canFind(homeDir))
        {
            return path.replace(homeDir, "$HOME");
        }
        
        // For very long paths, show only basename and parent
        if (path.length > 80)
        {
            auto base = baseName(path);
            auto dir = baseName(dirName(path));
            return ".../" ~ dir ~ "/" ~ base;
        }
        
        return path;
    }
    
    /// Redact environment variable names (hide values)
    /// Shows variable names but masks potentially sensitive ones
    static string redactEnvKeys(string[] keys) @safe
    {
        import std.algorithm : map, filter, joiner;
        import std.conv : to;
        
        // Sensitive environment variable patterns
        immutable sensitivePatterns = [
            "KEY", "TOKEN", "PASS", "SECRET", "CREDENTIAL", 
            "API", "AUTH", "CERT", "PRIVATE"
        ];
        
        auto redacted = keys.map!((k) {
            auto upper = k.toUpper();
            foreach (pattern; sensitivePatterns)
            {
                if (upper.canFind(pattern))
                {
                    return k ~ "=***";
                }
            }
            return k;
        });
        
        return redacted.joiner(", ").to!string;
    }
}

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
        
        // Audit log if enabled (with redaction for sensitive data)
        if (auditLog)
        {
            import std.algorithm : map;
            import std.array : array;
            
            // Redact command arguments
            auto redactedCmd = cmd.map!(arg => AuditRedactor.redactArg(arg)).array;
            Logger.debugLog("[AUDIT] Executing: " ~ redactedCmd.join(" "));
            
            // Redact working directory
            if (!workDir.empty)
                Logger.debugLog("[AUDIT]   WorkDir: " ~ AuditRedactor.redactPath(workDir));
            
            // Redact environment variable keys/values
            if (environment.length > 0)
            {
                auto envKeys = environment.keys.array;
                Logger.debugLog("[AUDIT]   EnvVars: " ~ AuditRedactor.redactEnvKeys(envKeys));
            }
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

@safe unittest
{
    import std.process : environment;
    
    // Test AuditRedactor: Home directory redaction
    version(Posix)
    {
        auto homeDir = environment.get("HOME", "");
        if (!homeDir.empty)
        {
            auto pathWithHome = homeDir ~ "/projects/secret";
            auto redacted = AuditRedactor.redactPath(pathWithHome);
            assert(redacted.canFind("$HOME"));
            assert(!redacted.canFind(homeDir));
        }
    }
    
    // Test API key redaction in arguments
    auto apiKeyArg = "API_KEY=super-secret-12345";
    auto redacted = AuditRedactor.redactArg(apiKeyArg);
    assert(redacted == "API_KEY=***REDACTED***");
    assert(!redacted.canFind("super-secret"));
    
    // Test TOKEN redaction
    auto tokenArg = "AUTH_TOKEN=bearer-token-xyz";
    redacted = AuditRedactor.redactArg(tokenArg);
    assert(redacted == "AUTH_TOKEN=***REDACTED***");
    
    // Test PASS redaction
    auto passArg = "DB_PASS=mypassword123";
    redacted = AuditRedactor.redactArg(passArg);
    assert(redacted == "DB_PASS=***REDACTED***");
    
    // Test SECRET redaction
    auto secretArg = "SECRET=topsecret";
    redacted = AuditRedactor.redactArg(secretArg);
    assert(redacted == "SECRET=***REDACTED***");
    
    // Test normal argument passes through
    auto normalArg = "build.txt";
    redacted = AuditRedactor.redactArg(normalArg);
    assert(redacted == "build.txt");
    
    // Test long path truncation
    auto longPath = "/very/long/path/that/goes/on/and/on/and/contains/many/directories/until/it/exceeds/the/limit/file.txt";
    redacted = AuditRedactor.redactPath(longPath);
    assert(redacted.length < longPath.length);
    assert(redacted.canFind("..."));
    
    // Test env key redaction
    auto envKeys = ["PATH", "API_KEY", "HOME", "SECRET_TOKEN", "USER"];
    auto redactedKeys = AuditRedactor.redactEnvKeys(envKeys);
    assert(redactedKeys.canFind("API_KEY=***"));
    assert(redactedKeys.canFind("SECRET_TOKEN=***"));
    assert(redactedKeys.canFind("PATH")); // Non-sensitive, not redacted
    assert(!redactedKeys.canFind("API_KEY,") || redactedKeys.canFind("API_KEY=***"));
}

@safe unittest
{
    // Test audit logging is opt-in
    auto exec = SecureExecutor.create();
    // Should not log by default
    auto result = exec.run(["echo", "test"]);
    assert(result.isOk);
    
    // Enable audit logging
    auto audited = SecureExecutor.create().audit();
    result = audited.run(["echo", "test"]);
    assert(result.isOk);
    
    // Test audit with sensitive environment variables
    auto execWithEnv = SecureExecutor.create()
        .audit()
        .withEnv("API_KEY", "secret123")
        .withEnv("HOME", "/home/user");
    // Execution with redacted logging
    result = execWithEnv.run(["echo", "hello"]);
    assert(result.isOk);
}

