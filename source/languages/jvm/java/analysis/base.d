module languages.jvm.java.analysis.base;

import languages.jvm.java.core.config;

/// Analysis issue
struct AnalysisIssue
{
    string file;
    int line;
    string severity; // error, warning, info
    string message;
    string rule;
}

/// Analysis result
struct AnalysisResult
{
    bool success = false;
    string error;
    AnalysisIssue[] issues;
    int errorCount = 0;
    int warningCount = 0;
    
    bool hasErrors() const
    {
        return errorCount > 0;
    }
    
    bool hasWarnings() const
    {
        return warningCount > 0;
    }
    
    bool hasIssues() const
    {
        return !issues.empty;
    }
    
    string[] errors() const
    {
        import std.algorithm;
        import std.array;
        return issues.filter!(i => i.severity == "error")
                     .map!(i => i.file ~ ":" ~ i.line.to!string ~ ": " ~ i.message)
                     .array;
    }
    
    string[] warnings() const
    {
        import std.algorithm;
        import std.array;
        return issues.filter!(i => i.severity == "warning")
                     .map!(i => i.file ~ ":" ~ i.line.to!string ~ ": " ~ i.message)
                     .array;
    }
}

/// Base interface for Java static analyzers
interface Analyzer
{
    /// Analyze Java sources
    AnalysisResult analyze(string[] sources, AnalysisConfig config, string workingDir);
    
    /// Check if analyzer is available
    bool isAvailable();
    
    /// Get analyzer name
    string name() const;
}

/// Factory for creating analyzers
class AnalyzerFactory
{
    static Analyzer create(JavaAnalyzer type, string workingDir = ".")
    {
        import languages.jvm.java.analysis.spotbugs;
        import languages.jvm.java.analysis.pmd;
        import languages.jvm.java.analysis.checkstyle;
        
        final switch (type)
        {
            case JavaAnalyzer.Auto:
                return createAuto(workingDir);
            case JavaAnalyzer.SpotBugs:
                return new SpotBugsAnalyzer();
            case JavaAnalyzer.PMD:
                return new PMDAnalyzer();
            case JavaAnalyzer.Checkstyle:
                return new CheckstyleAnalyzer();
            case JavaAnalyzer.ErrorProne:
            case JavaAnalyzer.SonarQube:
            case JavaAnalyzer.None:
                return new NullAnalyzer();
        }
    }
    
    private static Analyzer createAuto(string workingDir)
    {
        import languages.jvm.java.analysis.spotbugs;
        import languages.jvm.java.analysis.pmd;
        import languages.jvm.java.analysis.checkstyle;
        
        // Try SpotBugs first
        auto spotbugs = new SpotBugsAnalyzer();
        if (spotbugs.isAvailable())
            return spotbugs;
        
        // Try PMD
        auto pmd = new PMDAnalyzer();
        if (pmd.isAvailable())
            return pmd;
        
        // Try Checkstyle
        auto checkstyle = new CheckstyleAnalyzer();
        if (checkstyle.isAvailable())
            return checkstyle;
        
        return new NullAnalyzer();
    }
}

/// Null analyzer (does nothing)
class NullAnalyzer : Analyzer
{
    override AnalysisResult analyze(string[] sources, AnalysisConfig config, string workingDir)
    {
        AnalysisResult result;
        result.success = true;
        return result;
    }
    
    override bool isAvailable()
    {
        return true;
    }
    
    override string name() const
    {
        return "None";
    }
}

