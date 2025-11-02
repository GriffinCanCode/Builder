module distributed.worker.execution;

import std.datetime : Duration, Clock, seconds, msecs;
import core.time : MonoTime;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import distributed.protocol.protocol;
import distributed.protocol.messages;
import utils.logging.logger;
import errors;

/// Worker executor - handles action execution
struct WorkerExecutor
{
    /// Execute build action
    void executeAction(
        ActionRequest request,
        bool enableSandboxing,
        Capabilities defaultCapabilities,
        void delegate(ActionResult) @trusted sendResultCallback
    ) @trusted
    {
        import distributed.worker.sandbox;
        
        auto startTime = MonoTime.currTime;
        
        Logger.debugLog("Executing action: " ~ request.id.toString());
        
        try
        {
            // 1. Fetch input artifacts (simplified - would fetch from artifact store)
            InputArtifact[] inputs;
            foreach (inputSpec; request.inputs)
            {
                InputArtifact artifact;
                artifact.id = inputSpec.id;
                artifact.path = inputSpec.path;
                artifact.executable = inputSpec.executable;
                // Would fetch data from artifact store
                artifact.data = [];
                inputs ~= artifact;
            }
            
            // 2. Prepare sandbox
            auto sandbox = createSandbox(enableSandboxing);
            auto envResult = sandbox.prepare(request, inputs);
            if (envResult.isErr)
            {
                Logger.error("Sandbox preparation failed: " ~ envResult.unwrapErr().message());
                reportFailure(request.id, "Sandbox preparation failed", startTime, sendResultCallback);
                return;
            }
            
            auto sandboxEnv = envResult.unwrap();
            scope(exit) sandboxEnv.cleanup();
            
            // 3. Execute command
            auto execResult = sandboxEnv.execute(
                request.command,
                request.env,
                request.timeout
            );
            
            if (execResult.isErr)
            {
                Logger.error("Execution failed: " ~ execResult.unwrapErr().message());
                reportFailure(request.id, "Execution failed", startTime, sendResultCallback);
                return;
            }
            
            auto output = execResult.unwrap();
            auto duration = MonoTime.currTime - startTime;
            
            // Check for resource violations
            auto monitor = sandboxEnv.monitor();
            if (monitor.isViolated())
            {
                foreach (violation; monitor.violations())
                {
                    Logger.warning("Resource violation: " ~ violation.message);
                    Logger.debugLog("  Type: " ~ violation.type.to!string);
                    Logger.debugLog("  Actual: " ~ violation.actual.to!string);
                    Logger.debugLog("  Limit: " ~ violation.limit.to!string);
                }
                
                // Report as failure if violations occurred
                reportFailure(request.id, "Resource limit violations", startTime, sendResultCallback);
                return;
            }
            
            // 4. Upload outputs (simplified - would upload to artifact store)
            ArtifactId[] outputIds;
            foreach (outputSpec; request.outputs)
            {
                // Would read output file and upload
                // For now, generate placeholder ID
                outputIds ~= ArtifactId(new ubyte[32]);
            }
            
            // 5. Report success
            ActionResult result;
            result.id = request.id;
            result.status = output.exitCode == 0 ? ResultStatus.Success : ResultStatus.Failure;
            result.duration = duration;
            result.outputs = outputIds;
            result.stdout = output.stdout;
            result.stderr = output.stderr;
            result.exitCode = output.exitCode;
            result.resources = sandboxEnv.resourceUsage();
            
            sendResultCallback(result);
            
            if (result.status == ResultStatus.Success)
                Logger.debugLog("Action succeeded: " ~ request.id.toString());
            else
                Logger.warning("Action failed with exit code " ~ output.exitCode.to!string);
        }
        catch (Exception e)
        {
            Logger.error("Action execution exception: " ~ e.msg);
            reportFailure(request.id, e.msg, startTime, sendResultCallback);
        }
    }
    
    /// Report action failure
    private void reportFailure(
        ActionId actionId,
        string error,
        MonoTime startTime,
        void delegate(ActionResult) @trusted sendResultCallback
    ) @trusted
    {
        ActionResult result;
        result.id = actionId;
        result.status = ResultStatus.Error;
        result.stderr = error;
        result.duration = MonoTime.currTime - startTime;
        
        sendResultCallback(result);
    }
}

