module languages.dotnet.csharp.tooling.info;

import std.stdio;
import std.process;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import std.conv;

/// .NET information utilities
struct DotNetInfo
{
    /// Get dotnet version
    static string getVersion()
    {
        try
        {
            auto result = execute(["dotnet", "--version"]);
            if (result.status == 0)
            {
                return result.output.strip();
            }
        }
        catch (Exception e)
        {
        }
        
        return "";
    }
    
    /// Get full dotnet info
    static string getInfo()
    {
        try
        {
            auto result = execute(["dotnet", "--info"]);
            if (result.status == 0)
            {
                return result.output;
            }
        }
        catch (Exception e)
        {
        }
        
        return "";
    }
    
    /// List installed SDKs
    static string[] listSDKs()
    {
        string[] sdks;
        
        try
        {
            auto result = execute(["dotnet", "--list-sdks"]);
            if (result.status == 0)
            {
                auto lines = result.output.split("\n");
                foreach (line; lines)
                {
                    line = line.strip();
                    if (!line.empty)
                        sdks ~= line;
                }
            }
        }
        catch (Exception e)
        {
        }
        
        return sdks;
    }
    
    /// List installed runtimes
    static string[] listRuntimes()
    {
        string[] runtimes;
        
        try
        {
            auto result = execute(["dotnet", "--list-runtimes"]);
            if (result.status == 0)
            {
                auto lines = result.output.split("\n");
                foreach (line; lines)
                {
                    line = line.strip();
                    if (!line.empty)
                        runtimes ~= line;
                }
            }
        }
        catch (Exception e)
        {
        }
        
        return runtimes;
    }
    
    /// Check if specific SDK version is installed
    static bool hasSDK(string version_)
    {
        auto sdks = listSDKs();
        foreach (sdk; sdks)
        {
            if (sdk.canFind(version_))
                return true;
        }
        return false;
    }
    
    /// Check if specific runtime is installed
    static bool hasRuntime(string name, string version_ = "")
    {
        auto runtimes = listRuntimes();
        foreach (runtime; runtimes)
        {
            if (runtime.canFind(name))
            {
                if (version_.empty || runtime.canFind(version_))
                    return true;
            }
        }
        return false;
    }
}

/// C# compiler information
struct CSCInfo
{
    /// Get csc version
    static string getVersion()
    {
        try
        {
            auto result = execute(["csc", "/version"]);
            if (result.status == 0)
            {
                return result.output.strip();
            }
        }
        catch (Exception e)
        {
        }
        
        return "";
    }
}

