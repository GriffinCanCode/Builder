module languages.jvm.kotlin.tooling.formatters.base;

import languages.jvm.kotlin.core.config;

/// Format result
struct FormatResult
{
    bool success = false;
    string error;
    int filesFormatted = 0;
    int filesChecked = 0;
    string[] violations;
}

/// Base interface for Kotlin formatters
interface KotlinFormatter_
{
    /// Format Kotlin source files
    FormatResult format(string[] sources, FormatterConfig config);
    
    /// Check formatting without modifying files
    FormatResult check(string[] sources, FormatterConfig config);
    
    /// Check if formatter is available
    bool isAvailable();
    
    /// Get formatter name
    string name() const;
}

/// Factory for creating Kotlin formatters
class KotlinFormatterFactory
{
    /// Create formatter based on configuration
    static KotlinFormatter_ create(KotlinFormatter formatter)
    {
        import languages.jvm.kotlin.tooling.formatters.ktlint;
        import languages.jvm.kotlin.tooling.formatters.ktfmt;
        import languages.jvm.kotlin.tooling.formatters.intellij;
        
        final switch (formatter)
        {
            case KotlinFormatter.Auto:
                // Try ktlint first, then ktfmt
                if (KtLintFormatter.staticIsAvailable())
                    return new KtLintFormatter();
                if (KtFmtFormatter.staticIsAvailable())
                    return new KtFmtFormatter();
                return new IntelliJFormatter();
            
            case KotlinFormatter.KtLint:
                return new KtLintFormatter();
            
            case KotlinFormatter.KtFmt:
                return new KtFmtFormatter();
            
            case KotlinFormatter.IntelliJ:
                return new IntelliJFormatter();
            
            case KotlinFormatter.None:
                return null;
        }
    }
}

