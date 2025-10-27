module languages.compiled.cpp.tooling.toolchain;

import std.process;
import std.string;
import std.algorithm;
import std.array;
import std.file;
import std.path;
import std.conv;
import std.regex;
import languages.compiled.cpp.core.config;
import utils.logging.logger;
import utils.process : isCommandAvailable;

/// Compiler information
struct CompilerInfo
{
    string name;
    string path;
    string version_;
    string versionFull;
    string target;
    bool isAvailable;
    Compiler type;
}

/// Toolchain manager for C/C++ compilers
class Toolchain
{
    /// Detect and get compiler info
    static CompilerInfo detect(Compiler compiler, string customPath = "")
    {
        final switch (compiler)
        {
            case Compiler.Auto:
                return detectAuto();
            case Compiler.GCC:
                return detectGCC();
            case Compiler.Clang:
                return detectClang();
            case Compiler.MSVC:
                return detectMSVC();
            case Compiler.Intel:
                return detectIntel();
            case Compiler.Custom:
                return detectCustom(customPath);
        }
    }
    
    /// Auto-detect best available compiler
    private static CompilerInfo detectAuto()
    {
        // Priority: Clang > GCC > MSVC > Intel
        auto clang = detectClang();
        if (clang.isAvailable)
            return clang;
        
        auto gcc = detectGCC();
        if (gcc.isAvailable)
            return gcc;
        
        auto msvc = detectMSVC();
        if (msvc.isAvailable)
            return msvc;
        
        auto intel = detectIntel();
        if (intel.isAvailable)
            return intel;
        
        // Return empty if none available
        return CompilerInfo();
    }
    
    /// Detect Clang
    private static CompilerInfo detectClang()
    {
        CompilerInfo info;
        info.type = Compiler.Clang;
        info.name = "Clang";
        
        // Try to find clang
        version(Windows)
        {
            auto res = execute(["where", "clang"]);
        }
        else
        {
            auto res = execute(["which", "clang"]);
        }
        
        if (res.status != 0)
        {
            info.isAvailable = false;
            return info;
        }
        
        info.path = res.output.strip;
        info.isAvailable = true;
        
        // Get version
        auto verRes = execute(["clang", "--version"]);
        if (verRes.status == 0)
        {
            info.versionFull = verRes.output.strip;
            
            // Parse version: "clang version 15.0.0"
            auto versionMatch = matchFirst(verRes.output, regex(`version\s+(\d+\.\d+\.\d+)`));
            if (!versionMatch.empty && versionMatch.length > 1)
            {
                info.version_ = versionMatch[1];
            }
            
            // Parse target
            auto targetMatch = matchFirst(verRes.output, regex(`Target:\s+(.+)`));
            if (!targetMatch.empty && targetMatch.length > 1)
            {
                info.target = targetMatch[1].strip;
            }
        }
        
        return info;
    }
    
    /// Detect GCC
    private static CompilerInfo detectGCC()
    {
        CompilerInfo info;
        info.type = Compiler.GCC;
        info.name = "GCC";
        
        // Try to find gcc
        version(Windows)
        {
            auto res = execute(["where", "gcc"]);
        }
        else
        {
            auto res = execute(["which", "gcc"]);
        }
        
        if (res.status != 0)
        {
            info.isAvailable = false;
            return info;
        }
        
        info.path = res.output.strip;
        info.isAvailable = true;
        
        // Get version
        auto verRes = execute(["gcc", "--version"]);
        if (verRes.status == 0)
        {
            info.versionFull = verRes.output.strip;
            
            // Parse version: "gcc (GCC) 11.3.0"
            auto versionMatch = matchFirst(verRes.output, regex(`\d+\.\d+\.\d+`));
            if (!versionMatch.empty)
            {
                info.version_ = versionMatch[0];
            }
        }
        
        // Get target
        auto targetRes = execute(["gcc", "-dumpmachine"]);
        if (targetRes.status == 0)
        {
            info.target = targetRes.output.strip;
        }
        
        return info;
    }
    
    /// Detect MSVC
    private static CompilerInfo detectMSVC()
    {
        CompilerInfo info;
        info.type = Compiler.MSVC;
        info.name = "MSVC";
        
        version(Windows)
        {
            // Try to find cl.exe
            auto res = execute(["where", "cl"]);
            if (res.status == 0)
            {
                info.path = res.output.strip;
                info.isAvailable = true;
                
                // Get version
                auto verRes = execute(["cl"]);
                if (verRes.status == 0 || !verRes.output.empty)
                {
                    info.versionFull = verRes.output.strip;
                    
                    // Parse version: "Microsoft (R) C/C++ Optimizing Compiler Version 19.29.30133"
                    auto versionMatch = matchFirst(verRes.output, regex(`Version\s+(\d+\.\d+\.\d+)`));
                    if (!versionMatch.empty && versionMatch.length > 1)
                    {
                        info.version_ = versionMatch[1];
                    }
                }
            }
            else
            {
                info.isAvailable = false;
            }
        }
        else
        {
            info.isAvailable = false;
        }
        
        return info;
    }
    
    /// Detect Intel C++ Compiler
    private static CompilerInfo detectIntel()
    {
        CompilerInfo info;
        info.type = Compiler.Intel;
        info.name = "Intel";
        
        // Try icx (new Intel compiler) first, then icpc (classic)
        version(Windows)
        {
            auto res = execute(["where", "icx"]);
            if (res.status != 0)
                res = execute(["where", "icpc"]);
        }
        else
        {
            auto res = execute(["which", "icx"]);
            if (res.status != 0)
                res = execute(["which", "icpc"]);
        }
        
        if (res.status != 0)
        {
            info.isAvailable = false;
            return info;
        }
        
        info.path = res.output.strip;
        info.isAvailable = true;
        
        // Determine which compiler we found
        string compilerCmd = baseName(info.path, ".exe");
        
        // Get version
        auto verRes = execute([compilerCmd, "--version"]);
        if (verRes.status == 0)
        {
            info.versionFull = verRes.output.strip;
            
            // Parse version
            auto versionMatch = matchFirst(verRes.output, regex(`\d+\.\d+\.\d+`));
            if (!versionMatch.empty)
            {
                info.version_ = versionMatch[0];
            }
        }
        
        return info;
    }
    
    /// Detect custom compiler
    private static CompilerInfo detectCustom(string customPath)
    {
        CompilerInfo info;
        info.type = Compiler.Custom;
        info.name = "Custom";
        
        if (customPath.empty)
        {
            info.isAvailable = false;
            return info;
        }
        
        // Check if file exists
        if (!exists(customPath))
        {
            info.isAvailable = false;
            return info;
        }
        
        info.path = customPath;
        info.isAvailable = true;
        
        // Try to get version
        try
        {
            auto verRes = execute([customPath, "--version"]);
            if (verRes.status == 0)
            {
                info.versionFull = verRes.output.strip;
                
                auto versionMatch = matchFirst(verRes.output, regex(`\d+\.\d+\.\d+`));
                if (!versionMatch.empty)
                {
                    info.version_ = versionMatch[0];
                }
            }
        }
        catch (Exception e)
        {
            // Ignore version detection errors
        }
        
        return info;
    }
    
    /// Get C++ compiler command from C compiler
    static string getCppCompiler(CompilerInfo info)
    {
        if (!info.isAvailable)
            return "";
        
        final switch (info.type)
        {
            case Compiler.Auto:
                return "";
            case Compiler.GCC:
                return "g++";
            case Compiler.Clang:
                return "clang++";
            case Compiler.MSVC:
                return "cl";
            case Compiler.Intel:
                // Try icx first (new), then icpc (classic)
                version(Windows)
                {
                    auto res = execute(["where", "icx"]);
                    if (res.status == 0)
                        return "icx";
                    return "icpc";
                }
                else
                {
                    auto res = execute(["which", "icx"]);
                    if (res.status == 0)
                        return "icx";
                    return "icpc";
                }
            case Compiler.Custom:
                return info.path;
        }
    }
    
    /// Get C compiler command
    static string getCCompiler(CompilerInfo info)
    {
        if (!info.isAvailable)
            return "";
        
        final switch (info.type)
        {
            case Compiler.Auto:
                return "";
            case Compiler.GCC:
                return "gcc";
            case Compiler.Clang:
                return "clang";
            case Compiler.MSVC:
                return "cl";
            case Compiler.Intel:
                // Try icx first (new), then icc (classic)
                version(Windows)
                {
                    auto res = execute(["where", "icx"]);
                    if (res.status == 0)
                        return "icx";
                    return "icc";
                }
                else
                {
                    auto res = execute(["which", "icx"]);
                    if (res.status == 0)
                        return "icx";
                    return "icc";
                }
            case Compiler.Custom:
                return info.path;
        }
    }
    
    /// Check if command is available
    static bool isAvailable(string command)
    {
        return isCommandAvailable(command);
    }
    
    /// Get compiler include paths
    static string[] getIncludePaths(CompilerInfo info)
    {
        string[] paths;
        
        if (!info.isAvailable)
            return paths;
        
        string compiler = getCppCompiler(info);
        
        // Use -E -v to get include paths
        string[] cmd;
        
        final switch (info.type)
        {
            case Compiler.Auto:
                return paths;
            case Compiler.GCC:
            case Compiler.Clang:
            case Compiler.Intel:
                cmd = [compiler, "-E", "-x", "c++", "-", "-v"];
                break;
            case Compiler.MSVC:
                // MSVC doesn't have a simple way to get include paths
                return paths;
            case Compiler.Custom:
                // Try GCC-like syntax
                cmd = [compiler, "-E", "-x", "c++", "-", "-v"];
                break;
        }
        
        try
        {
            auto res = execute(cmd);
            string output = res.output;
            
            // Parse include paths from output
            bool inIncludeSection = false;
            foreach (line; output.split("\n"))
            {
                if (line.canFind("#include <...> search starts here:"))
                {
                    inIncludeSection = true;
                    continue;
                }
                
                if (inIncludeSection && line.canFind("End of search list"))
                {
                    break;
                }
                
                if (inIncludeSection)
                {
                    string path = line.strip;
                    if (!path.empty && exists(path))
                    {
                        paths ~= path;
                    }
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to get include paths: " ~ e.msg);
        }
        
        return paths;
    }
    
    /// Get compiler predefined macros
    static string[string] getPredefinedMacros(CompilerInfo info)
    {
        string[string] macros;
        
        if (!info.isAvailable)
            return macros;
        
        string compiler = getCppCompiler(info);
        
        string[] cmd;
        
        final switch (info.type)
        {
            case Compiler.Auto:
                return macros;
            case Compiler.GCC:
            case Compiler.Clang:
            case Compiler.Intel:
                cmd = [compiler, "-dM", "-E", "-x", "c++", "-"];
                break;
            case Compiler.MSVC:
                // MSVC: cl /EP /Zc:preprocessor
                cmd = [compiler, "/EP", "/Zc:preprocessor"];
                break;
            case Compiler.Custom:
                // Try GCC-like syntax
                cmd = [compiler, "-dM", "-E", "-x", "c++", "-"];
                break;
        }
        
        try
        {
            auto res = execute(cmd);
            
            // Parse macros: #define NAME VALUE
            foreach (line; res.output.split("\n"))
            {
                auto defineMatch = matchFirst(line, regex(`^#define\s+(\w+)\s+(.+)$`));
                if (!defineMatch.empty && defineMatch.length > 2)
                {
                    macros[defineMatch[1]] = defineMatch[2];
                }
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to get predefined macros: " ~ e.msg);
        }
        
        return macros;
    }
}

/// Build system detector
class BuildSystemDetector
{
    /// Detect build system from project structure
    static BuildSystem detect(string projectDir)
    {
        // Check for various build system files
        string cmakeFile = buildPath(projectDir, "CMakeLists.txt");
        if (exists(cmakeFile))
            return BuildSystem.CMake;
        
        string makeFile = buildPath(projectDir, "Makefile");
        if (exists(makeFile))
            return BuildSystem.Make;
        
        string ninjaFile = buildPath(projectDir, "build.ninja");
        if (exists(ninjaFile))
            return BuildSystem.Ninja;
        
        string bazelFile = buildPath(projectDir, "BUILD");
        string bazelWorkspace = buildPath(projectDir, "WORKSPACE");
        if (exists(bazelFile) || exists(bazelWorkspace))
            return BuildSystem.Bazel;
        
        string mesonFile = buildPath(projectDir, "meson.build");
        if (exists(mesonFile))
            return BuildSystem.Meson;
        
        string xmakeFile = buildPath(projectDir, "xmake.lua");
        if (exists(xmakeFile))
            return BuildSystem.Xmake;
        
        return BuildSystem.None;
    }
    
    /// Check if build system is available
    static bool isAvailable(BuildSystem buildSystem)
    {
        final switch (buildSystem)
        {
            case BuildSystem.None:
                return true;
            case BuildSystem.Auto:
                return true;
            case BuildSystem.CMake:
                return Toolchain.isAvailable("cmake");
            case BuildSystem.Make:
                return Toolchain.isAvailable("make");
            case BuildSystem.Ninja:
                return Toolchain.isAvailable("ninja");
            case BuildSystem.Bazel:
                return Toolchain.isAvailable("bazel");
            case BuildSystem.Meson:
                return Toolchain.isAvailable("meson");
            case BuildSystem.Xmake:
                return Toolchain.isAvailable("xmake");
        }
    }
}

