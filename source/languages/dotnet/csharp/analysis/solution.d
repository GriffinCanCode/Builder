module languages.dotnet.csharp.analysis.solution;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;

/// Solution information parsed from .sln
struct SolutionInfo
{
    /// Solution file path
    string filePath;
    
    /// Solution name
    string name;
    
    /// Projects in solution
    SolutionProject[] projects;
    
    /// Solution configurations
    string[] configurations;
    
    /// Visual Studio version
    string vsVersion;
}

/// Project entry in solution
struct SolutionProject
{
    /// Project name
    string name;
    
    /// Project file path (relative to solution)
    string filePath;
    
    /// Project GUID
    string guid;
    
    /// Project type GUID
    string typeGuid;
}

/// Parse solution file
SolutionInfo parseSolutionFile(string filePath)
{
    SolutionInfo info;
    info.filePath = filePath;
    info.name = baseName(filePath, ".sln");
    
    if (!exists(filePath))
        return info;
    
    try
    {
        auto content = readText(filePath);
        auto lines = content.split("\n");
        
        // Extract Visual Studio version
        foreach (line; lines)
        {
            if (line.canFind("VisualStudioVersion"))
            {
                auto parts = line.split("=");
                if (parts.length >= 2)
                {
                    info.vsVersion = parts[1].strip();
                }
                break;
            }
        }
        
        // Extract projects
        auto projectPattern = regex(`Project\("([^"]+)"\)\s*=\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"`);
        
        foreach (match; matchAll(content, projectPattern))
        {
            SolutionProject proj;
            proj.typeGuid = match[1];
            proj.name = match[2];
            proj.filePath = match[3].replace("\\", "/"); // Normalize path separators
            proj.guid = match[4];
            
            // Only include C# projects
            if (proj.filePath.endsWith(".csproj"))
            {
                info.projects ~= proj;
            }
        }
        
        // Extract configurations
        auto configPattern = regex(`(Debug|Release)\|(Any CPU|x86|x64)`);
        foreach (match; matchAll(content, configPattern))
        {
            auto config = match[1] ~ "|" ~ match[2];
            if (!info.configurations.canFind(config))
            {
                info.configurations ~= config;
            }
        }
    }
    catch (Exception e)
    {
        // Failed to parse
    }
    
    return info;
}

/// Find solution file in directory
string findSolutionFile(string dir)
{
    import infrastructure.utils.security.validation;
    
    if (!exists(dir) || !isDir(dir))
        return "";
    
    foreach (entry; dirEntries(dir, "*.sln", SpanMode.shallow))
    {
        // Validate entry is within directory
        if (!SecurityValidator.isPathWithinBase(entry.name, dir))
            continue;
        return entry.name;
    }
    
    return "";
}

/// Find all solution files in directory
string[] findSolutionFiles(string dir)
{
    import infrastructure.utils.security.validation;
    
    string[] solutions;
    
    if (!exists(dir) || !isDir(dir))
        return solutions;
    
    foreach (entry; dirEntries(dir, "*.sln", SpanMode.shallow))
    {
        // Validate entry is within directory
        if (SecurityValidator.isPathWithinBase(entry.name, dir))
            solutions ~= entry.name;
    }
    
    return solutions;
}

