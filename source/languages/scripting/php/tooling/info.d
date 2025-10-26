module languages.scripting.php.tooling.info;

import std.process;
import std.string;
import std.algorithm;
import std.array;
import std.regex;
import std.conv;

/// PHP interpreter information
struct PHPInfo
{
    string path;
    string version_;
    int majorVersion;
    int minorVersion;
    int releaseVersion;
    bool isThreadSafe;
    string sapi;
    string[] loadedExtensions;
    string iniPath;
    
    /// Check if extension is loaded
    bool hasExtension(string ext) const
    {
        return loadedExtensions.canFind(ext.toLower);
    }
    
    /// Check if version supports features
    bool supportsEnums() const pure nothrow
    {
        return (majorVersion == 8 && minorVersion >= 1) || majorVersion > 8;
    }
    
    bool supportsFibers() const pure nothrow
    {
        return (majorVersion == 8 && minorVersion >= 1) || majorVersion > 8;
    }
    
    bool supportsReadonly() const pure nothrow
    {
        return (majorVersion == 8 && minorVersion >= 1) || majorVersion > 8;
    }
    
    bool supportsAttributes() const pure nothrow
    {
        return majorVersion >= 8;
    }
    
    bool supportsNamedArguments() const pure nothrow
    {
        return majorVersion >= 8;
    }
    
    bool supportsUnionTypes() const pure nothrow
    {
        return majorVersion >= 8;
    }
    
    bool supportsMatchExpression() const pure nothrow
    {
        return majorVersion >= 8;
    }
}

/// Get detailed PHP information
PHPInfo getPHPInfo(string phpCmd = "php")
{
    PHPInfo info;
    info.path = getPHPPath(phpCmd);
    
    // Get version
    auto versionOutput = getPHPVersion(phpCmd);
    auto versionMatch = matchFirst(versionOutput, regex(r"(\d+)\.(\d+)\.(\d+)"));
    if (versionMatch)
    {
        info.version_ = versionMatch[0];
        info.majorVersion = versionMatch[1].to!int;
        info.minorVersion = versionMatch[2].to!int;
        info.releaseVersion = versionMatch[3].to!int;
    }
    
    // Check thread safety
    auto versionCmd = execute([phpCmd, "--version"]);
    if (versionCmd.status == 0)
    {
        info.isThreadSafe = versionCmd.output.canFind("thread safety");
    }
    
    // Get SAPI
    auto sapiCmd = execute([phpCmd, "-r", "echo php_sapi_name();"]);
    if (sapiCmd.status == 0)
        info.sapi = sapiCmd.output.strip;
    
    // Get loaded extensions
    auto extCmd = execute([phpCmd, "-m"]);
    if (extCmd.status == 0)
    {
        info.loadedExtensions = extCmd.output
            .lineSplitter
            .map!(line => line.strip.toLower)
            .filter!(line => !line.empty && line[0] != '[')
            .array;
    }
    
    // Get INI path
    auto iniCmd = execute([phpCmd, "--ini"]);
    if (iniCmd.status == 0)
    {
        foreach (line; iniCmd.output.lineSplitter)
        {
            if (line.canFind("Loaded Configuration File"))
            {
                auto parts = line.split(":");
                if (parts.length > 1)
                    info.iniPath = parts[1].strip;
                break;
            }
        }
    }
    
    return info;
}

/// Get PHP version
string getPHPVersion(string phpCmd = "php")
{
    auto res = execute([phpCmd, "--version"]);
    if (res.status == 0)
    {
        // Extract version from output (e.g., "PHP 8.3.0 (cli)")
        auto versionMatch = matchFirst(res.output, regex(r"PHP (\d+\.\d+\.\d+)"));
        if (versionMatch)
            return versionMatch[1];
        return res.output.lineSplitter.front.strip;
    }
    return "unknown";
}

/// Get PHP interpreter path
string getPHPPath(string phpCmd = "php")
{
    version(Windows)
    {
        auto res = execute(["where", phpCmd]);
    }
    else
    {
        auto res = execute(["which", phpCmd]);
    }
    
    if (res.status == 0)
        return res.output.strip.split("\n")[0].strip;
    return "";
}

