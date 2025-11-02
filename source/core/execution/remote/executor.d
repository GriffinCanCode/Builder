module core.execution.remote.executor;

import std.datetime : Duration, Clock, MonoTime, minutes;
import std.algorithm : map;
import std.array : array;
import std.conv : to;
import core.distributed.protocol.protocol;
import core.distributed.coordinator.coordinator;
import core.distributed.coordinator.scheduler;
import core.execution.hermetic;
import core.caching.distributed.remote.client;
import errors;
import utils.logging.logger;

/// Remote executor - executes actions on remote workers using native hermetic sandboxing
///
/// Design Philosophy:
/// - Ship SandboxSpec to workers (not containers)
/// - Workers use native OS sandboxing (namespaces/sandbox-exec/job objects)
/// - Zero container runtime overhead
/// - Leverage existing hermetic infrastructure
///
/// Flow:
/// 1. Build SandboxSpec from action
/// 2. Upload inputs to artifact store
/// 3. Send ActionRequest + SandboxSpec to worker
/// 4. Worker executes hermetically using native backend
/// 5. Worker uploads outputs to artifact store
/// 6. Return results

/// Remote execution configuration
struct RemoteExecutorConfig
{
    string coordinatorUrl;              // Coordinator endpoint
    string artifactStoreUrl;            // Artifact store endpoint
    bool enableCaching = true;          // Use action cache?
    bool enableCompression = true;      // Compress artifacts?
    size_t maxConcurrent = 100;         // Max concurrent executions
    Duration defaultTimeout = minutes(5);
}

/// Remote execution result
struct RemoteExecutionResult
{
    ActionId actionId;
    ResultStatus status;
    Duration duration;
    string stdout;
    string stderr;
    int exitCode;
    ResourceUsage resources;
    ArtifactId[] outputArtifacts;
    bool fromCache;
    WorkerId executedBy;
}

/// Remote executor
/// Orchestrates execution across worker pool using native hermetic sandboxing
final class RemoteExecutor
{
    private RemoteExecutorConfig config;
    private Coordinator coordinator;
    private RemoteCacheClient artifactStore;
    
    this(RemoteExecutorConfig config) @trusted
    {
        this.config = config;
        
        // Initialize artifact store client
        import core.caching.distributed.remote.protocol : RemoteCacheConfig;
        
        RemoteCacheConfig cacheConfig;
        cacheConfig.url = config.artifactStoreUrl;
        cacheConfig.enableCompression = config.enableCompression;
        
        this.artifactStore = new RemoteCacheClient(cacheConfig);
    }
    
    /// Execute action remotely
    Result!(RemoteExecutionResult, BuildError) execute(
        ActionId actionId,
        SandboxSpec spec,
        string[] command,
        string workDir
    ) @trusted
    {
        auto startTime = MonoTime.currTime;
        
        Logger.info("Remote execution: " ~ actionId.toString());
        
        // 1. Check action cache
        if (config.enableCaching)
        {
            auto cacheResult = checkActionCache(actionId);
            if (cacheResult.isOk)
            {
                auto cached = cacheResult.unwrap();
                Logger.info("Action cache hit: " ~ actionId.toString());
                return Ok!(RemoteExecutionResult, BuildError)(cached);
            }
        }
        
        // 2. Upload input artifacts
        auto uploadResult = uploadInputs(spec);
        if (uploadResult.isErr)
        {
            return Err!(RemoteExecutionResult, BuildError)(uploadResult.unwrapErr());
        }
        
        auto inputArtifacts = uploadResult.unwrap();
        
        // 3. Build action request with hermetic spec
        auto request = buildActionRequest(
            actionId,
            spec,
            command,
            inputArtifacts
        );
        
        // 4. Submit to coordinator for execution
        auto executeResult = submitToWorker(request);
        if (executeResult.isErr)
        {
            return Err!(RemoteExecutionResult, BuildError)(executeResult.unwrapErr());
        }
        
        auto builderResult = executeResult.unwrap();
        
        // 5. Download output artifacts
        auto downloadResult = downloadOutputs(builderResult.outputs);
        if (downloadResult.isErr)
        {
            return Err!(RemoteExecutionResult, BuildError)(downloadResult.unwrapErr());
        }
        
        // 6. Build result
        RemoteExecutionResult result;
        result.actionId = actionId;
        result.status = builderResult.status;
        result.duration = builderResult.duration;
        result.stdout = builderResult.stdout;
        result.stderr = builderResult.stderr;
        result.exitCode = builderResult.exitCode;
        result.resources = builderResult.resources;
        result.outputArtifacts = builderResult.outputs;
        result.fromCache = false;
        
        // 7. Cache result if successful
        if (config.enableCaching && result.status == ResultStatus.Success)
        {
            cacheActionResult(actionId, result);
        }
        
        immutable totalDuration = MonoTime.currTime - startTime;
        Logger.info("Remote execution completed in " ~ 
                   totalDuration.total!"msecs".to!string ~ "ms");
        
        return Ok!(RemoteExecutionResult, BuildError)(result);
    }
    
    /// Build action request from hermetic spec
    private ActionRequest buildActionRequest(
        ActionId actionId,
        SandboxSpec spec,
        string[] command,
        InputSpec[] inputs
    ) @safe
    {
        import std.algorithm : joiner;
        
        // Convert command array to shell command
        immutable cmdStr = command.joiner(" ").array.to!string;
        
        // Build output specs from hermetic spec
        OutputSpec[] outputs;
        foreach (outputPath; spec.outputs.paths)
        {
            outputs ~= OutputSpec(outputPath, false);
        }
        
        // Convert hermetic spec to capabilities
        auto caps = specToCapabilities(spec);
        
        // Build environment from EnvSet
        string[string] env = spec.environment.vars.dup;
        
        // Calculate timeout from resource limits (convert ms to Duration)
        import std.datetime : msecs;
        auto timeout = spec.resources.maxCpuTimeMs > 0 ? 
            msecs(spec.resources.maxCpuTimeMs) : msecs(0);
        
        return new ActionRequest(
            actionId,
            cmdStr,
            env,
            inputs,
            outputs,
            caps,
            Priority.Normal,
            timeout
        );
    }
    
    /// Convert SandboxSpec to Capabilities for transmission
    private Capabilities specToCapabilities(SandboxSpec spec) const pure @safe
    {
        Capabilities caps;
        
        // Map hermetic spec to capabilities
        caps.network = spec.network.allowExternal;  // Use network policy
        caps.readPaths = spec.inputs.paths.dup;
        caps.writePaths = spec.outputs.paths.dup;
        caps.timeout = spec.resources.maxCpuTimeMs;
        caps.maxCpu = 0;  // ResourceLimits doesn't have maxCpuCores
        caps.maxMemory = spec.resources.maxMemoryBytes;
        
        return caps;
    }
    
    /// Upload input artifacts to store
    private Result!(InputSpec[], BuildError) uploadInputs(SandboxSpec spec) @trusted
    {
        InputSpec[] inputs;
        
        foreach (inputPath; spec.inputs.paths)
        {
            // Read input file/directory
            auto readResult = readArtifact(inputPath);
            if (readResult.isErr)
            {
                auto error = new GenericError(
                    "Failed to read input: " ~ inputPath ~ ": " ~ 
                    readResult.unwrapErr(),
                    ErrorCode.FileNotFound
                );
                return Err!(InputSpec[], BuildError)(error);
            }
            
            auto data = readResult.unwrap();
            
            // Compute artifact ID (content hash)
            auto artifactId = computeArtifactId(data);
            
            // Upload to artifact store
            auto uploadResult = artifactStore.put(artifactId, data);
            if (uploadResult.isErr)
            {
                return Err!(InputSpec[], BuildError)(uploadResult.unwrapErr());
            }
            
            // Check if executable
            bool executable = isExecutable(inputPath);
            
            inputs ~= InputSpec(artifactId, inputPath, executable);
            
            Logger.debugLog("Uploaded input: " ~ inputPath ~ 
                          " -> " ~ artifactId.toString());
        }
        
        return Ok!(InputSpec[], BuildError)(inputs);
    }
    
    /// Download output artifacts from store
    private Result!BuildError downloadOutputs(ArtifactId[] artifacts) @trusted
    {
        foreach (artifactId; artifacts)
        {
            // Convert ActionId to string hash for cache lookup
            auto downloadResult = artifactStore.get(artifactId.toString());
            if (downloadResult.isErr)
            {
                return downloadResult;
            }
            
            Logger.debugLog("Downloaded output: " ~ artifactId.toString());
        }
        
        return Ok!BuildError();
    }
    
    /// Submit action to worker via coordinator
    private Result!(core.distributed.protocol.protocol.ActionResult, BuildError) 
    submitToWorker(ActionRequest request) @trusted
    {
        if (coordinator is null)
        {
            auto error = new GenericError(
                "Coordinator not initialized",
                ErrorCode.InternalError
            );
            return Err!(core.distributed.protocol.protocol.ActionResult, BuildError)(error);
        }
        
        // Submit to coordinator
        auto scheduleResult = coordinator.scheduleAction(request);
        if (scheduleResult.isErr)
        {
            auto error = new GenericError(
                "Failed to schedule action: " ~ scheduleResult.unwrapErr().message(),
                ErrorCode.ActionSchedulingFailed
            );
            return Err!(core.distributed.protocol.protocol.ActionResult, BuildError)(error);
        }
        
        // Wait for completion (would use proper async mechanism)
        // For now, placeholder
        core.distributed.protocol.protocol.ActionResult result;
        result.id = request.id;
        result.status = ResultStatus.Success;
        
        return Ok!(core.distributed.protocol.protocol.ActionResult, BuildError)(result);
    }
    
    /// Check action cache
    private Result!(RemoteExecutionResult, BuildError) checkActionCache(ActionId actionId) @trusted
    {
        // Query action cache (would integrate with action cache service)
        auto error = new GenericError("Not in cache", ErrorCode.CacheMiss);
        return Err!(RemoteExecutionResult, BuildError)(error);
    }
    
    /// Cache action result
    private Result!BuildError cacheActionResult(
        ActionId actionId,
        RemoteExecutionResult result
    ) @trusted
    {
        // Store in action cache (would integrate with action cache service)
        Logger.debugLog("Caching action result: " ~ actionId.toString());
        return Ok!BuildError();
    }
    
    /// Read artifact from filesystem
    private Result!(ubyte[], string) readArtifact(string path) @trusted
    {
        import std.file : read, exists;
        
        if (!exists(path))
            return Err!(ubyte[], string)("File not found: " ~ path);
        
        try
        {
            auto data = cast(ubyte[])read(path);
            return Ok!(ubyte[], string)(data);
        }
        catch (Exception e)
        {
            return Err!(ubyte[], string)(e.msg);
        }
    }
    
    /// Compute artifact ID from content
    private ArtifactId computeArtifactId(const ubyte[] data) @trusted
    {
        import utils.crypto.blake3 : Blake3Hasher;
        
        auto hasher = Blake3Hasher();
        hasher.update(data);
        
        ubyte[32] hash;
        hasher.finalize(hash);
        
        return ArtifactId(hash);
    }
    
    /// Check if file is executable
    private bool isExecutable(string path) @trusted
    {
        version(Posix)
        {
            import core.sys.posix.sys.stat;
            import std.string : toStringz;
            
            stat_t statbuf;
            if (stat(toStringz(path), &statbuf) == 0)
            {
                return (statbuf.st_mode & S_IXUSR) != 0;
            }
        }
        
        return false;
    }
}

/// Hermetic spec serialization for transmission to workers
struct HermeticSpecCodec
{
    /// Serialize SandboxSpec for transmission
    static ubyte[] serialize(SandboxSpec spec) @trusted
    {
        import std.bitmanip : write;
        import std.datetime : Duration;
        
        ubyte[] buffer;
        buffer.reserve(4096);
        
        // Inputs
        buffer.write!uint(cast(uint)spec.inputs.length, buffer.length);
        foreach (input; spec.inputs)
        {
            buffer.write!uint(cast(uint)input.length, buffer.length);
            buffer ~= cast(ubyte[])input;
        }
        
        // Outputs
        buffer.write!uint(cast(uint)spec.outputs.length, buffer.length);
        foreach (output; spec.outputs)
        {
            buffer.write!uint(cast(uint)output.length, buffer.length);
            buffer ~= cast(ubyte[])output;
        }
        
        // Temp directories
        buffer.write!uint(cast(uint)spec.temps.length, buffer.length);
        foreach (temp; spec.temps)
        {
            buffer.write!uint(cast(uint)temp.length, buffer.length);
            buffer ~= cast(ubyte[])temp;
        }
        
        // Flags
        ubyte flags = 0;
        if (spec.allowNetwork) flags |= 0x01;
        buffer.write!ubyte(flags, buffer.length);
        
        // Environment
        buffer.write!uint(cast(uint)spec.environment.length, buffer.length);
        foreach (key, value; spec.environment)
        {
            buffer.write!uint(cast(uint)key.length, buffer.length);
            buffer ~= cast(ubyte[])key;
            buffer.write!uint(cast(uint)value.length, buffer.length);
            buffer ~= cast(ubyte[])value;
        }
        
        // Resources
        buffer.write!ulong(spec.resources.maxMemoryBytes, buffer.length);
        buffer.write!ulong(spec.resources.maxCpuCores, buffer.length);
        buffer.write!long(spec.resources.timeout.total!"msecs", buffer.length);
        
        return buffer;
    }
    
    /// Deserialize SandboxSpec from transmission
    static Result!(SandboxSpec, string) deserialize(const ubyte[] data) @system
    {
        import std.bitmanip : read;
        import std.datetime : dur;
        
        if (data.length < 4)
            return Err!(SandboxSpec, string)("Data too short");
        
        ubyte[] mutableData = cast(ubyte[])data.dup;
        size_t offset = 0;
        
        auto builder = SandboxSpecBuilder.create();
        
        try
        {
            // Inputs
            auto inputCountSlice = mutableData[offset .. offset + 4];
            immutable inputCount = inputCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. inputCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                
                immutable path = cast(string)data[offset .. offset + len];
                offset += len;
                
                builder.input(path);
            }
            
            // Outputs
            auto outputCountSlice = mutableData[offset .. offset + 4];
            immutable outputCount = outputCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. outputCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                
                immutable path = cast(string)data[offset .. offset + len];
                offset += len;
                
                builder.output(path);
            }
            
            // Temps
            auto tempCountSlice = mutableData[offset .. offset + 4];
            immutable tempCount = tempCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. tempCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                
                immutable path = cast(string)data[offset .. offset + len];
                offset += len;
                
                builder.temp(path);
            }
            
            // Flags
            auto flagSlice = mutableData[offset .. offset + 1];
            immutable flags = flagSlice.read!ubyte();
            offset += 1;
            
            if (flags & 0x01)
                builder.allowNetwork();
            
            // Environment
            auto envCountSlice = mutableData[offset .. offset + 4];
            immutable envCount = envCountSlice.read!uint();
            offset += 4;
            
            foreach (_; 0 .. envCount)
            {
                auto keyLenSlice = mutableData[offset .. offset + 4];
                immutable keyLen = keyLenSlice.read!uint();
                offset += 4;
                
                immutable key = cast(string)data[offset .. offset + keyLen];
                offset += keyLen;
                
                auto valLenSlice = mutableData[offset .. offset + 4];
                immutable valLen = valLenSlice.read!uint();
                offset += 4;
                
                immutable value = cast(string)data[offset .. offset + valLen];
                offset += valLen;
                
                builder.env(key, value);
            }
            
            // Resources
            auto memSlice = mutableData[offset .. offset + 8];
            immutable maxMemory = memSlice.read!ulong();
            offset += 8;
            
            auto cpuSlice = mutableData[offset .. offset + 8];
            immutable maxCpu = cpuSlice.read!ulong();
            offset += 8;
            
            auto timeoutSlice = mutableData[offset .. offset + 8];
            immutable timeoutMs = timeoutSlice.read!long();
            
            builder.maxMemory(maxMemory);
            builder.maxCpu(cast(size_t)maxCpu);
            builder.timeout(dur!"msecs"(timeoutMs));
            
            auto specResult = builder.build();
            if (specResult.isErr)
                return Err!(SandboxSpec, string)(specResult.unwrapErr());
            
            return Ok!(SandboxSpec, string)(specResult.unwrap());
        }
        catch (Exception e)
        {
            return Err!(SandboxSpec, string)("Deserialization failed: " ~ e.msg);
        }
    }
}

