module errors.formatting.format;

import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.format : formattedWrite;
import errors.types.types;
import errors.handling.codes;
import errors.types.context : ErrorSuggestion, ErrorContext;

private import std.string : sformat = format;

/// ANSI color codes for terminal output
private enum Color : string
{
    Reset = "\x1b[0m",
    Bold = "\x1b[1m",
    Red = "\x1b[31m",
    Green = "\x1b[32m",
    Yellow = "\x1b[33m",
    Blue = "\x1b[36m",
    Gray = "\x1b[90m"
}

/// Formatting options for error display
struct FormatOptions
{
    bool colors = true;        // Use ANSI colors
    bool showCode = true;      // Show error code
    bool showCategory = true;  // Show error category
    bool showContexts = true;  // Show context chain
    bool showSuggestions = true; // Show helpful suggestions
    bool showTimestamp = false; // Show timestamps
    size_t maxWidth = 80;      // Max line width
}

/// Format error for display
string format(const BuildError error, FormatOptions opts = FormatOptions.init)
{
    import std.array : appender;
    auto result = appender!string;
    result.reserve(256); // Reserve capacity for typical error message
    
    // Header with category and code
    if (opts.showCategory)
    {
        if (opts.colors)
            result.put(cast(string)(Color.Bold ~ Color.Red));
        
        result.put("[");
        result.put(error.category().to!string);
        
        if (opts.showCode)
        {
            result.put(":");
            result.put(error.code().to!string);
        }
        
        result.put("]");
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
        
        result.put(" ");
    }
    
    // Main message
    if (opts.colors)
        result.put(cast(string)Color.Red);
    result.put(error.message());
    if (opts.colors)
        result.put(cast(string)Color.Reset);
    
    result.put("\n");
    
    // Context chain
    if (opts.showContexts)
    {
        foreach (ctx; error.contexts())
        {
            if (opts.colors)
                result.put(cast(string)Color.Gray);
            result.put("  → ");
            result.put(ctx.toString());
            result.put("\n");
            if (opts.colors)
                result.put(cast(string)Color.Reset);
        }
    }
    
    // Type-specific formatting
    result.put(formatSpecific(error, opts));
    
    // Add suggestions
    if (opts.showSuggestions)
    {
        import std.algorithm : uniq;
        import std.array : array;
        import errors.types.context : ErrorSuggestion;
        
        // Try to get typed suggestions from the error
        const(ErrorSuggestion)[] typedSuggestions;
        if (auto baseErr = cast(const BaseBuildError)error)
        {
            typedSuggestions = baseErr.suggestions();
        }
        
        // If we have typed suggestions, format them nicely
        if (!typedSuggestions.empty)
        {
            result.put("\n");
            if (opts.colors)
                result.put(cast(string)(Color.Bold ~ Color.Yellow));
            result.put("Suggestions:\n");
            if (opts.colors)
                result.put(cast(string)Color.Reset);
            
            // Track seen suggestions to avoid duplicates
            bool[string] seen;
            foreach (suggestion; typedSuggestions)
            {
                string formatted = formatSuggestion(suggestion, opts);
                if (formatted !in seen)
                {
                    seen[formatted] = true;
                    result.put(formatted);
                }
            }
        }
        else
        {
            // Fallback to generic suggestions if no typed suggestions
            string[] suggestions = suggestFixes(error);
            if (!suggestions.empty)
            {
                result.put("\n");
                if (opts.colors)
                    result.put(cast(string)(Color.Bold ~ Color.Yellow));
                result.put("Suggestions:\n");
                if (opts.colors)
                    result.put(cast(string)Color.Reset);
                
                bool[string] seen;
                foreach (suggestion; suggestions)
                {
                    if (suggestion !in seen)
                    {
                        seen[suggestion] = true;
                        if (opts.colors)
                            result.put(cast(string)Color.Yellow);
                        result.put("  • ");
                        result.put(suggestion);
                        result.put("\n");
                        if (opts.colors)
                            result.put(cast(string)Color.Reset);
                    }
                }
            }
        }
    }
    
    return result.data;
}

/// Format a single suggestion with type-specific styling
string formatSuggestion(const ErrorSuggestion suggestion, FormatOptions opts)
{
    import std.array : appender;
    
    auto result = appender!string;
    
    // Bullet point
    if (opts.colors)
        result.put(cast(string)Color.Yellow);
    result.put("  • ");
    
    // Icon/prefix based on type
    final switch (suggestion.type)
    {
        case ErrorSuggestion.Type.Command:
            if (opts.colors)
                result.put(cast(string)Color.Green);
            result.put("Run: ");
            if (opts.colors)
                result.put(cast(string)Color.Reset);
            break;
        case ErrorSuggestion.Type.Documentation:
            if (opts.colors)
                result.put(cast(string)Color.Blue);
            result.put("Docs: ");
            if (opts.colors)
                result.put(cast(string)Color.Reset);
            break;
        case ErrorSuggestion.Type.FileCheck:
            if (opts.colors)
                result.put(cast(string)Color.Yellow);
            result.put("Check: ");
            if (opts.colors)
                result.put(cast(string)Color.Reset);
            break;
        case ErrorSuggestion.Type.Configuration:
            if (opts.colors)
                result.put(cast(string)Color.Yellow);
            result.put("Config: ");
            if (opts.colors)
                result.put(cast(string)Color.Reset);
            break;
        case ErrorSuggestion.Type.General:
            break;
    }
    
    // Message
    result.put(suggestion.message);
    
    // Detail (command, URL, etc.)
    if (!suggestion.detail.empty)
    {
        result.put("\n    ");
        if (opts.colors)
            result.put(cast(string)Color.Gray);
        
        final switch (suggestion.type)
        {
            case ErrorSuggestion.Type.Command:
                result.put("$ ");
                result.put(suggestion.detail);
                break;
            case ErrorSuggestion.Type.Documentation:
                result.put("→ ");
                result.put(suggestion.detail);
                break;
            case ErrorSuggestion.Type.FileCheck:
            case ErrorSuggestion.Type.Configuration:
            case ErrorSuggestion.Type.General:
                result.put(suggestion.detail);
                break;
        }
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
    }
    
    result.put("\n");
    
    if (opts.colors)
        result.put(cast(string)Color.Reset);
    
    return result.data;
}

/// Format type-specific error details
private string formatSpecific(const BuildError error, FormatOptions opts)
{
    import std.traits : hasMember;
    import std.array : appender;
    
    auto result = appender!string;
    result.reserve(128);
    
    // Try to cast to known types for additional formatting
    if (auto buildErr = cast(const BuildFailureError)error)
    {
        if (opts.colors)
            result.put(cast(string)Color.Gray);
        result.put("  Target: ");
        result.put(buildErr.targetId);
        result.put("\n");
        
        if (!buildErr.failedDeps.empty)
        {
            result.put("  Failed dependencies:\n");
            foreach (dep; buildErr.failedDeps)
            {
                result.put("    - ");
                result.put(dep);
                result.put("\n");
            }
        }
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
    }
    else if (auto parseErr = cast(const ParseError)error)
    {
        if (opts.colors)
            result.put(cast(string)Color.Gray);
        
        if (!parseErr.filePath.empty)
        {
            result.put("  File: ");
            result.put(parseErr.filePath);
            if (parseErr.line > 0)
            {
                result.put(":");
                result.put(parseErr.line.to!string);
            }
            if (parseErr.column > 0)
            {
                result.put(":");
                result.put(parseErr.column.to!string);
            }
            result.put("\n");
        }
        
        if (!parseErr.snippet.empty)
        {
            result.put("\n");
            result.put(formatCodeSnippet(parseErr.snippet, parseErr.line, opts));
            result.put("\n");
        }
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
    }
    else if (auto analysisErr = cast(const AnalysisError)error)
    {
        if (opts.colors)
            result.put(cast(string)Color.Gray);
        
        result.put("  Target: ");
        result.put(analysisErr.targetName);
        result.put("\n");
        
        if (!analysisErr.unresolvedImports.empty)
        {
            result.put("  Unresolved imports:\n");
            foreach (imp; analysisErr.unresolvedImports)
            {
                result.put("    - ");
                result.put(imp);
                result.put("\n");
            }
        }
        
        if (!analysisErr.cyclePath.empty)
        {
            result.put("  Dependency cycle:\n    ");
            result.put(analysisErr.cyclePath.join(" → "));
            result.put("\n");
        }
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
    }
    else if (auto langErr = cast(const LanguageError)error)
    {
        if (opts.colors)
            result.put(cast(string)Color.Gray);
        
        result.put("  Language: ");
        result.put(langErr.language);
        result.put("\n");
        
        if (!langErr.filePath.empty)
        {
            result.put("  File: ");
            result.put(langErr.filePath);
            if (langErr.line > 0)
            {
                result.put(":");
                result.put(langErr.line.to!string);
            }
            result.put("\n");
        }
        
        if (!langErr.compilerOutput.empty)
        {
            result.put("\n  Compiler output:\n");
            result.put(indent(langErr.compilerOutput, 4));
            result.put("\n");
        }
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
    }
    
    return result.data;
}

/// Format a code snippet with line numbers and highlighting
private string formatCodeSnippet(string code, size_t errorLine, FormatOptions opts)
{
    import std.array : appender;
    auto lines = code.split("\n");
    auto result = appender!string;
    result.reserve(code.length + lines.length * 20); // Reserve space for line numbers and formatting
    
    foreach (i, line; lines)
    {
        size_t lineNum = errorLine + i;
        
        if (opts.colors)
            result.put(cast(string)Color.Gray);
        
        result.put(sformat("%4d | ", lineNum));
        
        if (opts.colors && i == 0)
            result.put(cast(string)Color.Red);
        
        result.put(line);
        
        if (opts.colors)
            result.put(cast(string)Color.Reset);
        
        result.put("\n");
    }
    
    return result.data;
}

/// Indent text by N spaces
private string indent(string text, size_t spaces)
{
    auto prefix = " ".repeat(spaces).join();
    return text.split("\n").map!(line => prefix ~ line).join("\n");
}

/// Format multiple errors as a tree
string formatTree(const BuildError[] errors, FormatOptions opts = FormatOptions.init)
{
    if (errors.empty)
        return "";
    
    string result;
    
    if (opts.colors)
        result ~= Color.Bold ~ Color.Red;
    
    result ~= "Build failed with " ~ errors.length.to!string ~ " error(s):\n\n";
    
    if (opts.colors)
        result ~= Color.Reset;
    
    foreach (i, error; errors)
    {
        result ~= sformat("Error %d:\n", i + 1);
        result ~= indent(format(error, opts), 2);
        result ~= "\n";
    }
    
    return result;
}

/// Create a summary of errors by category
string summarize(const BuildError[] errors)
{
    size_t[ErrorCategory] counts;
    
    foreach (error; errors)
        counts[error.category()]++;
    
    string result = "Error summary:\n";
    
    foreach (cat; counts.keys.sort())
    {
        result ~= sformat("  %s: %d\n", cat.to!string, counts[cat]);
    }
    
    return result;
}

/// Suggest fixes for common errors
string[] suggestFixes(const BuildError error)
{
    string[] suggestions;
    
    final switch (error.code())
    {
        case ErrorCode.UnknownError:
            suggestions ~= "Check the build logs for more details";
            suggestions ~= "Try running with verbose logging: builder build --verbose";
            break;
            
        case ErrorCode.BuildFailed:
            suggestions ~= "Review the error message above for specific issues";
            suggestions ~= "Check that all dependencies are properly installed";
            suggestions ~= "Verify that source files have no syntax errors";
            break;
            
        case ErrorCode.BuildTimeout:
            suggestions ~= "Increase the timeout value in your Builderfile";
            suggestions ~= "Check if the build is hanging on a specific step";
            suggestions ~= "Consider optimizing slow build steps";
            break;
            
        case ErrorCode.BuildCancelled:
            suggestions ~= "The build was manually cancelled or interrupted";
            suggestions ~= "Restart the build when ready: builder build";
            break;
            
        case ErrorCode.TargetNotFound:
            suggestions ~= "Check that the target name is spelled correctly";
            suggestions ~= "Run 'builder graph' to see available targets";
            suggestions ~= "Verify the target is defined in your Builderfile";
            break;
            
        case ErrorCode.HandlerNotFound:
            suggestions ~= "Ensure the language is specified correctly in Builderfile";
            suggestions ~= "Check that the language handler is installed";
            suggestions ~= "Run 'builder --version' to see supported languages";
            break;
            
        case ErrorCode.OutputMissing:
            suggestions ~= "Verify the build command produces the expected output file";
            suggestions ~= "Check the output path in your Builderfile";
            suggestions ~= "Ensure the build step completed successfully";
            break;
            
        case ErrorCode.ParseFailed:
            suggestions ~= "Check the syntax of your Builderfile";
            suggestions ~= "Validate JSON/YAML structure using a linter";
            suggestions ~= "See docs at: docs/CLI.md";
            break;
            
        case ErrorCode.InvalidJson:
            suggestions ~= "Verify JSON syntax using a JSON validator";
            suggestions ~= "Check for missing commas, brackets, or quotes";
            suggestions ~= "Ensure all strings are properly escaped";
            break;
            
        case ErrorCode.InvalidBuildFile:
            suggestions ~= "Verify the Builderfile follows the correct schema";
            suggestions ~= "Check examples at: examples/ directory";
            suggestions ~= "See documentation: docs/user-guides/CLI.md";
            break;
            
        case ErrorCode.MissingField:
            suggestions ~= "Add the required field to your configuration";
            suggestions ~= "Check the schema documentation for required fields";
            suggestions ~= "See docs/architecture/DSL.md for field reference";
            break;
            
        case ErrorCode.InvalidFieldValue:
            suggestions ~= "Check the field value type and format";
            suggestions ~= "Refer to the schema for valid values";
            suggestions ~= "See examples in the examples/ directory";
            break;
            
        case ErrorCode.InvalidGlob:
            suggestions ~= "Verify glob pattern syntax (e.g., '*.d', '**/*.ts')";
            suggestions ~= "Check for special characters that need escaping";
            suggestions ~= "Test the pattern with: ls <pattern>";
            break;
            
        case ErrorCode.AnalysisFailed:
            suggestions ~= "Check for syntax errors in source files";
            suggestions ~= "Verify import statements are correct";
            suggestions ~= "Ensure all referenced files exist";
            break;
            
        case ErrorCode.ImportResolutionFailed:
            suggestions ~= "Verify the import path is correct";
            suggestions ~= "Check that the imported file exists";
            suggestions ~= "Ensure search paths are properly configured";
            suggestions ~= "Add the directory to 'include_paths' in Builderfile";
            break;
            
        case ErrorCode.CircularDependency:
            suggestions ~= "Use 'builder graph' to visualize dependencies";
            suggestions ~= "Consider breaking the cycle by extracting shared code";
            suggestions ~= "Refactor to use dependency injection or interfaces";
            break;
            
        case ErrorCode.MissingDependency:
            suggestions ~= "Install the missing dependency";
            suggestions ~= "Add the dependency to your Builderfile";
            suggestions ~= "Check package manager configuration";
            break;
            
        case ErrorCode.InvalidImport:
            suggestions ~= "Check the import statement syntax";
            suggestions ~= "Verify the module/package name is correct";
            suggestions ~= "Ensure the imported file has proper exports";
            break;
            
        case ErrorCode.CacheLoadFailed:
            suggestions ~= "The cache may be from an incompatible version";
            suggestions ~= "Run 'builder clean' to clear the cache";
            suggestions ~= "Check file permissions on .builder-cache/";
            break;
            
        case ErrorCode.CacheSaveFailed:
            suggestions ~= "Check available disk space";
            suggestions ~= "Verify write permissions on .builder-cache/";
            suggestions ~= "Try running 'builder clean' and rebuilding";
            break;
            
        case ErrorCode.CacheCorrupted:
            suggestions ~= "Run 'builder clean' to clear the cache";
            suggestions ~= "Delete the .builder-cache directory";
            suggestions ~= "The cache will be rebuilt on next build";
            break;
            
        case ErrorCode.CacheEvictionFailed:
            suggestions ~= "Check file permissions on cache directory";
            suggestions ~= "Manually delete old cache entries";
            suggestions ~= "Try 'builder clean --all'";
            break;
            
        case ErrorCode.FileNotFound:
            suggestions ~= "Verify the file path in the Builderfile";
            suggestions ~= "Check for typos in glob patterns";
            suggestions ~= "Ensure the file exists: ls <path>";
            suggestions ~= "Check if the file is excluded by .builderignore";
            break;
            
        case ErrorCode.FileReadFailed:
            suggestions ~= "Check file permissions: ls -la <file>";
            suggestions ~= "Ensure the file is not locked by another process";
            suggestions ~= "Verify the file is not corrupted";
            break;
            
        case ErrorCode.FileWriteFailed:
            suggestions ~= "Check write permissions on the output directory";
            suggestions ~= "Ensure sufficient disk space is available: df -h";
            suggestions ~= "Verify the path is not read-only";
            break;
            
        case ErrorCode.DirectoryNotFound:
            suggestions ~= "Create the directory: mkdir -p <path>";
            suggestions ~= "Verify the path is correct";
            suggestions ~= "Check parent directory permissions";
            break;
            
        case ErrorCode.PermissionDenied:
            suggestions ~= "Check file/directory permissions: ls -la <path>";
            suggestions ~= "Run with appropriate permissions or use sudo";
            suggestions ~= "Verify you own the file: ls -l <file>";
            break;
            
        case ErrorCode.GraphCycle:
            suggestions ~= "Use 'builder graph' to visualize the cycle";
            suggestions ~= "Break the cycle by removing or reordering dependencies";
            suggestions ~= "Consider using lazy loading or dependency injection";
            break;
            
        case ErrorCode.GraphInvalid:
            suggestions ~= "Check for malformed dependency declarations";
            suggestions ~= "Verify all targets exist";
            suggestions ~= "Run 'builder graph' to validate the structure";
            break;
            
        case ErrorCode.NodeNotFound:
            suggestions ~= "Ensure all referenced targets are defined";
            suggestions ~= "Check for typos in target names";
            suggestions ~= "Run 'builder graph' to see available targets";
            break;
            
        case ErrorCode.EdgeInvalid:
            suggestions ~= "Verify dependency declarations are well-formed";
            suggestions ~= "Check that targets are not self-referential";
            suggestions ~= "Ensure dependencies reference existing targets";
            break;
            
        case ErrorCode.SyntaxError:
            suggestions ~= "Check the syntax of your source file";
            suggestions ~= "Use a linter or IDE for syntax validation";
            suggestions ~= "Review the error message for the specific issue";
            break;
            
        case ErrorCode.CompilationFailed:
            suggestions ~= "Review the compiler error messages above";
            suggestions ~= "Check for syntax errors in source files";
            suggestions ~= "Ensure all dependencies are installed";
            suggestions ~= "Verify compiler version compatibility";
            break;
            
        case ErrorCode.ValidationFailed:
            suggestions ~= "Review the validation errors above";
            suggestions ~= "Check that all required fields are present";
            suggestions ~= "Verify field values match expected types";
            break;
            
        case ErrorCode.UnsupportedLanguage:
            suggestions ~= "Check the list of supported languages: builder --version";
            suggestions ~= "Ensure the language name is spelled correctly";
            suggestions ~= "Consider using a generic shell command instead";
            break;
            
        case ErrorCode.MissingCompiler:
            suggestions ~= "Install the required compiler/interpreter";
            suggestions ~= "Ensure the compiler is in your PATH";
            suggestions ~= "Verify installation: which <compiler>";
            suggestions ~= "Check language-specific installation guide";
            break;
            
        case ErrorCode.ProcessSpawnFailed:
            suggestions ~= "Verify the command exists: which <command>";
            suggestions ~= "Check that the executable has execute permissions";
            suggestions ~= "Ensure sufficient system resources are available";
            break;
            
        case ErrorCode.ProcessTimeout:
            suggestions ~= "Increase the timeout in your Builderfile";
            suggestions ~= "Check if the process is hanging or stuck";
            suggestions ~= "Review process logs for blocking operations";
            break;
            
        case ErrorCode.ProcessCrashed:
            suggestions ~= "Check process logs for crash details";
            suggestions ~= "Verify input data is valid";
            suggestions ~= "Ensure system resources are sufficient";
            suggestions ~= "Try running the command directly to reproduce";
            break;
            
        case ErrorCode.OutOfMemory:
            suggestions ~= "Increase available system memory";
            suggestions ~= "Reduce parallelism in build settings";
            suggestions ~= "Consider building in smaller chunks";
            suggestions ~= "Check for memory leaks in build scripts";
            break;
            
        case ErrorCode.ThreadPoolError:
            suggestions ~= "Check system thread limits: ulimit -u";
            suggestions ~= "Reduce parallelism setting in Builderfile";
            suggestions ~= "Restart the build with fewer concurrent tasks";
            break;
            
        case ErrorCode.InternalError:
            suggestions ~= "This is likely a bug in Builder";
            suggestions ~= "Please report this issue with logs attached";
            suggestions ~= "Try running with --verbose for more details";
            suggestions ~= "Report at: github.com/yourproject/builder/issues";
            break;
            
        case ErrorCode.NotImplemented:
            suggestions ~= "This feature is not yet implemented";
            suggestions ~= "Check for alternative approaches";
            suggestions ~= "Consider contributing or requesting this feature";
            break;
            
        case ErrorCode.AssertionFailed:
            suggestions ~= "This indicates an internal consistency error";
            suggestions ~= "Please report this with reproduction steps";
            suggestions ~= "Try 'builder clean' and rebuild";
            break;
            
        case ErrorCode.UnreachableCode:
            suggestions ~= "This should never happen - please report as a bug";
            suggestions ~= "Include full error context when reporting";
            suggestions ~= "Try 'builder clean' to reset state";
            break;
            
        case ErrorCode.TelemetryNoSession:
            suggestions ~= "Initialize telemetry session before use";
            suggestions ~= "Check that telemetry is enabled in configuration";
            suggestions ~= "Verify telemetry dependencies are installed";
            break;
            
        case ErrorCode.TelemetryStorage:
            suggestions ~= "Check disk space availability";
            suggestions ~= "Verify write permissions on telemetry directory";
            suggestions ~= "Consider disabling telemetry if not needed";
            break;
            
        case ErrorCode.TelemetryInvalid:
            suggestions ~= "Verify telemetry configuration format";
            suggestions ~= "Check that telemetry data is not corrupted";
            suggestions ~= "Reset telemetry: rm -rf .builder/telemetry/";
            break;
            
        case ErrorCode.TraceInvalidFormat:
            suggestions ~= "Check trace format configuration";
            suggestions ~= "Verify trace exporter settings";
            suggestions ~= "Refer to tracing documentation";
            break;
            
        case ErrorCode.TraceNoActiveSpan:
            suggestions ~= "Ensure a trace span is started before use";
            suggestions ~= "Check tracing initialization code";
            suggestions ~= "Verify tracing is enabled";
            break;
            
        case ErrorCode.TraceExportFailed:
            suggestions ~= "Check trace exporter configuration";
            suggestions ~= "Verify network connectivity if using remote exporter";
            suggestions ~= "Check exporter logs for details";
            break;
    }
    
    return suggestions;
}

