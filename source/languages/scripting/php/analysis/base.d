module languages.scripting.php.analysis.base;

import languages.scripting.php.core.config;
import std.process;
import std.path;
import std.file;

/// Analysis result
struct AnalysisResult
{
    bool success;
    string output;
    string[] errors;
    string[] warnings;
    int errorCount;
    int warningCount;
    
    /// Check if analysis found any issues
    bool hasIssues() const pure nothrow
    {
        return errorCount > 0 || warningCount > 0;
    }
    
    /// Check if analysis found errors
    bool hasErrors() const pure nothrow
    {
        return errorCount > 0;
    }
}

/// Base interface for PHP static analyzers
interface Analyzer
{
    /// Analyze PHP source files
    AnalysisResult analyze(
        string[] sources,
        AnalysisConfig config,
        string projectRoot
    );
    
    /// Check if analyzer is available on system
    bool isAvailable();
    
    /// Get analyzer name
    string name() const;
    
    /// Get analyzer version
    string getVersion();
    
    /// Find configuration file in project
    string findConfigFile(string projectRoot);
}

/// Factory for creating analyzers
class AnalyzerFactory
{
    /// Create analyzer based on type
    static Analyzer create(PHPAnalyzer type, string projectRoot = ".")
    {
        import languages.scripting.php.analysis.phpstan;
        import languages.scripting.php.analysis.psalm;
        import languages.scripting.php.analysis.phan;
        
        final switch (type)
        {
            case PHPAnalyzer.Auto:
                return createAuto(projectRoot);
            case PHPAnalyzer.PHPStan:
                return new PHPStanAnalyzer();
            case PHPAnalyzer.Psalm:
                return new PsalmAnalyzer();
            case PHPAnalyzer.Phan:
                return new PhanAnalyzer();
            case PHPAnalyzer.PHPCSFixer:
                // PHP-CS-Fixer can also run in analysis mode
                return new PHPStanAnalyzer(); // Fallback
            case PHPAnalyzer.None:
                return new NullAnalyzer();
        }
    }
    
    /// Auto-detect best available analyzer
    private static Analyzer createAuto(string projectRoot)
    {
        import languages.scripting.php.analysis.phpstan;
        import languages.scripting.php.analysis.psalm;
        import languages.scripting.php.analysis.phan;
        
        // Priority: PHPStan > Psalm > Phan (based on popularity and features)
        
        // Check for PHPStan
        auto phpstan = new PHPStanAnalyzer();
        if (phpstan.isAvailable() || !phpstan.findConfigFile(projectRoot).empty)
            return phpstan;
        
        // Check for Psalm
        auto psalm = new PsalmAnalyzer();
        if (psalm.isAvailable() || !psalm.findConfigFile(projectRoot).empty)
            return psalm;
        
        // Check for Phan
        auto phan = new PhanAnalyzer();
        if (phan.isAvailable() || !phan.findConfigFile(projectRoot).empty)
            return phan;
        
        // Fallback to null analyzer
        return new NullAnalyzer();
    }
    
    /// Detect analyzer from project configuration
    static PHPAnalyzer detectFromProject(string projectRoot)
    {
        // Check for PHPStan config
        if (exists(buildPath(projectRoot, "phpstan.neon")) ||
            exists(buildPath(projectRoot, "phpstan.neon.dist")) ||
            exists(buildPath(projectRoot, "phpstan.dist.neon")))
        {
            return PHPAnalyzer.PHPStan;
        }
        
        // Check for Psalm config
        if (exists(buildPath(projectRoot, "psalm.xml")) ||
            exists(buildPath(projectRoot, "psalm.xml.dist")))
        {
            return PHPAnalyzer.Psalm;
        }
        
        // Check for Phan config
        if (exists(buildPath(projectRoot, ".phan")) ||
            exists(buildPath(projectRoot, ".phan/config.php")))
        {
            return PHPAnalyzer.Phan;
        }
        
        return PHPAnalyzer.Auto;
    }
}

/// Null analyzer - does nothing
class NullAnalyzer : Analyzer
{
    AnalysisResult analyze(
        string[] sources,
        AnalysisConfig config,
        string projectRoot
    )
    {
        AnalysisResult result;
        result.success = true;
        result.output = "No analyzer configured";
        return result;
    }
    
    bool isAvailable()
    {
        return true;
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        return "n/a";
    }
    
    string findConfigFile(string projectRoot)
    {
        return "";
    }
}

