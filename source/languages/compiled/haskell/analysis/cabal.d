module languages.compiled.haskell.analysis.cabal;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import utils.logging.logger;

/// Cabal package metadata
struct CabalMetadata
{
    string name;
    string version_;
    string synopsis;
    string description;
    string license;
    string author;
    string maintainer;
    string category;
    string homepage;
    string bugReports;
    string[] buildDepends;
    string[] exposedModules;
    string[] otherModules;
    string[] executables;
    string[] testSuites;
    string ghcVersion;
}

/// Parse a .cabal file
CabalMetadata parseCabalFile(string filepath)
{
    CabalMetadata meta;
    
    if (!exists(filepath))
    {
        Logger.warning("Cabal file not found: " ~ filepath);
        return meta;
    }
    
    try
    {
        auto content = readText(filepath);
        return parseCabalContent(content);
    }
    catch (Exception e)
    {
        Logger.warning("Failed to parse Cabal file: " ~ e.msg);
        return meta;
    }
}

/// Parse Cabal file content
CabalMetadata parseCabalContent(string content)
{
    CabalMetadata meta;
    
    string currentSection = "";
    
    foreach (line; content.lineSplitter)
    {
        string trimmed = line.strip;
        
        // Skip comments and empty lines
        if (trimmed.empty || trimmed.startsWith("--"))
            continue;
        
        // Check for section headers
        if (trimmed.startsWith("library"))
        {
            currentSection = "library";
            continue;
        }
        else if (trimmed.startsWith("executable "))
        {
            currentSection = "executable";
            auto exeName = trimmed["executable ".length .. $].strip;
            meta.executables ~= exeName;
            continue;
        }
        else if (trimmed.startsWith("test-suite "))
        {
            currentSection = "test-suite";
            auto testName = trimmed["test-suite ".length .. $].strip;
            meta.testSuites ~= testName;
            continue;
        }
        
        // Parse field: value pairs
        auto colonPos = trimmed.indexOf(":");
        if (colonPos > 0)
        {
            string field = trimmed[0 .. colonPos].strip.toLower;
            string value = trimmed[colonPos + 1 .. $].strip;
            
            switch (field)
            {
                case "name":
                    meta.name = value;
                    break;
                case "version":
                    meta.version_ = value;
                    break;
                case "synopsis":
                    meta.synopsis = value;
                    break;
                case "description":
                    meta.description = value;
                    break;
                case "license":
                    meta.license = value;
                    break;
                case "author":
                    meta.author = value;
                    break;
                case "maintainer":
                    meta.maintainer = value;
                    break;
                case "category":
                    meta.category = value;
                    break;
                case "homepage":
                    meta.homepage = value;
                    break;
                case "bug-reports":
                    meta.bugReports = value;
                    break;
                case "build-depends":
                    meta.buildDepends ~= parseDependencyList(value);
                    break;
                case "exposed-modules":
                    meta.exposedModules ~= parseModuleList(value);
                    break;
                case "other-modules":
                    meta.otherModules ~= parseModuleList(value);
                    break;
                default:
                    break;
            }
        }
        // Handle multi-line continuations (indented lines)
        else if (line.startsWith(" ") || line.startsWith("\t"))
        {
            // This is a continuation of the previous field
            // For build-depends, exposed-modules, etc.
            string value = trimmed;
            
            if (currentSection == "library" || currentSection == "executable")
            {
                // Try to detect what field this continues
                if (value.canFind(","))
                {
                    // Likely a dependency or module list
                    meta.buildDepends ~= parseDependencyList(value);
                }
            }
        }
    }
    
    return meta;
}

/// Parse comma-separated dependency list
private string[] parseDependencyList(string deps)
{
    string[] result;
    
    foreach (dep; deps.split(","))
    {
        string trimmed = dep.strip;
        if (trimmed.empty)
            continue;
        
        // Extract package name (ignore version constraints)
        auto parts = trimmed.split;
        if (parts.length > 0)
        {
            result ~= parts[0];
        }
    }
    
    return result;
}

/// Parse comma-separated module list
private string[] parseModuleList(string modules)
{
    string[] result;
    
    foreach (mod; modules.split(","))
    {
        string trimmed = mod.strip;
        if (!trimmed.empty)
        {
            result ~= trimmed;
        }
    }
    
    return result;
}

/// Find all .cabal files in a directory
string[] findCabalFiles(string projectRoot)
{
    string[] cabalFiles;
    
    try
    {
        foreach (entry; dirEntries(projectRoot, "*.cabal", SpanMode.shallow))
        {
            if (entry.isFile)
            {
                cabalFiles ~= entry.name;
            }
        }
    }
    catch (Exception e)
    {
        Logger.warning("Failed to search for Cabal files: " ~ e.msg);
    }
    
    return cabalFiles;
}

