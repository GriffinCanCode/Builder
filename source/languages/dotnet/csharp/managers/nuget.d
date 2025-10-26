module languages.dotnet.csharp.managers.nuget;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.dotnet.csharp.core.config;
import utils.logging.logger;

/// NuGet package management operations
struct NuGetOps
{
    /// Restore NuGet packages
    static bool restore(string projectRoot, NuGetConfig config)
    {
        Logger.info("Restoring NuGet packages");
        
        string[] cmd = ["dotnet", "restore"];
        
        // Config file
        if (!config.configFile.empty && exists(config.configFile))
            cmd ~= ["--configfile", config.configFile];
        
        // Packages directory
        if (!config.packagesDirectory.empty)
            cmd ~= ["--packages", config.packagesDirectory];
        
        // Sources
        foreach (source; config.sources)
        {
            cmd ~= ["--source", source];
        }
        
        // Locked mode
        if (config.lockedMode)
            cmd ~= ["--locked-mode"];
        
        // Force evaluate
        if (config.forceEvaluate)
            cmd ~= ["--force-evaluate"];
        
        // No cache
        if (config.noCache)
            cmd ~= ["--no-cache"];
        
        // Execute restore
        auto result = executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("NuGet restore failed: " ~ result.output);
            return false;
        }
        
        Logger.info("NuGet restore succeeded");
        return true;
    }
    
    /// Install a NuGet package
    static bool install(string projectRoot, string packageName, string packageVersion = "")
    {
        Logger.info("Installing NuGet package: " ~ packageName);
        
        string[] cmd = ["dotnet", "add", "package", packageName];
        
        if (!packageVersion.empty)
            cmd ~= ["--version", packageVersion];
        
        auto result = executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("Package install failed: " ~ result.output);
            return false;
        }
        
        Logger.info("Package installed successfully");
        return true;
    }
    
    /// Remove a NuGet package
    static bool remove(string projectRoot, string packageName)
    {
        Logger.info("Removing NuGet package: " ~ packageName);
        
        string[] cmd = ["dotnet", "remove", "package", packageName];
        
        auto result = executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.error("Package removal failed: " ~ result.output);
            return false;
        }
        
        Logger.info("Package removed successfully");
        return true;
    }
    
    /// List installed packages
    static string[] listPackages(string projectRoot)
    {
        string[] packages;
        
        string[] cmd = ["dotnet", "list", "package"];
        
        auto result = executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.warning("Failed to list packages: " ~ result.output);
            return packages;
        }
        
        // Parse output
        auto lines = result.output.split("\n");
        foreach (line; lines)
        {
            line = line.strip();
            if (line.startsWith(">"))
            {
                // Package line format: "> PackageName    Version"
                auto parts = line[1..$].split();
                if (parts.length >= 2)
                    packages ~= parts[0] ~ " " ~ parts[1];
            }
        }
        
        return packages;
    }
    
    /// Update packages
    static bool update(string projectRoot)
    {
        Logger.info("Updating NuGet packages");
        
        // List packages first
        auto packages = listPackages(projectRoot);
        
        foreach (pkg; packages)
        {
            auto parts = pkg.split();
            if (parts.length >= 1)
            {
                // Update to latest version
                string[] cmd = ["dotnet", "add", "package", parts[0]];
                executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
            }
        }
        
        Logger.info("Package update completed");
        return true;
    }
    
    /// Check for outdated packages
    static string[] outdatedPackages(string projectRoot)
    {
        string[] outdated;
        
        string[] cmd = ["dotnet", "list", "package", "--outdated"];
        
        auto result = executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            Logger.warning("Failed to check outdated packages: " ~ result.output);
            return outdated;
        }
        
        // Parse output
        auto lines = result.output.split("\n");
        foreach (line; lines)
        {
            line = line.strip();
            if (line.startsWith(">"))
            {
                outdated ~= line[1..$].strip();
            }
        }
        
        return outdated;
    }
    
    /// Check for vulnerable packages
    static string[] vulnerablePackages(string projectRoot)
    {
        string[] vulnerable;
        
        string[] cmd = ["dotnet", "list", "package", "--vulnerable"];
        
        auto result = executeShell(cmd.join(" "), null, Config.none, size_t.max, projectRoot);
        
        if (result.status != 0)
        {
            // Vulnerability check might not be available in all versions
            return vulnerable;
        }
        
        // Parse output
        auto lines = result.output.split("\n");
        foreach (line; lines)
        {
            line = line.strip();
            if (line.startsWith(">"))
            {
                vulnerable ~= line[1..$].strip();
            }
        }
        
        return vulnerable;
    }
}

