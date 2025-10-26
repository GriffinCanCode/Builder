module config.parsing.parser;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import std.json;
import config.schema.schema;
import config.interpretation.dsl;
import config.workspace.workspace;
import utils.logging.logger;
import utils.files.glob;
import errors;

/// Parse BUILD files and workspace configuration
class ConfigParser
{
    /// Parse entire workspace starting from root
    /// Returns Result with WorkspaceConfig and accumulated errors
    /// 
    /// By default, uses CollectAll policy to gather all parsing errors
    /// while still loading valid BUILD files. This maximizes information
    /// available to the caller.
    static Result!(WorkspaceConfig, BuildError) parseWorkspace(
        string root,
        AggregationPolicy policy = AggregationPolicy.CollectAll)
    {
        WorkspaceConfig config;
        config.root = absolutePath(root);
        
        // Find all BUILD files
        auto buildFiles = findBuildFiles(root);
        Logger.debug_("Found " ~ buildFiles.length.to!string ~ " BUILD files");
        
        // Parse each BUILD file with error aggregation
        auto aggregated = aggregateFlatMap(
            buildFiles,
            (string buildFile) => parseBuildFile(buildFile, root),
            policy
        );
        
        // Log results
        if (aggregated.hasErrors)
        {
            Logger.warning(
                "Failed to parse " ~ aggregated.errors.length.to!string ~
                " BUILD file(s)"
            );
            
            // Log each error with full context
            import errors.formatting.format : format;
            foreach (error; aggregated.errors)
            {
                Logger.error(format(error));
            }
        }
        
        if (aggregated.hasSuccesses)
        {
            config.targets = aggregated.successes;
            Logger.debug_(
                "Successfully parsed " ~ aggregated.successes.length.to!string ~
                " target(s) from " ~ buildFiles.length.to!string ~ " BUILD file(s)"
            );
        }
        
        // If policy is fail-fast and we have errors, return early
        if (policy == AggregationPolicy.FailFast && aggregated.hasErrors)
        {
            return Err!(WorkspaceConfig, BuildError)(aggregated.errors[0]);
        }
        
        // Load workspace config if exists
        string workspaceFile = buildPath(root, "WORKSPACE");
        if (exists(workspaceFile))
        {
            auto wsResult = parseWorkspaceFile(workspaceFile, config);
            if (wsResult.isErr)
            {
                auto error = wsResult.unwrapErr();
                Logger.error("Failed to parse WORKSPACE file");
                import errors.formatting.format : format;
                Logger.error(format(error));
                
                // For fail-fast policy, return immediately
                if (policy == AggregationPolicy.FailFast)
                {
                    return Err!(WorkspaceConfig, BuildError)(error);
                }
                
                // For other policies, this is a fatal error since WORKSPACE
                // config affects all targets
                if (policy == AggregationPolicy.StopAtFatal && !error.recoverable())
                {
                    return Err!(WorkspaceConfig, BuildError)(error);
                }
            }
        }
        
        // Return success if we have at least one target or no errors
        // This allows partial success: some BUILD files failed but others succeeded
        if (aggregated.hasSuccesses || !aggregated.hasErrors)
        {
            return Ok!(WorkspaceConfig, BuildError)(config);
        }
        
        // Complete failure - no targets parsed and we have errors
        return Err!(WorkspaceConfig, BuildError)(aggregated.errors[0]);
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
    
    /// Parse a single BUILD file - returns Result type for type-safe error handling
    private static Result!(Target[], BuildError) parseBuildFile(string path, string root)
    {
        try
        {
            Target[] targets;
            
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
                    // Use D-based DSL parser
                    auto dslResult = parseDSL(content, path, root);
                    if (dslResult.isOk)
                    {
                        targets = dslResult.unwrap();
                        
                        // Resolve glob patterns in sources
                        string dir = dirName(path);
                        foreach (ref target; targets)
                        {
                            target.sources = expandGlobs(target.sources, dir);
                            
                            // Generate full target name
                            string relativeDir = relativePath(dir, root);
                            target.name = "//" ~ relativeDir ~ ":" ~ target.name;
                        }
                    }
                    else
                    {
                        // Return the error from DSL parser
                        return Err!(Target[], BuildError)(dslResult.unwrapErr());
                    }
                }
            }
            
            return Ok!(Target[], BuildError)(targets);
        }
        catch (JSONException e)
        {
            auto error = new ParseError(path, e.msg, ErrorCode.InvalidJson);
            error.addContext(ErrorContext("parsing JSON", "invalid JSON syntax"));
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
        catch (FileException e)
        {
            auto error = new IOError(path, e.msg, ErrorCode.FileReadFailed);
            error.addContext(ErrorContext("reading BUILD file"));
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
        catch (Exception e)
        {
            auto error = new ParseError(path, e.msg, ErrorCode.ParseFailed);
            error.addContext(ErrorContext("parsing BUILD file", baseName(path)));
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
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
            
            // Parse language-specific configuration
            // Support both "config" (general) and language-specific keys (jsConfig, pyConfig, etc.)
            if ("config" in targetJson)
            {
                import std.json : toJSON;
                string configKey = target.language.to!string.toLower;
                target.langConfig[configKey] = targetJson["config"].toJSON();
            }
            // Backward compatibility: support language-specific config names
            if ("jsConfig" in targetJson)
            {
                import std.json : toJSON;
                target.langConfig["javascript"] = targetJson["jsConfig"].toJSON();
            }
            if ("pyConfig" in targetJson)
            {
                import std.json : toJSON;
                target.langConfig["python"] = targetJson["pyConfig"].toJSON();
            }
            if ("goConfig" in targetJson)
            {
                import std.json : toJSON;
                target.langConfig["go"] = targetJson["goConfig"].toJSON();
            }
            
            targets ~= target;
        }
        
        return targets;
    }
    
    /// Parse workspace-level configuration (DSL format only)
    /// Returns Result to allow proper error propagation
    private static Result!BuildError parseWorkspaceFile(string path, ref WorkspaceConfig config)
    {
        try
        {
            auto content = readText(path);
            auto result = parseWorkspaceDSL(content, path, config);
            
            if (result.isErr)
            {
                return result;
            }
            
            Logger.debug_("Parsed WORKSPACE configuration successfully");
            return Result!BuildError.ok();
        }
        catch (FileException e)
        {
            auto error = new IOError(path, e.msg, ErrorCode.FileReadFailed);
            error.addContext(ErrorContext("reading WORKSPACE file"));
            return Result!BuildError.err(error);
        }
        catch (Exception e)
        {
            auto error = new ParseError(path, e.msg, ErrorCode.ParseFailed);
            error.addContext(ErrorContext("parsing WORKSPACE file"));
            return Result!BuildError.err(error);
        }
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
        return glob(patterns, baseDir);
    }
}

