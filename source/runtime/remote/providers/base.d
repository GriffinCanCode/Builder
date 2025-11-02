module runtime.remote.providers.base;

import std.datetime : SysTime;
import distributed.protocol.protocol : WorkerId;
import errors;

/// Worker status from cloud provider
struct WorkerStatus
{
    enum State
    {
        Pending,
        Running,
        Stopping,
        Stopped,
        Failed
    }
    
    State state;
    string publicIp;
    string privateIp;
    SysTime launchTime;
}

/// Cloud provider interface for worker provisioning
/// 
/// Responsibility: Abstract cloud provider operations
/// Implementations: AWS EC2, Kubernetes, GCP, Azure, etc.
interface CloudProvider
{
    /// Provision new worker instance
    /// 
    /// Responsibility: Request worker from cloud provider
    /// Returns: WorkerId on success, error on failure
    Result!(WorkerId, BuildError) provisionWorker(
        string instanceType,
        string imageId,
        string[string] tags
    );
    
    /// Terminate worker instance
    /// 
    /// Responsibility: Gracefully shutdown worker
    /// Returns: Success or error
    Result!BuildError terminateWorker(WorkerId workerId);
    
    /// Get worker status
    /// 
    /// Responsibility: Query worker state from provider
    /// Returns: WorkerStatus with current state
    Result!(WorkerStatus, BuildError) getWorkerStatus(WorkerId workerId);
}

