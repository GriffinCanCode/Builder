module languages.scripting.lua.tooling.formatters.base;

import languages.scripting.lua.core.config;

/// Format result structure
struct FormatResult
{
    bool success;
    string error;
    string[] modifiedFiles;
}

/// Base interface for Lua formatters
interface Formatter
{
    /// Format Lua source files
    FormatResult format(string[] sources, LuaConfig config);
    
    /// Check if formatter is available
    bool isAvailable();
    
    /// Get formatter name
    string name() const;
    
    /// Get formatter version
    string getVersion();
}

/// Factory for creating formatters
class FormatterFactory
{
    /// Create formatter based on type
    static Formatter create(LuaFormatter type, LuaConfig config)
    {
        import languages.scripting.lua.tooling.formatters.stylua;
        import languages.scripting.lua.tooling.detection;
        
        final switch (type)
        {
            case LuaFormatter.Auto:
                // Auto-detect best available formatter
                auto best = detectBestFormatter();
                return create(best, config);
                
            case LuaFormatter.StyLua:
                return new StyLuaFormatter();
                
            case LuaFormatter.LuaFormat:
                // lua-format support (could be implemented later)
                return new StyLuaFormatter(); // Fallback
                
            case LuaFormatter.None:
                return new NullFormatter();
        }
    }
}

/// Null formatter (does nothing)
class NullFormatter : Formatter
{
    override FormatResult format(string[] sources, LuaConfig config)
    {
        FormatResult result;
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

