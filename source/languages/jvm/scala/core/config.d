module languages.jvm.scala.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import analysis.targets.types;
import config.schema.schema;

/// Scala version variants
enum ScalaVersion
{
    /// Scala 2.12.x (LTS)
    Scala2_12,
    /// Scala 2.13.x (current stable)
    Scala2_13,
    /// Scala 3.x (Dotty)
    Scala3,
    /// Auto-detect from project
    Auto
}

/// Scala build modes
enum ScalaBuildMode
{
    /// Standard JAR library or executable
    JAR,
    /// Fat JAR with all dependencies (assembly/uber-jar)
    Assembly,
    /// GraalVM native image
    NativeImage,
    /// Scala.js JavaScript output
    ScalaJS,
    /// Scala Native compilation
    ScalaNative,
    /// Standard compilation without packaging
    Compile
}

/// Build tool selection
enum ScalaBuildTool
{
    /// Auto-detect from project structure
    Auto,
    /// sbt (Scala Build Tool) - primary
    SBT,
    /// Mill build tool (modern alternative)
    Mill,
    /// Scala CLI (lightweight)
    ScalaCLI,
    /// Apache Maven (with scala-maven-plugin)
    Maven,
    /// Gradle (with scala plugin)
    Gradle,
    /// Direct scalac/scala (no build tool)
    Direct,
    /// Bloop (build server)
    Bloop,
    /// None - manual control
    None
}

/// Testing framework selection
enum ScalaTestFramework
{
    /// Auto-detect from dependencies
    Auto,
    /// ScalaTest (most popular)
    ScalaTest,
    /// Specs2 (BDD-style)
    Specs2,
    /// MUnit (lightweight, fast)
    MUnit,
    /// uTest (minimal)
    UTest,
    /// ScalaCheck (property-based)
    ScalaCheck,
    /// ZIO Test
    ZIOTest,
    /// None - skip testing
    None
}

/// Code formatter selection
enum ScalaFormatter
{
    /// Auto-detect best available
    Auto,
    /// Scalafmt (standard)
    Scalafmt,
    /// None - skip formatting
    None
}

/// Static analyzer/linter selection
enum ScalaLinter
{
    /// Auto-detect best available
    Auto,
    /// Scalafix (refactoring/linting)
    Scalafix,
    /// WartRemover (functional purity)
    WartRemover,
    /// Scapegoat (static analysis)
    Scapegoat,
    /// Scalastyle (style checker)
    Scalastyle,
    /// None - skip analysis
    None
}

/// Compiler optimization level
enum OptimizationLevel
{
    /// No optimizations
    None,
    /// Basic optimizations
    Basic,
    /// Aggressive optimizations
    Aggressive
}

/// Scala version information
struct ScalaVersionInfo
{
    /// Major version (2 or 3)
    int major = 2;
    
    /// Minor version (12, 13 for Scala 2; 0, 1, 2... for Scala 3)
    int minor = 13;
    
    /// Patch version
    int patch = 0;
    
    /// Parse from string like "2.13.10", "3.3.0"
    static ScalaVersionInfo parse(string ver)
    {
        ScalaVersionInfo v;
        
        if (ver.empty)
            return v;
        
        auto parts = ver.split(".");
        if (parts.length >= 1)
            v.major = parts[0].to!int;
        if (parts.length >= 2)
            v.minor = parts[1].to!int;
        if (parts.length >= 3)
            v.patch = parts[2].to!int;
        
        return v;
    }
    
    /// Convert to string
    string toString() const
    {
        return format("%d.%d.%d", major, minor, patch);
    }
    
    /// Get binary version (e.g., "2.13", "3")
    string binaryVersion() const
    {
        if (major == 3)
            return "3";
        return format("%d.%d", major, minor);
    }
    
    /// Check if Scala 3
    bool isScala3() const
    {
        return major >= 3;
    }
    
    /// Check if supports given feature
    bool supportsGiven() const { return major >= 3; }
    bool supportsExtensionMethods() const { return major >= 3; }
    bool supportsOpaqueTypes() const { return major >= 3; }
    bool supportsUnionTypes() const { return major >= 3; }
    bool supportsMatchTypes() const { return major >= 3; }
    bool supportsContextFunctions() const { return major >= 3; }
    bool supportsPolymorphicFunctionTypes() const { return major >= 3; }
    bool supportsTypeClasses() const { return major >= 2 && minor >= 12; }
}

/// sbt configuration
struct SBTConfig
{
    /// Auto-reload on file changes
    bool autoReload = true;
    
    /// Clean before compile
    bool clean = false;
    
    /// Skip tests during compile
    bool skipTests = false;
    
    /// Offline mode
    bool offline = false;
    
    /// sbt tasks to run
    string[] tasks;
    
    /// Reload plugins
    bool reloadPlugins = false;
    
    /// Force recompilation
    bool force = false;
    
    /// Interactive mode
    bool interactive = false;
    
    /// sbt server mode
    bool serverMode = true;
    
    /// BSP (Build Server Protocol) mode
    bool bsp = false;
}

/// Mill configuration
struct MillConfig
{
    /// Clean before build
    bool clean = false;
    
    /// Skip tests
    bool skipTests = false;
    
    /// Watch mode for continuous builds
    bool watch = false;
    
    /// Mill tasks/targets
    string[] targets;
    
    /// Interactive mode
    bool interactive = false;
    
    /// Import ivy dependencies
    bool importIvy = true;
}

/// Scala CLI configuration
struct ScalaCLIConfig
{
    /// Main class
    string mainClass;
    
    /// Power mode (advanced features)
    bool power = false;
    
    /// Watch mode
    bool watch = false;
    
    /// Additional options
    string[] options;
    
    /// Java properties
    string[string] javaProps;
}

/// Scala.js configuration
struct ScalaJSConfig
{
    /// Enable Scala.js compilation
    bool enabled = false;
    
    /// Output mode (fastOpt, fullOpt)
    string mode = "fastOpt";
    
    /// Module kind (NoModule, CommonJSModule, ESModule)
    string moduleKind = "NoModule";
    
    /// Source map generation
    bool sourceMaps = true;
    
    /// ECMAScript version target
    string esVersion = "es2015";
    
    /// Enable optimizer
    bool optimize = false;
    
    /// Check IR
    bool checkIR = false;
}

/// Scala Native configuration
struct ScalaNativeConfig
{
    /// Enable Scala Native compilation
    bool enabled = false;
    
    /// Release mode (fast or full)
    string mode = "debug";
    
    /// Link-time optimization
    bool lto = true;
    
    /// Garbage collector (immix, boehm, none)
    string gc = "immix";
    
    /// Clang compiler to use
    string clang;
    
    /// Clang++ compiler
    string clangPP;
    
    /// Additional linker options
    string[] linkerOptions;
    
    /// Multithreading support
    bool multithreading = false;
}

/// Compiler configuration
struct CompilerConfig
{
    /// Optimization level
    OptimizationLevel optimization = OptimizationLevel.Basic;
    
    /// Enable warnings
    bool warnings = true;
    
    /// Treat warnings as errors
    bool warningsAsErrors = false;
    
    /// Enable deprecation warnings
    bool deprecation = true;
    
    /// Enable feature warnings (for experimental features)
    bool feature = true;
    
    /// Enable unchecked warnings
    bool unchecked = true;
    
    /// Explain type errors in detail
    bool explainTypes = false;
    
    /// Print types at definition sites
    bool printTypes = false;
    
    /// Enable Scala 3 experimental features
    bool experimental = false;
    
    /// Enable safe initialization checks (Scala 3)
    bool safeInit = false;
    
    /// Language features to enable
    string[] languageFeatures;
    
    /// Compiler plugins
    string[] plugins;
    
    /// Additional scalac options
    string[] options;
    
    /// Target JVM version
    string target = "1.8";
    
    /// Encoding
    string encoding = "UTF-8";
}

/// Testing configuration
struct TestConfig
{
    /// Testing framework
    ScalaTestFramework framework = ScalaTestFramework.Auto;
    
    /// Enable test execution
    bool enabled = true;
    
    /// Test pattern/glob
    string pattern = "**/*Test.scala,**/*Spec.scala";
    
    /// Enable coverage
    bool coverage = false;
    
    /// Coverage tool (scoverage)
    string coverageTool = "scoverage";
    
    /// Minimum coverage percentage
    double minCoverage = 0.0;
    
    /// Parallel test execution
    bool parallel = false;
    
    /// Fail fast on first error
    bool failFast = false;
    
    /// Verbose output
    bool verbose = false;
    
    /// Test options
    string[] options;
}

/// Formatter configuration
struct FormatterConfig
{
    /// Enable formatting
    bool enabled = false;
    
    /// Formatter to use
    ScalaFormatter formatter = ScalaFormatter.Auto;
    
    /// Auto-format before build
    bool autoFormat = false;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// Configuration file path (.scalafmt.conf)
    string configFile;
    
    /// Scalafmt version
    string version_;
}

/// Linter configuration
struct LinterConfig
{
    /// Enable linting
    bool enabled = false;
    
    /// Linter to use
    ScalaLinter linter = ScalaLinter.Auto;
    
    /// Fail build on warnings
    bool failOnWarnings = false;
    
    /// Configuration file
    string configFile;
    
    /// Rules to enable
    string[] rules;
    
    /// Rules to disable
    string[] disabledRules;
}

/// Documentation generation
struct DocConfig
{
    /// Generate Scaladoc
    bool enabled = false;
    
    /// Output directory
    string outputDir = "target/scaladoc";
    
    /// API mappings for external dependencies
    string[string] apiMappings;
    
    /// Additional doc options
    string[] options;
}

/// Native image configuration (GraalVM)
struct NativeConfig
{
    /// Enable native image compilation
    bool enabled = false;
    
    /// Main class
    string mainClass;
    
    /// Image name
    string imageName;
    
    /// Static linking
    bool staticImage = false;
    
    /// No fallback to JVM
    bool noFallback = true;
    
    /// Initialize at build time
    string[] initializeAtBuildTime;
    
    /// Initialize at run time
    string[] initializeAtRunTime;
    
    /// Enable reflection configuration
    bool enableReflection = true;
    
    /// Additional native-image arguments
    string[] buildArgs;
    
    /// GraalVM version requirement
    string graalVersion;
    
    /// Quick build mode (less optimization)
    bool quickBuild = false;
}

/// Dependency resolution
struct DependencyConfig
{
    /// Use Coursier for resolution
    bool useCoursier = true;
    
    /// Force resolution
    bool force = false;
    
    /// Additional resolvers
    string[] resolvers;
    
    /// Credentials for private repos
    string credentialsFile;
    
    /// Cache directory
    string cacheDir;
}

/// Complete Scala configuration
struct ScalaConfig
{
    /// Scala version
    ScalaVersionInfo versionInfo;
    
    /// Parse from JSON (required by ConfigParsingMixin)
    static ScalaConfig fromJSON(JSONValue json)
    {
        return parseScalaConfigFromJSON(json);
    }
    
    /// Build mode
    ScalaBuildMode mode = ScalaBuildMode.JAR;
    
    /// Build tool
    ScalaBuildTool buildTool = ScalaBuildTool.Auto;
    
    /// sbt configuration
    SBTConfig sbt;
    
    /// Mill configuration
    MillConfig mill;
    
    /// Scala CLI configuration
    ScalaCLIConfig scalaCli;
    
    /// Scala.js configuration
    ScalaJSConfig scalaJs;
    
    /// Scala Native configuration
    ScalaNativeConfig scalaNative;
    
    /// Compiler configuration
    CompilerConfig compiler;
    
    /// Testing configuration
    TestConfig test;
    
    /// Formatter configuration
    FormatterConfig formatter;
    
    /// Linter configuration
    LinterConfig linter;
    
    /// Documentation configuration
    DocConfig doc;
    
    /// Native image configuration
    NativeConfig nativeImage;
    
    /// Dependency configuration
    DependencyConfig dependencies;
    
    /// JVM flags for execution
    string[] jvmFlags;
    
    /// Classpath entries
    string[] classpath;
    
    /// Additional system properties
    string[string] systemProperties;
}

/// Parse Scala configuration from target
ScalaConfig parseScalaConfig(const Target target)
{
    ScalaConfig config;
    
    // Parse from langConfig JSON
    if ("scala" in target.langConfig)
    {
        try
        {
            JSONValue json = parseJSON(target.langConfig["scala"]);
            config = parseScalaConfigFromJSON(json);
        }
        catch (Exception e)
        {
            // Use defaults
        }
    }
    
    return config;
}

/// Parse Scala configuration from JSON
ScalaConfig parseScalaConfigFromJSON(JSONValue json)
{
    ScalaConfig config;
    
    // Version
    if ("version" in json)
        config.versionInfo = ScalaVersionInfo.parse(json["version"].str);
    
    // Build mode
    if ("mode" in json)
        config.mode = json["mode"].str.toScalaBuildMode();
    
    // Build tool
    if ("buildTool" in json)
        config.buildTool = json["buildTool"].str.toScalaBuildTool();
    
    // Sub-configurations
    if ("sbt" in json)
        config.sbt = parseSBTConfig(json["sbt"]);
    if ("mill" in json)
        config.mill = parseMillConfig(json["mill"]);
    if ("scalaCli" in json)
        config.scalaCli = parseScalaCLIConfig(json["scalaCli"]);
    if ("scalaJs" in json)
        config.scalaJs = parseScalaJSConfig(json["scalaJs"]);
    if ("scalaNative" in json)
        config.scalaNative = parseScalaNativeConfig(json["scalaNative"]);
    if ("compiler" in json)
        config.compiler = parseCompilerConfig(json["compiler"]);
    if ("test" in json)
        config.test = parseTestConfig(json["test"]);
    if ("formatter" in json)
        config.formatter = parseFormatterConfig(json["formatter"]);
    if ("linter" in json)
        config.linter = parseLinterConfig(json["linter"]);
    if ("doc" in json)
        config.doc = parseDocConfig(json["doc"]);
    if ("nativeImage" in json)
        config.nativeImage = parseNativeConfig(json["nativeImage"]);
    if ("dependencies" in json)
        config.dependencies = parseDependencyConfig(json["dependencies"]);
    
    // Simple arrays
    if ("jvmFlags" in json)
        config.jvmFlags = json["jvmFlags"].array.map!(e => e.str).array;
    if ("classpath" in json)
        config.classpath = json["classpath"].array.map!(e => e.str).array;
    
    return config;
}

// Helper parsing functions
private SBTConfig parseSBTConfig(JSONValue json)
{
    SBTConfig config;
    if ("autoReload" in json) config.autoReload = json["autoReload"].type == JSONType.true_;
    if ("clean" in json) config.clean = json["clean"].type == JSONType.true_;
    if ("skipTests" in json) config.skipTests = json["skipTests"].type == JSONType.true_;
    if ("offline" in json) config.offline = json["offline"].type == JSONType.true_;
    if ("tasks" in json) config.tasks = json["tasks"].array.map!(e => e.str).array;
    if ("reloadPlugins" in json) config.reloadPlugins = json["reloadPlugins"].type == JSONType.true_;
    if ("force" in json) config.force = json["force"].type == JSONType.true_;
    if ("interactive" in json) config.interactive = json["interactive"].type == JSONType.true_;
    if ("serverMode" in json) config.serverMode = json["serverMode"].type == JSONType.true_;
    if ("bsp" in json) config.bsp = json["bsp"].type == JSONType.true_;
    return config;
}

private MillConfig parseMillConfig(JSONValue json)
{
    MillConfig config;
    if ("clean" in json) config.clean = json["clean"].type == JSONType.true_;
    if ("skipTests" in json) config.skipTests = json["skipTests"].type == JSONType.true_;
    if ("watch" in json) config.watch = json["watch"].type == JSONType.true_;
    if ("targets" in json) config.targets = json["targets"].array.map!(e => e.str).array;
    if ("interactive" in json) config.interactive = json["interactive"].type == JSONType.true_;
    if ("importIvy" in json) config.importIvy = json["importIvy"].type == JSONType.true_;
    return config;
}

private ScalaCLIConfig parseScalaCLIConfig(JSONValue json)
{
    ScalaCLIConfig config;
    if ("mainClass" in json) config.mainClass = json["mainClass"].str;
    if ("power" in json) config.power = json["power"].type == JSONType.true_;
    if ("watch" in json) config.watch = json["watch"].type == JSONType.true_;
    if ("options" in json) config.options = json["options"].array.map!(e => e.str).array;
    return config;
}

private ScalaJSConfig parseScalaJSConfig(JSONValue json)
{
    ScalaJSConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("mode" in json) config.mode = json["mode"].str;
    if ("moduleKind" in json) config.moduleKind = json["moduleKind"].str;
    if ("sourceMaps" in json) config.sourceMaps = json["sourceMaps"].type == JSONType.true_;
    if ("esVersion" in json) config.esVersion = json["esVersion"].str;
    if ("optimize" in json) config.optimize = json["optimize"].type == JSONType.true_;
    if ("checkIR" in json) config.checkIR = json["checkIR"].type == JSONType.true_;
    return config;
}

private ScalaNativeConfig parseScalaNativeConfig(JSONValue json)
{
    ScalaNativeConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("mode" in json) config.mode = json["mode"].str;
    if ("lto" in json) config.lto = json["lto"].type == JSONType.true_;
    if ("gc" in json) config.gc = json["gc"].str;
    if ("clang" in json) config.clang = json["clang"].str;
    if ("clangPP" in json) config.clangPP = json["clangPP"].str;
    if ("linkerOptions" in json) config.linkerOptions = json["linkerOptions"].array.map!(e => e.str).array;
    if ("multithreading" in json) config.multithreading = json["multithreading"].type == JSONType.true_;
    return config;
}

private CompilerConfig parseCompilerConfig(JSONValue json)
{
    CompilerConfig config;
    if ("optimization" in json) config.optimization = json["optimization"].str.toOptimizationLevel();
    if ("warnings" in json) config.warnings = json["warnings"].type == JSONType.true_;
    if ("warningsAsErrors" in json) config.warningsAsErrors = json["warningsAsErrors"].type == JSONType.true_;
    if ("deprecation" in json) config.deprecation = json["deprecation"].type == JSONType.true_;
    if ("feature" in json) config.feature = json["feature"].type == JSONType.true_;
    if ("unchecked" in json) config.unchecked = json["unchecked"].type == JSONType.true_;
    if ("explainTypes" in json) config.explainTypes = json["explainTypes"].type == JSONType.true_;
    if ("printTypes" in json) config.printTypes = json["printTypes"].type == JSONType.true_;
    if ("experimental" in json) config.experimental = json["experimental"].type == JSONType.true_;
    if ("safeInit" in json) config.safeInit = json["safeInit"].type == JSONType.true_;
    if ("languageFeatures" in json) config.languageFeatures = json["languageFeatures"].array.map!(e => e.str).array;
    if ("plugins" in json) config.plugins = json["plugins"].array.map!(e => e.str).array;
    if ("options" in json) config.options = json["options"].array.map!(e => e.str).array;
    if ("target" in json) config.target = json["target"].str;
    if ("encoding" in json) config.encoding = json["encoding"].str;
    return config;
}

private TestConfig parseTestConfig(JSONValue json)
{
    TestConfig config;
    if ("framework" in json) config.framework = json["framework"].str.toScalaTestFramework();
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("pattern" in json) config.pattern = json["pattern"].str;
    if ("coverage" in json) config.coverage = json["coverage"].type == JSONType.true_;
    if ("coverageTool" in json) config.coverageTool = json["coverageTool"].str;
    if ("minCoverage" in json) config.minCoverage = json["minCoverage"].floating;
    if ("parallel" in json) config.parallel = json["parallel"].type == JSONType.true_;
    if ("failFast" in json) config.failFast = json["failFast"].type == JSONType.true_;
    if ("verbose" in json) config.verbose = json["verbose"].type == JSONType.true_;
    if ("options" in json) config.options = json["options"].array.map!(e => e.str).array;
    return config;
}

private FormatterConfig parseFormatterConfig(JSONValue json)
{
    FormatterConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("formatter" in json) config.formatter = json["formatter"].str.toScalaFormatter();
    if ("autoFormat" in json) config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("checkOnly" in json) config.checkOnly = json["checkOnly"].type == JSONType.true_;
    if ("configFile" in json) config.configFile = json["configFile"].str;
    if ("version" in json) config.version_ = json["version"].str;
    return config;
}

private LinterConfig parseLinterConfig(JSONValue json)
{
    LinterConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("linter" in json) config.linter = json["linter"].str.toScalaLinter();
    if ("failOnWarnings" in json) config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    if ("configFile" in json) config.configFile = json["configFile"].str;
    if ("rules" in json) config.rules = json["rules"].array.map!(e => e.str).array;
    if ("disabledRules" in json) config.disabledRules = json["disabledRules"].array.map!(e => e.str).array;
    return config;
}

private DocConfig parseDocConfig(JSONValue json)
{
    DocConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("outputDir" in json) config.outputDir = json["outputDir"].str;
    if ("options" in json) config.options = json["options"].array.map!(e => e.str).array;
    return config;
}

private NativeConfig parseNativeConfig(JSONValue json)
{
    NativeConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("mainClass" in json) config.mainClass = json["mainClass"].str;
    if ("imageName" in json) config.imageName = json["imageName"].str;
    if ("staticImage" in json) config.staticImage = json["staticImage"].type == JSONType.true_;
    if ("noFallback" in json) config.noFallback = json["noFallback"].type == JSONType.true_;
    if ("initializeAtBuildTime" in json) config.initializeAtBuildTime = json["initializeAtBuildTime"].array.map!(e => e.str).array;
    if ("initializeAtRunTime" in json) config.initializeAtRunTime = json["initializeAtRunTime"].array.map!(e => e.str).array;
    if ("enableReflection" in json) config.enableReflection = json["enableReflection"].type == JSONType.true_;
    if ("buildArgs" in json) config.buildArgs = json["buildArgs"].array.map!(e => e.str).array;
    if ("graalVersion" in json) config.graalVersion = json["graalVersion"].str;
    if ("quickBuild" in json) config.quickBuild = json["quickBuild"].type == JSONType.true_;
    return config;
}

private DependencyConfig parseDependencyConfig(JSONValue json)
{
    DependencyConfig config;
    if ("useCoursier" in json) config.useCoursier = json["useCoursier"].type == JSONType.true_;
    if ("force" in json) config.force = json["force"].type == JSONType.true_;
    if ("resolvers" in json) config.resolvers = json["resolvers"].array.map!(e => e.str).array;
    if ("credentialsFile" in json) config.credentialsFile = json["credentialsFile"].str;
    if ("cacheDir" in json) config.cacheDir = json["cacheDir"].str;
    return config;
}

// Enum conversion helpers
private ScalaBuildMode toScalaBuildMode(string s)
{
    switch (s.toLower)
    {
        case "jar": return ScalaBuildMode.JAR;
        case "assembly": case "fat-jar": case "fatjar": case "uber-jar": return ScalaBuildMode.Assembly;
        case "native-image": case "graalvm": return ScalaBuildMode.NativeImage;
        case "scalajs": case "scala-js": case "js": return ScalaBuildMode.ScalaJS;
        case "scalanative": case "scala-native": case "native": return ScalaBuildMode.ScalaNative;
        case "compile": return ScalaBuildMode.Compile;
        default: return ScalaBuildMode.JAR;
    }
}

private ScalaBuildTool toScalaBuildTool(string s)
{
    switch (s.toLower)
    {
        case "auto": return ScalaBuildTool.Auto;
        case "sbt": return ScalaBuildTool.SBT;
        case "mill": return ScalaBuildTool.Mill;
        case "scala-cli": case "scalacli": return ScalaBuildTool.ScalaCLI;
        case "maven": case "mvn": return ScalaBuildTool.Maven;
        case "gradle": return ScalaBuildTool.Gradle;
        case "direct": case "scalac": return ScalaBuildTool.Direct;
        case "bloop": return ScalaBuildTool.Bloop;
        case "none": return ScalaBuildTool.None;
        default: return ScalaBuildTool.Auto;
    }
}

private ScalaTestFramework toScalaTestFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return ScalaTestFramework.Auto;
        case "scalatest": return ScalaTestFramework.ScalaTest;
        case "specs2": return ScalaTestFramework.Specs2;
        case "munit": return ScalaTestFramework.MUnit;
        case "utest": return ScalaTestFramework.UTest;
        case "scalacheck": return ScalaTestFramework.ScalaCheck;
        case "ziotest": case "zio-test": return ScalaTestFramework.ZIOTest;
        case "none": return ScalaTestFramework.None;
        default: return ScalaTestFramework.Auto;
    }
}

private ScalaFormatter toScalaFormatter(string s)
{
    switch (s.toLower)
    {
        case "auto": return ScalaFormatter.Auto;
        case "scalafmt": return ScalaFormatter.Scalafmt;
        case "none": return ScalaFormatter.None;
        default: return ScalaFormatter.Auto;
    }
}

private ScalaLinter toScalaLinter(string s)
{
    switch (s.toLower)
    {
        case "auto": return ScalaLinter.Auto;
        case "scalafix": return ScalaLinter.Scalafix;
        case "wartremover": case "wart-remover": return ScalaLinter.WartRemover;
        case "scapegoat": return ScalaLinter.Scapegoat;
        case "scalastyle": return ScalaLinter.Scalastyle;
        case "none": return ScalaLinter.None;
        default: return ScalaLinter.Auto;
    }
}

private OptimizationLevel toOptimizationLevel(string s)
{
    switch (s.toLower)
    {
        case "none": return OptimizationLevel.None;
        case "basic": return OptimizationLevel.Basic;
        case "aggressive": case "full": return OptimizationLevel.Aggressive;
        default: return OptimizationLevel.Basic;
    }
}

