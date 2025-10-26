module languages.jvm.java.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import analysis.targets.types;
import config.schema.schema;

/// Java build modes
enum JavaBuildMode
{
    /// Standard JAR library or executable
    JAR,
    /// Fat JAR with all dependencies (uber-jar)
    FatJAR,
    /// Web Application Archive
    WAR,
    /// Enterprise Archive
    EAR,
    /// Java 9+ modular JAR
    ModularJAR,
    /// GraalVM native image
    NativeImage,
    /// RAR (Resource Adapter Archive)
    RAR,
    /// Standard compilation without packaging
    Compile
}

/// Build tool selection
enum JavaBuildTool
{
    /// Auto-detect from project structure
    Auto,
    /// Apache Maven
    Maven,
    /// Gradle
    Gradle,
    /// Direct javac/jar (no build tool)
    Direct,
    /// Ant (legacy)
    Ant,
    /// None - manual control
    None
}

/// Testing framework selection
enum JavaTestFramework
{
    /// Auto-detect from dependencies
    Auto,
    /// JUnit 5 (Jupiter)
    JUnit5,
    /// JUnit 4
    JUnit4,
    /// TestNG
    TestNG,
    /// Spock (Groovy)
    Spock,
    /// None - skip testing
    None
}

/// Static analyzer selection
enum JavaAnalyzer
{
    /// Auto-detect best available
    Auto,
    /// SpotBugs (successor to FindBugs)
    SpotBugs,
    /// PMD source code analyzer
    PMD,
    /// Checkstyle code style checker
    Checkstyle,
    /// Error Prone (Google)
    ErrorProne,
    /// SonarQube/SonarLint
    SonarQube,
    /// None - skip analysis
    None
}

/// Code formatter selection
enum JavaFormatter
{
    /// Auto-detect best available
    Auto,
    /// google-java-format (Google Style)
    GoogleJavaFormat,
    /// Eclipse formatter
    Eclipse,
    /// IntelliJ formatter
    IntelliJ,
    /// Prettier with Java plugin
    Prettier,
    /// None - skip formatting
    None
}

/// Java version specification
struct JavaVersion
{
    /// Major version (8, 11, 17, 21, etc.)
    int major = 11;
    
    /// Minor version (optional)
    int minor = 0;
    
    /// Patch version (optional)
    int patch = 0;
    
    /// Parse from string like "11", "17.0.2", "1.8"
    static JavaVersion parse(string ver)
    {
        JavaVersion v;
        
        if (ver.empty)
            return v;
        
        auto parts = ver.split(".");
        if (parts.length >= 1)
        {
            // Handle legacy "1.8" format
            if (parts[0] == "1" && parts.length >= 2)
                v.major = parts[1].to!int;
            else
                v.major = parts[0].to!int;
        }
        if (parts.length >= 2 && parts[0] != "1")
            v.minor = parts[1].to!int;
        if (parts.length >= 3)
            v.patch = parts[2].to!int;
        
        return v;
    }
    
    /// Convert to string
    string toString() const
    {
        if (minor == 0 && patch == 0)
            return major.to!string;
        if (patch == 0)
            return format("%d.%d", major, minor);
        return format("%d.%d.%d", major, minor, patch);
    }
    
    /// Check if version supports modules (Java 9+)
    bool supportsModules() const
    {
        return major >= 9;
    }
    
    /// Check if version supports records (Java 14+)
    bool supportsRecords() const
    {
        return major >= 14;
    }
    
    /// Check if version supports sealed classes (Java 17+)
    bool supportsSealedClasses() const
    {
        return major >= 17;
    }
    
    /// Check if version supports pattern matching (Java 16+)
    bool supportsPatternMatching() const
    {
        return major >= 16;
    }
    
    /// Check if version supports text blocks (Java 15+)
    bool supportsTextBlocks() const
    {
        return major >= 15;
    }
    
    /// Check if version supports switch expressions (Java 14+)
    bool supportsSwitchExpressions() const
    {
        return major >= 14;
    }
    
    /// Check if version supports var (Java 10+)
    bool supportsVar() const
    {
        return major >= 10;
    }
}

/// Maven configuration
struct MavenConfig
{
    /// Auto-install dependencies
    bool autoInstall = true;
    
    /// Run mvn clean before build
    bool clean = false;
    
    /// Skip tests during build
    bool skipTests = false;
    
    /// Update snapshots
    bool updateSnapshots = false;
    
    /// Offline mode
    bool offline = false;
    
    /// Maven profiles to activate
    string[] profiles;
    
    /// Additional Maven goals
    string[] goals;
    
    /// Maven settings.xml path
    string settingsFile;
    
    /// Local repository path
    string localRepo;
}

/// Gradle configuration
struct GradleConfig
{
    /// Auto-install dependencies
    bool autoInstall = true;
    
    /// Run clean before build
    bool clean = false;
    
    /// Skip tests during build
    bool skipTests = false;
    
    /// Offline mode
    bool offline = false;
    
    /// Refresh dependencies
    bool refreshDependencies = false;
    
    /// Gradle tasks to run
    string[] tasks;
    
    /// Build type (e.g., "debug", "release")
    string buildType;
    
    /// Use Gradle daemon
    bool daemon = true;
    
    /// Parallel execution
    bool parallel = true;
    
    /// Configuration cache
    bool configurationCache = true;
}

/// Module system configuration (Java 9+)
struct ModuleConfig
{
    /// Enable module system
    bool enabled = false;
    
    /// Module name
    string moduleName;
    
    /// Module path
    string[] modulePath;
    
    /// Add modules
    string[] addModules;
    
    /// Add exports
    string[] addExports;
    
    /// Add opens
    string[] addOpens;
    
    /// Add reads
    string[] addReads;
    
    /// Patch modules
    string[string] patchModule;
}

/// Annotation processor configuration
struct ProcessorConfig
{
    /// Enable annotation processing
    bool enabled = false;
    
    /// Processor class names
    string[] processors;
    
    /// Processor path
    string[] processorPath;
    
    /// Processor options
    string[string] options;
    
    /// Common processors
    bool lombok = false;
    bool mapstruct = false;
    bool autovalue = false;
    bool dagger = false;
    bool immutables = false;
}

/// Native image configuration (GraalVM)
struct NativeConfig
{
    /// Enable native image compilation
    bool enabled = false;
    
    /// Main class for native image
    string mainClass;
    
    /// Native image name
    string imageName;
    
    /// Static linking
    bool staticImage = false;
    
    /// Include all metadata
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
}

/// Testing configuration
struct TestConfig
{
    /// Testing framework
    JavaTestFramework framework = JavaTestFramework.Auto;
    
    /// Enable test execution
    bool enabled = true;
    
    /// Test pattern
    string pattern = "**/*Test.java";
    
    /// Enable coverage
    bool coverage = false;
    
    /// Coverage tool (jacoco, cobertura)
    string coverageTool = "jacoco";
    
    /// Coverage output format
    string[] coverageFormats = ["html", "xml"];
    
    /// Minimum coverage percentage
    double minCoverage = 0.0;
    
    /// Parallel test execution
    bool parallel = false;
    
    /// Fail fast on first error
    bool failFast = false;
    
    /// Verbose output
    bool verbose = false;
}

/// Static analysis configuration
struct AnalysisConfig
{
    /// Enable static analysis
    bool enabled = false;
    
    /// Analyzer to use
    JavaAnalyzer analyzer = JavaAnalyzer.Auto;
    
    /// Fail build on warnings
    bool failOnWarnings = false;
    
    /// Fail build on errors
    bool failOnErrors = true;
    
    /// Effort level (min, default, max) for SpotBugs
    string effort = "default";
    
    /// Threshold (low, medium, high) for issues
    string threshold = "medium";
    
    /// Exclude patterns
    string[] excludePatterns;
    
    /// Configuration file path
    string configFile;
    
    /// Maximum number of violations allowed
    int maxViolations = 0;
}

/// Formatter configuration
struct FormatterConfig
{
    /// Enable formatting
    bool enabled = false;
    
    /// Formatter to use
    JavaFormatter formatter = JavaFormatter.Auto;
    
    /// Auto-format before build
    bool autoFormat = false;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// Configuration file path
    string configFile;
    
    /// Style guide (google, aosp, etc.)
    string style = "google";
}

/// Packaging configuration
struct PackagingConfig
{
    /// Main class for executable JARs
    string mainClass;
    
    /// Manifest attributes
    string[string] manifestAttributes;
    
    /// Include dependencies in JAR
    bool includeDependencies = false;
    
    /// Shade/relocate packages (for fat JARs)
    string[string] relocations;
    
    /// Minimize JAR (remove unused classes)
    bool minimize = false;
    
    /// Create sources JAR
    bool createSourcesJar = false;
    
    /// Create Javadoc JAR
    bool createJavadocJar = false;
    
    /// Compress JAR
    bool compress = true;
    
    /// JAR index
    bool createIndex = true;
}

/// Complete Java configuration
struct JavaConfig
{
    /// Build mode
    JavaBuildMode mode = JavaBuildMode.JAR;
    
    /// Build tool
    JavaBuildTool buildTool = JavaBuildTool.Auto;
    
    /// Java version (source)
    JavaVersion sourceVersion;
    
    /// Java version (target)
    JavaVersion targetVersion;
    
    /// Maven configuration
    MavenConfig maven;
    
    /// Gradle configuration
    GradleConfig gradle;
    
    /// Module system configuration
    ModuleConfig modules;
    
    /// Annotation processors
    ProcessorConfig processors;
    
    /// Native image configuration
    NativeConfig nativeImage;
    
    /// Testing configuration
    TestConfig test;
    
    /// Static analysis
    AnalysisConfig analysis;
    
    /// Code formatting
    FormatterConfig formatter;
    
    /// Packaging
    PackagingConfig packaging;
    
    /// Compiler flags
    string[] compilerFlags;
    
    /// JVM flags for execution
    string[] jvmFlags;
    
    /// Classpath entries
    string[] classpath;
    
    /// Encoding
    string encoding = "UTF-8";
    
    /// Enable warnings
    bool warnings = true;
    
    /// Treat warnings as errors
    bool warningsAsErrors = false;
    
    /// Enable deprecation warnings
    bool deprecation = true;
    
    /// Enable preview features
    bool enablePreview = false;
    
    /// Add exports for compilation
    string[] addExports;
    
    /// Add opens for compilation
    string[] addOpens;
}

/// Parse Java configuration from target
JavaConfig parseJavaConfig(Target target)
{
    JavaConfig config;
    
    // Parse from langConfig JSON
    if ("java" in target.langConfig)
    {
        try
        {
            JSONValue json = parseJSON(target.langConfig["java"]);
            config = parseJavaConfigFromJSON(json);
        }
        catch (Exception e)
        {
            // Use defaults
        }
    }
    
    return config;
}

/// Parse Java configuration from JSON
JavaConfig parseJavaConfigFromJSON(JSONValue json)
{
    JavaConfig config;
    
    // Build mode
    if ("mode" in json)
        config.mode = json["mode"].str.toJavaBuildMode();
    
    // Build tool
    if ("buildTool" in json)
        config.buildTool = json["buildTool"].str.toJavaBuildTool();
    
    // Java versions
    if ("sourceVersion" in json)
        config.sourceVersion = JavaVersion.parse(json["sourceVersion"].str);
    if ("targetVersion" in json)
        config.targetVersion = JavaVersion.parse(json["targetVersion"].str);
    
    // Maven
    if ("maven" in json)
        config.maven = parseMavenConfig(json["maven"]);
    
    // Gradle
    if ("gradle" in json)
        config.gradle = parseGradleConfig(json["gradle"]);
    
    // Modules
    if ("modules" in json)
        config.modules = parseModuleConfig(json["modules"]);
    
    // Processors
    if ("processors" in json)
        config.processors = parseProcessorConfig(json["processors"]);
    
    // Native image
    if ("nativeImage" in json)
        config.nativeImage = parseNativeConfig(json["nativeImage"]);
    
    // Testing
    if ("test" in json)
        config.test = parseTestConfig(json["test"]);
    
    // Analysis
    if ("analysis" in json)
        config.analysis = parseAnalysisConfig(json["analysis"]);
    
    // Formatter
    if ("formatter" in json)
        config.formatter = parseFormatterConfig(json["formatter"]);
    
    // Packaging
    if ("packaging" in json)
        config.packaging = parsePackagingConfig(json["packaging"]);
    
    // Simple fields
    if ("compilerFlags" in json)
        config.compilerFlags = json["compilerFlags"].array.map!(e => e.str).array;
    if ("jvmFlags" in json)
        config.jvmFlags = json["jvmFlags"].array.map!(e => e.str).array;
    if ("classpath" in json)
        config.classpath = json["classpath"].array.map!(e => e.str).array;
    if ("encoding" in json)
        config.encoding = json["encoding"].str;
    if ("warnings" in json)
        config.warnings = json["warnings"].type == JSONType.true_;
    if ("warningsAsErrors" in json)
        config.warningsAsErrors = json["warningsAsErrors"].type == JSONType.true_;
    if ("deprecation" in json)
        config.deprecation = json["deprecation"].type == JSONType.true_;
    if ("enablePreview" in json)
        config.enablePreview = json["enablePreview"].type == JSONType.true_;
    
    return config;
}

// Helper parsing functions
private MavenConfig parseMavenConfig(JSONValue json)
{
    MavenConfig config;
    if ("autoInstall" in json) config.autoInstall = json["autoInstall"].type == JSONType.true_;
    if ("clean" in json) config.clean = json["clean"].type == JSONType.true_;
    if ("skipTests" in json) config.skipTests = json["skipTests"].type == JSONType.true_;
    if ("updateSnapshots" in json) config.updateSnapshots = json["updateSnapshots"].type == JSONType.true_;
    if ("offline" in json) config.offline = json["offline"].type == JSONType.true_;
    if ("profiles" in json) config.profiles = json["profiles"].array.map!(e => e.str).array;
    if ("goals" in json) config.goals = json["goals"].array.map!(e => e.str).array;
    if ("settingsFile" in json) config.settingsFile = json["settingsFile"].str;
    if ("localRepo" in json) config.localRepo = json["localRepo"].str;
    return config;
}

private GradleConfig parseGradleConfig(JSONValue json)
{
    GradleConfig config;
    if ("autoInstall" in json) config.autoInstall = json["autoInstall"].type == JSONType.true_;
    if ("clean" in json) config.clean = json["clean"].type == JSONType.true_;
    if ("skipTests" in json) config.skipTests = json["skipTests"].type == JSONType.true_;
    if ("offline" in json) config.offline = json["offline"].type == JSONType.true_;
    if ("refreshDependencies" in json) config.refreshDependencies = json["refreshDependencies"].type == JSONType.true_;
    if ("tasks" in json) config.tasks = json["tasks"].array.map!(e => e.str).array;
    if ("buildType" in json) config.buildType = json["buildType"].str;
    if ("daemon" in json) config.daemon = json["daemon"].type == JSONType.true_;
    if ("parallel" in json) config.parallel = json["parallel"].type == JSONType.true_;
    if ("configurationCache" in json) config.configurationCache = json["configurationCache"].type == JSONType.true_;
    return config;
}

private ModuleConfig parseModuleConfig(JSONValue json)
{
    ModuleConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("moduleName" in json) config.moduleName = json["moduleName"].str;
    if ("modulePath" in json) config.modulePath = json["modulePath"].array.map!(e => e.str).array;
    if ("addModules" in json) config.addModules = json["addModules"].array.map!(e => e.str).array;
    if ("addExports" in json) config.addExports = json["addExports"].array.map!(e => e.str).array;
    if ("addOpens" in json) config.addOpens = json["addOpens"].array.map!(e => e.str).array;
    if ("addReads" in json) config.addReads = json["addReads"].array.map!(e => e.str).array;
    return config;
}

private ProcessorConfig parseProcessorConfig(JSONValue json)
{
    ProcessorConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("processors" in json) config.processors = json["processors"].array.map!(e => e.str).array;
    if ("processorPath" in json) config.processorPath = json["processorPath"].array.map!(e => e.str).array;
    if ("lombok" in json) config.lombok = json["lombok"].type == JSONType.true_;
    if ("mapstruct" in json) config.mapstruct = json["mapstruct"].type == JSONType.true_;
    if ("autovalue" in json) config.autovalue = json["autovalue"].type == JSONType.true_;
    if ("dagger" in json) config.dagger = json["dagger"].type == JSONType.true_;
    if ("immutables" in json) config.immutables = json["immutables"].type == JSONType.true_;
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
    return config;
}

private TestConfig parseTestConfig(JSONValue json)
{
    TestConfig config;
    if ("framework" in json) config.framework = json["framework"].str.toJavaTestFramework();
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("pattern" in json) config.pattern = json["pattern"].str;
    if ("coverage" in json) config.coverage = json["coverage"].type == JSONType.true_;
    if ("coverageTool" in json) config.coverageTool = json["coverageTool"].str;
    if ("coverageFormats" in json) config.coverageFormats = json["coverageFormats"].array.map!(e => e.str).array;
    if ("minCoverage" in json) config.minCoverage = json["minCoverage"].floating;
    if ("parallel" in json) config.parallel = json["parallel"].type == JSONType.true_;
    if ("failFast" in json) config.failFast = json["failFast"].type == JSONType.true_;
    if ("verbose" in json) config.verbose = json["verbose"].type == JSONType.true_;
    return config;
}

private AnalysisConfig parseAnalysisConfig(JSONValue json)
{
    AnalysisConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("analyzer" in json) config.analyzer = json["analyzer"].str.toJavaAnalyzer();
    if ("failOnWarnings" in json) config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    if ("failOnErrors" in json) config.failOnErrors = json["failOnErrors"].type == JSONType.true_;
    if ("effort" in json) config.effort = json["effort"].str;
    if ("threshold" in json) config.threshold = json["threshold"].str;
    if ("excludePatterns" in json) config.excludePatterns = json["excludePatterns"].array.map!(e => e.str).array;
    if ("configFile" in json) config.configFile = json["configFile"].str;
    if ("maxViolations" in json) config.maxViolations = json["maxViolations"].integer.to!int;
    return config;
}

private FormatterConfig parseFormatterConfig(JSONValue json)
{
    FormatterConfig config;
    if ("enabled" in json) config.enabled = json["enabled"].type == JSONType.true_;
    if ("formatter" in json) config.formatter = json["formatter"].str.toJavaFormatter();
    if ("autoFormat" in json) config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("checkOnly" in json) config.checkOnly = json["checkOnly"].type == JSONType.true_;
    if ("configFile" in json) config.configFile = json["configFile"].str;
    if ("style" in json) config.style = json["style"].str;
    return config;
}

private PackagingConfig parsePackagingConfig(JSONValue json)
{
    PackagingConfig config;
    if ("mainClass" in json) config.mainClass = json["mainClass"].str;
    if ("includeDependencies" in json) config.includeDependencies = json["includeDependencies"].type == JSONType.true_;
    if ("minimize" in json) config.minimize = json["minimize"].type == JSONType.true_;
    if ("createSourcesJar" in json) config.createSourcesJar = json["createSourcesJar"].type == JSONType.true_;
    if ("createJavadocJar" in json) config.createJavadocJar = json["createJavadocJar"].type == JSONType.true_;
    if ("compress" in json) config.compress = json["compress"].type == JSONType.true_;
    if ("createIndex" in json) config.createIndex = json["createIndex"].type == JSONType.true_;
    return config;
}

// Enum conversion helpers
private JavaBuildMode toJavaBuildMode(string s)
{
    switch (s.toLower)
    {
        case "jar": return JavaBuildMode.JAR;
        case "fatjar": case "fat-jar": case "uber-jar": case "uberjar": return JavaBuildMode.FatJAR;
        case "war": return JavaBuildMode.WAR;
        case "ear": return JavaBuildMode.EAR;
        case "modular": case "modular-jar": return JavaBuildMode.ModularJAR;
        case "native": case "native-image": return JavaBuildMode.NativeImage;
        case "rar": return JavaBuildMode.RAR;
        case "compile": return JavaBuildMode.Compile;
        default: return JavaBuildMode.JAR;
    }
}

private JavaBuildTool toJavaBuildTool(string s)
{
    switch (s.toLower)
    {
        case "auto": return JavaBuildTool.Auto;
        case "maven": case "mvn": return JavaBuildTool.Maven;
        case "gradle": return JavaBuildTool.Gradle;
        case "direct": return JavaBuildTool.Direct;
        case "ant": return JavaBuildTool.Ant;
        case "none": return JavaBuildTool.None;
        default: return JavaBuildTool.Auto;
    }
}

private JavaTestFramework toJavaTestFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return JavaTestFramework.Auto;
        case "junit5": case "junit-5": case "jupiter": return JavaTestFramework.JUnit5;
        case "junit4": case "junit-4": case "junit": return JavaTestFramework.JUnit4;
        case "testng": return JavaTestFramework.TestNG;
        case "spock": return JavaTestFramework.Spock;
        case "none": return JavaTestFramework.None;
        default: return JavaTestFramework.Auto;
    }
}

private JavaAnalyzer toJavaAnalyzer(string s)
{
    switch (s.toLower)
    {
        case "auto": return JavaAnalyzer.Auto;
        case "spotbugs": return JavaAnalyzer.SpotBugs;
        case "pmd": return JavaAnalyzer.PMD;
        case "checkstyle": return JavaAnalyzer.Checkstyle;
        case "errorprone": case "error-prone": return JavaAnalyzer.ErrorProne;
        case "sonarqube": case "sonar": return JavaAnalyzer.SonarQube;
        case "none": return JavaAnalyzer.None;
        default: return JavaAnalyzer.Auto;
    }
}

private JavaFormatter toJavaFormatter(string s)
{
    switch (s.toLower)
    {
        case "auto": return JavaFormatter.Auto;
        case "google": case "google-java-format": return JavaFormatter.GoogleJavaFormat;
        case "eclipse": return JavaFormatter.Eclipse;
        case "intellij": return JavaFormatter.IntelliJ;
        case "prettier": return JavaFormatter.Prettier;
        case "none": return JavaFormatter.None;
        default: return JavaFormatter.Auto;
    }
}

