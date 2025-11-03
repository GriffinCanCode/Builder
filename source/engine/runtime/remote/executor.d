module engine.runtime.remote.executor;

import std.datetime : Duration, Clock, MonoTime, minutes;
import std.algorithm : map;
import std.array : array;
import std.conv : to;
import engine.distributed.protocol.protocol;
import engine.distributed.coordinator.coordinator;
import engine.distributed.coordinator.scheduler;
import engine.runtime.hermetic;
import engine.runtime.remote.codec : HermeticSpecCodec;
import engine.runtime.remote.artifacts : ArtifactManager;
import engine.caching.distributed.remote.client;
import engine.distributed.storage.store : ArtifactStore;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

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
/// 
/// Responsibility: Orchestrate remote execution flow
/// Delegates artifact management to ArtifactManager (SRP)
final class RemoteExecutor
{
    private RemoteExecutorConfig config;
    private Coordinator coordinator;
    private ArtifactManager artifactManager;
    
    this(RemoteExecutorConfig config) @trusted
    {
        this.config = config;
        
        // Initialize artifact store client
        import engine.caching.distributed.remote.protocol : RemoteCacheConfig;
        
        RemoteCacheConfig cacheConfig;
        cacheConfig.url = config.artifactStoreUrl;
        cacheConfig.enableCompression = config.enableCompression;
        
        auto cacheClient = new RemoteCacheClient(cacheConfig);
        
        // Initialize artifact manager (SRP: separated from execution orchestration)
        this.artifactManager = new ArtifactManager(cacheClient);
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
        
        // 2. Upload input artifacts (delegated to ArtifactManager)
        auto uploadResult = artifactManager.uploadInputs(spec);
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
        
        // 5. Download output artifacts (delegated to ArtifactManager)
        auto downloadResult = artifactManager.downloadOutputs(builderResult.outputs);
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
        import std.datetime : msecs;
        
        Capabilities caps;
        
        // Map hermetic spec to capabilities
        caps.network = !spec.network.isHermetic;  // Use network policy - non-hermetic means network allowed
        caps.readPaths = spec.inputs.paths.dup;
        caps.writePaths = spec.outputs.paths.dup;
        caps.timeout = msecs(spec.resources.maxCpuTimeMs);
        caps.maxCpu = 0;  // ResourceLimits doesn't have maxCpuCores
        caps.maxMemory = spec.resources.maxMemoryBytes;
        
        return caps;
    }
    
    
    /// Submit action to worker via coordinator
    private Result!(distributed.protocol.protocol.ActionResult, BuildError) 
    submitToWorker(ActionRequest request) @trusted
    {
        if (coordinator is null)
        {
            auto error = new GenericError(
                "Coordinator not initialized",
                ErrorCode.InternalError
            );
            return Err!(distributed.protocol.protocol.ActionResult, BuildError)(error);
        }
        
        // Submit to coordinator
        auto scheduleResult = coordinator.scheduleAction(request);
        if (scheduleResult.isErr)
        {
            auto error = new GenericError(
                "Failed to schedule action: " ~ scheduleResult.unwrapErr().message(),
                ErrorCode.ActionSchedulingFailed
            );
            return Err!(distributed.protocol.protocol.ActionResult, BuildError)(error);
        }
        
        // Wait for completion (would use proper async mechanism)
        // For now, placeholder
        distributed.protocol.protocol.ActionResult result;
        result.id = request.id;
        result.status = ResultStatus.Success;
        
        return Ok!(distributed.protocol.protocol.ActionResult, BuildError)(result);
    }
    
    /// Check action cache
    private Result!(RemoteExecutionResult, BuildError) checkActionCache(ActionId actionId) @trusted
    {
        // Query action cache (would integrate with action cache service)
        auto error = new GenericError("Not in cache", ErrorCode.CacheNotFound);
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
    
}
