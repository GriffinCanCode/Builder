module languages.compiled.d.analysis.manifest;

import std.stdio;
import std.file;
import std.path;
import std.json;
import std.string;
import std.algorithm;
import std.array;
import utils.logging.logger;

/// DUB package manifest information
struct PackageManifest
{
    string name;
    string version_;
    string description;
    string[] authors;
    string license;
    string copyright;
    string homepage;
    string[] sourcePaths;
    string[] importPaths;
    string targetType;
    string targetName;
    string targetPath;
    string mainSourceFile;
    string[string] dependencies;
    string[string] configurations;
    string[string] buildTypes;
    string[string] subPackages;
}

/// DUB manifest parser (supports both JSON and SDL formats)
class DubManifest
{
    /// Find dub.json or dub.sdl in source directories or parent directories
    static string findManifest(string[] sources)
    {
        if (sources.empty)
            return "";
        
        // Get directory of first source
        string dir = dirName(sources[0]);
        if (dir.empty || dir == ".")
            dir = getcwd();
        
        // Search up the directory tree
        string currentDir = dir;
        for (int i = 0; i < 10; i++) // Limit search depth
        {
            // Check for dub.json
            string jsonPath = buildPath(currentDir, "dub.json");
            if (exists(jsonPath) && isFile(jsonPath))
            {
                return jsonPath;
            }
            
            // Check for dub.sdl
            string sdlPath = buildPath(currentDir, "dub.sdl");
            if (exists(sdlPath) && isFile(sdlPath))
            {
                return sdlPath;
            }
            
            // Move up one directory
            string parent = dirName(currentDir);
            if (parent == currentDir) // Reached root
                break;
            currentDir = parent;
        }
        
        return "";
    }
    
    /// Parse DUB manifest file
    static PackageManifest parse(string manifestPath)
    {
        if (!exists(manifestPath))
        {
            throw new Exception("Manifest file not found: " ~ manifestPath);
        }
        
        string ext = extension(manifestPath).toLower();
        
        if (ext == ".json")
        {
            return parseJSON(manifestPath);
        }
        else if (ext == ".sdl")
        {
            return parseSDL(manifestPath);
        }
        else
        {
            throw new Exception("Unknown manifest format: " ~ ext);
        }
    }
    
    /// Parse dub.json format
    private static PackageManifest parseJSON(string path)
    {
        PackageManifest manifest;
        
        try
        {
            string content = readText(path);
            JSONValue json = std.json.parseJSON(content);
            
            if ("name" in json)
                manifest.name = json["name"].str;
            if ("version" in json)
                manifest.version_ = json["version"].str;
            if ("description" in json)
                manifest.description = json["description"].str;
            if ("license" in json)
                manifest.license = json["license"].str;
            if ("copyright" in json)
                manifest.copyright = json["copyright"].str;
            if ("homepage" in json)
                manifest.homepage = json["homepage"].str;
            if ("mainSourceFile" in json)
                manifest.mainSourceFile = json["mainSourceFile"].str;
            if ("targetType" in json)
                manifest.targetType = json["targetType"].str;
            if ("targetName" in json)
                manifest.targetName = json["targetName"].str;
            if ("targetPath" in json)
                manifest.targetPath = json["targetPath"].str;
            
            // Authors
            if ("authors" in json && json["authors"].type == JSONType.array)
            {
                foreach (author; json["authors"].array)
                {
                    manifest.authors ~= author.str;
                }
            }
            
            // Source paths
            if ("sourcePaths" in json && json["sourcePaths"].type == JSONType.array)
            {
                foreach (p; json["sourcePaths"].array)
                {
                    manifest.sourcePaths ~= p.str;
                }
            }
            
            // Import paths
            if ("importPaths" in json && json["importPaths"].type == JSONType.array)
            {
                foreach (p; json["importPaths"].array)
                {
                    manifest.importPaths ~= p.str;
                }
            }
            
            // Dependencies
            if ("dependencies" in json && json["dependencies"].type == JSONType.object)
            {
                foreach (string name, value; json["dependencies"].object)
                {
                    if (value.type == JSONType.string)
                    {
                        manifest.dependencies[name] = value.str;
                    }
                    else if (value.type == JSONType.object && "version" in value)
                    {
                        manifest.dependencies[name] = value["version"].str;
                    }
                }
            }
            
            // Configurations
            if ("configurations" in json && json["configurations"].type == JSONType.array)
            {
                foreach (config; json["configurations"].array)
                {
                    if (config.type == JSONType.object && "name" in config)
                    {
                        string configName = config["name"].str;
                        manifest.configurations[configName] = configName;
                    }
                }
            }
            
            // Sub-packages
            if ("subPackages" in json && json["subPackages"].type == JSONType.array)
            {
                foreach (sub; json["subPackages"].array)
                {
                    if (sub.type == JSONType.string)
                    {
                        manifest.subPackages[sub.str] = sub.str;
                    }
                    else if (sub.type == JSONType.object && "name" in sub)
                    {
                        string subName = sub["name"].str;
                        manifest.subPackages[subName] = subName;
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse dub.json: " ~ e.msg);
        }
        
        return manifest;
    }
    
    /// Parse dub.sdl format (simplified - basic support)
    private static PackageManifest parseSDL(string path)
    {
        PackageManifest manifest;
        
        try
        {
            string content = readText(path);
            
            foreach (line; content.split("\n"))
            {
                string trimmed = line.strip();
                
                // Skip comments and empty lines
                if (trimmed.empty || trimmed.startsWith("//") || trimmed.startsWith("#"))
                    continue;
                
                // Simple key-value parsing
                if (trimmed.startsWith("name "))
                {
                    manifest.name = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("version "))
                {
                    manifest.version_ = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("description "))
                {
                    manifest.description = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("license "))
                {
                    manifest.license = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("copyright "))
                {
                    manifest.copyright = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("homepage "))
                {
                    manifest.homepage = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("targetType "))
                {
                    manifest.targetType = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("targetName "))
                {
                    manifest.targetName = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("targetPath "))
                {
                    manifest.targetPath = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("mainSourceFile "))
                {
                    manifest.mainSourceFile = parseSDLValue(trimmed);
                }
                else if (trimmed.startsWith("dependency "))
                {
                    auto parts = parseSDLDependency(trimmed);
                    if (parts.length >= 2)
                    {
                        manifest.dependencies[parts[0]] = parts[1];
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse dub.sdl: " ~ e.msg);
        }
        
        return manifest;
    }
    
    /// Parse value from SDL line
    private static string parseSDLValue(string line)
    {
        auto parts = line.split();
        if (parts.length < 2)
            return "";
        
        string value = parts[1..$].join(" ");
        
        // Remove quotes
        if (value.startsWith("\"") && value.endsWith("\""))
        {
            value = value[1..$-1];
        }
        
        return value;
    }
    
    /// Parse dependency from SDL line
    private static string[] parseSDLDependency(string line)
    {
        // dependency "name" version="version"
        auto parts = line.split();
        if (parts.length < 2)
            return [];
        
        string name = parts[1].strip("\"");
        string ver = "";
        
        if (parts.length >= 3 && parts[2].startsWith("version="))
        {
            ver = parts[2]["version=".length..$].strip("\"");
        }
        
        return [name, ver];
    }
}


