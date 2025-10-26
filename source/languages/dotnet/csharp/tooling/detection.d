module languages.dotnet.csharp.tooling.detection;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.string;

/// .NET tool detection utilities
struct DotNetToolDetection
{
    /// Check if dotnet CLI is available
    static bool isDotNetAvailable()
    {
        try
        {
            auto result = execute(["dotnet", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Check if project has .csproj file
    static bool hasProjectFile(string dir)
    {
        if (!exists(dir) || !isDir(dir))
            return false;
        
        foreach (entry; dirEntries(dir, "*.csproj", SpanMode.shallow))
        {
            return true;
        }
        
        return false;
    }
    
    /// Check if directory has solution file
    static bool hasSolutionFile(string dir)
    {
        if (!exists(dir) || !isDir(dir))
            return false;
        
        foreach (entry; dirEntries(dir, "*.sln", SpanMode.shallow))
        {
            return true;
        }
        
        return false;
    }
    
    /// Find all project files in directory
    static string[] findProjectFiles(string dir)
    {
        string[] projects;
        
        if (!exists(dir) || !isDir(dir))
            return projects;
        
        foreach (entry; dirEntries(dir, "*.csproj", SpanMode.shallow))
        {
            projects ~= entry.name;
        }
        
        return projects;
    }
    
    /// Find solution file in directory
    static string findSolutionFile(string dir)
    {
        if (!exists(dir) || !isDir(dir))
            return "";
        
        foreach (entry; dirEntries(dir, "*.sln", SpanMode.shallow))
        {
            return entry.name;
        }
        
        return "";
    }
}

/// C# compiler detection
struct CSCToolDetection
{
    /// Check if csc compiler is available
    static bool isCSCAvailable()
    {
        try
        {
            auto result = execute(["csc", "/help"]);
            return result.status == 0 || result.status == 1; // csc returns 1 for /help
        }
        catch (Exception e)
        {
            return false;
        }
    }
}

/// Formatter tool detection
struct FormatterDetection
{
    /// Check if dotnet-format is available
    static bool isDotNetFormatAvailable()
    {
        try
        {
            auto result = execute(["dotnet", "format", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Check if CSharpier is available
    static bool isCSharpierAvailable()
    {
        try
        {
            auto result = execute(["dotnet", "csharpier", "--version"]);
            return result.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
}

/// Analyzer tool detection
struct AnalyzerDetection
{
    /// Check if Roslyn analyzers are available (built into SDK)
    static bool isRoslynAvailable()
    {
        return DotNetToolDetection.isDotNetAvailable();
    }
}

