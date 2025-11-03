module engine.runtime.hermetic.platforms.macos;

version(OSX):

import std.process : execute, Config;
import std.file : exists, mkdirRecurse, write, remove, tempDir;
import std.path : buildPath;
import std.string : join, replace;
import std.conv : to;
import std.algorithm : map;
import std.array : array;
import engine.runtime.hermetic.core.spec;
import infrastructure.errors;

/// macOS sandbox-exec based sandboxing
/// Uses Sandbox Profile Language (SBPL) for declarative security
/// 
/// Design: Generates SBPL profiles that define allowed operations
/// SBPL is a scheme-like language that uses deny-by-default model:
/// - All operations denied unless explicitly allowed
/// - Uses pattern matching for paths and operations
/// - Compiles to kernel sandbox rules
/// 
/// This provides strong sandboxing on macOS without requiring root
struct MacOSSandbox
{
    private SandboxSpec spec;
    private string profilePath;
    
    /// Create sandbox from spec
    static Result!MacOSSandbox create(SandboxSpec spec_) @system
    {
        MacOSSandbox sandbox;
        sandbox.spec = spec_;
        
        // Generate sandbox profile
        auto profileResult = sandbox.generateProfile();
        if (profileResult.isErr)
            return Result!MacOSSandbox.err(profileResult.unwrapErr());
        
        sandbox.profilePath = profileResult.unwrap();
        
        return Result!MacOSSandbox.ok(sandbox);
    }
    
    /// Execute command in sandbox
    Result!ExecutionOutput execute(string[] command, string workingDir) @system
    {
        // Build sandbox-exec command
        string[] sandboxCmd = [
            "sandbox-exec",
            "-f", profilePath
        ];
        
        sandboxCmd ~= command;
        
        // Build environment
        auto env = spec.environment.toMap();
        
        // Execute with sandbox
        try
        {
            auto result = .execute(sandboxCmd, env, Config.none, size_t.max, workingDir);
            
            ExecutionOutput output;
            output.stdout = result.output;
            output.stderr = "";  // sandbox-exec mixes stdout/stderr
            output.exitCode = result.status;
            
            // Cleanup profile
            cleanup();
            
            return Result!ExecutionOutput.ok(output);
        }
        catch (Exception e)
        {
            cleanup();
            return Result!ExecutionOutput.err("Execution failed: " ~ e.msg);
        }
    }
    
    /// Generate SBPL profile from spec
    private Result!string generateProfile() @system
    {
        import std.random : uniform;
        import std.uuid : randomUUID;
        
        // Create temp profile file
        immutable profileDir = buildPath(tempDir(), "builder-sandbox");
        if (!exists(profileDir))
        {
            try
            {
                mkdirRecurse(profileDir);
            }
            catch (Exception e)
            {
                return Result!string.err("Failed to create profile dir: " ~ e.msg);
            }
        }
        
        immutable profilePath = buildPath(profileDir, randomUUID().toString() ~ ".sb");
        
        // Generate SBPL content
        auto profile = generateSBPL();
        
        try
        {
            write(profilePath, profile);
        }
        catch (Exception e)
        {
            return Result!string.err("Failed to write profile: " ~ e.msg);
        }
        
        return Result!string.ok(profilePath);
    }
    
    /// Generate SBPL (Sandbox Profile Language) content
    private string generateSBPL() @safe const
    {
        string[] rules;
        
        // Start with strict deny-by-default
        rules ~= "(version 1)";
        rules ~= "(deny default)";
        
        // Allow basic process operations
        rules ~= "(allow process-fork)";
        rules ~= "(allow process-exec";
        rules ~= "  (literal \"/usr/bin/true\")";
        rules ~= "  (literal \"/bin/sh\")";
        rules ~= "  (literal \"/usr/bin/env\"))";
        
        // Allow signal operations
        rules ~= "(allow signal)";
        rules ~= "(allow sysctl-read)";
        
        // Allow reading from input paths
        foreach (inPath; spec.inputs.paths)
        {
            rules ~= "(allow file-read*";
            rules ~= "  (subpath \"" ~ escapePath(inPath) ~ "\"))";
        }
        
        // Allow writing to output paths
        foreach (outPath; spec.outputs.paths)
        {
            rules ~= "(allow file-write*";
            rules ~= "  (subpath \"" ~ escapePath(outPath) ~ "\"))";
        }
        
        // Allow read-write for temp paths
        foreach (tempPath; spec.temps.paths)
        {
            rules ~= "(allow file-read* file-write*";
            rules ~= "  (subpath \"" ~ escapePath(tempPath) ~ "\"))";
        }
        
        // Network policy
        if (spec.network.isHermetic)
        {
            // Deny all network operations
            rules ~= "(deny network*)";
        }
        else
        {
            // Allow network based on policy
            if (spec.network.allowHttp || spec.network.allowHttps)
            {
                rules ~= "(allow network-outbound";
                
                if (spec.network.allowedHosts.length > 0)
                {
                    foreach (host; spec.network.allowedHosts)
                    {
                        rules ~= "  (remote tcp \"" ~ host ~ ":*\"))";
                    }
                }
                else
                {
                    rules ~= "  (remote tcp))";
                }
            }
            
            if (spec.network.allowDns)
            {
                rules ~= "(allow network-outbound";
                rules ~= "  (remote udp \"*:53\"))";
            }
        }
        
        // Allow essential system paths (read-only)
        rules ~= "(allow file-read*";
        rules ~= "  (subpath \"/usr/lib\")";
        rules ~= "  (subpath \"/usr/share\")";
        rules ~= "  (subpath \"/System/Library\")";
        rules ~= "  (subpath \"/Library\")";
        rules ~= "  (literal \"/dev/null\")";
        rules ~= "  (literal \"/dev/random\")";
        rules ~= "  (literal \"/dev/urandom\"))";
        
        // Allow mach operations (required for many tools)
        rules ~= "(allow mach-lookup)";
        rules ~= "(allow mach-register)";
        
        // Allow IPC with restrictions
        rules ~= "(allow ipc-posix-shm-read-data)";
        rules ~= "(allow ipc-posix-shm-write-data)";
        
        // Deny dangerous operations explicitly
        rules ~= "(deny file-write*";
        rules ~= "  (subpath \"/etc\")";
        rules ~= "  (subpath \"/var\")";
        rules ~= "  (subpath \"/tmp\"))";
        
        return rules.join("\n");
    }
    
    /// Escape path for SBPL
    private static string escapePath(string path) @safe pure
    {
        return path.replace("\\", "\\\\").replace("\"", "\\\"");
    }
    
    /// Cleanup profile file
    private void cleanup() @system nothrow
    {
        if (profilePath.length > 0 && exists(profilePath))
        {
            try
            {
                remove(profilePath);
            }
            catch (Exception) {}
        }
    }
}

/// Execution output
struct ExecutionOutput
{
    string stdout;
    string stderr;
    int exitCode;
}

/// Result type
private struct Result(T)
{
    private bool _isOk;
    private T _value;
    private string _error;
    
    static Result ok(T val) @safe
    {
        Result r;
        r._isOk = true;
        r._value = val;
        return r;
    }
    
    static Result ok() @safe
    {
        Result r;
        r._isOk = true;
        return r;
    }
    
    static Result err(string error) @safe
    {
        Result r;
        r._isOk = false;
        r._error = error;
        return r;
    }
    
    bool isOk() @safe const pure nothrow { return _isOk; }
    bool isErr() @safe const pure nothrow { return !_isOk; }
    
    T unwrap() @safe
    {
        if (!_isOk)
            throw new Exception("Result error: " ~ _error);
        return _value;
    }
    
    string unwrapErr() @safe const
    {
        if (_isOk)
            throw new Exception("Result is ok");
        return _error;
    }
}

@system unittest
{
    // Test profile generation
    auto spec = SandboxSpecBuilder.create()
        .input("/usr/lib")
        .output("/tmp/output")
        .temp("/tmp/work")
        .build();
    
    assert(spec.isOk);
    
    auto sandboxResult = MacOSSandbox.create(spec.unwrap());
    assert(sandboxResult.isOk);
    
    auto sandbox = sandboxResult.unwrap();
    auto profile = sandbox.generateSBPL();
    
    assert(profile.length > 0);
    assert(profile.canFind("(version 1)"));
    assert(profile.canFind("(deny default)"));
    assert(profile.canFind("/usr/lib"));
}

