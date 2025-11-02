module languages.dotnet.fsharp.config.quality;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Code analyzer selection
enum FSharpAnalyzer
{
    /// Auto-detect best available
    Auto,
    /// FSharpLint
    FSharpLint,
    /// Compiler warnings only
    Compiler,
    /// Ionide (LSP-based)
    Ionide,
    /// None - skip analysis
    None
}

/// Code formatter selection
enum FSharpFormatter
{
    /// Auto-detect best available
    Auto,
    /// Fantomas (official)
    Fantomas,
    /// None - skip formatting
    None
}

/// Static analysis configuration
struct FSharpAnalysisConfig
{
    /// Enable static analysis
    bool enabled = false;
    
    /// Analyzer to use
    FSharpAnalyzer analyzer = FSharpAnalyzer.Auto;
    
    /// Fail build on warnings
    bool failOnWarnings = false;
    
    /// Fail build on errors
    bool failOnErrors = true;
    
    /// FSharpLint: Config file path
    string lintConfig = "fsharplint.json";
    
    /// FSharpLint: Ignore files pattern
    string[] ignoreFiles;
    
    /// Compiler warning level
    int warningLevel = 4;
    
    /// Warnings as errors
    bool warningsAsErrors = false;
    
    /// Specific warnings to treat as errors
    int[] warningsAsErrorsList;
    
    /// Disable specific warnings
    int[] disableWarnings;
}

/// Formatter configuration
struct FSharpFormatterConfig
{
    /// Enable formatting
    bool enabled = false;
    
    /// Formatter to use
    FSharpFormatter formatter = FSharpFormatter.Auto;
    
    /// Auto-format before build
    bool autoFormat = false;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// Configuration file path
    string configFile = ".editorconfig";
    
    /// Max line length
    int maxLineLength = 120;
    
    /// Indent size
    int indentSize = 4;
    
    /// Fantomas: Insert final newline
    bool insertFinalNewline = true;
    
    /// Fantomas: Fsharp style
    bool fsharpStyle = true;
}

/// F# Quality Configuration
struct FSharpQualityConfig
{
    /// Static analysis
    FSharpAnalysisConfig analysis;
    
    /// Code formatting
    FSharpFormatterConfig formatter;
}

/// Parse FSharpAnalysisConfig from JSON
FSharpAnalysisConfig parseFSharpAnalysisConfig(JSONValue json)
{
    FSharpAnalysisConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("analyzer" in json)
        config.analyzer = json["analyzer"].str.toFSharpAnalyzer();
    if ("failOnWarnings" in json)
        config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    if ("failOnErrors" in json)
        config.failOnErrors = json["failOnErrors"].type == JSONType.true_;
    if ("lintConfig" in json)
        config.lintConfig = json["lintConfig"].str;
    if ("ignoreFiles" in json)
        config.ignoreFiles = json["ignoreFiles"].array.map!(e => e.str).array;
    if ("warningLevel" in json)
        config.warningLevel = cast(int)json["warningLevel"].integer;
    if ("warningsAsErrors" in json)
        config.warningsAsErrors = json["warningsAsErrors"].type == JSONType.true_;
    if ("warningsAsErrorsList" in json)
        config.warningsAsErrorsList = json["warningsAsErrorsList"].array.map!(e => cast(int)e.integer).array;
    if ("disableWarnings" in json)
        config.disableWarnings = json["disableWarnings"].array.map!(e => cast(int)e.integer).array;
    
    return config;
}

/// Parse FSharpFormatterConfig from JSON
FSharpFormatterConfig parseFSharpFormatterConfig(JSONValue json)
{
    FSharpFormatterConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("formatter" in json)
        config.formatter = json["formatter"].str.toFSharpFormatter();
    if ("autoFormat" in json)
        config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("checkOnly" in json)
        config.checkOnly = json["checkOnly"].str == "true";
    if ("configFile" in json)
        config.configFile = json["configFile"].str;
    if ("maxLineLength" in json)
        config.maxLineLength = cast(int)json["maxLineLength"].integer;
    if ("indentSize" in json)
        config.indentSize = cast(int)json["indentSize"].integer;
    if ("insertFinalNewline" in json)
        config.insertFinalNewline = json["insertFinalNewline"].type == JSONType.true_;
    if ("fsharpStyle" in json)
        config.fsharpStyle = json["fsharpStyle"].type == JSONType.true_;
    
    return config;
}

/// String to enum converters
FSharpAnalyzer toFSharpAnalyzer(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpAnalyzer.Auto;
        case "fsharplint": case "lint": return FSharpAnalyzer.FSharpLint;
        case "compiler": return FSharpAnalyzer.Compiler;
        case "ionide": return FSharpAnalyzer.Ionide;
        case "none": return FSharpAnalyzer.None;
        default: return FSharpAnalyzer.Auto;
    }
}

FSharpFormatter toFSharpFormatter(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpFormatter.Auto;
        case "fantomas": return FSharpFormatter.Fantomas;
        case "none": return FSharpFormatter.None;
        default: return FSharpFormatter.Auto;
    }
}

