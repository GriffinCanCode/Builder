module errors.format;

import std.conv;
import std.algorithm;
import std.array;
import std.range;
import std.format : formattedWrite;
import errors.types;
import errors.codes;

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
    string result;
    
    // Header with category and code
    if (opts.showCategory)
    {
        if (opts.colors)
            result ~= Color.Bold ~ Color.Red;
        
        result ~= "[" ~ error.category().to!string;
        
        if (opts.showCode)
            result ~= ":" ~ error.code().to!string;
        
        result ~= "]";
        
        if (opts.colors)
            result ~= Color.Reset;
        
        result ~= " ";
    }
    
    // Main message
    if (opts.colors)
        result ~= Color.Red;
    result ~= error.message();
    if (opts.colors)
        result ~= Color.Reset;
    
    result ~= "\n";
    
    // Context chain
    if (opts.showContexts)
    {
        foreach (ctx; error.contexts())
        {
            if (opts.colors)
                result ~= Color.Gray;
            result ~= "  → " ~ ctx.toString() ~ "\n";
            if (opts.colors)
                result ~= Color.Reset;
        }
    }
    
    // Type-specific formatting
    result ~= formatSpecific(error, opts);
    
    return result;
}

/// Format type-specific error details
private string formatSpecific(const BuildError error, FormatOptions opts)
{
    import std.traits : hasMember;
    
    string result;
    
    // Try to cast to known types for additional formatting
    if (auto buildErr = cast(const BuildFailureError)error)
    {
        if (opts.colors)
            result ~= Color.Gray;
        result ~= "  Target: " ~ buildErr.targetId ~ "\n";
        
        if (!buildErr.failedDeps.empty)
        {
            result ~= "  Failed dependencies:\n";
            foreach (dep; buildErr.failedDeps)
                result ~= "    - " ~ dep ~ "\n";
        }
        
        if (opts.colors)
            result ~= Color.Reset;
    }
    else if (auto parseErr = cast(const ParseError)error)
    {
        if (opts.colors)
            result ~= Color.Gray;
        
        if (!parseErr.filePath.empty)
        {
            result ~= "  File: " ~ parseErr.filePath;
            if (parseErr.line > 0)
                result ~= ":" ~ parseErr.line.to!string;
            if (parseErr.column > 0)
                result ~= ":" ~ parseErr.column.to!string;
            result ~= "\n";
        }
        
        if (!parseErr.snippet.empty)
        {
            result ~= "\n" ~ formatCodeSnippet(parseErr.snippet, parseErr.line, opts) ~ "\n";
        }
        
        if (opts.colors)
            result ~= Color.Reset;
    }
    else if (auto analysisErr = cast(const AnalysisError)error)
    {
        if (opts.colors)
            result ~= Color.Gray;
        
        result ~= "  Target: " ~ analysisErr.targetName ~ "\n";
        
        if (!analysisErr.unresolvedImports.empty)
        {
            result ~= "  Unresolved imports:\n";
            foreach (imp; analysisErr.unresolvedImports)
                result ~= "    - " ~ imp ~ "\n";
        }
        
        if (!analysisErr.cyclePath.empty)
        {
            result ~= "  Dependency cycle:\n    ";
            result ~= analysisErr.cyclePath.join(" → ") ~ "\n";
        }
        
        if (opts.colors)
            result ~= Color.Reset;
    }
    else if (auto langErr = cast(const LanguageError)error)
    {
        if (opts.colors)
            result ~= Color.Gray;
        
        result ~= "  Language: " ~ langErr.language ~ "\n";
        
        if (!langErr.filePath.empty)
        {
            result ~= "  File: " ~ langErr.filePath;
            if (langErr.line > 0)
                result ~= ":" ~ langErr.line.to!string;
            result ~= "\n";
        }
        
        if (!langErr.compilerOutput.empty)
        {
            result ~= "\n  Compiler output:\n";
            result ~= indent(langErr.compilerOutput, 4) ~ "\n";
        }
        
        if (opts.colors)
            result ~= Color.Reset;
    }
    
    return result;
}

/// Format a code snippet with line numbers and highlighting
private string formatCodeSnippet(string code, size_t errorLine, FormatOptions opts)
{
    auto lines = code.split("\n");
    string result;
    
    foreach (i, line; lines)
    {
        size_t lineNum = errorLine + i;
        
        if (opts.colors)
            result ~= Color.Gray;
        
        result ~= sformat("%4d | ", lineNum);
        
        if (opts.colors && i == 0)
            result ~= Color.Red;
        
        result ~= line;
        
        if (opts.colors)
            result ~= Color.Reset;
        
        result ~= "\n";
    }
    
    return result;
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
            suggestions ~= "Ensure the language is specified correctly in BUILD file";
            suggestions ~= "Check that the language handler is installed";
            break;
            
        case ErrorCode.CircularDependency:
            suggestions ~= "Use 'builder graph' to visualize dependencies";
            suggestions ~= "Consider breaking the cycle by extracting shared code";
            break;
            
        case ErrorCode.FileNotFound:
            suggestions ~= "Verify the file path in the BUILD file";
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

