module languages.scripting.lua.tooling.testers.base;

import languages.scripting.lua.core.config;
import config.schema.schema;
import analysis.targets.spec;

/// Test result structure
struct TestResult
{
    bool success;
    string error;
    string outputHash;
    int testsPassed;
    int testsFailed;
    int testsSkipped;
    float coveragePercent;
}

/// Base interface for Lua test frameworks
interface Tester
{
    /// Run tests
    TestResult runTests(
        string[] sources,
        LuaConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    /// Check if tester is available
    bool isAvailable();
    
    /// Get tester name
    string name() const;
    
    /// Get tester version
    string getVersion();
}

/// Factory for creating test frameworks
class TesterFactory
{
    /// Create tester based on type
    static Tester create(LuaTestFramework type, LuaConfig config)
    {
        import languages.scripting.lua.tooling.testers.busted;
        import languages.scripting.lua.tooling.testers.luaunit;
        import languages.scripting.lua.tooling.detection;
        
        final switch (type)
        {
            case LuaTestFramework.Auto:
                // Auto-detect best available test framework
                auto best = detectBestTester();
                return create(best, config);
                
            case LuaTestFramework.Busted:
                return new BustedTester();
                
            case LuaTestFramework.LuaUnit:
                return new LuaUnitTester();
                
            case LuaTestFramework.Telescope:
            case LuaTestFramework.TestMore:
                // Could be implemented later, fallback to LuaUnit
                return new LuaUnitTester();
                
            case LuaTestFramework.None:
                return new NullTester();
        }
    }
}

/// Null tester (does nothing)
class NullTester : Tester
{
    override TestResult runTests(
        string[] sources,
        LuaConfig config,
        Target target,
        WorkspaceConfig workspace
    )
    {
        TestResult result;
        result.success = true;
        return result;
    }
    
    override bool isAvailable()
    {
        return true;
    }
    
    override string name() const
    {
        return "None";
    }
    
    override string getVersion()
    {
        return "N/A";
    }
}

