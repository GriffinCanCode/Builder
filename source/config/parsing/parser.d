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
import analysis.detection.inference;
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
    /// 
    /// Safety: This function is @trusted because:
    /// 1. File I/O (findBuildFiles, readText) is inherently @system
    /// 2. absolutePath() performs path normalization (system call)
    /// 3. SecurityValidator.isPathWithinBase() validates paths in findBuildFiles
    /// 4. All exceptions are caught and converted to Result types
    /// 5. Zero-config inference delegates to validated TargetInference
    /// 
    /// Invariants:
    /// - root path is converted to absolute path for consistency
    /// - All file paths are validated against workspace root in findBuildFiles
    /// - Parsing errors are accumulated via AggregationPolicy
    /// - Invalid files are skipped, valid ones are processed
    /// 
    /// What could go wrong:
    /// - Path traversal: prevented by validation in findBuildFiles
    /// - File read fails: exception caught, converted to BuildError
    /// - Malicious Builderfile: parser validates syntax, rejects invalid
    /// - Zero-config inference fails: caught and returned as error Result
    static Result!(WorkspaceConfig, BuildError) parseWorkspace(
        in string root,
        in AggregationPolicy policy = AggregationPolicy.CollectAll) @trusted
    {
        WorkspaceConfig config;
        config.root = absolutePath(root);
        
        // Find all Builderfile files
        auto buildFiles = findBuildFiles(root);
        
        // Zero-config mode: infer targets if no Builderfiles found
        if (buildFiles.empty)
        {
            Logger.info("No Builderfile found - attempting zero-config inference...");
            
            try
            {
                auto inference = new TargetInference(root);
                config.targets = inference.inferTargets();
                
                if (config.targets.empty)
                {
                    auto error = new ParseError(root, 
                        "No Builderfile found and no targets could be inferred", 
                        ErrorCode.ParseFailed);
                    error.addContext(ErrorContext("workspace initialization", 
                        "Run 'builder init' to create a Builderfile"));
                    return Err!(WorkspaceConfig, BuildError)(error);
                }
                
                Logger.success("Zero-config mode: inferred " ~ 
                    config.targets.length.to!string ~ " target(s)");
            }
            catch (Exception e)
            {
                auto error = new ParseError(root, 
                    "Failed to infer targets: " ~ e.msg, 
                    ErrorCode.ParseFailed);
                return Err!(WorkspaceConfig, BuildError)(error);
            }
        }
        else
        {
            Logger.debugLog("Found " ~ buildFiles.length.to!string ~ " Builderfile files");
            
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
                Logger.debugLog(
                    "Successfully parsed " ~ aggregated.successes.length.to!string ~
                    " target(s) from " ~ buildFiles.length.to!string ~ " Builderfile file(s)"
                );
            }
            
            // If policy is fail-fast and we have errors, return early
            if (policy == AggregationPolicy.FailFast && aggregated.hasErrors)
            {
                return Err!(WorkspaceConfig, BuildError)(aggregated.errors[0]);
            }
            
            // For zero-config mode check after parsing
            // Return success if we have at least one target or no errors
            // This allows partial success: some Builderfile files failed but others succeeded
            if (aggregated.hasSuccesses || !aggregated.hasErrors)
            {
                return Ok!(WorkspaceConfig, BuildError)(config);
            }
            
            // Complete failure - no targets parsed and we have errors
            if (aggregated.hasErrors)
            {
                return Err!(WorkspaceConfig, BuildError)(aggregated.errors[0]);
            }
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
        
        // For zero-config mode, we already have targets  
        if (buildFiles.empty && !config.targets.empty)
        {
            return Ok!(WorkspaceConfig, BuildError)(config);
        }
        
        // Should not reach here, but provide a fallback
        return Ok!(WorkspaceConfig, BuildError)(config);
    }
    
    /// Find all Builderfile files in directory tree
    private static string[] findBuildFiles(string root)
    {
        string[] buildFiles;
        
        if (!exists(root) || !isDir(root))
            return buildFiles;
        
        foreach (entry; dirEntries(root, SpanMode.depth))
        {
            // Validate entry is within root directory to prevent traversal attacks
            import utils.security.validation;
            if (!SecurityValidator.isPathWithinBase(entry.name, root))
                continue;
            
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
                    
                    // Validate all expanded sources are within workspace
                    foreach (source; target.sources)
                    {
                        import utils.security.validation;
                        if (!SecurityValidator.isPathWithinBase(source, root))
                        {
                            auto error = new ParseError(path, 
                                "Source file outside workspace: " ~ source, 
                                ErrorCode.InvalidFieldValue);
                            error.addContext(ErrorContext("validating sources", "path traversal detected"));
                            return Err!(Target[], BuildError)(error);
                        }
                    }
                    
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
            
            Logger.debugLog("Parsed Builderspace configuration successfully");
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
            case "kotlin": case "kt": return TargetLanguage.Kotlin;
            case "csharp": case "cs": case "c#": return TargetLanguage.CSharp;
            case "fsharp": case "fs": case "f#": return TargetLanguage.FSharp;
            case "zig": return TargetLanguage.Zig;
            case "swift": return TargetLanguage.Swift;
            case "ruby": case "rb": return TargetLanguage.Ruby;
            case "php": return TargetLanguage.PHP;
            case "scala": return TargetLanguage.Scala;
            case "elixir": case "ex": return TargetLanguage.Elixir;
            case "nim": return TargetLanguage.Nim;
            case "lua": return TargetLanguage.Lua;
            case "r": return TargetLanguage.R;
            case "css": return TargetLanguage.CSS;
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
            case ".js": case ".jsx": case ".mjs": return TargetLanguage.JavaScript;
            case ".ts": case ".tsx": return TargetLanguage.TypeScript;
            case ".go": return TargetLanguage.Go;
            case ".rs": return TargetLanguage.Rust;
            case ".cpp": case ".cc": case ".cxx": case ".c++": case ".hpp": case ".hxx": return TargetLanguage.Cpp;
            case ".c": case ".h": return TargetLanguage.C;
            case ".java": return TargetLanguage.Java;
            case ".kt": case ".kts": return TargetLanguage.Kotlin;
            case ".cs": return TargetLanguage.CSharp;
            case ".fs": case ".fsi": case ".fsx": return TargetLanguage.FSharp;
            case ".zig": return TargetLanguage.Zig;
            case ".swift": return TargetLanguage.Swift;
            case ".rb": return TargetLanguage.Ruby;
            case ".php": return TargetLanguage.PHP;
            case ".scala": case ".sc": return TargetLanguage.Scala;
            case ".ex": case ".exs": return TargetLanguage.Elixir;
            case ".nim": return TargetLanguage.Nim;
            case ".lua": return TargetLanguage.Lua;
            case ".r": case ".R": return TargetLanguage.R;
            case ".css": case ".scss": case ".sass": case ".less": return TargetLanguage.CSS;
            default: return TargetLanguage.Generic;
        }
    }
    
    /// Expand glob patterns to actual files
    private static string[] expandGlobs(string[] patterns, string baseDir)
    {
        return glob(patterns, baseDir);
    }
}

