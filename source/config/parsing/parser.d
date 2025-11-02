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
import languages.registry;

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
    /// Safety: This function is @system because:
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
        in AggregationPolicy policy = AggregationPolicy.CollectAll) @system
    {
        WorkspaceConfig config;
        config.root = absolutePath(root);
        
        // Find all Builderfile files
        auto buildFiles = findBuildFiles(root);
        
        // Zero-config mode: infer targets if no Builderfiles found
        if (buildFiles.empty)
        {
            Logger.info("═══════════════════════════════════════════");
            Logger.info("  MODE: Zero-Config (No Builderfile found)");
            Logger.info("═══════════════════════════════════════════");
            Logger.info("Attempting automatic target inference...");
            
            try
            {
                auto inference = new TargetInference(root);
                config.targets = inference.inferTargets();
                
                if (config.targets.empty)
                {
                    auto error = new ParseError(root, 
                        "No Builderfile found and no build targets could be automatically inferred", 
                        ErrorCode.ParseFailed);
                    error.addContext(ErrorContext("workspace initialization", 
                        "Run 'builder init' to create a Builderfile"));
                    error.addSuggestion("Run 'builder init' to create a Builderfile with example targets");
                    error.addSuggestion("Add a Builderfile manually - see docs/user-guides/CLI.md");
                    error.addSuggestion("Ensure your project has recognizable source files (*.py, *.js, *.d, etc.)");
                    error.addSuggestion("Check examples/ directory for language-specific configurations");
                    return Err!(WorkspaceConfig, BuildError)(error);
                }
                
                Logger.success("Zero-config mode: inferred " ~ 
                    config.targets.length.to!string ~ " target(s)");
            }
            catch (Exception e)
            {
                auto error = new ParseError(root, 
                    "Failed to automatically infer build targets: " ~ e.msg, 
                    ErrorCode.ParseFailed);
                error.addSuggestion("Create a Builderfile manually: builder init");
                error.addSuggestion("Check that your project structure is supported");
                error.addSuggestion("See docs/user-guides/CLI.md for configuration help");
                return Err!(WorkspaceConfig, BuildError)(error);
            }
        }
        else
        {
            Logger.info("═══════════════════════════════════════════");
            Logger.info("  MODE: Builderfile (" ~ buildFiles.length.to!string ~ " file(s) found)");
            Logger.info("═══════════════════════════════════════════");
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
                Logger.success(
                    "Successfully parsed " ~ aggregated.successes.length.to!string ~
                    " target(s) from " ~ buildFiles.length.to!string ~ " Builderfile file(s)"
                );
            }
            else if (aggregated.hasErrors && !aggregated.hasSuccesses)
            {
                Logger.error("All Builderfile files failed to parse");
                Logger.info("Consider fixing errors or removing invalid Builderfiles");
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
                                "Security violation: Source file references path outside workspace: " ~ source, 
                                ErrorCode.InvalidFieldValue);
                            error.addSuggestion("Ensure all source paths are within the project workspace");
                            error.addSuggestion("Use relative paths instead of absolute paths");
                            error.addSuggestion("Check for '..' in paths that escape the workspace");
                            error.addSuggestion("Copy external files into the workspace if needed");
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
            // Use builder pattern for type-safe error construction with structured suggestions
            import errors.types.context : ErrorSuggestion;
            
            auto error = ErrorBuilder!ParseError.create(path, "Invalid JSON syntax in Builderfile: " ~ e.msg, ErrorCode.InvalidJson)
                .withContext("parsing JSON", "invalid JSON syntax")
                .withCommand("Validate JSON syntax", "jsonlint " ~ path)
                .withDocs("JSON linter online", "https://jsonlint.com")
                .withFileCheck("Check for missing commas, brackets, or quotes")
                .withFileCheck("Ensure all strings are properly escaped")
                .withSuggestion("Use a JSON-aware editor (VSCode, Sublime, etc.)")
                .build();
            
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
        catch (FileException e)
        {
            // Use smart constructor with built-in context-aware suggestions
            auto error = fileReadError(path, e.msg, "reading Builderfile");
            Logger.error(format(error));
            return Err!(Target[], BuildError)(error);
        }
        catch (Exception e)
        {
            // Use smart parse error constructor with automatic suggestions
            auto error = parseErrorWithContext(path, "Failed to parse Builderfile: " ~ e.msg, 0, "parsing Builderfile file");
            error.addContext(ErrorContext("", baseName(path)));
            error.addSuggestion("Check the Builderfile syntax and structure");
            error.addSuggestion("See docs/user-guides/CLI.md for valid configuration format");
            error.addSuggestion("Review examples in the examples/ directory");
            error.addSuggestion("Validate JSON syntax if using JSON format");
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
            // Use smart constructor - automatically includes appropriate suggestions
            auto error = fileReadError(path, e.msg, "reading Builderspace file");
            error.addSuggestion("Ensure the Builderspace file exists");
            return Result!BuildError.err(error);
        }
        catch (Exception e)
        {
            // Use smart parse error constructor with Builderspace-specific suggestions
            auto error = parseErrorWithContext(path, "Failed to parse Builderspace file: " ~ e.msg, 0, "parsing Builderspace file");
            return Result!BuildError.err(error);
        }
    }
    
    /// Parse language from string - delegates to centralized registry
    private static TargetLanguage parseLanguage(string lang)
    {
        return parseLanguageName(lang);
    }
    
    /// Infer language from file extensions - delegates to centralized registry
    private static TargetLanguage inferLanguage(string[] sources)
    {
        if (sources.empty)
            return TargetLanguage.Generic;
        
        string ext = extension(sources[0]);
        return inferLanguageFromExtension(ext);
    }
    
    /// Expand glob patterns to actual files
    private static string[] expandGlobs(string[] patterns, string baseDir)
    {
        return glob(patterns, baseDir);
    }
}

