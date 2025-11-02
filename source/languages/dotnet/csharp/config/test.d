module languages.dotnet.csharp.config.test;

/// Testing framework selection
enum CSharpTestFramework
{
    Auto,   /// Auto-detect from dependencies
    XUnit,  /// xUnit
    NUnit,  /// NUnit
    MSTest, /// MSTest
    None    /// None - skip testing
}

/// Test execution configuration
struct TestConfig
{
    bool enabled = true;
    CSharpTestFramework framework = CSharpTestFramework.Auto;
    string[] testProjects;
    string filter;
    bool noBuild = false;
    bool noRestore = false;
    bool collectCoverage = false;
    string coverageFormat = "cobertura";
    int minCoverage = 0;
    string resultsDirectory;
    string logger;
    bool verboseRestore = false;
    string[] args;
}

/// C# testing configuration
struct CSharpTestConfig
{
    TestConfig test;
    bool runTests = true;
}

