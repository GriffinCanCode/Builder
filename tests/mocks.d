module tests.mocks;

import std.algorithm;
import std.array;
import infrastructure.config.schema.schema;
import core.graph.graph;
import languages.base.base;
import infrastructure.errors;
import infrastructure.analysis.targets.types;

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
    
    override Result!(string, BuildError) build(in Target target, in WorkspaceConfig config)
    {
        buildCalled = true;
        
        if (shouldSucceed)
        {
            return Ok!(string, BuildError)(outputHash);
        }
        else
        {
            auto error = new BuildFailureError(target.name, errorMessage);
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

