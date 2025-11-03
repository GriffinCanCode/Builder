module infrastructure.utils.process.checker;

import std.process : Config;
import infrastructure.utils.security : execute;  // SECURITY: Auto-migrated
import std.string;
import std.algorithm;

/// Utility class for checking tool/command availability
class ToolChecker
{
    /// Cache of command availability checks to avoid repeated system calls
    private static bool[string] availabilityCache;
    
    /// Check if a command/tool is available in the system PATH
    /// Params:
    ///   command = The command name to check (e.g., "node", "python3", "gcc")
    ///   useCache = Whether to use cached results (default: true)
    /// Returns: true if the command is available, false otherwise
    static bool isAvailable(string command, bool useCache = true) @system
    {
        if (command.empty)
            return false;
        
        // Check cache first if enabled
        if (useCache && command in availabilityCache)
            return availabilityCache[command];
        
        bool result = checkCommandAvailability(command);
        
        // Store in cache
        if (useCache)
            availabilityCache[command] = result;
        
        return result;
    }
    
    /// Check if any of the given commands is available
    /// Params:
    ///   commands = Array of command names to check
    ///   useCache = Whether to use cached results (default: true)
    /// Returns: true if at least one command is available, false otherwise
    static bool isAnyAvailable(string[] commands, bool useCache = true) @system
    {
        return commands.any!(cmd => isAvailable(cmd, useCache));
    }
    
    /// Check if all of the given commands are available
    /// Params:
    ///   commands = Array of command names to check
    ///   useCache = Whether to use cached results (default: true)
    /// Returns: true if all commands are available, false otherwise
    static bool areAllAvailable(string[] commands, bool useCache = true) @system
    {
        return commands.all!(cmd => isAvailable(cmd, useCache));
    }
    
    /// Find the first available command from a list of alternatives
    /// Params:
    ///   commands = Array of command names to check in order
    ///   useCache = Whether to use cached results (default: true)
    /// Returns: The first available command, or empty string if none available
    static string findFirstAvailable(string[] commands, bool useCache = true) @system
    {
        foreach (cmd; commands)
        {
            if (isAvailable(cmd, useCache))
                return cmd;
        }
        return "";
    }
    
    /// Clear the availability cache
    /// Useful if system PATH changes during execution
    static void clearCache() @system
    {
        availabilityCache.clear();
    }
    
    /// Get the version of a command by running it with --version
    /// Params:
    ///   command = The command to check
    /// Returns: The version string, or empty if unavailable or no version found
    static string getVersion(string command) @system
    {
        if (!isAvailable(command))
            return "";
        
        try
        {
            // Try --version first
            auto res = execute([command, "--version"]);
            if (res.status == 0 && !res.output.empty)
                return res.output.strip;
            
            // Try -version (some tools use this)
            res = execute([command, "-version"]);
            if (res.status == 0 && !res.output.empty)
                return res.output.strip;
            
            // Try version (some tools use this)
            res = execute([command, "version"]);
            if (res.status == 0 && !res.output.empty)
                return res.output.strip;
        }
        catch (Exception e)
        {
            // Ignore exceptions
        }
        
        return "";
    }
    
    private static bool checkCommandAvailability(string command) @system
    {
        version(Windows)
        {
            auto res = execute(["where", command]);
        }
        else
        {
            auto res = execute(["which", command]);
        }
        
        return res.status == 0;
    }
}

/// Convenience function for checking if a command is available
/// This is a shorthand for ToolChecker.isAvailable(command)
bool isCommandAvailable(string command) @system
{
    return ToolChecker.isAvailable(command);
}

/// Convenience function for finding the first available command
/// This is a shorthand for ToolChecker.findFirstAvailable(commands)
string findFirstAvailableCommand(string[] commands) @system
{
    return ToolChecker.findFirstAvailable(commands);
}

unittest
{
    // Test with a command that should always exist
    version(Windows)
    {
        assert(isCommandAvailable("cmd"));
        assert(ToolChecker.isAvailable("cmd"));
    }
    else
    {
        assert(isCommandAvailable("sh"));
        assert(ToolChecker.isAvailable("sh"));
    }
    
    // Test with a command that should not exist
    assert(!isCommandAvailable("this_command_definitely_does_not_exist_12345"));
    
    // Test cache
    ToolChecker.clearCache();
    version(Windows)
    {
        assert(ToolChecker.isAvailable("cmd", true));
        assert(ToolChecker.isAvailable("cmd", true)); // Should use cache
    }
    else
    {
        assert(ToolChecker.isAvailable("sh", true));
        assert(ToolChecker.isAvailable("sh", true)); // Should use cache
    }
    
    // Test findFirstAvailable
    version(Windows)
    {
        assert(findFirstAvailableCommand(["nonexistent", "cmd", "another_nonexistent"]) == "cmd");
    }
    else
    {
        assert(findFirstAvailableCommand(["nonexistent", "sh", "another_nonexistent"]) == "sh");
    }
}

