module languages.dotnet.fsharp.managers.fake;

import std.process;
import std.file;
import std.path;
import std.string;
import std.array;
import std.algorithm;
import utils.logging.logger;

/// FAKE (F# Make) build system operations
struct FAKEOps
{
    /// Run FAKE build script
    static bool run(string scriptFile = "build.fsx", string target = "", bool verbose = false, string[] args = [])
    {
        if (!exists(scriptFile))
        {
            Logger.error("FAKE script not found: " ~ scriptFile);
            return false;
        }
        
        string[] cmd = ["dotnet", "fake", "run", scriptFile];
        
        if (!target.empty)
            cmd ~= ["--target", target];
        
        if (verbose)
            cmd ~= ["--verbose"];
        
        cmd ~= args;
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("FAKE build failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Initialize FAKE in a project
    static bool init()
    {
        auto res = execute(["dotnet", "fake", "init"]);
        
        if (res.status != 0)
        {
            Logger.error("FAKE init failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// List available targets in a FAKE script
    static string[] listTargets(string scriptFile = "build.fsx")
    {
        if (!exists(scriptFile))
            return [];
        
        auto res = execute(["dotnet", "fake", "run", scriptFile, "--list"]);
        
        if (res.status != 0)
            return [];
        
        return res.output.splitLines
            .filter!(l => !l.empty && !l.startsWith("Available targets"))
            .map!(l => l.strip)
            .array;
    }
    
    /// Build target
    static bool build(string scriptFile = "build.fsx")
    {
        return run(scriptFile, "Build");
    }
    
    /// Clean target
    static bool clean(string scriptFile = "build.fsx")
    {
        return run(scriptFile, "Clean");
    }
    
    /// Test target
    static bool test(string scriptFile = "build.fsx")
    {
        return run(scriptFile, "Test");
    }
    
    /// Restore dependencies
    static bool restore()
    {
        auto res = execute(["dotnet", "tool", "restore"]);
        
        if (res.status != 0)
        {
            Logger.error("FAKE tool restore failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Check if FAKE is installed
    static bool isAvailable()
    {
        auto res = execute(["dotnet", "fake", "--version"]);
        return res.status == 0;
    }
    
    /// Check if project uses FAKE
    static bool isConfigured()
    {
        return exists("build.fsx") || exists("Build.fsx") || exists(".fake");
    }
    
    /// Get FAKE version
    static string getVersion()
    {
        auto res = execute(["dotnet", "fake", "--version"]);
        
        if (res.status != 0)
            return "";
        
        return res.output.strip;
    }
    
    /// Install FAKE as local tool
    static bool installTool()
    {
        auto res = execute(["dotnet", "tool", "install", "fake-cli"]);
        
        if (res.status != 0)
        {
            Logger.warning("Failed to install FAKE: " ~ res.output);
            return false;
        }
        
        return true;
    }
}

