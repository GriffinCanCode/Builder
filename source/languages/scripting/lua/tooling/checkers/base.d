module languages.scripting.lua.tooling.checkers.base;

import languages.scripting.lua.core.config;

/// Check result structure
struct CheckResult
{
    bool success;
    string error;
    string[] warnings;
}

/// Base interface for Lua linters/checkers
interface Checker
{
    /// Check Lua source files
    CheckResult check(string[] sources, LuaConfig config);
    
    /// Check if checker is available
    bool isAvailable();
    
    /// Get checker name
    string name() const;
    
    /// Get checker version
    string getVersion();
}

/// Factory for creating checkers
class CheckerFactory
{
    /// Create checker based on type
    static Checker create(LuaLinter type, LuaConfig config)
    {
        import languages.scripting.lua.tooling.checkers.luacheck;
        import languages.scripting.lua.tooling.detection;
        
        final switch (type)
        {
            case LuaLinter.Auto:
                // Auto-detect best available linter
                auto best = detectBestLinter();
                return create(best, config);
                
            case LuaLinter.Luacheck:
            case LuaLinter.LuacheckJIT:
                return new LuacheckLinter();
                
            case LuaLinter.Selene:
                // Selene support (could be implemented later)
                return new LuacheckLinter(); // Fallback
                
            case LuaLinter.None:
                return new NullChecker();
        }
    }
}

/// Null checker (does nothing)
class NullChecker : Checker
{
    override CheckResult check(string[] sources, LuaConfig config)
    {
        CheckResult result;
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

