module config.parser;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import std.json;
import config.schema;
import utils.logger;

/// Parse BUILD files and workspace configuration
class ConfigParser
{
    /// Parse entire workspace starting from root
    static WorkspaceConfig parseWorkspace(string root)
    {
        WorkspaceConfig config;
        config.root = absolutePath(root);
        
        // Find all BUILD files
        auto buildFiles = findBuildFiles(root);
        Logger.debug_("Found " ~ buildFiles.length.to!string ~ " BUILD files");
        
        // Parse each BUILD file
        foreach (buildFile; buildFiles)
        {
            auto targets = parseBuildFile(buildFile, root);
            config.targets ~= targets;
        }
        
        // Load workspace config if exists
        string workspaceFile = buildPath(root, "WORKSPACE");
        if (exists(workspaceFile))
        {
            parseWorkspaceFile(workspaceFile, config);
        }
        
        return config;
    }
    
    /// Find all BUILD files in directory tree
    private static string[] findBuildFiles(string root)
    {
        string[] buildFiles;
        
        if (!exists(root) || !isDir(root))
            return buildFiles;
        
        foreach (entry; dirEntries(root, SpanMode.depth))
        {
            if (entry.isFile && (entry.name.baseName == "BUILD" || entry.name.baseName == "BUILD.json"))
                buildFiles ~= entry.name;
        }
        
        return buildFiles;
    }
    
    /// Parse a single BUILD file
    private static Target[] parseBuildFile(string path, string root)
    {
        Target[] targets;
        
        try
        {
            // For now, support JSON-based BUILD files
            if (path.endsWith(".json"))
            {
                targets = parseJsonBuildFile(path, root);
            }
            else
            {
                // Try JSON first, then fall back to DSL parser
                auto content = readText(path);
                if (content.strip.startsWith("{") || content.strip.startsWith("["))
                {
                    targets = parseJsonBuildFile(path, root);
                }
                else
                {
                    // TODO: Implement D-based DSL parser
                    Logger.warning("D-based BUILD files not yet supported: " ~ path);
                }
            }
        }
        catch (Exception e)
        {
            Logger.error("Failed to parse " ~ path ~ ": " ~ e.msg);
        }
        
        return targets;
    }
    
    /// Parse JSON-based BUILD file
    private static Target[] parseJsonBuildFile(string path, string root)
    {
        Target[] targets;
        
        auto content = readText(path);
        auto json = parseJSON(content);
        
        // Support both single target and array of targets
        JSONValue[] targetJsons;
        if (json.type == JSONType.array)
            targetJsons = json.array;
        else
            targetJsons = [json];
        
        string dir = dirName(path);
        string relativeDir = relativePath(dir, root);
        
        foreach (targetJson; targetJsons)
        {
            Target target;
            
            target.name = "//" ~ relativeDir ~ ":" ~ targetJson["name"].str;
            
            // Parse type
            string typeStr = targetJson["type"].str;
            switch (typeStr.toLower)
            {
                case "executable": target.type = TargetType.Executable; break;
                case "library": target.type = TargetType.Library; break;
                case "test": target.type = TargetType.Test; break;
                default: target.type = TargetType.Custom; break;
            }
            
            // Parse language
            if ("language" in targetJson)
            {
                string langStr = targetJson["language"].str;
                target.language = parseLanguage(langStr);
            }
            else
            {
                // Infer from sources
                target.language = inferLanguage(targetJson["sources"].array.map!(s => s.str).array);
            }
            
            // Parse sources (support globs)
            target.sources = expandGlobs(
                targetJson["sources"].array.map!(s => s.str).array,
                dir
            );
            
            // Parse dependencies
            if ("deps" in targetJson)
            {
                target.deps = targetJson["deps"].array.map!(d => d.str).array;
            }
            
            // Parse environment
            if ("env" in targetJson)
            {
                foreach (key, value; targetJson["env"].object)
                    target.env[key] = value.str;
            }
            
            // Parse flags
            if ("flags" in targetJson)
            {
                target.flags = targetJson["flags"].array.map!(f => f.str).array;
            }
            
            // Parse output path
            if ("output" in targetJson)
            {
                target.outputPath = targetJson["output"].str;
            }
            
            targets ~= target;
        }
        
        return targets;
    }
    
    /// Parse workspace-level configuration
    private static void parseWorkspaceFile(string path, ref WorkspaceConfig config)
    {
        // TODO: Implement workspace config parsing
    }
    
    /// Parse language from string
    private static TargetLanguage parseLanguage(string lang)
    {
        switch (lang.toLower)
        {
            case "d": return TargetLanguage.D;
            case "python": case "py": return TargetLanguage.Python;
            case "javascript": case "js": return TargetLanguage.JavaScript;
            case "typescript": case "ts": return TargetLanguage.TypeScript;
            case "go": return TargetLanguage.Go;
            case "rust": case "rs": return TargetLanguage.Rust;
            case "c++": case "cpp": return TargetLanguage.Cpp;
            case "c": return TargetLanguage.C;
            case "java": return TargetLanguage.Java;
            default: return TargetLanguage.Generic;
        }
    }
    
    /// Infer language from file extensions
    private static TargetLanguage inferLanguage(string[] sources)
    {
        if (sources.empty)
            return TargetLanguage.Generic;
        
        string ext = extension(sources[0]);
        
        switch (ext)
        {
            case ".d": return TargetLanguage.D;
            case ".py": return TargetLanguage.Python;
            case ".js": return TargetLanguage.JavaScript;
            case ".ts": return TargetLanguage.TypeScript;
            case ".go": return TargetLanguage.Go;
            case ".rs": return TargetLanguage.Rust;
            case ".cpp": case ".cc": case ".cxx": return TargetLanguage.Cpp;
            case ".c": return TargetLanguage.C;
            case ".java": return TargetLanguage.Java;
            default: return TargetLanguage.Generic;
        }
    }
    
    /// Expand glob patterns to actual files
    private static string[] expandGlobs(string[] patterns, string baseDir)
    {
        import std.regex;
        
        string[] files;
        
        foreach (pattern; patterns)
        {
            string fullPattern = buildPath(baseDir, pattern);
            
            // Simple glob support
            if (pattern.canFind("*"))
            {
                // Convert glob to regex
                string dir = dirName(fullPattern);
                string filePattern = baseName(fullPattern);
                
                if (!exists(dir) || !isDir(dir))
                    continue;
                
                import std.array : replace;
                
                auto regex_pattern = filePattern
                    .replace(".", `\.`)
                    .replace("*", ".*")
                    .replace("?", ".");
                
                auto re = regex("^" ~ regex_pattern ~ "$");
                
                foreach (entry; dirEntries(dir, SpanMode.shallow))
                {
                    if (entry.isFile && matchFirst(entry.name.baseName, re))
                        files ~= entry.name;
                }
            }
            else
            {
                // Direct file reference
                if (exists(fullPattern))
                    files ~= fullPattern;
            }
        }
        
        return files;
    }
}

