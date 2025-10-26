module languages.jvm.scala.tooling.formatters.base;

import languages.jvm.scala.core.config;

/// Format result
struct FormatResult
{
    bool success = false;
    string error;
    string[] warnings;
    int filesFormatted = 0;
    int filesChecked = 0;
}

/// Base interface for Scala formatters
interface Formatter
{
    /// Format Scala sources
    FormatResult format(string[] sources, FormatterConfig config, string workingDir, bool checkOnly = false);
    
    /// Check if formatter is available
    bool isAvailable();
    
    /// Get formatter name
    string name() const;
}

/// Factory for creating formatters
class FormatterFactory
{
    static Formatter create(ScalaFormatter type, string workingDir = ".")
    {
        import languages.jvm.scala.tooling.formatters.scalafmt;
        
        final switch (type)
        {
            case ScalaFormatter.Auto:
                return createAuto(workingDir);
            case ScalaFormatter.Scalafmt:
                return new ScalafmtFormatter();
            case ScalaFormatter.None:
                return new NullFormatter();
        }
    }
    
    private static Formatter createAuto(string workingDir)
    {
        import languages.jvm.scala.tooling.formatters.scalafmt;
        
        // Prefer scalafmt if available
        auto scalafmt = new ScalafmtFormatter();
        if (scalafmt.isAvailable())
            return scalafmt;
        
        return new NullFormatter();
    }
}

/// Null formatter (does nothing)
class NullFormatter : Formatter
{
    override FormatResult format(string[] sources, FormatterConfig config, string workingDir, bool checkOnly = false)
    {
        FormatResult result;
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

