module languages.compiled.d.managers.toolchain;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.conv;
import utils.logging.logger;

/// D compiler information
struct CompilerInfo
{
    string name;
    string version_;
    string path;
    bool isAvailable;
}

/// D compiler tools and detection
class DCompilerTools
{
    /// Check if a compiler is available
    static bool isCompilerAvailable(string compiler)
    {
        if (compiler.empty)
            return false;
        
        try
        {
            auto res = execute([compiler, "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    /// Get compiler version
    static string getCompilerVersion(string compiler)
    {
        try
        {
            auto res = execute([compiler, "--version"]);
            if (res.status == 0)
            {
                auto lines = res.output.split("\n");
                if (lines.length > 0)
                {
                    return lines[0].strip();
                }
            }
        }
        catch (Exception e)
        {
        }
        return "unknown";
    }
    
    /// Detect all available D compilers
    static CompilerInfo[] detectCompilers()
    {
        CompilerInfo[] compilers;
        
        // Check LDC
        if (isCompilerAvailable("ldc2"))
        {
            CompilerInfo ldc;
            ldc.name = "ldc2";
            ldc.version_ = getCompilerVersion("ldc2");
            ldc.path = findExecutable("ldc2");
            ldc.isAvailable = true;
            compilers ~= ldc;
        }
        
        // Check DMD
        if (isCompilerAvailable("dmd"))
        {
            CompilerInfo dmd;
            dmd.name = "dmd";
            dmd.version_ = getCompilerVersion("dmd");
            dmd.path = findExecutable("dmd");
            dmd.isAvailable = true;
            compilers ~= dmd;
        }
        
        // Check GDC
        if (isCompilerAvailable("gdc"))
        {
            CompilerInfo gdc;
            gdc.name = "gdc";
            gdc.version_ = getCompilerVersion("gdc");
            gdc.path = findExecutable("gdc");
            gdc.isAvailable = true;
            compilers ~= gdc;
        }
        
        return compilers;
    }
    
    /// Find best available compiler (prefer LDC for production)
    static string findBestCompiler()
    {
        if (isCompilerAvailable("ldc2"))
            return "ldc2";
        
        if (isCompilerAvailable("dmd"))
            return "dmd";
        
        if (isCompilerAvailable("gdc"))
            return "gdc";
        
        return "";
    }
    
    /// Find executable in PATH
    private static string findExecutable(string name)
    {
        version(Windows)
        {
            if (!name.endsWith(".exe"))
                name ~= ".exe";
        }
        
        string pathEnv = environment.get("PATH", "");
        
        version(Windows)
        {
            auto paths = pathEnv.split(";");
        }
        else
        {
            auto paths = pathEnv.split(":");
        }
        
        foreach (dir; paths)
        {
            string fullPath = buildPath(dir, name);
            if (exists(fullPath))
            {
                return fullPath;
            }
        }
        
        return name; // Return name if not found, will fail later
    }
    
    /// Get compiler capabilities
    static string[] getCompilerCapabilities(string compiler)
    {
        string[] capabilities;
        
        if (compiler.canFind("ldc"))
        {
            capabilities ~= ["llvm", "lto", "cross-compile", "optimization"];
        }
        else if (compiler.canFind("dmd"))
        {
            capabilities ~= ["fast-compile", "reference"];
        }
        else if (compiler.canFind("gdc"))
        {
            capabilities ~= ["gcc", "optimization"];
        }
        
        return capabilities;
    }
    
    /// Check if DUB is available
    static bool isDubAvailable()
    {
        return isCompilerAvailable("dub");
    }
    
    /// Get DUB version
    static string getDubVersion()
    {
        return getCompilerVersion("dub");
    }
    
    /// Print compiler information
    static void printCompilerInfo(string compiler)
    {
        if (!isCompilerAvailable(compiler))
        {
            Logger.info(compiler ~ " is not available");
            return;
        }
        
        Logger.info("Compiler: " ~ compiler);
        Logger.info("Version: " ~ getCompilerVersion(compiler));
        Logger.info("Path: " ~ findExecutable(compiler));
        Logger.info("Capabilities: " ~ getCompilerCapabilities(compiler).join(", "));
    }
    
    /// Print all available compilers
    static void printAllCompilers()
    {
        auto compilers = detectCompilers();
        
        if (compilers.empty)
        {
            Logger.info("No D compilers found");
            return;
        }
        
        Logger.info("Available D compilers:");
        foreach (compiler; compilers)
        {
            Logger.info("  - " ~ compiler.name ~ " (" ~ compiler.version_ ~ ")");
            Logger.info("    Path: " ~ compiler.path);
        }
    }
}


