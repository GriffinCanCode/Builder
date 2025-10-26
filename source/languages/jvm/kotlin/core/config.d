module languages.jvm.kotlin.core.config;

import std.json;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import analysis.targets.types;
import config.schema.schema;

/// Kotlin build modes
enum KotlinBuildMode
{
    /// Standard JAR library or executable
    JAR,
    /// Fat JAR with all dependencies (uber-jar)
    FatJAR,
    /// Kotlin/Native executable
    Native,
    /// Kotlin/JS bundle
    JS,
    /// Kotlin Multiplatform
    Multiplatform,
    /// Android AAR
    Android,
    /// Standard compilation without packaging
    Compile
}

/// Build tool selection
enum KotlinBuildTool
{
    /// Auto-detect from project structure
    Auto,
    /// Gradle (recommended)
    Gradle,
    /// Maven with Kotlin plugin
    Maven,
    /// Direct kotlinc (no build tool)
    Direct,
    /// None - manual control
    None
}

/// Kotlin compiler selection
enum KotlinCompiler
{
    /// Auto-detect best available
    Auto,
    /// Official kotlinc (JVM)
    KotlinC,
    /// Kotlin/Native compiler
    KotlinNative,
    /// Kotlin/JS compiler (IR backend)
    KotlinJS,
    /// Kotlin/JVM compiler (optimized)
    KotlinJVM
}

/// Kotlin platform target
enum KotlinPlatform
{
    /// JVM bytecode
    JVM,
    /// JavaScript (IR backend)
    JS,
    /// Native binary (platform-specific)
    Native,
    /// Common multiplatform code
    Common,
    /// Android
    Android,
    /// WebAssembly (experimental)
    Wasm
}

/// Testing framework selection
enum KotlinTestFramework
{
    /// Auto-detect from dependencies
    Auto,
    /// kotlin.test
    KotlinTest,
    /// JUnit 5
    JUnit5,
    /// JUnit 4
    JUnit4,
    /// Kotest
    Kotest,
    /// Spek
    Spek,
    /// None - skip testing
    None
}

/// Code analyzer selection
enum KotlinAnalyzer
{
    /// Auto-detect best available
    Auto,
    /// detekt (comprehensive linter)
    Detekt,
    /// KtLint (style checker)
    KtLint,
    /// Compiler warnings only
    Compiler,
    /// None - skip analysis
    None
}

/// Code formatter selection
enum KotlinFormatter
{
    /// Auto-detect best available
    Auto,
    /// ktlint (official style)
    KtLint,
    /// ktfmt (Google style)
    KtFmt,
    /// IntelliJ IDEA formatter
    IntelliJ,
    /// None - skip formatting
    None
}

/// Annotation processor type
enum ProcessorType
{
    /// KAPT (Kotlin Annotation Processing Tool)
    KAPT,
    /// KSP (Kotlin Symbol Processing)
    KSP
}

/// Kotlin language version
struct KotlinVersion
{
    /// Major version (1, 2, etc.)
    int major = 1;
    
    /// Minor version
    int minor = 9;
    
    /// Patch version
    int patch = 0;
    
    /// Parse from string like "1.9", "2.0.0"
    static KotlinVersion parse(string ver)
    {
        KotlinVersion v;
        
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
        if (patch == 0)
            return format("%d.%d", major, minor);
        return format("%d.%d.%d", major, minor, patch);
    }
    
    /// Check if version supports coroutines (1.3+)
    bool supportsCoroutines() const
    {
        return major > 1 || (major == 1 && minor >= 3);
    }
    
    /// Check if version supports inline classes (1.3+)
    bool supportsInlineClasses() const
    {
        return major > 1 || (major == 1 && minor >= 3);
    }
    
    /// Check if version supports contracts (1.3+)
    bool supportsContracts() const
    {
        return major > 1 || (major == 1 && minor >= 3);
    }
    
    /// Check if version supports sealed interfaces (1.5+)
    bool supportsSealedInterfaces() const
    {
        return major > 1 || (major == 1 && minor >= 5);
    }
    
    /// Check if version supports JVM IR backend (1.5+)
    bool supportsJVMIR() const
    {
        return major > 1 || (major == 1 && minor >= 5);
    }
    
    /// Check if version supports Kotlin/JS IR (1.4+)
    bool supportsJSIR() const
    {
        return major > 1 || (major == 1 && minor >= 4);
    }
    
    /// Check if version supports KSP (1.5+)
    bool supportsKSP() const
    {
        return major > 1 || (major == 1 && minor >= 5);
    }
    
    /// Check if version supports context receivers (1.6.20+)
    bool supportsContextReceivers() const
    {
        return major > 1 || (major == 1 && minor > 6) || 
               (major == 1 && minor == 6 && patch >= 20);
    }
    
    /// Check if version supports data objects (1.9+)
    bool supportsDataObjects() const
    {
        return major > 1 || (major == 1 && minor >= 9);
    }
    
    /// Check if version supports K2 compiler (2.0+)
    bool supportsK2() const
    {
        return major >= 2;
    }
}

/// JVM target version for Kotlin
struct JVMTarget
{
    /// Target version (8, 11, 17, 21, etc.)
    int targetVersion = 11;
    
    /// Parse from string like "1.8", "11", "17"
    static JVMTarget parse(string ver)
    {
        JVMTarget target;
        
        if (ver.empty)
            return target;
        
        // Handle legacy "1.8" format
        if (ver.startsWith("1."))
        {
            auto parts = ver.split(".");
            if (parts.length >= 2)
                target.targetVersion = parts[1].to!int;
        }
        else
        {
            target.targetVersion = ver.to!int;
        }
        
        return target;
    }
    
    /// Convert to string (1.8 format)
    string toString() const
    {
        if (targetVersion == 8)
            return "1.8";
        return targetVersion.to!string;
    }
}

/// Gradle configuration for Kotlin
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
    
    /// Use Kotlin DSL (build.gradle.kts)
    bool kotlinDSL = true;
}

/// Maven configuration for Kotlin
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

/// Annotation processor configuration
struct ProcessorConfig
{
    /// Enable annotation processing
    bool enabled = false;
    
    /// Processor type
    ProcessorType type = ProcessorType.KSP;
    
    /// Annotation processor classes
    string[] processors;
    
    /// Arguments to pass to processors
    string[string] arguments;
    
    /// Generated source output directory
    string outputDir;
    
    /// Include compiled classes in output
    bool includeCompileClasspath = true;
    
    /// Verbose processor output
    bool verbose = false;
    
    /// KAPT: Correct error types
    bool correctErrorTypes = true;
    
    /// KAPT: Use K2 KAPT
    bool useK2 = false;
    
    /// KSP: Enable incremental processing
    bool incremental = true;
    
    /// KSP: All warnings as errors
    bool allWarningsAsErrors = false;
}

/// Coroutines configuration
struct CoroutinesConfig
{
    /// Enable coroutines
    bool enabled = true;
    
    /// kotlinx-coroutines version
    string version_ = "1.8.0";
    
    /// Enable debug mode
    bool debugMode = false;
    
    /// Enable flow
    bool flow = true;
    
    /// Enable channels
    bool channels = true;
    
    /// JVM specific: use -Xmx for coroutines
    bool jvmOptimize = true;
}

/// Testing configuration
struct TestConfig
{
    /// Testing framework
    KotlinTestFramework framework = KotlinTestFramework.Auto;
    
    /// Run tests in parallel
    bool parallel = true;
    
    /// Fail fast on first error
    bool failFast = false;
    
    /// Test name pattern filter
    string[] testPatterns;
    
    /// Additional test flags
    string[] testFlags;
    
    /// Code coverage
    bool coverage = false;
    
    /// Coverage tool (jacoco, kover)
    string coverageTool = "kover";
    
    /// Minimum coverage threshold
    int coverageThreshold = 0;
}

/// Static analysis configuration
struct AnalysisConfig
{
    /// Enable static analysis
    bool enabled = false;
    
    /// Analyzer to use
    KotlinAnalyzer analyzer = KotlinAnalyzer.Auto;
    
    /// Fail build on warnings
    bool failOnWarnings = false;
    
    /// Fail build on errors
    bool failOnErrors = true;
    
    /// detekt: Config file path
    string detektConfig;
    
    /// detekt: Build upon default config
    bool detektBuildUponDefaultConfig = true;
    
    /// detekt: Parallel execution
    bool detektParallel = true;
    
    /// ktlint: Android style
    bool ktlintAndroidStyle = false;
    
    /// Custom rules
    string[] customRules;
}

/// Formatter configuration
struct FormatterConfig
{
    /// Enable formatting
    bool enabled = false;
    
    /// Formatter to use
    KotlinFormatter formatter = KotlinFormatter.Auto;
    
    /// Auto-format before build
    bool autoFormat = false;
    
    /// Check only (don't modify files)
    bool checkOnly = false;
    
    /// Configuration file path
    string configFile;
    
    /// ktlint: Android style
    bool ktlintAndroidStyle = false;
    
    /// ktlint: Experimental rules
    bool ktlintExperimental = false;
    
    /// ktfmt: Google style
    bool ktfmtGoogleStyle = true;
    
    /// ktfmt: Dropbox style
    bool ktfmtDropboxStyle = false;
}

/// Packaging configuration
struct PackagingConfig
{
    /// Main class for executable JARs
    string mainClass;
    
    /// Manifest attributes
    string[string] manifestAttributes;
    
    /// Include Kotlin runtime
    bool includeRuntime = true;
    
    /// Include dependencies in JAR
    bool includeDependencies = false;
    
    /// Shade/relocate packages (for fat JARs)
    string[string] relocations;
    
    /// Minimize JAR (remove unused classes)
    bool minimize = false;
    
    /// Create sources JAR
    bool createSourcesJar = false;
    
    /// Create Javadoc JAR (KDoc)
    bool createJavadocJar = false;
    
    /// Compress JAR
    bool compress = true;
}

/// Multiplatform configuration
struct MultiplatformConfig
{
    /// Enable multiplatform
    bool enabled = false;
    
    /// Target platforms
    KotlinPlatform[] targets;
    
    /// Common source set
    string commonMain = "src/commonMain/kotlin";
    
    /// Common test source set
    string commonTest = "src/commonTest/kotlin";
    
    /// Platform-specific source sets
    string[string] platformSources;
    
    /// Hierarchical structure
    bool hierarchical = true;
    
    /// Expect/actual enforcement
    bool enforceExpectActual = true;
}

/// Native configuration
struct NativeConfig
{
    /// Enable native compilation
    bool enabled = false;
    
    /// Target platform (linux_x64, mingw_x64, macos_arm64, etc.)
    string target;
    
    /// Optimization mode (none, debug, release)
    string optimization = "release";
    
    /// Link libraries
    string[] libraries;
    
    /// Include directories for C interop
    string[] includeDirs;
    
    /// Enable C interop
    bool cinterop = false;
    
    /// C interop definition file
    string cinteropDef;
    
    /// Static linking
    bool staticLink = false;
}

/// Android configuration
struct AndroidConfig
{
    /// Enable Android build
    bool enabled = false;
    
    /// Compile SDK version
    int compileSdk = 34;
    
    /// Minimum SDK version
    int minSdk = 21;
    
    /// Target SDK version
    int targetSdk = 34;
    
    /// Android Gradle Plugin version
    string agpVersion = "8.2.0";
    
    /// Build variants
    string[] variants = ["debug", "release"];
    
    /// Enable R8 (code shrinker)
    bool enableR8 = true;
    
    /// Enable ProGuard
    bool enableProGuard = false;
    
    /// ProGuard rules file
    string proguardRules;
}

/// Complete Kotlin configuration
struct KotlinConfig
{
    /// Build mode
    KotlinBuildMode mode = KotlinBuildMode.JAR;
    
    /// Build tool
    KotlinBuildTool buildTool = KotlinBuildTool.Auto;
    
    /// Compiler selection
    KotlinCompiler compiler = KotlinCompiler.Auto;
    
    /// Target platform
    KotlinPlatform platform = KotlinPlatform.JVM;
    
    /// Kotlin language version
    KotlinVersion languageVersion;
    
    /// Kotlin API version
    KotlinVersion apiVersion;
    
    /// JVM target (for JVM platform)
    JVMTarget jvmTarget;
    
    /// Gradle configuration
    GradleConfig gradle;
    
    /// Maven configuration
    MavenConfig maven;
    
    /// Annotation processors
    ProcessorConfig processors;
    
    /// Coroutines configuration
    CoroutinesConfig coroutines;
    
    /// Testing configuration
    TestConfig test;
    
    /// Static analysis
    AnalysisConfig analysis;
    
    /// Code formatting
    FormatterConfig formatter;
    
    /// Packaging
    PackagingConfig packaging;
    
    /// Multiplatform
    MultiplatformConfig multiplatform;
    
    /// Native compilation
    NativeConfig native;
    
    /// Android
    AndroidConfig android;
    
    /// Compiler flags
    string[] compilerFlags;
    
    /// JVM flags for execution
    string[] jvmFlags;
    
    /// Classpath entries
    string[] classpath;
    
    /// Module path entries
    string[] modulePath;
    
    /// Enable progressive mode
    bool progressive = false;
    
    /// Enable explicit API mode
    bool explicitApi = false;
    
    /// Suppress warnings
    string[] suppressWarnings;
    
    /// Enable all warnings
    bool allWarnings = false;
    
    /// Treat warnings as errors
    bool warningsAsErrors = false;
    
    /// Enable verbose output
    bool verbose = false;
    
    /// Enable incremental compilation
    bool incremental = true;
    
    /// Friend modules (access internal declarations)
    string[] friendModules;
    
    /// Enable Java interop
    bool javaInterop = true;
    
    /// Enable assertions
    bool enableAssertions = false;
}

/// Parse Kotlin configuration from target
KotlinConfig parseKotlinConfig(Target target)
{
    KotlinConfig config;
    
    // Parse from langConfig JSON
    if ("kotlin" in target.langConfig)
    {
        try
        {
            JSONValue json = parseJSON(target.langConfig["kotlin"]);
            config = parseKotlinConfigFromJSON(json);
        }
        catch (Exception e)
        {
            // Use defaults
        }
    }
    
    return config;
}

/// Parse Kotlin configuration from JSON
KotlinConfig parseKotlinConfigFromJSON(JSONValue json)
{
    KotlinConfig config;
    
    // Build mode
    if ("mode" in json)
        config.mode = json["mode"].str.toKotlinBuildMode();
    
    // Build tool
    if ("buildTool" in json)
        config.buildTool = json["buildTool"].str.toKotlinBuildTool();
    
    // Compiler
    if ("compiler" in json)
        config.compiler = json["compiler"].str.toKotlinCompiler();
    
    // Platform
    if ("platform" in json)
        config.platform = json["platform"].str.toKotlinPlatform();
    
    // Versions
    if ("languageVersion" in json)
        config.languageVersion = KotlinVersion.parse(json["languageVersion"].str);
    if ("apiVersion" in json)
        config.apiVersion = KotlinVersion.parse(json["apiVersion"].str);
    if ("jvmTarget" in json)
        config.jvmTarget = JVMTarget.parse(json["jvmTarget"].str);
    
    // Gradle
    if ("gradle" in json)
        config.gradle = parseGradleConfig(json["gradle"]);
    
    // Maven
    if ("maven" in json)
        config.maven = parseMavenConfig(json["maven"]);
    
    // Processors
    if ("processors" in json)
        config.processors = parseProcessorConfig(json["processors"]);
    
    // Coroutines
    if ("coroutines" in json)
        config.coroutines = parseCoroutinesConfig(json["coroutines"]);
    
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
    
    // Multiplatform
    if ("multiplatform" in json)
        config.multiplatform = parseMultiplatformConfig(json["multiplatform"]);
    
    // Native
    if ("native" in json)
        config.native = parseNativeConfig(json["native"]);
    
    // Android
    if ("android" in json)
        config.android = parseAndroidConfig(json["android"]);
    
    // Simple fields
    if ("compilerFlags" in json)
        config.compilerFlags = json["compilerFlags"].array.map!(e => e.str).array;
    if ("jvmFlags" in json)
        config.jvmFlags = json["jvmFlags"].array.map!(e => e.str).array;
    if ("classpath" in json)
        config.classpath = json["classpath"].array.map!(e => e.str).array;
    if ("modulePath" in json)
        config.modulePath = json["modulePath"].array.map!(e => e.str).array;
    if ("progressive" in json)
        config.progressive = json["progressive"].type == JSONType.true_;
    if ("explicitApi" in json)
        config.explicitApi = json["explicitApi"].type == JSONType.true_;
    if ("suppressWarnings" in json)
        config.suppressWarnings = json["suppressWarnings"].array.map!(e => e.str).array;
    if ("allWarnings" in json)
        config.allWarnings = json["allWarnings"].type == JSONType.true_;
    if ("warningsAsErrors" in json)
        config.warningsAsErrors = json["warningsAsErrors"].type == JSONType.true_;
    if ("verbose" in json)
        config.verbose = json["verbose"].type == JSONType.true_;
    if ("incremental" in json)
        config.incremental = json["incremental"].type == JSONType.true_;
    if ("friendModules" in json)
        config.friendModules = json["friendModules"].array.map!(e => e.str).array;
    if ("javaInterop" in json)
        config.javaInterop = json["javaInterop"].type == JSONType.true_;
    if ("enableAssertions" in json)
        config.enableAssertions = json["enableAssertions"].type == JSONType.true_;
    
    return config;
}

// Helper parsing functions
private GradleConfig parseGradleConfig(JSONValue json)
{
    GradleConfig config;
    
    if ("autoInstall" in json)
        config.autoInstall = json["autoInstall"].type == JSONType.true_;
    if ("clean" in json)
        config.clean = json["clean"].type == JSONType.true_;
    if ("skipTests" in json)
        config.skipTests = json["skipTests"].type == JSONType.true_;
    if ("offline" in json)
        config.offline = json["offline"].type == JSONType.true_;
    if ("refreshDependencies" in json)
        config.refreshDependencies = json["refreshDependencies"].type == JSONType.true_;
    if ("tasks" in json)
        config.tasks = json["tasks"].array.map!(e => e.str).array;
    if ("buildType" in json)
        config.buildType = json["buildType"].str;
    if ("daemon" in json)
        config.daemon = json["daemon"].type == JSONType.true_;
    if ("parallel" in json)
        config.parallel = json["parallel"].type == JSONType.true_;
    if ("configurationCache" in json)
        config.configurationCache = json["configurationCache"].type == JSONType.true_;
    if ("kotlinDSL" in json)
        config.kotlinDSL = json["kotlinDSL"].type == JSONType.true_;
    
    return config;
}

private MavenConfig parseMavenConfig(JSONValue json)
{
    MavenConfig config;
    
    if ("autoInstall" in json)
        config.autoInstall = json["autoInstall"].type == JSONType.true_;
    if ("clean" in json)
        config.clean = json["clean"].type == JSONType.true_;
    if ("skipTests" in json)
        config.skipTests = json["skipTests"].type == JSONType.true_;
    if ("updateSnapshots" in json)
        config.updateSnapshots = json["updateSnapshots"].type == JSONType.true_;
    if ("offline" in json)
        config.offline = json["offline"].type == JSONType.true_;
    if ("profiles" in json)
        config.profiles = json["profiles"].array.map!(e => e.str).array;
    if ("goals" in json)
        config.goals = json["goals"].array.map!(e => e.str).array;
    if ("settingsFile" in json)
        config.settingsFile = json["settingsFile"].str;
    if ("localRepo" in json)
        config.localRepo = json["localRepo"].str;
    
    return config;
}

private ProcessorConfig parseProcessorConfig(JSONValue json)
{
    ProcessorConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("type" in json)
        config.type = json["type"].str.toLower == "ksp" ? ProcessorType.KSP : ProcessorType.KAPT;
    if ("processors" in json)
        config.processors = json["processors"].array.map!(e => e.str).array;
    if ("outputDir" in json)
        config.outputDir = json["outputDir"].str;
    if ("verbose" in json)
        config.verbose = json["verbose"].type == JSONType.true_;
    if ("correctErrorTypes" in json)
        config.correctErrorTypes = json["correctErrorTypes"].type == JSONType.true_;
    if ("useK2" in json)
        config.useK2 = json["useK2"].type == JSONType.true_;
    if ("incremental" in json)
        config.incremental = json["incremental"].type == JSONType.true_;
    if ("allWarningsAsErrors" in json)
        config.allWarningsAsErrors = json["allWarningsAsErrors"].type == JSONType.true_;
    
    return config;
}

private CoroutinesConfig parseCoroutinesConfig(JSONValue json)
{
    CoroutinesConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("version" in json)
        config.version_ = json["version"].str;
    if ("debug" in json)
        config.debugMode = json["debug"].type == JSONType.true_;
    if ("flow" in json)
        config.flow = json["flow"].type == JSONType.true_;
    if ("channels" in json)
        config.channels = json["channels"].type == JSONType.true_;
    if ("jvmOptimize" in json)
        config.jvmOptimize = json["jvmOptimize"].type == JSONType.true_;
    
    return config;
}

private TestConfig parseTestConfig(JSONValue json)
{
    TestConfig config;
    
    if ("framework" in json)
        config.framework = json["framework"].str.toKotlinTestFramework();
    if ("parallel" in json)
        config.parallel = json["parallel"].type == JSONType.true_;
    if ("failFast" in json)
        config.failFast = json["failFast"].type == JSONType.true_;
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
    
    return config;
}

private AnalysisConfig parseAnalysisConfig(JSONValue json)
{
    AnalysisConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("analyzer" in json)
        config.analyzer = json["analyzer"].str.toKotlinAnalyzer();
    if ("failOnWarnings" in json)
        config.failOnWarnings = json["failOnWarnings"].type == JSONType.true_;
    if ("failOnErrors" in json)
        config.failOnErrors = json["failOnErrors"].type == JSONType.true_;
    if ("detektConfig" in json)
        config.detektConfig = json["detektConfig"].str;
    if ("detektBuildUponDefaultConfig" in json)
        config.detektBuildUponDefaultConfig = json["detektBuildUponDefaultConfig"].type == JSONType.true_;
    if ("detektParallel" in json)
        config.detektParallel = json["detektParallel"].type == JSONType.true_;
    if ("ktlintAndroidStyle" in json)
        config.ktlintAndroidStyle = json["ktlintAndroidStyle"].type == JSONType.true_;
    if ("customRules" in json)
        config.customRules = json["customRules"].array.map!(e => e.str).array;
    
    return config;
}

private FormatterConfig parseFormatterConfig(JSONValue json)
{
    FormatterConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("formatter" in json)
        config.formatter = json["formatter"].str.toKotlinFormatter();
    if ("autoFormat" in json)
        config.autoFormat = json["autoFormat"].type == JSONType.true_;
    if ("checkOnly" in json)
        config.checkOnly = json["checkOnly"].type == JSONType.true_;
    if ("configFile" in json)
        config.configFile = json["configFile"].str;
    if ("ktlintAndroidStyle" in json)
        config.ktlintAndroidStyle = json["ktlintAndroidStyle"].type == JSONType.true_;
    if ("ktlintExperimental" in json)
        config.ktlintExperimental = json["ktlintExperimental"].type == JSONType.true_;
    if ("ktfmtGoogleStyle" in json)
        config.ktfmtGoogleStyle = json["ktfmtGoogleStyle"].type == JSONType.true_;
    if ("ktfmtDropboxStyle" in json)
        config.ktfmtDropboxStyle = json["ktfmtDropboxStyle"].type == JSONType.true_;
    
    return config;
}

private PackagingConfig parsePackagingConfig(JSONValue json)
{
    PackagingConfig config;
    
    if ("mainClass" in json)
        config.mainClass = json["mainClass"].str;
    if ("includeRuntime" in json)
        config.includeRuntime = json["includeRuntime"].type == JSONType.true_;
    if ("includeDependencies" in json)
        config.includeDependencies = json["includeDependencies"].type == JSONType.true_;
    if ("minimize" in json)
        config.minimize = json["minimize"].type == JSONType.true_;
    if ("createSourcesJar" in json)
        config.createSourcesJar = json["createSourcesJar"].type == JSONType.true_;
    if ("createJavadocJar" in json)
        config.createJavadocJar = json["createJavadocJar"].type == JSONType.true_;
    if ("compress" in json)
        config.compress = json["compress"].type == JSONType.true_;
    
    return config;
}

private MultiplatformConfig parseMultiplatformConfig(JSONValue json)
{
    MultiplatformConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("targets" in json)
        config.targets = json["targets"].array.map!(e => e.str.toKotlinPlatform()).array;
    if ("commonMain" in json)
        config.commonMain = json["commonMain"].str;
    if ("commonTest" in json)
        config.commonTest = json["commonTest"].str;
    if ("hierarchical" in json)
        config.hierarchical = json["hierarchical"].type == JSONType.true_;
    if ("enforceExpectActual" in json)
        config.enforceExpectActual = json["enforceExpectActual"].type == JSONType.true_;
    
    return config;
}

private NativeConfig parseNativeConfig(JSONValue json)
{
    NativeConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("target" in json)
        config.target = json["target"].str;
    if ("optimization" in json)
        config.optimization = json["optimization"].str;
    if ("libraries" in json)
        config.libraries = json["libraries"].array.map!(e => e.str).array;
    if ("includeDirs" in json)
        config.includeDirs = json["includeDirs"].array.map!(e => e.str).array;
    if ("cinterop" in json)
        config.cinterop = json["cinterop"].type == JSONType.true_;
    if ("cinteropDef" in json)
        config.cinteropDef = json["cinteropDef"].str;
    if ("staticLink" in json)
        config.staticLink = json["staticLink"].type == JSONType.true_;
    
    return config;
}

private AndroidConfig parseAndroidConfig(JSONValue json)
{
    AndroidConfig config;
    
    if ("enabled" in json)
        config.enabled = json["enabled"].type == JSONType.true_;
    if ("compileSdk" in json)
        config.compileSdk = cast(int)json["compileSdk"].integer;
    if ("minSdk" in json)
        config.minSdk = cast(int)json["minSdk"].integer;
    if ("targetSdk" in json)
        config.targetSdk = cast(int)json["targetSdk"].integer;
    if ("agpVersion" in json)
        config.agpVersion = json["agpVersion"].str;
    if ("variants" in json)
        config.variants = json["variants"].array.map!(e => e.str).array;
    if ("enableR8" in json)
        config.enableR8 = json["enableR8"].type == JSONType.true_;
    if ("enableProGuard" in json)
        config.enableProGuard = json["enableProGuard"].type == JSONType.true_;
    if ("proguardRules" in json)
        config.proguardRules = json["proguardRules"].str;
    
    return config;
}

// String to enum converters
private KotlinBuildMode toKotlinBuildMode(string s)
{
    switch (s.toLower)
    {
        case "jar": return KotlinBuildMode.JAR;
        case "fatjar": return KotlinBuildMode.FatJAR;
        case "native": return KotlinBuildMode.Native;
        case "js": return KotlinBuildMode.JS;
        case "multiplatform": return KotlinBuildMode.Multiplatform;
        case "android": return KotlinBuildMode.Android;
        case "compile": return KotlinBuildMode.Compile;
        default: return KotlinBuildMode.JAR;
    }
}

private KotlinBuildTool toKotlinBuildTool(string s)
{
    switch (s.toLower)
    {
        case "auto": return KotlinBuildTool.Auto;
        case "gradle": return KotlinBuildTool.Gradle;
        case "maven": return KotlinBuildTool.Maven;
        case "direct": return KotlinBuildTool.Direct;
        case "none": return KotlinBuildTool.None;
        default: return KotlinBuildTool.Auto;
    }
}

private KotlinCompiler toKotlinCompiler(string s)
{
    switch (s.toLower)
    {
        case "auto": return KotlinCompiler.Auto;
        case "kotlinc": return KotlinCompiler.KotlinC;
        case "native": return KotlinCompiler.KotlinNative;
        case "js": return KotlinCompiler.KotlinJS;
        case "jvm": return KotlinCompiler.KotlinJVM;
        default: return KotlinCompiler.Auto;
    }
}

private KotlinPlatform toKotlinPlatform(string s)
{
    switch (s.toLower)
    {
        case "jvm": return KotlinPlatform.JVM;
        case "js": return KotlinPlatform.JS;
        case "native": return KotlinPlatform.Native;
        case "common": return KotlinPlatform.Common;
        case "android": return KotlinPlatform.Android;
        case "wasm": return KotlinPlatform.Wasm;
        default: return KotlinPlatform.JVM;
    }
}

private KotlinTestFramework toKotlinTestFramework(string s)
{
    switch (s.toLower)
    {
        case "auto": return KotlinTestFramework.Auto;
        case "kotlintest": case "kotlin.test": return KotlinTestFramework.KotlinTest;
        case "junit5": return KotlinTestFramework.JUnit5;
        case "junit4": return KotlinTestFramework.JUnit4;
        case "kotest": return KotlinTestFramework.Kotest;
        case "spek": return KotlinTestFramework.Spek;
        case "none": return KotlinTestFramework.None;
        default: return KotlinTestFramework.Auto;
    }
}

private KotlinAnalyzer toKotlinAnalyzer(string s)
{
    switch (s.toLower)
    {
        case "auto": return KotlinAnalyzer.Auto;
        case "detekt": return KotlinAnalyzer.Detekt;
        case "ktlint": return KotlinAnalyzer.KtLint;
        case "compiler": return KotlinAnalyzer.Compiler;
        case "none": return KotlinAnalyzer.None;
        default: return KotlinAnalyzer.Auto;
    }
}

private KotlinFormatter toKotlinFormatter(string s)
{
    switch (s.toLower)
    {
        case "auto": return KotlinFormatter.Auto;
        case "ktlint": return KotlinFormatter.KtLint;
        case "ktfmt": return KotlinFormatter.KtFmt;
        case "intellij": return KotlinFormatter.IntelliJ;
        case "none": return KotlinFormatter.None;
        default: return KotlinFormatter.Auto;
    }
}

