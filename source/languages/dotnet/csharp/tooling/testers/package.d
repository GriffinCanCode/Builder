module languages.dotnet.csharp.tooling.testers.package;

public import languages.dotnet.csharp.tooling.testers.base;
public import languages.dotnet.csharp.tooling.testers.xunit;
public import languages.dotnet.csharp.tooling.testers.nunit;
public import languages.dotnet.csharp.tooling.testers.mstest;

import languages.dotnet.csharp.config.test;

/// Test runner factory
class TestRunnerFactory
{
    /// Create test runner for specified framework
    static ITestRunner create(CSharpTestFramework framework)
    {
        final switch (framework)
        {
            case CSharpTestFramework.XUnit:
                return new XUnitRunner();
            
            case CSharpTestFramework.NUnit:
                return new NUnitRunner();
            
            case CSharpTestFramework.MSTest:
                return new MSTestRunner();
            
            case CSharpTestFramework.Auto:
            case CSharpTestFramework.None:
                // Return first available
                auto xunit = new XUnitRunner();
                if (xunit.isAvailable())
                    return xunit;
                
                auto nunit = new NUnitRunner();
                if (nunit.isAvailable())
                    return nunit;
                
                auto mstest = new MSTestRunner();
                if (mstest.isAvailable())
                    return mstest;
                
                return xunit; // Default fallback
        }
    }
    
    /// Auto-detect and create appropriate test runner
    static ITestRunner autoDetect(string projectPath)
    {
        auto framework = detectTestFramework(projectPath);
        if (framework == CSharpTestFramework.None)
            framework = CSharpTestFramework.Auto;
        
        return create(framework);
    }
}

