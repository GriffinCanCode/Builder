module languages.web.css.processors.base;

import languages.web.css.core.config;
import infrastructure.config.schema.schema;

/// Base interface for CSS processors
interface CSSProcessor
{
    /// Compile CSS files
    CSSCompileResult compile(
        const(string[]) sources,
        CSSConfig config,
        in Target target,
        in WorkspaceConfig workspace
    );
    
    /// Check if processor is available
    bool isAvailable();
    
    /// Get processor name
    string name() const;
    
    /// Get processor version
    string getVersion();
}

/// Factory for creating CSS processors
class CSSProcessorFactory
{
    /// Create processor based on type
    static CSSProcessor create(CSSProcessorType processorType)
    {
        import languages.web.css.processors.none;
        import languages.web.css.processors.postcss;
        import languages.web.css.processors.scss;
        
        final switch (processorType)
        {
            case CSSProcessorType.None:
                return new NoneProcessor();
            case CSSProcessorType.PostCSS:
                return new PostCSSProcessor();
            case CSSProcessorType.SCSS:
                return new SCSSProcessor();
            case CSSProcessorType.Less:
                return new LessProcessor();
            case CSSProcessorType.Stylus:
                return new StylusProcessor();
            case CSSProcessorType.Auto:
                return new NoneProcessor();
        }
    }
}

