module languages.dotnet.fsharp.managers.paket;

import std.process;
import std.file;
import std.path;
import std.string;
import std.array;
import std.algorithm;
import utils.logging.logger;

/// Paket package manager operations
struct PaketOps
{
    /// Install packages using Paket
    static bool install(string dependenciesFile = "paket.dependencies")
    {
        if (!exists(dependenciesFile))
        {
            Logger.error("Paket dependencies file not found: " ~ dependenciesFile);
            return false;
        }
        
        auto res = execute(["dotnet", "paket", "install"]);
        
        if (res.status != 0)
        {
            Logger.error("Paket install failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Restore packages
    static bool restore()
    {
        auto res = execute(["dotnet", "paket", "restore"]);
        
        if (res.status != 0)
        {
            Logger.error("Paket restore failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Update packages
    static bool update(string group = "", string packageId = "")
    {
        string[] cmd = ["dotnet", "paket", "update"];
        
        if (!group.empty)
            cmd ~= ["--group", group];
        
        if (!packageId.empty)
            cmd ~= [packageId];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Paket update failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Add a package
    static bool add(string packageId, string version_ = "", string group = "")
    {
        string[] cmd = ["dotnet", "paket", "add", packageId];
        
        if (!version_.empty)
            cmd ~= ["--version", version_];
        
        if (!group.empty)
            cmd ~= ["--group", group];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Paket add failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Remove a package
    static bool remove(string packageId, string group = "")
    {
        string[] cmd = ["dotnet", "paket", "remove", packageId];
        
        if (!group.empty)
            cmd ~= ["--group", group];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Paket remove failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Initialize Paket in a project
    static bool init()
    {
        auto res = execute(["dotnet", "paket", "init"]);
        
        if (res.status != 0)
        {
            Logger.error("Paket init failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Convert from NuGet to Paket
    static bool convert(bool force = false)
    {
        string[] cmd = ["dotnet", "paket", "convert-from-nuget"];
        
        if (force)
            cmd ~= ["--force"];
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Paket convert failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Generate load scripts for F# Interactive
    static bool generateLoadScripts()
    {
        auto res = execute(["dotnet", "paket", "generate-load-scripts"]);
        
        if (res.status != 0)
        {
            Logger.error("Paket generate-load-scripts failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    /// Parse paket.dependencies file
    static string[] parseDependencies(string dependenciesFile = "paket.dependencies")
    {
        string[] packages;
        
        if (!exists(dependenciesFile))
            return packages;
        
        try
        {
            auto content = readText(dependenciesFile);
            
            foreach (line; content.splitLines)
            {
                auto trimmed = line.strip;
                
                // Look for "nuget PackageName" lines
                if (trimmed.startsWith("nuget "))
                {
                    auto parts = trimmed.split();
                    if (parts.length >= 2)
                        packages ~= parts[1];
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse paket.dependencies: " ~ e.msg);
        }
        
        return packages;
    }
    
    /// Check if Paket is installed
    static bool isAvailable()
    {
        auto res = execute(["dotnet", "paket", "--version"]);
        return res.status == 0;
    }
    
    /// Check if project uses Paket
    static bool isConfigured()
    {
        return exists("paket.dependencies") || exists("paket.lock");
    }
    
    /// Get Paket version
    static string getVersion()
    {
        auto res = execute(["dotnet", "paket", "--version"]);
        
        if (res.status != 0)
            return "";
        
        return res.output.strip;
    }
}

