module languages.dotnet.fsharp.config.test;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Testing framework selection
enum FSharpTestFramework
{
    /// Auto-detect from dependencies
    Auto,
    /// Expecto (functional)
    Expecto,
    /// xUnit
    XUnit,
    /// NUnit
    NUnit,
    /// FsUnit
    FsUnit,
    /// Unquote
    Unquote,
    /// None - skip testing
    None
}

/// Testing configuration
struct FSharpTestConfig
{
    /// Testing framework
    FSharpTestFramework framework = FSharpTestFramework.Auto;
    
    /// Run tests in parallel
    bool parallel = true;
    
    /// Fail fast on first error
    bool failFast = false;
    
    /// Test filter expression
    string filter;
    
    /// Test name patterns
    string[] testPatterns;
    
    /// Additional test flags
    string[] testFlags;
    
    /// Code coverage
    bool coverage = false;
    
    /// Coverage tool (coverlet, altcover)
    string coverageTool = "coverlet";
    
    /// Minimum coverage threshold
    int coverageThreshold = 0;
    
    /// Timeout per test (seconds)
    int timeout = 300;
}

/// Parse FSharpTestConfig from JSON
FSharpTestConfig parseFSharpTestConfig(JSONValue json)
{
    FSharpTestConfig config;
    
    if ("framework" in json)
        config.framework = json["framework"].str.toFSharpTestFramework();
    if ("parallel" in json)
        config.parallel = json["parallel"].type == JSONType.true_;
    if ("failFast" in json)
        config.failFast = json["failFast"].type == JSONType.true_;
    if ("filter" in json)
        config.filter = json["filter"].str;
    if ("testPatterns" in json)
        config.testPatterns = json["testPatterns"].array.map!(e => e.str).array;
    if ("testFlags" in json)
        config.testFlags = json["testFlags"].array.map!(e => e.str).array;
    if ("coverage" in json)
        config.coverage = json["coverage"].type == JSONType.true_;
    if ("coverageTool" in json)
        config.coverageTool = json["coverageTool"].str;
    if ("coverageThreshold" in json)
        config.coverageThreshold = cast(int)json["coverageThreshold"].integer;
    if ("timeout" in json)
        config.timeout = cast(int)json["timeout"].integer;
    
    return config;
}

/// String to enum converter
FSharpTestFramework toFSharpTestFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return FSharpTestFramework.Auto;
        case "expecto": return FSharpTestFramework.Expecto;
        case "xunit": return FSharpTestFramework.XUnit;
        case "nunit": return FSharpTestFramework.NUnit;
        case "fsunit": return FSharpTestFramework.FsUnit;
        case "unquote": return FSharpTestFramework.Unquote;
        case "none": return FSharpTestFramework.None;
        default: return FSharpTestFramework.Auto;
    }
}

