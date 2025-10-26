module languages.dotnet.csharp.tooling.analyzers.base;

import std.string;
import languages.dotnet.csharp.core.config;

/// Analysis result structure
struct AnalysisResult
{
    /// Analysis succeeded
    bool success;
    
    /// Errors found
    string[] errors;
    
    /// Warnings found
    string[] warnings;
    
    /// Info messages
    string[] info;
    
    /// Check if has errors
    bool hasErrors() const
    {
        return errors.length > 0;
    }
    
    /// Check if has warnings
    bool hasWarnings() const
    {
        return warnings.length > 0;
    }
}

/// Base interface for C# analyzers
interface CSharpAnalyzer_
{
    /// Analyze source files
    AnalysisResult analyze(
        string[] sources,
        AnalysisConfig config,
        string projectRoot
    );
    
    /// Check if analyzer is available
    bool isAvailable();
    
    /// Get analyzer name
    string name();
}

/// Analyzer factory
struct CSharpAnalyzerFactory
{
    /// Create appropriate analyzer
    static CSharpAnalyzer_ create(CSharpAnalyzer analyzer, string projectRoot)
    {
        import languages.dotnet.csharp.tooling.analyzers.roslyn;
        
        final switch (analyzer)
        {
            case CSharpAnalyzer.Auto:
            case CSharpAnalyzer.Roslyn:
                return new RoslynAnalyzer();
            
            case CSharpAnalyzer.StyleCop:
            case CSharpAnalyzer.SonarAnalyzer:
            case CSharpAnalyzer.Roslynator:
            case CSharpAnalyzer.FxCop:
                // These are Roslyn-based analyzers that work through the same mechanism
                return new RoslynAnalyzer();
            
            case CSharpAnalyzer.None:
                return new RoslynAnalyzer(); // Dummy, won't be called
        }
    }
}

