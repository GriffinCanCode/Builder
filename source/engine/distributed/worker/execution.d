module engine.distributed.worker.execution;

import std.datetime : Duration, Clock, seconds, msecs;
import core.time : MonoTime;
import std.conv : to;
import std.file : read, exists;
import core.thread : Thread;
import core.atomic;
import engine.distributed.protocol.protocol;
import engine.distributed.protocol.messages;
import engine.distributed.storage.artifacts;
import infrastructure.utils.logging.logger;
import infrastructure.errors;
import infrastructure.utils.crypto.blake3 : Blake3;

/// Worker executor - handles action execution
struct WorkerExecutor
{
    private ArtifactStore artifactStore;
    
    /// Constructor
    this(ArtifactStore artifactStore) @safe
    {
        this.artifactStore = artifactStore;
    }
    
    /// Execute build action
    void executeAction(ActionRequest request, bool enableSandboxing, Capabilities defaultCapabilities,
        void delegate(ActionResult) @trusted sendResultCallback) @trusted
    {
        import engine.distributed.worker.sandbox;
        
        immutable startTime = MonoTime.currTime;
        Logger.debugLog("Executing action: " ~ request.id.toString());
        
        try
        {
            // 1. Fetch input artifacts from artifact store
            InputArtifact[] inputs;
            foreach (inputSpec; request.inputs)
            {
                auto fetchResult = artifactStore.fetch(inputSpec);
                if (fetchResult.isErr)
                {
                    Logger.error("Failed to fetch input artifact " ~ inputSpec.id.toString() ~ ": " ~ fetchResult.unwrapErr().message());
                    reportFailure(request.id, "Input artifact fetch failed: " ~ inputSpec.path, startTime, sendResultCallback);
                    return;
                }
                inputs ~= fetchResult.unwrap();
                Logger.debugLog("Fetched input artifact: " ~ inputSpec.id.toString() ~ " (" ~ inputs[$-1].data.length.to!string ~ " bytes)");
            }
            
            // 2. Prepare sandbox
            auto envResult = createSandbox(enableSandboxing).prepare(request, inputs);
            if (envResult.isErr)
            {
                Logger.error("Sandbox preparation failed: " ~ envResult.unwrapErr().message());
                reportFailure(request.id, "Sandbox preparation failed", startTime, sendResultCallback);
                return;
            }
            
            auto sandboxEnv = envResult.unwrap();
            scope(exit) sandboxEnv.cleanup();
            
            // 3. Execute command
            auto execResult = sandboxEnv.execute(request.command, request.env, request.timeout);
            if (execResult.isErr)
            {
                Logger.error("Execution failed: " ~ execResult.unwrapErr().message());
                reportFailure(request.id, "Execution failed", startTime, sendResultCallback);
                return;
            }
            
            auto output = execResult.unwrap();
            immutable duration = MonoTime.currTime - startTime;
            
            // Check for resource violations
            auto monitor = sandboxEnv.monitor();
            if (monitor.isViolated())
            {
                foreach (violation; monitor.violations())
                {
                    Logger.warning("Resource violation: " ~ violation.message);
                    Logger.debugLog("  Type: " ~ violation.type.to!string ~ ", Actual: " ~ violation.actual.to!string ~ ", Limit: " ~ violation.limit.to!string);
                }
                reportFailure(request.id, "Resource limit violations", startTime, sendResultCallback);
                return;
            }
            
            // 4. Upload outputs to artifact store
            ArtifactId[] outputIds;
            foreach (outputSpec; request.outputs)
            {
                immutable outputPath = sandboxEnv.resolveOutputPath(outputSpec.path);
                if (!exists(outputPath))
                {
                    if (!outputSpec.optional)
                    {
                        Logger.error("Required output not found: " ~ outputPath);
                        reportFailure(request.id, "Missing required output: " ~ outputSpec.path, startTime, sendResultCallback);
                        return;
                    }
                    Logger.debugLog("Optional output not found: " ~ outputPath);
                    continue;
                }
                
                ubyte[] outputData;
                try { outputData = cast(ubyte[])read(outputPath); }
                catch (Exception e)
                {
                    Logger.error("Failed to read output file " ~ outputPath ~ ": " ~ e.msg);
                    reportFailure(request.id, "Failed to read output: " ~ outputSpec.path, startTime, sendResultCallback);
                    return;
                }
                
                auto hasher = Blake3(0);
                hasher.put(outputData);
                ubyte[32] hash = hasher.finish(32)[0 .. 32];
                auto artifactId = ArtifactId(hash);
                
                auto uploadResult = artifactStore.upload(artifactId, outputData);
                if (uploadResult.isErr)
                {
                    Logger.error("Failed to upload output artifact " ~ artifactId.toString() ~ ": " ~ uploadResult.unwrapErr().message());
                    reportFailure(request.id, "Output artifact upload failed: " ~ outputSpec.path, startTime, sendResultCallback);
                    return;
                }
                
                outputIds ~= artifactId;
                Logger.debugLog("Uploaded output artifact: " ~ artifactId.toString() ~ " (" ~ outputData.length.to!string ~ " bytes)");
            }
            
            // 5. Report success
            auto result = ActionResult(request.id, output.exitCode == 0 ? ResultStatus.Success : ResultStatus.Failure,
                duration, outputIds, output.stdout, output.stderr, output.exitCode, sandboxEnv.resourceUsage());
            sendResultCallback(result);
            
            if (result.status == ResultStatus.Success) Logger.debugLog("Action succeeded: " ~ request.id.toString());
            else Logger.warning("Action failed with exit code " ~ output.exitCode.to!string);
        }
        catch (Exception e)
        {
            Logger.error("Action execution exception: " ~ e.msg);
            reportFailure(request.id, e.msg, startTime, sendResultCallback);
        }
    }
    
    /// Report action failure
    private void reportFailure(ActionId actionId, string error, MonoTime startTime,
        void delegate(ActionResult) @trusted sendResultCallback) @trusted
    {
        sendResultCallback(ActionResult(actionId, ResultStatus.Error, MonoTime.currTime - startTime, 
            [], "", error, 0, ResourceUsage.init));
    }
}

