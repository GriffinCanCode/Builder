module tests.mocks;

import std.algorithm;
import std.array;
import infrastructure.config.schema.schema;
import core.graph.graph;
import languages.base.base;
import infrastructure.errors;
import infrastructure.analysis.targets.types;
import engine.runtime.remote.core.interface_ : IRemoteExecutionService, ServiceStatus;
import engine.runtime.remote.core.executor : RemoteExecutionResult;
import engine.runtime.remote.protocol.reapi : Action, ExecuteResponse;
import engine.runtime.remote.monitoring.metrics : ServiceMetrics;
import engine.distributed.protocol.protocol : ActionId;
import engine.runtime.hermetic : SandboxSpec;

/// Helper function: Call handler.buildWithContext() with simplified test context
/// Usage in tests: auto result = testBuild(handler, target, config);
Result!(string, BuildError) testBuild(LanguageHandler handler, Target target, WorkspaceConfig config)
{
    BuildContext context;
    context.target = target;
    context.config = config;
    context.incrementalEnabled = false; // Tests run fresh by default
    return handler.buildWithContext(context);
}

/// Mock build node for testing
class MockBuildNode
{
    string id;
    BuildStatus status;
    MockBuildNode[] dependencies;
    
    this(string id, BuildStatus status = BuildStatus.Pending)
    {
        this.id = id;
        this.status = status;
    }
    
    void addDep(MockBuildNode dep)
    {
        dependencies ~= dep;
    }
    
    bool isReady() const
    {
        return dependencies.all!(d => d.status == BuildStatus.Success);
    }
}

/// Mock language handler for testing
class MockLanguageHandler : LanguageHandler
{
    bool buildCalled;
    bool needsRebuildValue;
    string[] outputPaths;
    bool shouldSucceed = true;
    string outputHash = "mock-hash";
    string errorMessage = "Mock build failed";
    
    this(bool shouldRebuild = true)
    {
        needsRebuildValue = shouldRebuild;
    }
    
    override Result!(string, BuildError) buildWithContext(BuildContext context)
    {
        buildCalled = true;
        
        if (shouldSucceed)
        {
            return Ok!(string, BuildError)(outputHash);
        }
        else
        {
            auto error = new BuildFailureError(context.target.name, errorMessage);
            return Err!(string, BuildError)(error);
        }
    }
    
    override bool needsRebuild(in Target target, in WorkspaceConfig config)
    {
        return needsRebuildValue;
    }
    
    override void clean(in Target target, in WorkspaceConfig config)
    {
        // Mock implementation
    }
    
    override string[] getOutputs(in Target target, in WorkspaceConfig config)
    {
        return outputPaths;
    }
    
    override Import[] analyzeImports(in string[] sources)
    {
        // Mock implementation - return empty array
        return [];
    }
    
    void reset()
    {
        buildCalled = false;
    }
}

/// Call tracker for testing
class CallTracker
{
    private string[] calls;
    
    void record(string call)
    {
        calls ~= call;
    }
    
    bool wasCalled(string call) const
    {
        return calls.canFind(call);
    }
    
    size_t callCount(string call) const
    {
        return calls.count!(c => c == call);
    }
    
    string[] getCalls() const
    {
        return calls.dup;
    }
    
    void reset()
    {
        calls = [];
    }
}

/// Spy pattern for capturing calls
mixin template Spy(string methodName)
{
    private CallTracker tracker;
    
    void recordCall(string name, Args...)(Args args)
    {
        import std.conv : to;
        string call = name;
        static foreach (i, arg; args)
        {
            call ~= "," ~ arg.to!string;
        }
        tracker.record(call);
    }
}

/// Stub for controlling return values
class Stub(T)
{
    private T returnValue;
    private Exception exception;
    
    void returns(T value)
    {
        returnValue = value;
        exception = null;
    }
    
    void throws(Exception e)
    {
        exception = e;
    }
    
    T call()
    {
        if (exception)
            throw exception;
        return returnValue;
    }
}

/// Mock remote execution service for testing
/// Tracks method calls and allows configurable behavior
final class MockRemoteExecutionService : IRemoteExecutionService
{
    // Call tracking
    bool startCalled;
    bool stopCalled;
    size_t executeCallCount;
    size_t executeReapiCallCount;
    size_t getStatusCallCount;
    size_t getMetricsCallCount;
    
    // Configuration for behavior
    bool shouldStartSucceed = true;
    bool shouldExecuteSucceed = true;
    bool shouldExecuteReapiSucceed = true;
    bool isRunning;
    string startErrorMessage = "Mock start failed";
    string executeErrorMessage = "Mock execution failed";
    
    // Captured arguments
    ActionId lastExecuteActionId;
    SandboxSpec lastExecuteSpec;
    string[] lastExecuteCommand;
    string lastExecuteWorkDir;
    Action lastReapiAction;
    bool lastReapiSkipCache;
    
    // Return values
    RemoteExecutionResult executionResult;
    ExecuteResponse reapiResponse;
    ServiceStatus status;
    ServiceMetrics metrics;
    
    @trusted
    {
        Result!BuildError start()
        {
            startCalled = true;
            isRunning = shouldStartSucceed;
            
            if (shouldStartSucceed)
            {
                return Ok!BuildError();
            }
            else
            {
                auto error = new GenericError(startErrorMessage, ErrorCode.InitializationFailed);
                return Err!BuildError(error);
            }
        }
        
        void stop()
        {
            stopCalled = true;
            isRunning = false;
        }
        
        Result!(RemoteExecutionResult, BuildError) execute(
            ActionId actionId,
            SandboxSpec spec,
            string[] command,
            string workDir
        )
        {
            executeCallCount++;
            lastExecuteActionId = actionId;
            lastExecuteSpec = spec;
            lastExecuteCommand = command.dup;
            lastExecuteWorkDir = workDir;
            
            if (shouldExecuteSucceed)
            {
                return Ok!(RemoteExecutionResult, BuildError)(executionResult);
            }
            else
            {
                auto error = new GenericError(executeErrorMessage, ErrorCode.ExecutionFailed);
                return Err!(RemoteExecutionResult, BuildError)(error);
            }
        }
        
        Result!(ExecuteResponse, BuildError) executeReapi(
            Action action,
            bool skipCacheLookup = false
        )
        {
            executeReapiCallCount++;
            lastReapiAction = action;
            lastReapiSkipCache = skipCacheLookup;
            
            if (shouldExecuteReapiSucceed)
            {
                return Ok!(ExecuteResponse, BuildError)(reapiResponse);
            }
            else
            {
                auto error = new GenericError("REAPI execution failed", ErrorCode.ExecutionFailed);
                return Err!(ExecuteResponse, BuildError)(error);
            }
        }
        
        ServiceStatus getStatus()
        {
            getStatusCallCount++;
            status.running = isRunning;
            return status;
        }
        
        ServiceMetrics getMetrics()
        {
            getMetricsCallCount++;
            return metrics;
        }
    }
    
    /// Reset all tracking state (useful between tests)
    void reset()
    {
        startCalled = false;
        stopCalled = false;
        executeCallCount = 0;
        executeReapiCallCount = 0;
        getStatusCallCount = 0;
        getMetricsCallCount = 0;
        isRunning = false;
        shouldStartSucceed = true;
        shouldExecuteSucceed = true;
        shouldExecuteReapiSucceed = true;
    }
}

