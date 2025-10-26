module languages.scripting.elixir.managers.hex;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import languages.scripting.elixir.core.config;
import utils.logging.logger;

/// Hex package manager
class HexManager
{
    /// Check if Hex is available
    static bool isAvailable()
    {
        auto res = execute(["mix", "hex", "--version"]);
        return res.status == 0;
    }
    
    /// Get Hex version
    static string getVersion()
    {
        auto res = execute(["mix", "hex", "--version"]);
        if (res.status == 0)
        {
            import std.string : strip;
            return res.output.strip;
        }
        return "unknown";
    }
    
    /// Build Hex package
    static bool buildPackage(HexConfig config, string mixCmd = "mix")
    {
        Logger.info("Building Hex package: " ~ config.packageName);
        
        // Validate package
        auto validateRes = execute([mixCmd, "hex.build", "--unpack"]);
        if (validateRes.status != 0)
        {
            Logger.error("Package validation failed: " ~ validateRes.output);
            return false;
        }
        
        // Build package
        auto buildRes = execute([mixCmd, "hex.build"]);
        if (buildRes.status != 0)
        {
            Logger.error("Package build failed: " ~ buildRes.output);
            return false;
        }
        
        Logger.info("Hex package built successfully");
        return true;
    }
    
    /// Publish package to Hex
    static bool publishPackage(HexConfig config, string mixCmd = "mix")
    {
        Logger.info("Publishing package to Hex.pm");
        
        string[] cmd = [mixCmd, "hex.publish"];
        
        if (!config.organization.empty)
            cmd ~= ["--organization", config.organization];
        
        auto res = execute(cmd);
        if (res.status != 0)
        {
            Logger.error("Package publish failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Package published successfully");
        return true;
    }
    
    /// Install specific package
    static bool installPackage(string packageName, string version_ = "")
    {
        string[] cmd = ["mix", "hex", "install", packageName];
        
        if (!version_.empty)
            cmd ~= version_;
        
        auto res = execute(cmd);
        return res.status == 0;
    }
    
    /// Search Hex packages
    static string searchPackages(string query)
    {
        auto res = execute(["mix", "hex.search", query]);
        if (res.status == 0)
            return res.output;
        return "";
    }
    
    /// Get package info
    static string getPackageInfo(string packageName)
    {
        auto res = execute(["mix", "hex.info", packageName]);
        if (res.status == 0)
            return res.output;
        return "";
    }
}

