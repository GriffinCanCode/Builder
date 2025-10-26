module languages.dotnet.fsharp.tooling.formatters.base;

import languages.dotnet.fsharp.core.config;

/// Format result structure
struct FormatResult
{
    /// Format succeeded
    bool success = false;
    
    /// Error message if failed
    string error;
    
    /// Files that were formatted
    string[] formattedFiles;
    
    /// Format issues found
    string[] issues;
}

/// Base interface for F# formatters
interface FSharpFormatter_
{
    /// Format files
    FormatResult format(string[] files, FSharpFormatterConfig config);
    
    /// Check formatting without modifying files
    FormatResult check(string[] files, FSharpFormatterConfig config);
    
    /// Get formatter name
    string getName();
    
    /// Check if formatter is available
    bool isAvailable();
}

/// Factory for creating appropriate formatter
class FSharpFormatterFactory
{
    /// Create formatter for specified type
    static FSharpFormatter_ create(FSharpFormatter formatter)
    {
        import languages.dotnet.fsharp.tooling.formatters.fantomas;
        
        final switch (formatter)
        {
            case FSharpFormatter.Auto:
            case FSharpFormatter.Fantomas:
                return new FantomasFormatter();
            case FSharpFormatter.None:
                return null;
        }
    }
}

