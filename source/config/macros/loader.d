module config.macros.loader;

import std.array;
import std.algorithm;
import config.macros.api;
import config.schema.schema : Target;
import errors;
import utils.logging.logger;

/// Macro function type
alias MacroFunction = Target[] delegate(string[]);

/// Registry for D-based macros
final class MacroRegistry
{
    private static MacroRegistry _instance;
    private MacroFunction[string] macros;
    
    /// Get singleton instance
    static MacroRegistry instance() @trusted
    {
        if (_instance is null)
        {
            _instance = new MacroRegistry();
        }
        return _instance;
    }
    
    private this() @safe
    {
    }
    
    /// Register a macro function
    void register(Func)(string name, Func fn) @trusted
    {
        macros[name] = delegate Target[](string[] args) {
            return fn(args);
        };
        Logger.debugLog("Registered macro: " ~ name);
    }
    
    /// Check if macro exists
    bool has(string name) const @safe
    {
        return (name in macros) !is null;
    }
    
    /// Call a macro
    Result!(Target[], BuildError) call(string name, string[] args) @trusted
    {
        if (name !in macros)
        {
            import errors.types.types : ParseError;
            return typeof(return).err(new ParseError(
                "",
                "Unknown macro: " ~ name,
                ErrorCode.InvalidConfiguration
            ));
        }
        
        try
        {
            auto result = macros[name](args);
            return typeof(return).ok(result);
        }
        catch (Exception e)
        {
            import errors.types.types : ParseError;
            return typeof(return).err(new ParseError(
                "",
                "Macro '" ~ name ~ "' failed: " ~ e.msg,
                ErrorCode.MacroExpansionFailed
            ));
        }
    }
    
    /// Get list of registered macros
    string[] list() const @safe
    {
        return macros.keys;
    }
    
    /// Clear all registered macros
    void clear() @safe
    {
        macros.clear();
    }
}

/// Dynamic macro loader from compiled .d files
struct MacroLoader
{
    /// Load macros from a D source file
    static Result!(bool, BuildError) loadFromFile(string filename) @system
    {
        import std.file : exists, readText;
        import std.process : execute, ProcessException;
        import std.path : buildPath, absolutePath, dirName;
        import std.string : strip;
        
        if (!exists(filename))
        {
            import errors.types.types : IOError;
            return typeof(return).err(new IOError(
                filename,
                "Macro file not found: " ~ filename,
                ErrorCode.FileNotFound
            ));
        }
        
        // For now, just log that we would load the file
        // Full implementation would compile and load the D module
        Logger.info("Loading macros from: " ~ filename);
        
        // TODO: Implement dynamic compilation and loading
        // This requires:
        // 1. Compile the D file to a shared library
        // 2. Load the shared library dynamically
        // 3. Extract and register macro functions
        
        return typeof(return).ok(true);
    }
    
    /// Load macros from a directory
    static Result!(bool, BuildError) loadFromDirectory(string dir) @system
    {
        import std.file : dirEntries, SpanMode, exists;
        import std.path : extension;
        import std.algorithm : filter, each;
        
        if (!exists(dir))
        {
            import errors.types.types : IOError;
            return typeof(return).err(new IOError(
                dir,
                "Macro directory not found: " ~ dir,
                ErrorCode.FileNotFound
            ));
        }
        
        try
        {
            dirEntries(dir, "*.d", SpanMode.shallow)
                .filter!(f => f.isFile)
                .each!(f => loadFromFile(f.name));
            
            return typeof(return).ok(true);
        }
        catch (Exception e)
        {
            import errors.types.types : ParseError;
            return typeof(return).err(new ParseError(
                dir,
                "Failed to load macros from directory: " ~ e.msg,
                ErrorCode.MacroLoadFailed
            ));
        }
    }
}
