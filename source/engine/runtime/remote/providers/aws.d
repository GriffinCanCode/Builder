module engine.runtime.remote.providers.aws;

import engine.runtime.remote.providers.base;
import engine.distributed.protocol.protocol : WorkerId;
import infrastructure.errors;
import infrastructure.utils.logging.logger;
import std.process : execute, environment;
import std.format : format;
import std.datetime : Clock;
import std.string : strip, split, indexOf;
import std.conv : to;

/// AWS EC2 provider implementation
/// 
/// Responsibility: Manage workers on AWS EC2
/// Uses: AWS CLI for EC2 instance lifecycle management
final class AwsEc2Provider : CloudProvider
{
    private string region;
    private string accessKey;
    private string secretKey;
    
    this(string region, string accessKey, string secretKey) @safe
    {
        this.region = region;
        this.accessKey = accessKey;
        this.secretKey = secretKey;
    }
    
    Result!(WorkerId, BuildError) provisionWorker(
        string instanceType,
        string imageId,
        string[string] tags
    ) @trusted
    {
        // Build tag specifications
        string tagSpecs = "ResourceType=instance,Tags=[";
        tagSpecs ~= "{Key=Name,Value=builder-worker},";
        foreach (key, value; tags)
        {
            tagSpecs ~= format("{Key=%s,Value=%s},", key, value);
        }
        tagSpecs ~= "]";
        
        // Run instances using AWS CLI
        string[] awsArgs = [
            "aws", "ec2", "run-instances",
            "--region", region,
            "--image-id", imageId,
            "--instance-type", instanceType,
            "--count", "1",
            "--tag-specifications", tagSpecs,
            "--output", "json"
        ];
        
        // Set AWS credentials in environment
        string[string] env;
        if (accessKey.length > 0 && secretKey.length > 0)
        {
            env["AWS_ACCESS_KEY_ID"] = accessKey;
            env["AWS_SECRET_ACCESS_KEY"] = secretKey;
        }
        env["AWS_REGION"] = region;
        
        auto result = execute(awsArgs, env);
        
        if (result.status != 0)
        {
            auto error = new SystemError(
                format("Failed to launch EC2 instance: %s", result.output),
                ErrorCode.ExternalError
            );
            return Err!(WorkerId, BuildError)(error);
        }
        
        // Parse instance ID from JSON output (simplified)
        auto output = result.output;
        auto instanceIdIdx = output.indexOf("\"InstanceId\":\"");
        if (instanceIdIdx == -1)
        {
            auto error = new SystemError(
                "Failed to parse instance ID from AWS response",
                ErrorCode.ExternalError
            );
            return Err!(WorkerId, BuildError)(error);
        }
        
        auto idStart = instanceIdIdx + 14; // Length of "\"InstanceId\":\""
        auto idEnd = output.indexOf("\"", idStart);
        immutable instanceId = output[idStart..idEnd];
        
        Logger.info("Launched EC2 instance: " ~ instanceId);
        return Ok!(WorkerId, BuildError)(WorkerId(instanceId));
    }
    
    Result!BuildError terminateWorker(WorkerId workerId) @trusted
    {
        string[] awsArgs = [
            "aws", "ec2", "terminate-instances",
            "--region", region,
            "--instance-ids", workerId.id
        ];
        
        // Set AWS credentials in environment
        string[string] env;
        if (accessKey.length > 0 && secretKey.length > 0)
        {
            env["AWS_ACCESS_KEY_ID"] = accessKey;
            env["AWS_SECRET_ACCESS_KEY"] = secretKey;
        }
        env["AWS_REGION"] = region;
        
        auto result = execute(awsArgs, env);
        
        if (result.status != 0)
        {
            auto error = new SystemError(
                format("Failed to terminate EC2 instance %s: %s", workerId.id, result.output),
                ErrorCode.ExternalError
            );
            return Err!BuildError(error);
        }
        
        Logger.info("Terminated EC2 instance: " ~ workerId.id);
        return Ok!BuildError();
    }
    
    Result!(WorkerStatus, BuildError) getWorkerStatus(WorkerId workerId) @trusted
    {
        string[] awsArgs = [
            "aws", "ec2", "describe-instances",
            "--region", region,
            "--instance-ids", workerId.id,
            "--output", "json"
        ];
        
        // Set AWS credentials in environment
        string[string] env;
        if (accessKey.length > 0 && secretKey.length > 0)
        {
            env["AWS_ACCESS_KEY_ID"] = accessKey;
            env["AWS_SECRET_ACCESS_KEY"] = secretKey;
        }
        env["AWS_REGION"] = region;
        
        auto result = execute(awsArgs, env);
        
        if (result.status != 0)
        {
            auto error = new SystemError(
                format("Failed to describe EC2 instance %s: %s", workerId.id, result.output),
                ErrorCode.ExternalError
            );
            return Err!(WorkerStatus, BuildError)(error);
        }
        
        // Parse JSON output (simplified - real implementation would use JSON parser)
        WorkerStatus status;
        auto output = result.output;
        
        // Extract state (pending, running, stopping, stopped, terminated)
        if (output.indexOf("\"Name\":\"pending\"") != -1)
            status.state = WorkerStatus.State.Pending;
        else if (output.indexOf("\"Name\":\"running\"") != -1)
            status.state = WorkerStatus.State.Running;
        else if (output.indexOf("\"Name\":\"stopping\"") != -1)
            status.state = WorkerStatus.State.Stopping;
        else if (output.indexOf("\"Name\":\"stopped\"") != -1 || 
                 output.indexOf("\"Name\":\"terminated\"") != -1)
            status.state = WorkerStatus.State.Stopped;
        else
            status.state = WorkerStatus.State.Failed;
        
        // Extract public IP
        auto publicIpIdx = output.indexOf("\"PublicIpAddress\":\"");
        if (publicIpIdx != -1)
        {
            auto ipStart = publicIpIdx + 19; // Length of "\"PublicIpAddress\":\""
            auto ipEnd = output.indexOf("\"", ipStart);
            if (ipEnd != -1)
                status.publicIp = output[ipStart..ipEnd];
        }
        
        // Extract private IP
        auto privateIpIdx = output.indexOf("\"PrivateIpAddress\":\"");
        if (privateIpIdx != -1)
        {
            auto ipStart = privateIpIdx + 20; // Length of "\"PrivateIpAddress\":\""
            auto ipEnd = output.indexOf("\"", ipStart);
            if (ipEnd != -1)
                status.privateIp = output[ipStart..ipEnd];
        }
        
        status.launchTime = Clock.currTime; // Would extract from LaunchTime field
        
        return Ok!(WorkerStatus, BuildError)(status);
    }
}

