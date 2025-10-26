module languages.dotnet.csharp.tooling.formatters.base;

import std.string;
import languages.dotnet.csharp.core.config;

/// Format result structure
struct FormatResult
{
    /// Format succeeded
    bool success;
    
    /// Files that were formatted
    string[] formattedFiles;
    
    /// Error message if failed
    string error;
}

/// Base interface for C# formatters
interface CSharpFormatter_
{
    /// Format source files
    FormatResult format(
        string[] sources,
        FormatterConfig config,
        string projectRoot,
        bool checkOnly = false
    );
    
    /// Check if formatter is available
    bool isAvailable();
    
    /// Get formatter name
    string name();
}

/// Formatter factory
struct CSharpFormatterFactory
{
    /// Create appropriate formatter
    static CSharpFormatter_ create(CSharpFormatter formatter, string projectRoot)
    {
        import languages.dotnet.csharp.tooling.formatters.dotnetformat;
        import languages.dotnet.csharp.tooling.formatters.csharpier;
        
        final switch (formatter)
        {
            case CSharpFormatter.Auto:
                // Try dotnet-format first, then CSharpier
                auto dotnetFormatter = new DotNetFormatter();
                if (dotnetFormatter.isAvailable())
                    return dotnetFormatter;
                
                auto csharpierFormatter = new CSharpierFormatter();
                if (csharpierFormatter.isAvailable())
                    return csharpierFormatter;
                
                return dotnetFormatter; // Return anyway for error reporting
            
            case CSharpFormatter.DotNetFormat:
                return new DotNetFormatter();
            
            case CSharpFormatter.CSharpier:
                return new CSharpierFormatter();
            
            case CSharpFormatter.None:
                return new DotNetFormatter(); // Dummy, won't be called
        }
    }
}

