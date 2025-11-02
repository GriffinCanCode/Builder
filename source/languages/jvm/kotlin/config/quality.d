module languages.jvm.kotlin.config.quality;

/// Code analyzer selection
enum KotlinAnalyzer
{
    Auto,     /// Auto-detect best available
    Detekt,   /// detekt (comprehensive linter)
    KtLint,   /// KtLint (style checker)
    Compiler, /// Compiler warnings only
    None      /// None - skip analysis
}

/// Code formatter selection
enum KotlinFormatter
{
    Auto,      /// Auto-detect best available
    KtLint,    /// ktlint (official style)
    KtFmt,     /// ktfmt (Google style)
    IntelliJ,  /// IntelliJ IDEA formatter
    None       /// None - skip formatting
}

/// Static analysis configuration
struct AnalysisConfig
{
    bool enabled = false;
    KotlinAnalyzer analyzer = KotlinAnalyzer.Auto;
    string configFile;
    string[] ruleSets;
    string[] disabledRules;
    int failThreshold = 0;
    bool autoCorrect = false;
    bool parallel = true;
    string reportFormat = "txt";
    string outputPath;
}

/// Code formatting configuration
struct FormatterConfig
{
    bool enabled = false;
    KotlinFormatter formatter = KotlinFormatter.Auto;
    string configFile;
    bool autoFormat = false;
    bool verifyOnly = false;
    string[] excludes;
    string style = "official";
}

/// Kotlin code quality configuration
struct KotlinQualityConfig
{
    AnalysisConfig analysis;
    FormatterConfig formatter;
    bool strictMode = false;
    bool explicitApi = false;
}

