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

/// Parse Builderfile files and workspace configuration
class ConfigParser
{
    /// Parse entire workspace starting from root
    /// Returns Result with WorkspaceConfig and accumulated errors
    /// 
    /// By default, uses CollectAll policy to gather all parsing errors
    /// while still loading valid Builderfile files. This maximizes information
    /// available to the caller.
    static Result!(WorkspaceConfig, BuildError) parseWorkspace(
        in string root,
        in AggregationPolicy policy = AggregationPolicy.CollectAll) @trusted
    {
        WorkspaceConfig config;
        config.root = absolutePath(root);
        
        // Find all Builderfile files
        auto buildFiles = findBuildFiles(root);
        Logger.debug_("Found " ~ buildFiles.length.to!string ~ " Builderfile files");
        
        // Parse each Builderfile with error aggregation
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
                " Builderfile file(s)"
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
                " target(s) from " ~ buildFiles.length.to!string ~ " Builderfile file(s)"
            );
        }
        
        // If policy is fail-fast and we have errors, return early
        if (policy == AggregationPolicy.FailFast && aggregated.hasErrors)
        {
            return Err!(WorkspaceConfig, BuildError)(aggregated.errors[0]);
        }
        
        // Load workspace config if exists
        string workspaceFile = buildPath(root, "Builderspace");
        if (exists(workspaceFile))
        {
            auto wsResult = parseWorkspaceFile(workspaceFile, config);
            if (wsResult.isErr)
            {
                auto error = wsResult.unwrapErr();
                Logger.error("Failed to parse Builderspace file");
                import errors.formatting.format : format;
                Logger.error(format(error));
                
                // For fail-fast policy, return immediately
                if (policy == AggregationPolicy.FailFast)
                {
                    return Err!(WorkspaceConfig, BuildError)(error);
                }
                
                // For other policies, this is a fatal error since Builderspace
                // config affects all targets
                if (policy == AggregationPolicy.StopAtFatal && !error.recoverable())
                {
                    return Err!(WorkspaceConfig, BuildError)(error);
                }
            }
        }
        
        // Return success if we have at least one target or no errors
        // This allows partial success: some Builderfile files failed but others succeeded
        if (aggregated.hasSuccesses || !aggregated.hasErrors)
        {
            return Ok!(WorkspaceConfig, BuildError)(config);
        }
        
        // Complete failure - no targets parsed and we have errors
        return Err!(WorkspaceConfig, BuildError)(aggregated.errors[0]);
    }
    
    /// Find all Builderfile files in directory tree
    private static string[] findBuildFiles(string root)
    {
        string[] buildFiles;
        
        if (!exists(root) || !isDir(root))
            return buildFiles;
        
        foreach (entry; dirEntries(root, SpanMode.depth))
        {
            if (entry.isFile && entry.name.baseName == "Builderfile")
                buildFiles ~= entry.name;
        }
        
        return buildFiles;
    }
    
    /// Parse a single Builderfile file - returns Result type for type-safe error handling
    private static Result!(Target[], BuildError) parseBuildFile(string path, string root)
    {
        try
        {
            Target[] targets;
            
            // Use D-based DSL parser
            auto content = readText(path);
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
            error.addContext(ErrorContext("reading Builderfile file"));
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
        catch (Exception e)
        {
            auto error = new ParseError(path, e.msg, ErrorCode.ParseFailed);
            error.addContext(ErrorContext("parsing Builderfile file", baseName(path)));
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
    }
    
    /// Parse workspace-level configuration
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
            
            Logger.debug_("Parsed Builderspace configuration successfully");
            return Result!BuildError.ok();
        }
        catch (FileException e)
        {
            auto error = new IOError(path, e.msg, ErrorCode.FileReadFailed);
            error.addContext(ErrorContext("reading Builderspace file"));
            return Result!BuildError.err(error);
        }
        catch (Exception e)
        {
            auto error = new ParseError(path, e.msg, ErrorCode.ParseFailed);
            error.addContext(ErrorContext("parsing Builderspace file"));
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

