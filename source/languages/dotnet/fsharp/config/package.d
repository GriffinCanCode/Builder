module languages.dotnet.fsharp.config;

/// F# Configuration Modules
/// 
/// Grouped configuration pattern for maintainability.
/// Each module handles one aspect of F# configuration.

import std.json;
import analysis.targets.types;

public import languages.dotnet.fsharp.config.build;
public import languages.dotnet.fsharp.config.dependency;
public import languages.dotnet.fsharp.config.quality;
public import languages.dotnet.fsharp.config.test;

/// Unified F# configuration
/// Composes specialized config groups
struct FSharpConfig
{
    FSharpBuildConfig build;
    FSharpDependencyConfig dependencies;
    FSharpQualityConfig quality;
    FSharpTestConfig test;
    
    // Convenience accessors for common patterns
    ref FSharpBuildMode mode() return { return build.mode; }
    ref FSharpBuildTool buildTool() return { return build.buildTool; }
    ref FSharpCompiler compiler() return { return build.compiler; }
    ref FSharpPlatform platform() return { return build.platform; }
    ref FSharpVersion languageVersion() return { return build.languageVersion; }
    ref DotnetConfig dotnet() return { return build.dotnet; }
    ref FAKEConfig fake() return { return build.fake; }
    ref FSIConfig fsi() return { return build.fsi; }
    ref FableConfig fable() return { return build.fable; }
    ref NativeAOTConfig native() return { return build.native; }
    ref FSharpPackagingConfig packaging() return { return build.packaging; }
    ref string[] compilerFlags() return { return build.compilerFlags; }
    ref string[] defines() return { return build.defines; }
    ref bool checked() return { return build.checked; }
    ref bool debug_() return { return build.debug_; }
    ref bool optimize() return { return build.optimize; }
    ref bool tailcalls() return { return build.tailcalls; }
    ref bool crossoptimize() return { return build.crossoptimize; }
    ref bool deterministic() return { return build.deterministic; }
    ref bool generateDocs() return { return build.generateDocs; }
    ref string xmlDoc() return { return build.xmlDoc; }
    ref bool verbose() return { return build.verbose; }
    
    ref FSharpPackageManager packageManager() return { return dependencies.packageManager; }
    ref PaketConfig paket() return { return dependencies.paket; }
    ref NuGetConfig nuget() return { return dependencies.nuget; }
    
    ref FSharpAnalysisConfig analysis() return { return quality.analysis; }
    ref FSharpFormatterConfig formatter() return { return quality.formatter; }
    
    /// Parse from JSON (required by ConfigParsingMixin)
    static FSharpConfig fromJSON(JSONValue json)
    {
        return parseFSharpConfigFromJSON(json);
    }
}

/// Parse F# configuration from target
FSharpConfig parseFSharpConfig(in Target target)
{
    FSharpConfig config;
    
    // Parse from langConfig JSON
    if ("fsharp" in target.langConfig)
    {
        try
        {
            JSONValue json = parseJSON(target.langConfig["fsharp"]);
            config = parseFSharpConfigFromJSON(json);
        }
        catch (Exception e)
        {
            // Use defaults
        }
    }
    
    return config;
}

/// Parse F# configuration from JSON
FSharpConfig parseFSharpConfigFromJSON(JSONValue json)
{
    FSharpConfig config;
    
    // Build configuration
    if ("mode" in json)
        config.build.mode = json["mode"].str.toFSharpBuildMode();
    if ("buildTool" in json)
        config.build.buildTool = json["buildTool"].str.toFSharpBuildTool();
    if ("compiler" in json)
        config.build.compiler = json["compiler"].str.toFSharpCompiler();
    if ("platform" in json)
        config.build.platform = json["platform"].str.toFSharpPlatform();
    if ("languageVersion" in json)
        config.build.languageVersion = FSharpVersion.parse(json["languageVersion"].str);
    if ("dotnet" in json)
        config.build.dotnet = parseDotnetConfig(json["dotnet"]);
    if ("fake" in json)
        config.build.fake = parseFAKEConfig(json["fake"]);
    if ("fsi" in json)
        config.build.fsi = parseFSIConfig(json["fsi"]);
    if ("fable" in json)
        config.build.fable = parseFableConfig(json["fable"]);
    if ("native" in json)
        config.build.native = parseNativeAOTConfig(json["native"]);
    if ("packaging" in json)
        config.build.packaging = parseFSharpPackagingConfig(json["packaging"]);
    if ("compilerFlags" in json)
    {
        import std.algorithm : map;
        import std.array : array;
        config.build.compilerFlags = json["compilerFlags"].array.map!(e => e.str).array;
    }
    if ("defines" in json)
    {
        import std.algorithm : map;
        import std.array : array;
        config.build.defines = json["defines"].array.map!(e => e.str).array;
    }
    if ("checked" in json)
        config.build.checked = json["checked"].type == JSONType.true_;
    if ("debug" in json)
        config.build.debug_ = json["debug"].type == JSONType.true_;
    if ("optimize" in json)
        config.build.optimize = json["optimize"].type == JSONType.true_;
    if ("tailcalls" in json)
        config.build.tailcalls = json["tailcalls"].type == JSONType.true_;
    if ("crossoptimize" in json)
        config.build.crossoptimize = json["crossoptimize"].type == JSONType.true_;
    if ("deterministic" in json)
        config.build.deterministic = json["deterministic"].type == JSONType.true_;
    if ("generateDocs" in json)
        config.build.generateDocs = json["generateDocs"].type == JSONType.true_;
    if ("xmlDoc" in json)
        config.build.xmlDoc = json["xmlDoc"].str;
    if ("verbose" in json)
        config.build.verbose = json["verbose"].type == JSONType.true_;
    
    // Dependency configuration
    if ("packageManager" in json)
        config.dependencies.packageManager = json["packageManager"].str.toFSharpPackageManager();
    if ("paket" in json)
        config.dependencies.paket = parsePaketConfig(json["paket"]);
    if ("nuget" in json)
        config.dependencies.nuget = parseNuGetConfig(json["nuget"]);
    
    // Quality configuration
    if ("analysis" in json)
        config.quality.analysis = parseFSharpAnalysisConfig(json["analysis"]);
    if ("formatter" in json)
        config.quality.formatter = parseFSharpFormatterConfig(json["formatter"]);
    
    // Testing configuration
    if ("test" in json)
        config.test = parseFSharpTestConfig(json["test"]);
    
    return config;
}

