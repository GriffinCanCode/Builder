module languages.compiled.cpp.builders.base;

import std.range;
import std.string;
import std.conv;
import languages.compiled.cpp.config;
import config.schema.schema;
import analysis.targets.types;

/// Base interface for C++ builders
interface CppBuilder
{
    /// Build C++ project
    CppCompileResult build(
        string[] sources,
        CppConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    /// Check if builder is available on system
    bool isAvailable();
    
    /// Get builder name
    string name() const;
    
    /// Get builder version
    string getVersion();
    
    /// Supports specific features
    bool supportsFeature(string feature);
}

/// Factory for creating C++ builders
class CppBuilderFactory
{
    /// Create builder based on build system and compiler
    static CppBuilder create(CppConfig config)
    {
        import languages.compiled.cpp.builders.direct;
        import languages.compiled.cpp.builders.cmake;
        import languages.compiled.cpp.builders.make;
        import languages.compiled.cpp.builders.ninja;
        
        // If build system is specified, use it
        if (config.buildSystem != BuildSystem.None && config.buildSystem != BuildSystem.Auto)
        {
            return createBuildSystem(config.buildSystem, config);
        }
        
        // Auto-detect build system
        auto buildSystem = config.buildSystem;
        if (buildSystem == BuildSystem.Auto)
        {
            buildSystem = detectBuildSystem();
        }
        
        // If no build system, use direct compilation
        if (buildSystem == BuildSystem.None)
        {
            return new DirectBuilder(config);
        }
        
        return createBuildSystem(buildSystem, config);
    }
    
    /// Create builder for specific build system
    private static CppBuilder createBuildSystem(BuildSystem buildSystem, CppConfig config)
    {
        import languages.compiled.cpp.builders.direct;
        import languages.compiled.cpp.builders.cmake;
        import languages.compiled.cpp.builders.make;
        import languages.compiled.cpp.builders.ninja;
        
        final switch (buildSystem)
        {
            case BuildSystem.None:
                return new DirectBuilder(config);
            case BuildSystem.Auto:
                return create(config);
            case BuildSystem.CMake:
                auto cmake = new CMakeBuilder(config);
                if (cmake.isAvailable())
                    return cmake;
                return new DirectBuilder(config);
            case BuildSystem.Make:
                auto make = new MakeBuilder(config);
                if (make.isAvailable())
                    return make;
                return new DirectBuilder(config);
            case BuildSystem.Ninja:
                auto ninja = new NinjaBuilder(config);
                if (ninja.isAvailable())
                    return ninja;
                return new DirectBuilder(config);
            case BuildSystem.Bazel:
            case BuildSystem.Meson:
            case BuildSystem.Xmake:
                // TODO: Implement these build systems
                return new DirectBuilder(config);
        }
    }
    
    /// Detect build system from current directory
    private static BuildSystem detectBuildSystem()
    {
        import languages.compiled.cpp.toolchain;
        import std.file;
        import std.path;
        
        string cwd = getcwd();
        return BuildSystemDetector.detect(cwd);
    }
}

/// Base builder with common functionality
abstract class BaseCppBuilder : CppBuilder
{
    protected CppConfig config;
    
    this(CppConfig config)
    {
        this.config = config;
    }
    
    abstract CppCompileResult build(
        string[] sources,
        CppConfig config,
        Target target,
        WorkspaceConfig workspace
    );
    
    abstract bool isAvailable();
    abstract string name() const;
    abstract string getVersion();
    
    bool supportsFeature(string feature)
    {
        // Base implementation: common features
        switch (feature)
        {
            case "compile":
            case "link":
                return true;
            default:
                return false;
        }
    }
    
    /// Get compiler command for source file
    protected string getCompilerCommand(string source, CppConfig config)
    {
        import std.path : extension;
        import languages.compiled.cpp.toolchain;
        
        auto compilerInfo = Toolchain.detect(config.compiler, config.customCompiler);
        
        string ext = extension(source).toLower;
        
        // Determine if C or C++
        bool isCpp = (ext == ".cpp" || ext == ".cxx" || ext == ".cc" || 
                     ext == ".C" || ext == ".c++" || ext == ".hpp" || ext == ".hxx");
        
        if (isCpp)
            return Toolchain.getCppCompiler(compilerInfo);
        else
            return Toolchain.getCCompiler(compilerInfo);
    }
    
    /// Build compiler flags from config
    protected string[] buildCompilerFlags(CppConfig config, bool isCpp)
    {
        import std.conv : to;
        
        string[] flags;
        
        // Standard
        if (isCpp)
        {
            flags ~= getStandardFlag(config.cppStandard);
        }
        else
        {
            flags ~= getCStandardFlag(config.cStandard);
        }
        
        // Optimization
        flags ~= getOptimizationFlag(config.optLevel);
        
        // Warnings
        flags ~= getWarningFlags(config.warnings);
        
        // Debug info
        if (config.debugInfo)
        {
            flags ~= "-g";
        }
        
        // PIC/PIE
        if (config.pic || config.outputType == OutputType.SharedLib)
        {
            flags ~= "-fPIC";
        }
        if (config.pie && config.outputType == OutputType.Executable)
        {
            flags ~= "-fPIE";
        }
        
        // Exceptions
        if (!config.exceptions && isCpp)
        {
            flags ~= "-fno-exceptions";
        }
        
        // RTTI
        if (!config.rtti && isCpp)
        {
            flags ~= "-fno-rtti";
        }
        
        // LTO
        if (config.lto != LtoMode.Off)
        {
            flags ~= getLtoFlag(config.lto);
        }
        
        // Sanitizers
        foreach (sanitizer; config.sanitizers)
        {
            flags ~= getSanitizerFlag(sanitizer);
        }
        
        // Color diagnostics
        if (config.colorDiagnostics)
        {
            flags ~= "-fdiagnostics-color=always";
        }
        
        // Time report
        if (config.timeReport)
        {
            flags ~= "-ftime-report";
        }
        
        // Modules (C++20)
        if (config.modules && isCpp)
        {
            flags ~= "-fmodules";
        }
        
        // Include directories
        foreach (inc; config.includeDirs)
        {
            flags ~= "-I" ~ inc;
        }
        
        // Defines
        foreach (def; config.defines)
        {
            flags ~= "-D" ~ def;
        }
        
        // Custom flags
        flags ~= config.compilerFlags;
        
        return flags;
    }
    
    /// Build linker flags from config
    protected string[] buildLinkerFlags(CppConfig config)
    {
        string[] flags;
        
        // Library directories
        foreach (libDir; config.libDirs)
        {
            flags ~= "-L" ~ libDir;
        }
        
        // Libraries
        foreach (lib; config.libs)
        {
            flags ~= "-l" ~ lib;
        }
        
        // System libraries
        foreach (sysLib; config.sysLibs)
        {
            flags ~= "-l" ~ sysLib;
        }
        
        // PIE
        if (config.pie && config.outputType == OutputType.Executable)
        {
            flags ~= "-pie";
        }
        
        // Strip
        if (config.strip)
        {
            flags ~= "-s";
        }
        
        // LTO
        if (config.lto != LtoMode.Off)
        {
            flags ~= getLtoFlag(config.lto);
        }
        
        // Sanitizers (need to be linked too)
        foreach (sanitizer; config.sanitizers)
        {
            flags ~= getSanitizerFlag(sanitizer);
        }
        
        // Custom linker flags
        flags ~= config.linkerFlags;
        
        return flags;
    }
    
    private string getStandardFlag(CppStandard std)
    {
        final switch (std)
        {
            case CppStandard.Cpp98: return "-std=c++98";
            case CppStandard.Cpp03: return "-std=c++03";
            case CppStandard.Cpp11: return "-std=c++11";
            case CppStandard.Cpp14: return "-std=c++14";
            case CppStandard.Cpp17: return "-std=c++17";
            case CppStandard.Cpp20: return "-std=c++20";
            case CppStandard.Cpp23: return "-std=c++23";
            case CppStandard.Cpp26: return "-std=c++26";
            case CppStandard.GnuCpp98: return "-std=gnu++98";
            case CppStandard.GnuCpp03: return "-std=gnu++03";
            case CppStandard.GnuCpp11: return "-std=gnu++11";
            case CppStandard.GnuCpp14: return "-std=gnu++14";
            case CppStandard.GnuCpp17: return "-std=gnu++17";
            case CppStandard.GnuCpp20: return "-std=gnu++20";
            case CppStandard.GnuCpp23: return "-std=gnu++23";
            case CppStandard.GnuCpp26: return "-std=gnu++26";
        }
    }
    
    private string getCStandardFlag(CStandard std)
    {
        final switch (std)
        {
            case CStandard.C89: return "-std=c89";
            case CStandard.C90: return "-std=c90";
            case CStandard.C99: return "-std=c99";
            case CStandard.C11: return "-std=c11";
            case CStandard.C17: return "-std=c17";
            case CStandard.C23: return "-std=c23";
            case CStandard.GnuC89: return "-std=gnu89";
            case CStandard.GnuC90: return "-std=gnu90";
            case CStandard.GnuC99: return "-std=gnu99";
            case CStandard.GnuC11: return "-std=gnu11";
            case CStandard.GnuC17: return "-std=gnu17";
            case CStandard.GnuC23: return "-std=gnu23";
        }
    }
    
    private string getOptimizationFlag(OptLevel opt)
    {
        final switch (opt)
        {
            case OptLevel.O0: return "-O0";
            case OptLevel.O1: return "-O1";
            case OptLevel.O2: return "-O2";
            case OptLevel.O3: return "-O3";
            case OptLevel.Os: return "-Os";
            case OptLevel.Ofast: return "-Ofast";
            case OptLevel.Og: return "-Og";
        }
    }
    
    private string[] getWarningFlags(WarningLevel level)
    {
        final switch (level)
        {
            case WarningLevel.None: return [];
            case WarningLevel.Default: return [];
            case WarningLevel.Extra: return ["-Wall"];
            case WarningLevel.All: return ["-Wall", "-Wextra"];
            case WarningLevel.Pedantic: return ["-Wall", "-Wextra", "-pedantic"];
            case WarningLevel.Error: return ["-Wall", "-Wextra", "-Werror"];
        }
    }
    
    private string getLtoFlag(LtoMode lto)
    {
        final switch (lto)
        {
            case LtoMode.Off: return "";
            case LtoMode.Thin: return "-flto=thin";
            case LtoMode.Full: return "-flto";
        }
    }
    
    private string getSanitizerFlag(Sanitizer san)
    {
        final switch (san)
        {
            case Sanitizer.None: return "";
            case Sanitizer.Address: return "-fsanitize=address";
            case Sanitizer.Thread: return "-fsanitize=thread";
            case Sanitizer.Memory: return "-fsanitize=memory";
            case Sanitizer.UndefinedBehavior: return "-fsanitize=undefined";
            case Sanitizer.Leak: return "-fsanitize=leak";
            case Sanitizer.HWAddress: return "-fsanitize=hwaddress";
        }
    }
}

