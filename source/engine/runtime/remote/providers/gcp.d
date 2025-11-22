module engine.runtime.remote.providers.gcp;

import engine.runtime.remote.providers.base;
import engine.distributed.protocol.protocol : WorkerId;
import infrastructure.errors;
import infrastructure.utils.logging.logger;
import std.process : execute;
import std.format : format;
import std.datetime : Clock;
import std.string : strip, split, indexOf;
import std.conv : to;

/// Google Cloud Platform Compute Engine provider implementation
/// 
/// Responsibility: Manage workers on GCP Compute Engine
/// Uses: gcloud CLI for instance lifecycle management
final class GcpComputeProvider : CloudProvider
{
    private string project;
    private string zone;
    private string serviceAccountKey;
    
    this(string project, string zone, string serviceAccountKey = "") @safe
    {
        this.project = project;
        this.zone = zone;
        this.serviceAccountKey = serviceAccountKey;
    }
    
    Result!(WorkerId, BuildError) provisionWorker(
        string instanceType,
        string imageId,
        string[string] tags
    ) @trusted
    {
        import std.uuid : randomUUID;
        
        // Generate unique instance name
        immutable instanceName = "builder-worker-" ~ randomUUID().toString()[0..13];
        
        // Build gcloud command
        string[] gcloudArgs = [
            "gcloud", "compute", "instances", "create",
            instanceName,
            "--project=" ~ project,
            "--zone=" ~ zone,
            "--machine-type=" ~ instanceType,
            "--image=" ~ imageId,
            "--boot-disk-size=50GB",
            "--boot-disk-type=pd-standard",
            "--scopes=cloud-platform",
            "--format=json"
        ];
        
        // Add labels (GCP equivalent of tags)
        if (tags.length > 0)
        {
            string labelStr = "--labels=";
            size_t count = 0;
            foreach (key, value; tags)
            {
                if (count > 0)
                    labelStr ~= ",";
                labelStr ~= format("%s=%s", key, value);
                count++;
            }
            gcloudArgs ~= labelStr;
        }
        
        // Set up environment
        string[string] env;
        if (serviceAccountKey.length > 0)
            env["GOOGLE_APPLICATION_CREDENTIALS"] = serviceAccountKey;
        
        auto result = execute(gcloudArgs, env);
        
        if (result.status != 0)
        {
            auto error = new SystemError(
                format("Failed to create GCP instance: %s", result.output),
                ErrorCode.ExternalError
            );
            return Err!(WorkerId, BuildError)(error);
        }
        
        Logger.info("Created GCP instance: " ~ instanceName);
        return Ok!(WorkerId, BuildError)(WorkerId(instanceName));
    }
    
    Result!BuildError terminateWorker(WorkerId workerId) @trusted
    {
        string[] gcloudArgs = [
            "gcloud", "compute", "instances", "delete",
            workerId.id,
            "--project=" ~ project,
            "--zone=" ~ zone,
            "--quiet"
        ];
        
        // Set up environment
        string[string] env;
        if (serviceAccountKey.length > 0)
            env["GOOGLE_APPLICATION_CREDENTIALS"] = serviceAccountKey;
        
        auto result = execute(gcloudArgs, env);
        
        if (result.status != 0)
        {
            auto error = new SystemError(
                format("Failed to delete GCP instance %s: %s", workerId.id, result.output),
                ErrorCode.ExternalError
            );
            return Err!BuildError(error);
        }
        
        Logger.info("Deleted GCP instance: " ~ workerId.id);
        return Ok!BuildError();
    }
    
    Result!(WorkerStatus, BuildError) getWorkerStatus(WorkerId workerId) @trusted
    {
        string[] gcloudArgs = [
            "gcloud", "compute", "instances", "describe",
            workerId.id,
            "--project=" ~ project,
            "--zone=" ~ zone,
            "--format=json"
        ];
        
        // Set up environment
        string[string] env;
        if (serviceAccountKey.length > 0)
            env["GOOGLE_APPLICATION_CREDENTIALS"] = serviceAccountKey;
        
        auto result = execute(gcloudArgs, env);
        
        if (result.status != 0)
        {
            auto error = new SystemError(
                format("Failed to describe GCP instance %s: %s", workerId.id, result.output),
                ErrorCode.ExternalError
            );
            return Err!(WorkerStatus, BuildError)(error);
        }
        
        // Parse JSON output (simplified - real implementation would use JSON parser)
        WorkerStatus status;
        auto output = result.output;
        
        // Extract status (PROVISIONING, STAGING, RUNNING, STOPPING, TERMINATED)
        if (output.indexOf("\"status\":\"PROVISIONING\"") != -1 || 
            output.indexOf("\"status\":\"STAGING\"") != -1)
            status.state = WorkerStatus.State.Pending;
        else if (output.indexOf("\"status\":\"RUNNING\"") != -1)
            status.state = WorkerStatus.State.Running;
        else if (output.indexOf("\"status\":\"STOPPING\"") != -1 || 
                 output.indexOf("\"status\":\"SUSPENDING\"") != -1)
            status.state = WorkerStatus.State.Stopping;
        else if (output.indexOf("\"status\":\"TERMINATED\"") != -1 || 
                 output.indexOf("\"status\":\"SUSPENDED\"") != -1)
            status.state = WorkerStatus.State.Stopped;
        else
            status.state = WorkerStatus.State.Failed;
        
        // Extract external IP
        auto extIpIdx = output.indexOf("\"natIP\":\"");
        if (extIpIdx != -1)
        {
            auto ipStart = extIpIdx + 9; // Length of "\"natIP\":\""
            auto ipEnd = output.indexOf("\"", ipStart);
            if (ipEnd != -1)
                status.publicIp = output[ipStart..ipEnd];
        }
        
        // Extract internal IP
        auto intIpIdx = output.indexOf("\"networkIP\":\"");
        if (intIpIdx != -1)
        {
            auto ipStart = intIpIdx + 13; // Length of "\"networkIP\":\""
            auto ipEnd = output.indexOf("\"", ipStart);
            if (ipEnd != -1)
                status.privateIp = output[ipStart..ipEnd];
        }
        
        status.launchTime = Clock.currTime; // Would extract from creationTimestamp
        
        return Ok!(WorkerStatus, BuildError)(status);
    }
}


