module languages.dotnet.csharp.config.quality;

/// Code analyzer selection
enum CSharpAnalyzer
{
    Auto,            /// Auto-detect analyzers from project
    Roslyn,          /// Roslyn analyzers
    StyleCop,        /// StyleCop analyzers
    FxCopAnalyzers,  /// FxCop analyzers
    SonarAnalyzer,   /// SonarAnalyzer for C#
    None             /// None - skip analysis
}

/// Code formatter selection
enum CSharpFormatter
{
    Auto,         /// Auto-detect best available
    DotNetFormat, /// dotnet format (official)
    Rider,        /// JetBrains Rider formatter
    CodeMaid,     /// CodeMaid
    None          /// None - skip formatting
}

/// Static analysis configuration
struct AnalysisConfig
{
    bool enabled = false;
    CSharpAnalyzer analyzer = CSharpAnalyzer.Auto;
    string ruleSet;
    string[] disabledAnalyzers;
    bool treatWarningsAsErrors = false;
    int warningLevel = 4;
    string[] noWarn;
    string[] warningsAsErrors;
}

/// Code formatting configuration
struct FormatterConfig
{
    bool enabled = false;
    CSharpFormatter formatter = CSharpFormatter.Auto;
    string editorConfig;
    bool verify = false;
    bool fixWhitespace = true;
    bool fixStyle = true;
    bool fixAnalyzers = false;
    string[] excludes;
}

/// C# quality configuration
struct CSharpQualityConfig
{
    AnalysisConfig analysis;
    FormatterConfig formatter;
    bool codeMetrics = false;
    bool xmlDocumentation = false;
    bool generateDocFile = false;
    string docFile;
}

