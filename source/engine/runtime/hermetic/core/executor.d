module engine.runtime.hermetic.core.executor;

import std.process : execute, Config;
import std.file : exists, mkdirRecurse, tempDir;
import std.path : buildPath, absolutePath;
import std.datetime : Duration;
import std.conv : to;
import std.range : empty;
import engine.runtime.hermetic.core.spec;
import engine.runtime.hermetic.security.audit;
import infrastructure.errors;

// Platform-specific imports
version(linux)
{
    import engine.runtime.hermetic.platforms.linux;
}
version(OSX)
{
    import engine.runtime.hermetic.platforms.macos;
}
version(Windows)
{
    import engine.runtime.hermetic.platforms.windows;
}

/// Unified hermetic execution interface
/// Provides platform-agnostic API for sandboxed execution
/// 
/// Design: Factory pattern with platform-specific backends
/// - Linux: namespace-based isolation
/// - macOS: sandbox-exec with SBPL
/// - Windows: (future) job objects
/// - Fallback: basic process execution with validation
struct HermeticExecutor
{
    private SandboxSpec spec;
    private string workDir;
    private bool initialized;
    
    /// Create hermetic executor from spec
    static Result!(HermeticExecutor, BuildError) create(SandboxSpec spec, string workDir = "") @system
    {
        // Validate spec
        auto validateResult = spec.validate();
        if (validateResult.isErr)
            return Result!(HermeticExecutor, BuildError).err(
                new SystemError(validateResult.unwrapErr(), ErrorCode.InvalidConfiguration));
        
        HermeticExecutor executor;
        executor.spec = spec;
        
        // Setup work directory
        if (workDir.empty)
        {
            import std.random : uniform;
            import std.uuid : randomUUID;
            executor.workDir = buildPath(tempDir(), "builder-hermetic", randomUUID().toString());
        }
        else
        {
            executor.workDir = absolutePath(workDir);
        }
        
        // Ensure work directory exists
        try
        {
            if (!exists(executor.workDir))
                mkdirRecurse(executor.workDir);
        }
        catch (Exception e)
        {
            return Result!(HermeticExecutor, BuildError).err(
                ioError(executor.workDir, "Failed to create work directory: " ~ e.msg));
        }
        
        executor.initialized = true;
        return Result!(HermeticExecutor, BuildError).ok(executor);
    }
    
    /// Execute command hermetically
    Result!(Output, BuildError) execute(string[] command, string workingDir = "") @system
    {
        if (!initialized)
            return Result!(Output, BuildError).err(
                new SystemError("Executor not initialized", ErrorCode.NotInitialized));
        
        if (command.length == 0)
            return Result!(Output, BuildError).err(
                new SystemError("Empty command", ErrorCode.InvalidInput));
        
        // Use working dir or current dir
        immutable execDir = workingDir.empty ? workDir : workingDir;
        
        // Ensure working directory is in allowed paths
        if (!spec.canRead(execDir) && !spec.canWrite(execDir))
        {
            // Note: Optional audit logging disabled (auditLogger not passed to function)
            // TODO: Pass audit logger parameter if needed
            
            return Result!(Output, BuildError).err(
                new SystemError("Working directory not in allowed paths: " ~ execDir, 
                              ErrorCode.PermissionDenied));
        }
        
        // Select platform-specific backend
        version(linux)
        {
            return executeLinux(command, execDir);
        }
        else version(OSX)
        {
            return executeMacOS(command, execDir);
        }
        else version(Windows)
        {
            return executeWindows(command, execDir);
        }
        else
        {
            return executeFallback(command, execDir);
        }
    }
    
    /// Execute with timeout
    Result!(Output, BuildError) executeWithTimeout(string[] command, Duration timeout, string workingDir = "") @system
    {
        import engine.runtime.hermetic.security.timeout : createTimeoutEnforcer;
        
        if (!initialized)
            return Result!(Output, BuildError).err(
                new SystemError("Executor not initialized", ErrorCode.NotInitialized));
        
        if (command.length == 0)
            return Result!(Output, BuildError).err(
                new SystemError("Empty command", ErrorCode.InvalidInput));
        
        // Create timeout enforcer
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
        
        // Execute command
        auto result = execute(command, workingDir);
        
        // Check if timed out
        if (timeoutEnforcer.isTimedOut())
        {
            return Result!(Output, BuildError).err(
                new SystemError("Execution timed out after " ~ timeout.toString(), 
                              ErrorCode.ProcessTimeout));
        }
        
        return result;
    }
    
    /// Get sandbox specification
    const(SandboxSpec) getSpec() @safe const pure nothrow
    {
        return spec;
    }
    
    /// Check if platform supports hermetic builds
    static bool isSupported() @safe pure nothrow
    {
        version(linux)
            return true;
        else version(OSX)
            return true;
        else
            return false;
    }
    
    /// Get platform name
    static string platform() @safe pure nothrow
    {
        version(linux)
            return "linux-namespaces";
        else version(OSX)
            return "macos-sandbox";
        else version(Windows)
            return "windows-job";
        else
            return "fallback";
    }
    
    version(linux)
    {
        /// Execute using Linux namespaces
        private Result!(Output, BuildError) executeLinux(string[] command, string workingDir) @system
        {
            auto sandboxResult = LinuxSandbox.create(spec, workDir);
            if (sandboxResult.isErr)
                return Result!(Output, BuildError).err(
                    new SystemError(sandboxResult.unwrapErr(), ErrorCode.SandboxError));
            
            auto sandbox = sandboxResult.unwrap();
            auto execResult = sandbox.execute(command, workingDir);
            
            if (execResult.isErr)
                return Result!(Output, BuildError).err(
                    new SystemError(execResult.unwrapErr(), ErrorCode.ProcessSpawnFailed));
            
            auto linuxOutput = execResult.unwrap();
            Output output;
            output.stdout = linuxOutput.stdout;
            output.stderr = linuxOutput.stderr;
            output.exitCode = linuxOutput.exitCode;
            output.hermetic = true;
            
            return Result!(Output, BuildError).ok(output);
        }
    }
    
    version(OSX)
    {
        /// Execute using macOS sandbox-exec
        private Result!(Output, BuildError) executeMacOS(string[] command, string workingDir) @system
        {
            auto sandboxResult = MacOSSandbox.create(spec);
            if (sandboxResult.isErr)
                return Result!(Output, BuildError).err(
                    new SystemError(sandboxResult.unwrapErr(), ErrorCode.SandboxError));
            
            auto sandbox = sandboxResult.unwrap();
            auto execResult = sandbox.execute(command, workingDir);
            
            if (execResult.isErr)
                return Result!(Output, BuildError).err(
                    new SystemError(execResult.unwrapErr(), ErrorCode.ProcessSpawnFailed));
            
            auto macOutput = execResult.unwrap();
            Output output;
            output.stdout = macOutput.stdout;
            output.stderr = macOutput.stderr;
            output.exitCode = macOutput.exitCode;
            output.hermetic = true;
            
            return Result!(Output, BuildError).ok(output);
        }
    }
    
    version(Windows)
    {
        /// Execute using Windows job objects
        private Result!(Output, BuildError) executeWindows(string[] command, string workingDir) @system
        {
            auto sandboxResult = WindowsSandbox.create(spec, workDir);
            if (sandboxResult.isErr)
                return Result!(Output, BuildError).err(
                    new SystemError(sandboxResult.unwrapErr(), ErrorCode.SandboxError));
            
            auto sandbox = sandboxResult.unwrap();
            auto execResult = sandbox.execute(command, workingDir);
            
            if (execResult.isErr)
                return Result!(Output, BuildError).err(
                    new SystemError(execResult.unwrapErr(), ErrorCode.ProcessSpawnFailed));
            
            auto winOutput = execResult.unwrap();
            Output output;
            output.stdout = winOutput.stdout;
            output.stderr = winOutput.stderr;
            output.exitCode = winOutput.exitCode;
            output.hermetic = false;  // Windows implementation is partial
            
            return Result!(Output, BuildError).ok(output);
        }
    }
    
    /// Fallback execution (no sandboxing, validation only)
    private Result!(Output, BuildError) executeFallback(string[] command, string workingDir) @system
    {
        import infrastructure.utils.security.validation : SecurityValidator;
        
        // Validate command
        foreach (arg; command)
        {
            if (!SecurityValidator.isArgumentSafe(arg))
                return Result!(Output, BuildError).err(
                    new SystemError("Unsafe command argument: " ~ arg, 
                                  ErrorCode.InvalidInput));
        }
        
        // Build environment
        auto env = spec.environment.toMap();
        
        // Execute without sandboxing
        try
        {
            auto result = .execute(command, env, Config.none, size_t.max, workingDir);
            
            Output output;
            output.stdout = result.output;
            output.stderr = "";
            output.exitCode = result.status;
            output.hermetic = false;  // Not truly hermetic
            
            return Result!(Output, BuildError).ok(output);
        }
        catch (Exception e)
        {
            return Result!(Output, BuildError).err(
                processExecutionError(command[0], 1, "Execution failed: " ~ e.msg));
        }
    }
}

/// Execution output
struct Output
{
    string stdout;
    string stderr;
    int exitCode;
    bool hermetic;  // Was execution truly hermetic?
    string[] outputFiles;  // Paths to output files produced
    
    /// Check if execution succeeded
    bool success() @safe const pure nothrow
    {
        return exitCode == 0;
    }
}

/// Builder for common sandbox specifications
struct HermeticSpecBuilder
{
    /// Create spec for typical build (read sources, write outputs)
    static Result!(SandboxSpec, BuildError) forBuild(
        string workspaceRoot,
        string[] sources,
        string outputDir,
        string tempDir
    ) @system
    {
        auto builder = SandboxSpecBuilder.create();
        
        // Add workspace as input (read source files)
        builder.input(workspaceRoot);
        
        // Add output directory
        builder.output(outputDir);
        
        // Add temp directory
        builder.temp(tempDir);
        
        // Add standard library paths (read-only)
        version(linux)
        {
            builder.input("/usr/lib");
            builder.input("/usr/include");
            builder.input("/lib");
            builder.input("/lib64");
        }
        version(OSX)
        {
            builder.input("/usr/lib");
            builder.input("/usr/include");
            builder.input("/System/Library");
            builder.input("/Library");
        }
        
        // Hermetic network (no access)
        builder.withNetwork(NetworkPolicy.hermetic());
        
        // Add minimal environment
        builder.env("PATH", "/usr/bin:/bin");
        builder.env("LANG", "C.UTF-8");
        
        auto result = builder.build();
        if (result.isErr)
            return Result!(SandboxSpec, BuildError).err(
                new SystemError(result.unwrapErr(), ErrorCode.InvalidConfiguration));
        return Result!(SandboxSpec, BuildError).ok(result.unwrap());
    }
    
    /// Create spec for test execution
    static Result!(SandboxSpec, BuildError) forTest(
        string workspaceRoot,
        string testDir,
        string tempDir
    ) @system
    {
        auto builder = SandboxSpecBuilder.create();
        
        // Tests can read workspace
        builder.input(workspaceRoot);
        
        // Tests can write to temp
        builder.temp(tempDir);
        
        // Add standard library paths
        version(linux)
        {
            builder.input("/usr/lib");
            builder.input("/lib");
        }
        version(OSX)
        {
            builder.input("/usr/lib");
            builder.input("/System/Library");
        }
        
        // Tests might need network (less strict)
        auto networkPolicy = NetworkPolicy.hermetic();
        builder.withNetwork(networkPolicy);
        
        // Standard environment
        builder.env("PATH", "/usr/bin:/bin");
        builder.env("LANG", "C.UTF-8");
        
        auto result = builder.build();
        if (result.isErr)
            return Result!(SandboxSpec, BuildError).err(
                new SystemError(result.unwrapErr(), ErrorCode.InvalidConfiguration));
        return Result!(SandboxSpec, BuildError).ok(result.unwrap());
    }
}

// Result type imported from errors module

@system unittest
{
    import std.stdio : writeln;
    
    writeln("Testing hermetic executor...");
    
    // Test spec creation
    auto specResult = HermeticSpecBuilder.forBuild(
        "/tmp/workspace",
        ["/tmp/workspace/main.d"],
        "/tmp/output",
        "/tmp/temp"
    );
    
    assert(specResult.isOk, "Failed to create spec: " ~ specResult.unwrapErr().toString());
    
    // Test executor creation
    auto executorResult = HermeticExecutor.create(specResult.unwrap());
    assert(executorResult.isOk, "Failed to create executor");
    
    writeln("Hermetic executor platform: ", HermeticExecutor.platform());
    writeln("Hermetic builds supported: ", HermeticExecutor.isSupported());
}

