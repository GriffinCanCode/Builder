module tests.mocks;

import std.algorithm;
import std.array;
import config.schema;
import core.graph;
import languages.base;

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
    LanguageBuildResult buildResult;
    
    this(bool shouldRebuild = true)
    {
        needsRebuildValue = shouldRebuild;
        buildResult.success = true;
        buildResult.message = "Mock build successful";
    }
    
    override LanguageBuildResult build(Target target, WorkspaceConfig config)
    {
        buildCalled = true;
        return buildResult;
    }
    
    override bool needsRebuild(Target target, WorkspaceConfig config)
    {
        return needsRebuildValue;
    }
    
    override void clean(Target target, WorkspaceConfig config)
    {
        // Mock implementation
    }
    
    override string[] getOutputs(Target target, WorkspaceConfig config)
    {
        return outputPaths;
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

