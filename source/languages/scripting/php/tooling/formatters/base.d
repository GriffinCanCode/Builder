module languages.scripting.php.tooling.formatters.base;

import languages.scripting.php.core.config;
import std.process;
import std.path;
import std.file;
import std.range;

/// Format result
struct FormatResult
{
    bool success;
    string output;
    string[] errors;
    string[] warnings;
    string[] filesChanged;
    int filesChecked;
    
    /// Check if any files need formatting
    bool needsFormatting() const pure nothrow
    {
        return !filesChanged.empty;
    }
}

/// Base interface for PHP code formatters
interface Formatter
{
    /// Format PHP source files
    FormatResult format(
        string[] sources,
        FormatterConfig config,
        string projectRoot,
        bool checkOnly = false
    );
    
    /// Check if formatter is available on system
    bool isAvailable();
    
    /// Get formatter name
    string name() const;
    
    /// Get formatter version
    string getVersion();
    
    /// Find configuration file in project
    string findConfigFile(string projectRoot);
}

/// Factory for creating formatters
class FormatterFactory
{
    /// Create formatter based on type
    static Formatter create(PHPFormatter type, string projectRoot = ".")
    {
        import languages.scripting.php.tooling.formatters.phpcsfixer;
        import languages.scripting.php.tooling.formatters.phpcs;
        
        final switch (type)
        {
            case PHPFormatter.Auto:
                return createAuto(projectRoot);
            case PHPFormatter.PHPCSFixer:
                return new PHPCSFixerFormatter();
            case PHPFormatter.PHPCS:
                return new PHPCSFormatter();
            case PHPFormatter.None:
                return new NullFormatter();
        }
    }
    
    /// Auto-detect best available formatter
    private static Formatter createAuto(string projectRoot)
    {
        import languages.scripting.php.tooling.formatters.phpcsfixer;
        import languages.scripting.php.tooling.formatters.phpcs;
        
        // Priority: PHP-CS-Fixer > PHPCS (PHP-CS-Fixer is more modern and automated)
        
        // Check for PHP-CS-Fixer
        auto phpcsfixer = new PHPCSFixerFormatter();
        if (phpcsfixer.isAvailable() || !phpcsfixer.findConfigFile(projectRoot).empty)
            return phpcsfixer;
        
        // Check for PHPCS
        auto phpcs = new PHPCSFormatter();
        if (phpcs.isAvailable() || !phpcs.findConfigFile(projectRoot).empty)
            return phpcs;
        
        // Fallback to null formatter
        return new NullFormatter();
    }
    
    /// Detect formatter from project configuration
    static PHPFormatter detectFromProject(string projectRoot)
    {
        // Check for PHP-CS-Fixer config
        if (exists(buildPath(projectRoot, ".php-cs-fixer.php")) ||
            exists(buildPath(projectRoot, ".php-cs-fixer.dist.php")) ||
            exists(buildPath(projectRoot, ".php_cs")) ||
            exists(buildPath(projectRoot, ".php_cs.dist")))
        {
            return PHPFormatter.PHPCSFixer;
        }
        
        // Check for PHPCS config
        if (exists(buildPath(projectRoot, "phpcs.xml")) ||
            exists(buildPath(projectRoot, "phpcs.xml.dist")) ||
            exists(buildPath(projectRoot, ".phpcs.xml")) ||
            exists(buildPath(projectRoot, ".phpcs.xml.dist")))
        {
            return PHPFormatter.PHPCS;
        }
        
        return PHPFormatter.Auto;
    }
}

/// Null formatter - does nothing
class NullFormatter : Formatter
{
    FormatResult format(
        string[] sources,
        FormatterConfig config,
        string projectRoot,
        bool checkOnly = false
    )
    {
        FormatResult result;
        result.success = true;
        result.output = "No formatter configured";
        result.filesChecked = cast(int)sources.length;
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

