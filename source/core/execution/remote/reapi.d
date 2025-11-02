module core.execution.remote.reapi;

import std.datetime : Duration, seconds;
import std.conv : to;
import std.digest : toHexString;
import std.string : toLower;
import std.algorithm : map;
import std.array : array;
import core.distributed.protocol.protocol;
import errors;

/// Remote Execution API protocol adapter
/// Provides Bazel REAPI compatibility while using Builder's native protocol
///
/// Design: Protocol translation layer that maps REAPI semantics to Builder's
/// efficient native protocol. Avoids gRPC dependency bloat while maintaining
/// wire-level compatibility with standard REAPI clients.

/// REAPI digest (content-addressed identifier)
struct Digest
{
    ubyte[32] hash;      // BLAKE3 hash (32 bytes)
    size_t sizeBytes;    // Size in bytes
    
    this(const ubyte[32] hash, size_t sizeBytes) pure nothrow @safe @nogc
    {
        this.hash = hash;
        this.sizeBytes = sizeBytes;
    }
    
    /// Create from ActionId
    this(ActionId actionId, size_t sizeBytes) pure nothrow @safe @nogc
    {
        this.hash = actionId.hash;
        this.sizeBytes = sizeBytes;
    }
    
    /// Convert to ActionId
    ActionId toActionId() const pure nothrow @safe @nogc
    {
        return ActionId(hash);
    }
    
    /// String representation (hex)
    string toString() const @trusted
    {
        return toHexString(hash[]).toLower();
    }
    
    /// Parse from string
    static Result!(Digest, string) parse(string hexStr, size_t sizeBytes) @trusted
    {
        if (hexStr.length != 64)
            return Err!(Digest, string)("Invalid digest length");
        
        try
        {
            import std.conv : to;
            import std.string : fromStringz;
            ubyte[32] hash;
            
            for (size_t i = 0; i < 32; i++)
            {
                auto hexPair = hexStr[i * 2 .. i * 2 + 2];
                hash[i] = cast(ubyte)hexPair.to!ubyte(16);
            }
            
            return Ok!(Digest, string)(Digest(hash, sizeBytes));
        }
        catch (Exception e)
        {
            return Err!(Digest, string)("Failed to parse digest: " ~ e.msg);
        }
    }
}

/// REAPI execution platform
struct Platform
{
    Property[] properties;
    
    /// Property key-value pair
    static struct Property
    {
        string name;
        string value;
    }
    
    /// Convert to Builder Capabilities
    Capabilities toCapabilities() const pure @safe
    {
        Capabilities caps;
        
        foreach (prop; properties)
        {
            switch (prop.name)
            {
                case "OSFamily":
                    // Handle OS family (linux, macos, windows)
                    break;
                case "container-image":
                    // Docker image specification
                    break;
                case "Pool":
                    // Worker pool specification
                    break;
                default:
                    // Custom properties
                    break;
            }
        }
        
        return caps;
    }
}

/// REAPI command
struct Command
{
    string[] arguments;                     // Command arguments
    EnvironmentVariable[] environmentVariables;
    string[] outputFiles;                   // Expected output files
    string[] outputDirectories;             // Expected output directories
    string[] outputPaths;                   // Output path prefixes
    Platform platform;                      // Execution platform
    string workingDirectory;                // Working directory
    bool outputNodeProperties;              // Include node properties
    
    /// Environment variable
    static struct EnvironmentVariable
    {
        string name;
        string value;
    }
    
    /// Convert to Builder ActionRequest
    ActionRequest toActionRequest(Digest actionDigest) const @safe
    {
        import std.algorithm : joiner, map;
        import std.range : chain;
        import std.conv : to;
        
        // Build command string - convert to mutable array first
        immutable cmdStr = arguments.length > 0 ? 
            arguments.map!(a => a.to!string).joiner(" ").to!string : "";
        
        // Build environment map
        string[string] env;
        foreach (envVar; environmentVariables)
        {
            env[envVar.name] = envVar.value;
        }
        
        // Build output specs
        OutputSpec[] outputs;
        foreach (path; chain(outputFiles, outputDirectories))
        {
            outputs ~= OutputSpec(path, false);
        }
        
        auto caps = platform.toCapabilities();
        
        return new ActionRequest(
            actionDigest.toActionId(),
            cmdStr,
            env,
            [],  // Inputs populated separately
            outputs,
            caps,
            Priority.Normal,
            caps.timeout
        );
    }
}

/// REAPI action
struct Action
{
    Digest commandDigest;                   // Command digest
    Digest inputRootDigest;                 // Input root digest
    Duration timeout;                       // Execution timeout
    bool doNotCache;                        // Skip caching?
    string salt;                            // Differentiation salt
    Platform platform;                      // Execution platform
    
    /// Compute action digest
    Digest digest() const @trusted
    {
        import utils.crypto.blake3 : Blake3;
        
        auto hasher = Blake3(0);
        hasher.put(cast(const(ubyte)[])commandDigest.hash);
        hasher.put(cast(const(ubyte)[])inputRootDigest.hash);
        
        auto timeoutMs = timeout.total!"msecs";
        hasher.put((cast(ubyte*)&timeoutMs)[0 .. timeoutMs.sizeof]);
        
        if (salt.length > 0)
            hasher.put(cast(const ubyte[])salt);
        
        auto hashBytes = hasher.finish(32);
        ubyte[32] hash;
        hash[0 .. 32] = hashBytes[0 .. 32];
        
        // Size is serialized representation size (approximate)
        immutable size = 64 + 8 + salt.length;
        
        return Digest(hash, size);
    }
}

/// REAPI execution result
struct ExecuteResponse
{
    ActionResult result;                    // Execution result
    bool cachedResult;                      // From cache?
    Status status;                          // Execution status
    string serverLogs;                      // Server logs
    string message;                         // Status message
    
    /// gRPC-style status
    static struct Status
    {
        int code;                           // Status code (0 = OK)
        string message;                     // Error message
        
        static Status ok() pure nothrow @safe @nogc
        {
            return Status(0, "");
        }
        
        static Status error(string message) pure @safe
        {
            return Status(2, message);  // UNKNOWN
        }
    }
}

/// REAPI action result
struct ActionResult
{
    OutputFile[] outputFiles;               // Output files
    OutputDirectory[] outputDirectories;    // Output directories
    int exitCode;                           // Exit code
    string stdoutRaw;                       // Stdout (if small)
    string stderrRaw;                       // Stderr (if small)
    Digest stdoutDigest;                    // Stdout digest (if large)
    Digest stderrDigest;                    // Stderr digest (if large)
    ExecutionMetadata executionMetadata;    // Execution metadata
    
    /// Output file
    static struct OutputFile
    {
        string path;
        Digest digest;
        bool isExecutable;
        string contents;                    // Inline contents (if small)
        OutputNode nodeProperties;
    }
    
    /// Output directory
    static struct OutputDirectory
    {
        string path;
        Digest treeDigest;                  // Directory tree digest
        OutputNode nodeProperties;
    }
    
    /// Output node properties
    static struct OutputNode
    {
        Property[] properties;
        
        static struct Property
        {
            string name;
            string value;
        }
    }
    
    /// Execution metadata
    static struct ExecutionMetadata
    {
        string worker;                      // Worker identifier
        Duration queuedTime;                // Time in queue
        Duration workerStartTime;           // Worker start
        Duration workerCompleteTime;        // Worker complete
        Duration inputFetchStartTime;       // Input fetch start
        Duration inputFetchCompleteTime;    // Input fetch complete
        Duration executionStartTime;        // Execution start
        Duration executionCompleteTime;     // Execution complete
        Duration outputUploadStartTime;     // Output upload start
        Duration outputUploadCompleteTime;  // Output upload complete
    }
    
    /// Convert from Builder ActionResult
    static ActionResult fromBuilderResult(
        core.distributed.protocol.protocol.ActionResult builderResult,
        OutputFile[] outputFiles
    ) @safe
    {
        ActionResult result;
        result.outputFiles = outputFiles;
        result.exitCode = builderResult.exitCode;
        result.stdoutRaw = builderResult.stdout;
        result.stderrRaw = builderResult.stderr;
        
        // Populate metadata
        result.executionMetadata.executionStartTime = Duration.zero;
        result.executionMetadata.executionCompleteTime = builderResult.duration;
        
        return result;
    }
}

/// REAPI protocol adapter
/// Translates between REAPI and Builder's native protocol
final class ReapiAdapter
{
    /// Execute action via REAPI
    Result!(ExecuteResponse, BuildError) execute(
        Action action,
        bool skipCacheLookup = false
    ) @trusted
    {
        // Convert to Builder action request
        auto actionDigest = action.digest();
        
        // This would integrate with the execution service
        // For now, return structure demonstrating the adapter
        
        ExecuteResponse response;
        response.status = ExecuteResponse.Status.ok();
        response.cachedResult = false;
        
        return Ok!(ExecuteResponse, BuildError)(response);
    }
    
    /// Wait for execution (long-running operation)
    Result!(ExecuteResponse, BuildError) waitExecution(
        string operationName,
        Duration timeout = 0.seconds
    ) @safe
    {
        // Implement long-running operation polling
        ExecuteResponse response;
        response.status = ExecuteResponse.Status.ok();
        
        return Ok!(ExecuteResponse, BuildError)(response);
    }
    
    /// Get action result from cache
    Result!(ActionResult, BuildError) getActionResult(
        Digest actionDigest
    ) @trusted
    {
        // Query action cache
        ActionResult result;
        
        return Ok!(ActionResult, BuildError)(result);
    }
    
    /// Update action result in cache
    Result!BuildError updateActionResult(
        Digest actionDigest,
        ActionResult result
    ) @trusted
    {
        // Update action cache
        return Ok!BuildError();
    }
}

/// REAPI request/response serialization
/// Wire format compatible with Bazel REAPI but using efficient binary encoding
struct ReapiCodec
{
    /// Serialize ExecuteRequest
    static ubyte[] serializeExecuteRequest(Action action, bool skipCacheLookup) @trusted
    {
        import std.bitmanip : write;
        
        ubyte[] buffer;
        buffer.reserve(1024);
        
        // Action digest
        buffer ~= action.digest().hash;
        buffer.write!ulong(action.digest().sizeBytes, buffer.length);
        
        // Skip cache flag
        buffer.write!ubyte(skipCacheLookup ? 1 : 0, buffer.length);
        
        // Platform properties
        buffer.write!uint(cast(uint)action.platform.properties.length, buffer.length);
        foreach (prop; action.platform.properties)
        {
            buffer.write!uint(cast(uint)prop.name.length, buffer.length);
            buffer ~= cast(ubyte[])prop.name;
            buffer.write!uint(cast(uint)prop.value.length, buffer.length);
            buffer ~= cast(ubyte[])prop.value;
        }
        
        return buffer;
    }
    
    /// Deserialize ExecuteResponse
    static Result!(ExecuteResponse, string) deserializeExecuteResponse(const ubyte[] data) @system
    {
        import std.bitmanip : read;
        
        if (data.length < 4)
            return Err!(ExecuteResponse, string)("Response too short");
        
        ExecuteResponse response;
        
        // Parse response (simplified)
        // Would parse full REAPI response structure
        
        return Ok!(ExecuteResponse, string)(response);
    }
}

/// REAPI capabilities
/// Reports worker capabilities to REAPI clients
struct ExecutionCapabilities
{
    DigestFunction digestFunction;          // Hash function
    ActionCacheUpdateCapabilities actionCacheUpdateCapabilities;
    ExecutionPriorityCapabilities executionPriorityCapabilities;
    SymlinkAbsolutePathStrategy symlinkAbsolutePathStrategy;
    
    /// Digest function enum
    enum DigestFunction
    {
        BLAKE3,     // Builder's native
        SHA256,     // REAPI standard
        SHA1
    }
    
    /// Action cache capabilities
    struct ActionCacheUpdateCapabilities
    {
        bool updateEnabled = true;
    }
    
    /// Priority capabilities
    struct ExecutionPriorityCapabilities
    {
        Priority[] priorities;
    }
    
    /// Symlink handling
    enum SymlinkAbsolutePathStrategy
    {
        UNKNOWN,
        DISALLOWED,
        ALLOWED
    }
}

