module languages.dotnet.csharp.analysis.project;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;

/// C# project information parsed from .csproj
struct ProjectInfo
{
    /// Project file path
    string filePath;
    
    /// Project name
    string name;
    
    /// Target framework(s)
    string[] targetFrameworks;
    
    /// Output type (Exe, Library, WinExe)
    string outputType;
    
    /// Root namespace
    string rootNamespace;
    
    /// Assembly name
    string assemblyName;
    
    /// Package references
    PackageReference[] packages;
    
    /// Project references
    string[] projectReferences;
    
    /// Language version
    string languageVersion;
    
    /// Nullable reference types setting
    string nullable;
    
    /// Implicit usings
    bool implicitUsings;
    
    /// Is SDK-style project
    bool isSdkStyle;
}

/// NuGet package reference
struct PackageReference
{
    /// Package name
    string name;
    
    /// Package version
    string version_;
}

/// Parse C# project file
ProjectInfo parseProjectFile(string filePath)
{
    ProjectInfo info;
    info.filePath = filePath;
    info.name = baseName(filePath, ".csproj");
    
    if (!exists(filePath))
        return info;
    
    try
    {
        auto content = readText(filePath);
        
        // Check if SDK-style project
        info.isSdkStyle = content.canFind("<Project Sdk=");
        
        // Extract target framework(s)
        auto tfmPattern = regex(`<TargetFramework>([^<]+)</TargetFramework>`);
        auto tfmMatch = matchFirst(content, tfmPattern);
        if (!tfmMatch.empty)
        {
            info.targetFrameworks ~= tfmMatch[1];
        }
        else
        {
            // Multiple target frameworks
            auto tfmsPattern = regex(`<TargetFrameworks>([^<]+)</TargetFrameworks>`);
            auto tfmsMatch = matchFirst(content, tfmsPattern);
            if (!tfmsMatch.empty)
            {
                info.targetFrameworks = tfmsMatch[1].split(";");
            }
        }
        
        // Extract output type
        auto outputTypePattern = regex(`<OutputType>([^<]+)</OutputType>`);
        auto outputTypeMatch = matchFirst(content, outputTypePattern);
        if (!outputTypeMatch.empty)
        {
            info.outputType = outputTypeMatch[1];
        }
        
        // Extract assembly name
        auto asmNamePattern = regex(`<AssemblyName>([^<]+)</AssemblyName>`);
        auto asmNameMatch = matchFirst(content, asmNamePattern);
        if (!asmNameMatch.empty)
        {
            info.assemblyName = asmNameMatch[1];
        }
        else
        {
            info.assemblyName = info.name;
        }
        
        // Extract root namespace
        auto nsPattern = regex(`<RootNamespace>([^<]+)</RootNamespace>`);
        auto nsMatch = matchFirst(content, nsPattern);
        if (!nsMatch.empty)
        {
            info.rootNamespace = nsMatch[1];
        }
        else
        {
            info.rootNamespace = info.name;
        }
        
        // Extract language version
        auto langVerPattern = regex(`<LangVersion>([^<]+)</LangVersion>`);
        auto langVerMatch = matchFirst(content, langVerPattern);
        if (!langVerMatch.empty)
        {
            info.languageVersion = langVerMatch[1];
        }
        
        // Extract nullable setting
        auto nullablePattern = regex(`<Nullable>([^<]+)</Nullable>`);
        auto nullableMatch = matchFirst(content, nullablePattern);
        if (!nullableMatch.empty)
        {
            info.nullable = nullableMatch[1];
        }
        
        // Extract implicit usings
        auto implicitUsingsPattern = regex(`<ImplicitUsings>(true|enable)</ImplicitUsings>`);
        info.implicitUsings = !matchFirst(content, implicitUsingsPattern).empty;
        
        // Extract package references
        auto pkgPattern = regex(`<PackageReference\s+Include="([^"]+)"\s+Version="([^"]+)"`);
        foreach (match; matchAll(content, pkgPattern))
        {
            PackageReference pkg;
            pkg.name = match[1];
            pkg.version_ = match[2];
            info.packages ~= pkg;
        }
        
        // Also handle package references with child elements
        auto pkgPattern2 = regex(`<PackageReference\s+Include="([^"]+)"[^>]*>[\s\n]*<Version>([^<]+)</Version>`);
        foreach (match; matchAll(content, pkgPattern2))
        {
            PackageReference pkg;
            pkg.name = match[1];
            pkg.version_ = match[2];
            info.packages ~= pkg;
        }
        
        // Extract project references
        auto projRefPattern = regex(`<ProjectReference\s+Include="([^"]+)"`);
        foreach (match; matchAll(content, projRefPattern))
        {
            info.projectReferences ~= match[1];
        }
    }
    catch (Exception e)
    {
        // Failed to parse
    }
    
    return info;
}

/// Find all .csproj files in directory
string[] findProjectFiles(string dir)
{
    import utils.security.validation;
    
    string[] projects;
    
    if (!exists(dir) || !isDir(dir))
        return projects;
    
    foreach (entry; dirEntries(dir, "*.csproj", SpanMode.shallow))
    {
        // Validate entry is within directory
        if (SecurityValidator.isPathWithinBase(entry.name, dir))
            projects ~= entry.name;
    }
    
    return projects;
}

