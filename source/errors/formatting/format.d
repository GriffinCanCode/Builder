module errors.formatting.format;

import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.format : formattedWrite;
import errors.types.types;
import errors.handling.codes;

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
        case ErrorCode.TargetNotFound:
            suggestions ~= "Check that the target name is spelled correctly";
            suggestions ~= "Run 'builder graph' to see available targets";
            break;
            
        case ErrorCode.HandlerNotFound:
            suggestions ~= "Ensure the language is specified correctly in Builderfile";
            suggestions ~= "Check that the language handler is installed";
            break;
            
        case ErrorCode.CircularDependency:
            suggestions ~= "Use 'builder graph' to visualize dependencies";
            suggestions ~= "Consider breaking the cycle by extracting shared code";
            break;
            
        case ErrorCode.FileNotFound:
            suggestions ~= "Verify the file path in the Builderfile";
            suggestions ~= "Check for typos in glob patterns";
            break;
            
        case ErrorCode.MissingCompiler:
            suggestions ~= "Install the required compiler/interpreter";
            suggestions ~= "Ensure the compiler is in your PATH";
            break;
            
        case ErrorCode.CacheCorrupted:
            suggestions ~= "Run 'builder clean' to clear the cache";
            suggestions ~= "Delete the .builder-cache directory";
            break;
            
        // All other cases - no specific suggestions
        case ErrorCode.BuildFailed:
        case ErrorCode.BuildTimeout:
        case ErrorCode.BuildCancelled:
        case ErrorCode.OutputMissing:
        case ErrorCode.ParseFailed:
        case ErrorCode.InvalidJson:
        case ErrorCode.InvalidBuildFile:
        case ErrorCode.MissingField:
        case ErrorCode.InvalidFieldValue:
        case ErrorCode.InvalidGlob:
        case ErrorCode.AnalysisFailed:
        case ErrorCode.ImportResolutionFailed:
        case ErrorCode.MissingDependency:
        case ErrorCode.InvalidImport:
        case ErrorCode.CacheLoadFailed:
        case ErrorCode.CacheSaveFailed:
        case ErrorCode.CacheEvictionFailed:
        case ErrorCode.FileReadFailed:
        case ErrorCode.FileWriteFailed:
        case ErrorCode.DirectoryNotFound:
        case ErrorCode.PermissionDenied:
        case ErrorCode.GraphCycle:
        case ErrorCode.GraphInvalid:
        case ErrorCode.NodeNotFound:
        case ErrorCode.EdgeInvalid:
        case ErrorCode.SyntaxError:
        case ErrorCode.CompilationFailed:
        case ErrorCode.ValidationFailed:
        case ErrorCode.UnsupportedLanguage:
        case ErrorCode.ProcessSpawnFailed:
        case ErrorCode.ProcessTimeout:
        case ErrorCode.ProcessCrashed:
        case ErrorCode.OutOfMemory:
        case ErrorCode.ThreadPoolError:
        case ErrorCode.InternalError:
        case ErrorCode.NotImplemented:
        case ErrorCode.AssertionFailed:
        case ErrorCode.UnreachableCode:
            break;
    }
    
    return suggestions;
}

