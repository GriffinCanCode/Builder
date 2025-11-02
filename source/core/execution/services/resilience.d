module core.execution.services.resilience;

import core.execution.recovery.retry : RetryOrchestrator, RetryPolicy;
import core.execution.recovery.checkpoint : CheckpointManager, Checkpoint;
import core.execution.recovery.resume : ResumePlanner, ResumePlan, ResumeConfig;
import core.graph.graph : BuildGraph;
import errors;

/// Resilience service interface
/// Handles retry logic and checkpoint/resume functionality
interface IResilienceService
{
    /// Execute action with retry logic (string result version)
    Result!(string, BuildError) withRetryString(
        string targetId,
        Result!(string, BuildError) delegate() action,
        RetryPolicy policy
    );
    
    /// Check if a checkpoint exists
    bool hasCheckpoint();
    
    /// Check if checkpoint is stale
    bool isCheckpointStale();
    
    /// Save a checkpoint
    bool saveCheckpoint(BuildGraph graph);
    
    /// Load checkpoint
    Result!(Checkpoint, BuildError) loadCheckpoint();
    
    /// Plan resume from checkpoint
    Result!(ResumePlan, BuildError) planResume(BuildGraph graph);
    
    /// Clear checkpoint
    void clearCheckpoint();
    
    /// Get retry policy for an error
    RetryPolicy policyFor(BuildError error);
}

/// Concrete resilience service implementation
final class ResilienceService : IResilienceService
{
    private RetryOrchestrator retryOrchestrator;
    private CheckpointManager checkpointManager;
    private ResumePlanner resumePlanner;
    private bool enableRetries;
    private bool enableCheckpoints;
    
    this(bool enableRetries = true, bool enableCheckpoints = true, string workspaceRoot = ".")
    {
        this.enableRetries = enableRetries;
        this.enableCheckpoints = enableCheckpoints;
        
        // Initialize retry orchestrator
        this.retryOrchestrator = new RetryOrchestrator();
        this.retryOrchestrator.setEnabled(enableRetries);
        
        // Initialize checkpoint manager
        this.checkpointManager = new CheckpointManager(workspaceRoot, enableCheckpoints);
        
        // Initialize resume planner
        this.resumePlanner = new ResumePlanner(ResumeConfig.fromEnvironment());
    }
    
    // Constructor for dependency injection (testing)
    this(RetryOrchestrator retryOrchestrator, 
         CheckpointManager checkpointManager,
         ResumePlanner resumePlanner)
    {
        this.retryOrchestrator = retryOrchestrator;
        this.checkpointManager = checkpointManager;
        this.resumePlanner = resumePlanner;
        this.enableRetries = true;
        this.enableCheckpoints = true;
    }
    
    /// Generic template method (kept for internal/test use)
    Result!(T, BuildError) withRetry(T)(
        string targetId,
        Result!(T, BuildError) delegate() action,
        RetryPolicy policy
    ) @trusted
    {
        if (!enableRetries)
        {
            return action();
        }
        
        return retryOrchestrator.withRetry(targetId, action, policy);
    }
    
    /// Execute action with retry logic (string result version)
    Result!(string, BuildError) withRetryString(
        string targetId,
        Result!(string, BuildError) delegate() action,
        RetryPolicy policy
    ) @trusted
    {
        return withRetry!string(targetId, action, policy);
    }
    
    bool hasCheckpoint() @trusted
    {
        if (!enableCheckpoints)
            return false;
        
        return checkpointManager.exists();
    }
    
    bool isCheckpointStale() @trusted
    {
        if (!enableCheckpoints)
            return true;
        
        return checkpointManager.isStale();
    }
    
    bool saveCheckpoint(BuildGraph graph) @trusted
    {
        if (!enableCheckpoints)
            return true;
        
        // Implementation would save checkpoint
        // Left as exercise - depends on checkpoint format
        return true;
    }
    
    Result!(Checkpoint, BuildError) loadCheckpoint() @trusted
    {
        if (!enableCheckpoints)
        {
            return Result!(Checkpoint, BuildError).err(
                new SystemError("Checkpoints disabled", ErrorCode.UnknownError)
            );
        }
        
        auto loadResult = checkpointManager.load();
        if (loadResult.isErr)
        {
            return Result!(Checkpoint, BuildError).err(
                new SystemError(loadResult.unwrapErr(), ErrorCode.CacheLoadFailed)
            );
        }
        return Result!(Checkpoint, BuildError).ok(loadResult.unwrap());
    }
    
    Result!(ResumePlan, BuildError) planResume(BuildGraph graph) @trusted
    {
        if (!enableCheckpoints)
        {
            return Result!(ResumePlan, BuildError).err(
                new SystemError("Checkpoints disabled", ErrorCode.UnknownError)
            );
        }
        
        auto checkpointResult = checkpointManager.load();
        if (checkpointResult.isErr)
        {
            return Result!(ResumePlan, BuildError).err(
                new SystemError(checkpointResult.unwrapErr(), ErrorCode.CacheLoadFailed)
            );
        }
        
        auto checkpoint = checkpointResult.unwrap();
        auto planResult = resumePlanner.plan(checkpoint, graph);
        if (planResult.isErr)
        {
            return Result!(ResumePlan, BuildError).err(
                new SystemError(planResult.unwrapErr(), ErrorCode.UnknownError)
            );
        }
        return Result!(ResumePlan, BuildError).ok(planResult.unwrap());
    }
    
    void clearCheckpoint() @trusted
    {
        if (enableCheckpoints)
        {
            checkpointManager.clear();
        }
    }
    
    RetryPolicy policyFor(BuildError error) @trusted
    {
        return retryOrchestrator.policyFor(error);
    }
}


/// Null resilience service for testing/disabled resilience
final class NullResilienceService : IResilienceService
{
    /// Execute action with retry logic (string result version)
    Result!(string, BuildError) withRetryString(
        string targetId,
        Result!(string, BuildError) delegate() action,
        RetryPolicy policy
    ) @trusted
    {
        return action();
    }
    
    bool hasCheckpoint() @trusted { return false; }
    bool isCheckpointStale() @trusted { return true; }
    
    bool saveCheckpoint(BuildGraph graph) @trusted
    {
        return true;
    }
    
    Result!(Checkpoint, BuildError) loadCheckpoint() @trusted
    {
        return Result!(Checkpoint, BuildError).err(
            new SystemError("Null resilience service", ErrorCode.UnknownError)
        );
    }
    
    Result!(ResumePlan, BuildError) planResume(BuildGraph graph) @trusted
    {
        return Result!(ResumePlan, BuildError).err(
            new SystemError("Null resilience service", ErrorCode.UnknownError)
        );
    }
    
    void clearCheckpoint() @trusted { }
    
    RetryPolicy policyFor(BuildError error) @trusted
    {
        return RetryPolicy();
    }
}

