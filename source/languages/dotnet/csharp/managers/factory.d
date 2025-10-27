module languages.dotnet.csharp.managers.factory;

import std.file;
import std.path;
import std.algorithm;
import std.range;
import languages.dotnet.csharp.core.config;
import languages.dotnet.csharp.managers.dotnet;
import languages.dotnet.csharp.managers.msbuild;
import languages.dotnet.csharp.tooling.detection;

/// Build tool factory
struct BuildToolFactory
{
    /// Enhance configuration from project structure
    static void enhanceConfigFromProject(ref CSharpConfig config, string projectRoot)
    {
        // Auto-detect build tool if set to Auto
        if (config.buildTool == CSharpBuildTool.Auto)
        {
            if (DotNetToolDetection.isDotNetAvailable())
            {
                config.buildTool = CSharpBuildTool.DotNet;
            }
            else if (MSBuildToolDetection.isMSBuildAvailable())
            {
                config.buildTool = CSharpBuildTool.MSBuild;
            }
            else
            {
                config.buildTool = CSharpBuildTool.CSC;
            }
        }
        
        // Auto-detect framework from project file
        if (config.framework == DotNetFramework.Auto)
        {
            auto framework = detectFrameworkFromProject(projectRoot);
            if (!framework.empty)
            {
                config.customFramework = framework;
            }
            else
            {
                // Default to .NET 8
                config.framework = DotNetFramework.Net8;
            }
        }
        
        // Auto-detect project type from project file
        if (config.projectType == CSharpProjectType.Console)
        {
            auto projectType = detectProjectTypeFromProject(projectRoot);
            config.projectType = projectType;
        }
    }
    
    /// Detect framework from project file
    private static string detectFrameworkFromProject(string projectRoot)
    {
        // Look for .csproj file
        foreach (entry; dirEntries(projectRoot, "*.csproj", SpanMode.shallow))
        {
            try
            {
                auto content = readText(entry.name);
                
                // Look for <TargetFramework> tag
                import std.regex;
                auto targetFrameworkPattern = regex(`<TargetFramework>([^<]+)</TargetFramework>`);
                auto match = matchFirst(content, targetFrameworkPattern);
                if (!match.empty)
                {
                    return match[1];
                }
            }
            catch (Exception e)
            {
                // Continue searching
            }
        }
        
        return "";
    }
    
    /// Detect project type from project file
    private static CSharpProjectType detectProjectTypeFromProject(string projectRoot)
    {
        // Look for .csproj file
        foreach (entry; dirEntries(projectRoot, "*.csproj", SpanMode.shallow))
        {
            try
            {
                auto content = readText(entry.name);
                
                // Detect based on SDK attribute
                if (content.canFind("Microsoft.NET.Sdk.Web"))
                {
                    if (content.canFind("Blazor"))
                        return CSharpProjectType.BlazorServer;
                    return CSharpProjectType.WebAPI;
                }
                else if (content.canFind("Microsoft.NET.Sdk.Worker"))
                {
                    return CSharpProjectType.Worker;
                }
                else if (content.canFind("Microsoft.NET.Sdk.Razor"))
                {
                    return CSharpProjectType.RazorClassLib;
                }
                else if (content.canFind("Microsoft.NET.Test.Sdk"))
                {
                    return CSharpProjectType.Test;
                }
                
                // Check for OutputType
                if (content.canFind("<OutputType>Library</OutputType>"))
                {
                    return CSharpProjectType.Library;
                }
                else if (content.canFind("<OutputType>Exe</OutputType>"))
                {
                    return CSharpProjectType.Console;
                }
                else if (content.canFind("<OutputType>WinExe</OutputType>"))
                {
                    if (content.canFind("WPF") || content.canFind("Windows.Presentation"))
                        return CSharpProjectType.WPF;
                    else if (content.canFind("WindowsForms") || content.canFind("System.Windows.Forms"))
                        return CSharpProjectType.WinForms;
                    return CSharpProjectType.Console;
                }
            }
            catch (Exception e)
            {
                // Continue
            }
        }
        
        return CSharpProjectType.Console;
    }
}

