module languages.scripting.python.tooling.info;

import std.process : Config;
import utils.security : execute;  // SECURITY: Auto-migrated
import std.string;
import std.regex;
import std.conv;
import languages.scripting.python.tooling.detection;

/// Python interpreter information
struct PythonInfo
{
    string path;
    string version_;
    int majorVersion;
    int minorVersion;
    int patchVersion;
    bool isVirtualEnv;
    string sitePackages;
}

/// Python information utilities
class PyInfo
{
    /// Get Python version
    static string getPythonVersion(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Get Python interpreter path
    static string getPythonPath(string pythonCmd = "python3")
    {
        version(Windows)
        {
            auto res = execute(["where", pythonCmd]);
        }
        else
        {
            auto res = execute(["which", pythonCmd]);
        }
        
        if (res.status == 0)
            return res.output.strip.split("\n")[0].strip;
        return "";
    }
    
    /// Check if running in a virtual environment
    static bool isInVirtualEnv(string pythonCmd = "python3")
    {
        auto cmd = [pythonCmd, "-c", "import sys; print(hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix))"];
        auto res = execute(cmd);
        if (res.status == 0)
            return res.output.strip == "True";
        return false;
    }
    
    /// Get detailed Python information
    static PythonInfo getPythonInfo(string pythonCmd = "python3")
    {
        PythonInfo info;
        info.path = getPythonPath(pythonCmd);
        
        // Get version
        auto versionOutput = getPythonVersion(pythonCmd);
        auto versionMatch = matchFirst(versionOutput, regex(`Python (\d+)\.(\d+)\.(\d+)`));
        if (versionMatch)
        {
            info.version_ = versionMatch[1] ~ "." ~ versionMatch[2] ~ "." ~ versionMatch[3];
            info.majorVersion = versionMatch[1].to!int;
            info.minorVersion = versionMatch[2].to!int;
            info.patchVersion = versionMatch[3].to!int;
        }
        
        // Check if in virtual environment
        info.isVirtualEnv = isInVirtualEnv(pythonCmd);
        
        // Get site packages
        auto siteCmd = [pythonCmd, "-c", "import site; print(site.getsitepackages()[0])"];
        auto siteRes = execute(siteCmd);
        if (siteRes.status == 0)
            info.sitePackages = siteRes.output.strip;
        
        return info;
    }
}

