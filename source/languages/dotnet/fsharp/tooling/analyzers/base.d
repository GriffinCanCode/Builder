module languages.dotnet.fsharp.tooling.analyzers.base;

import languages.dotnet.fsharp.config;

/// Analysis severity
enum AnalysisSeverity
{
    Info,
    Warning,
    Error
}

/// Analysis issue
struct AnalysisIssue
{
    /// File path
    string file;
    
    /// Line number
    int line;
    
    /// Column number
    int column;
    
    /// Severity
    AnalysisSeverity severity;
    
    /// Message
    string message;
    
    /// Rule ID
    string ruleId;
}

/// Analysis result structure
struct AnalysisResult
{
    /// Analysis succeeded
    bool success = false;
    
    /// Error message if failed
    string error;
    
    /// Issues found
    AnalysisIssue[] issues;
    
    /// Files analyzed
    string[] analyzedFiles;
}

/// Base interface for F# analyzers
interface FSharpAnalyzer_
{
    /// Analyze files
    AnalysisResult analyze(string[] files, FSharpAnalysisConfig config);
    
    /// Get analyzer name
    string getName();
    
    /// Check if analyzer is available
    bool isAvailable();
}

/// Factory for creating appropriate analyzer
class FSharpAnalyzerFactory
{
    /// Create analyzer for specified type
    static FSharpAnalyzer_ create(FSharpAnalyzer analyzer)
    {
        import languages.dotnet.fsharp.tooling.analyzers.lint;
        import languages.dotnet.fsharp.tooling.analyzers.compiler;
        
        final switch (analyzer)
        {
            case FSharpAnalyzer.Auto:
            case FSharpAnalyzer.FSharpLint:
                return new FSharpLintAnalyzer();
            case FSharpAnalyzer.Compiler:
                return new CompilerAnalyzer();
            case FSharpAnalyzer.Ionide:
                // Ionide is an IDE, not a standalone analyzer
                return new CompilerAnalyzer();
            case FSharpAnalyzer.None:
                return null;
        }
    }
}

