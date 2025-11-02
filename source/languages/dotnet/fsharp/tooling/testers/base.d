module languages.dotnet.fsharp.tooling.testers.base;

import languages.dotnet.fsharp.config;

/// Test result structure
struct TestResult
{
    /// Tests succeeded
    bool success = false;
    
    /// Error message if failed
    string error;
    
    /// Total tests run
    int totalTests = 0;
    
    /// Passed tests
    int passed = 0;
    
    /// Failed tests
    int failed = 0;
    
    /// Skipped tests
    int skipped = 0;
    
    /// Test duration (ms)
    long duration = 0;
}

/// Base interface for F# test runners
interface FSharpTester
{
    /// Run tests
    TestResult runTests(string[] testFiles, FSharpTestConfig config);
    
    /// Get framework name
    string getName();
    
    /// Check if framework is available
    bool isAvailable();
}

/// Factory for creating appropriate test runner
class FSharpTesterFactory
{
    /// Create test runner for specified framework
    static FSharpTester create(FSharpTestFramework framework)
    {
        import languages.dotnet.fsharp.tooling.testers.expecto;
        import languages.dotnet.fsharp.tooling.testers.xunit;
        import languages.dotnet.fsharp.tooling.testers.nunit;
        
        final switch (framework)
        {
            case FSharpTestFramework.Auto:
                // Try to detect based on dependencies
                return new ExpectoTester(); // Default to Expecto
            case FSharpTestFramework.Expecto:
                return new ExpectoTester();
            case FSharpTestFramework.XUnit:
                return new XUnitTester();
            case FSharpTestFramework.NUnit:
                return new NUnitTester();
            case FSharpTestFramework.FsUnit:
                // FsUnit works on top of NUnit/xUnit
                return new NUnitTester();
            case FSharpTestFramework.Unquote:
                // Unquote works with various frameworks
                return new XUnitTester();
            case FSharpTestFramework.None:
                return null;
        }
    }
}

