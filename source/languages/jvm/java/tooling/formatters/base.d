module languages.jvm.java.tooling.formatters.base;

import languages.jvm.java.core.config;

/// Format result
struct FormatResult
{
    bool success = false;
    string error;
    string[] warnings;
    int filesFormatted = 0;
}

/// Base interface for Java formatters
interface JavaFormatter
{
    /// Format Java sources
    FormatResult format(string[] sources, FormatterConfig config, string workingDir, bool checkOnly = false);
    
    /// Check if formatter is available
    bool isAvailable();
    
    /// Get formatter name
    string name() const;
}

/// Factory for creating formatters
class JavaFormatterFactory
{
    static JavaFormatter create(languages.jvm.java.core.config.JavaFormatter type, string workingDir = ".")
    {
        import languages.jvm.java.tooling.formatters.google;
        import languages.jvm.java.tooling.formatters.eclipse;
        
        final switch (type)
        {
            case languages.jvm.java.core.config.JavaFormatter.Auto:
                return createAuto(workingDir);
            case languages.jvm.java.core.config.JavaFormatter.GoogleJavaFormat:
                return new GoogleJavaFormatter();
            case languages.jvm.java.core.config.JavaFormatter.Eclipse:
                return new EclipseFormatter();
            case languages.jvm.java.core.config.JavaFormatter.IntelliJ:
            case languages.jvm.java.core.config.JavaFormatter.Prettier:
            case languages.jvm.java.core.config.JavaFormatter.None:
                return new NullFormatter();
        }
    }
    
    private static JavaFormatter createAuto(string workingDir)
    {
        import languages.jvm.java.tooling.formatters.google;
        
        // Prefer google-java-format if available
        auto google = new GoogleJavaFormatter();
        if (google.isAvailable())
            return google;
        
        return new NullFormatter();
    }
}

/// Null formatter (does nothing)
class NullFormatter : JavaFormatter
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

