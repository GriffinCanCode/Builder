module languages.jvm.kotlin.config.build;

import std.json;
import std.conv;
import std.algorithm;
import std.array;

/// Kotlin build modes
enum KotlinBuildMode
{
    JAR,           /// Standard JAR library or executable
    FatJAR,        /// Fat JAR with all dependencies (uber-jar)
    Native,        /// Kotlin/Native executable
    JS,            /// Kotlin/JS bundle
    Multiplatform, /// Kotlin Multiplatform
    Android,       /// Android AAR
    Compile        /// Standard compilation without packaging
}

/// Build tool selection
enum KotlinBuildTool
{
    Auto,    /// Auto-detect from project structure
    Gradle,  /// Gradle (recommended)
    Maven,   /// Maven with Kotlin plugin
    Direct,  /// Direct kotlinc (no build tool)
    None     /// None - manual control
}

/// Kotlin compiler selection
enum KotlinCompiler
{
    Auto,         /// Auto-detect best available
    KotlinC,      /// Official kotlinc (JVM)
    KotlinNative, /// Kotlin/Native compiler
    KotlinJS,     /// Kotlin/JS compiler (IR backend)
    KotlinJVM     /// Kotlin/JVM compiler (optimized)
}

/// Kotlin platform target
enum KotlinPlatform
{
    JVM,     /// JVM bytecode
    JS,      /// JavaScript (IR backend)
    Native,  /// Native binary (platform-specific)
    Common,  /// Common multiplatform code
    Android, /// Android
    Wasm     /// WebAssembly (experimental)
}

/// Kotlin language version
struct KotlinVersion
{
    int major = 1;
    int minor = 9;
    int patch = 0;
    
    static KotlinVersion parse(string ver) @safe
    {
        import std.string : split;
        
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
    
    string toString() const @safe
    {
        import std.format : format;
        
        if (patch == 0)
            return format("%d.%d", major, minor);
        return format("%d.%d.%d", major, minor, patch);
    }
    
    // Feature checks
    bool supportsCoroutines() const pure nothrow @safe
    {
        return major > 1 || (major == 1 && minor >= 3);
    }
    
    bool supportsK2() const pure nothrow @safe
    {
        return major >= 2;
    }
}

/// JVM target version
struct JVMTarget
{
    int targetVersion = 11;
    
    static JVMTarget parse(string ver) @safe
    {
        import std.string : startsWith, split;
        
        JVMTarget target;
        if (ver.empty)
            return target;
        
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
    
    string toString() const @safe
    {
        if (targetVersion == 8)
            return "1.8";
        return targetVersion.to!string;
    }
}

/// Core build configuration
struct KotlinBuildConfig
{
    KotlinBuildMode mode = KotlinBuildMode.JAR;
    KotlinBuildTool buildTool = KotlinBuildTool.Auto;
    KotlinCompiler compiler = KotlinCompiler.Auto;
    KotlinPlatform platform = KotlinPlatform.JVM;
    KotlinVersion languageVersion;
    KotlinVersion apiVersion;
    JVMTarget jvmTarget;
    
    string[] compilerFlags;
    string[] jvmArgs;
    bool progressive = false;
    bool allWarningsAsErrors = false;
    bool suppressWarnings = false;
    bool verbose = false;
    bool debugMode = false;
}

