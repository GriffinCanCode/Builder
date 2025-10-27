module languages.compiled.cpp.tooling.tools;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.compiled.cpp.core.config;
import languages.compiled.cpp.tooling.toolchain;
import utils.logging.logger;

/// Result from static analysis tool
struct AnalysisResult
{
    bool success;
    string error;
    bool hadIssues;
    string[] issues;
    string[] warnings;
    string[] errors;
}

/// Clang-Tidy static analyzer
class ClangTidy
{
    /// Check if clang-tidy is available
    static bool isAvailable()
    {
        return Toolchain.isAvailable("clang-tidy");
    }
    
    /// Get version
    static string getVersion()
    {
        auto res = execute(["clang-tidy", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Run clang-tidy on sources
    static AnalysisResult analyze(
        string[] sources,
        CppConfig config,
        string[] extraChecks = []
    )
    {
        AnalysisResult result;
        
        if (!isAvailable())
        {
            result.error = "clang-tidy not available";
            return result;
        }
        
        Logger.info("Running clang-tidy...");
        
        // Build checks list
        string[] checks = [
            "bugprone-*",
            "cert-*",
            "clang-analyzer-*",
            "cppcoreguidelines-*",
            "modernize-*",
            "performance-*",
            "readability-*"
        ];
        checks ~= extraChecks;
        
        string checkStr = checks.join(",");
        
        foreach (source; sources)
        {
            if (!exists(source))
                continue;
            
            string[] cmd = [
                "clang-tidy",
                source,
                "--checks=" ~ checkStr
            ];
            
            // Add include paths
            foreach (inc; config.includeDirs)
            {
                cmd ~= ["--", "-I" ~ inc];
            }
            
            // Add defines
            foreach (def; config.defines)
            {
                cmd ~= ["--", "-D" ~ def];
            }
            
            // Add standard
            cmd ~= ["--", "-std=c++17"]; // TODO: Use config.cppStandard
            
            Logger.debugLog("Analyzing: " ~ source);
            
            auto res = execute(cmd);
            
            // clang-tidy returns non-zero if issues found
            if (res.status != 0 || !res.output.empty)
            {
                result.hadIssues = true;
                
                // Parse output for errors and warnings
                foreach (line; res.output.split("\n"))
                {
                    if (line.canFind("error:"))
                    {
                        result.errors ~= line;
                    }
                    else if (line.canFind("warning:"))
                    {
                        result.warnings ~= line;
                    }
                    else if (!line.strip.empty)
                    {
                        result.issues ~= line;
                    }
                }
            }
        }
        
        result.success = true;
        return result;
    }
}

/// CppCheck static analyzer
class CppCheck
{
    /// Check if cppcheck is available
    static bool isAvailable()
    {
        return Toolchain.isAvailable("cppcheck");
    }
    
    /// Get version
    static string getVersion()
    {
        auto res = execute(["cppcheck", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Run cppcheck on sources
    static AnalysisResult analyze(
        string[] sources,
        CppConfig config
    )
    {
        AnalysisResult result;
        
        if (!isAvailable())
        {
            result.error = "cppcheck not available";
            return result;
        }
        
        Logger.info("Running cppcheck...");
        
        string[] cmd = [
            "cppcheck",
            "--enable=all",
            "--inconclusive",
            "--std=c++17", // TODO: Use config.cppStandard
            "--quiet"
        ];
        
        // Add include paths
        foreach (inc; config.includeDirs)
        {
            cmd ~= "-I" ~ inc;
        }
        
        // Add defines
        foreach (def; config.defines)
        {
            cmd ~= "-D" ~ def;
        }
        
        // Add sources
        cmd ~= sources;
        
        auto res = execute(cmd);
        
        // Parse output
        if (!res.output.empty)
        {
            result.hadIssues = true;
            
            foreach (line; res.output.split("\n"))
            {
                if (line.canFind("error:"))
                {
                    result.errors ~= line;
                }
                else if (line.canFind("warning:"))
                {
                    result.warnings ~= line;
                }
                else if (!line.strip.empty)
                {
                    result.issues ~= line;
                }
            }
        }
        
        result.success = true;
        return result;
    }
}

/// Clang-Format code formatter
class ClangFormat
{
    /// Check if clang-format is available
    static bool isAvailable()
    {
        return Toolchain.isAvailable("clang-format");
    }
    
    /// Get version
    static string getVersion()
    {
        auto res = execute(["clang-format", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Format source files
    static bool format(
        string[] sources,
        string style = "LLVM",
        bool inPlace = true
    )
    {
        if (!isAvailable())
        {
            Logger.warning("clang-format not available");
            return false;
        }
        
        Logger.info("Formatting code with clang-format...");
        
        foreach (source; sources)
        {
            if (!exists(source))
                continue;
            
            string[] cmd = [
                "clang-format",
                "--style=" ~ style
            ];
            
            if (inPlace)
            {
                cmd ~= "-i";
            }
            
            cmd ~= source;
            
            Logger.debugLog("Formatting: " ~ source);
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                Logger.error("Failed to format " ~ source ~ ": " ~ res.output);
                return false;
            }
        }
        
        Logger.info("Code formatted successfully");
        return true;
    }
    
    /// Check if files are formatted correctly
    static bool check(
        string[] sources,
        string style = "LLVM"
    )
    {
        if (!isAvailable())
        {
            return false;
        }
        
        bool allFormatted = true;
        
        foreach (source; sources)
        {
            if (!exists(source))
                continue;
            
            string[] cmd = [
                "clang-format",
                "--style=" ~ style,
                "--dry-run",
                "--Werror",
                source
            ];
            
            auto res = execute(cmd);
            
            if (res.status != 0)
            {
                Logger.warning("File not properly formatted: " ~ source);
                allFormatted = false;
            }
        }
        
        return allFormatted;
    }
}

/// Sanitizer result
struct SanitizerResult
{
    bool success;
    string error;
    bool hadIssues;
    string[] issues;
}

/// Sanitizer runner
class SanitizerRunner
{
    /// Run executable with sanitizers enabled
    static SanitizerResult run(
        string executable,
        Sanitizer[] sanitizers,
        string[] args = []
    )
    {
        SanitizerResult result;
        
        if (!exists(executable))
        {
            result.error = "Executable not found: " ~ executable;
            return result;
        }
        
        Logger.info("Running with sanitizers: " ~ sanitizers.to!string);
        
        // Build environment with sanitizer options
        string[string] env;
        foreach (key, value; environment.toAA())
            env[key] = value;
        
        // Configure sanitizer options
        foreach (san; sanitizers)
        {
            final switch (san)
            {
                case Sanitizer.None:
                    break;
                case Sanitizer.Address:
                    env["ASAN_OPTIONS"] = "detect_leaks=1:check_initialization_order=1";
                    break;
                case Sanitizer.Thread:
                    env["TSAN_OPTIONS"] = "history_size=7";
                    break;
                case Sanitizer.Memory:
                    env["MSAN_OPTIONS"] = "poison_in_dtor=1";
                    break;
                case Sanitizer.UndefinedBehavior:
                    env["UBSAN_OPTIONS"] = "print_stacktrace=1";
                    break;
                case Sanitizer.Leak:
                    env["LSAN_OPTIONS"] = "report_objects=1";
                    break;
                case Sanitizer.HWAddress:
                    env["HWASAN_OPTIONS"] = "print_stacktrace=1";
                    break;
            }
        }
        
        // Run executable
        string[] cmd = [executable] ~ args;
        
        auto res = execute(cmd, env);
        
        if (res.status != 0)
        {
            result.hadIssues = true;
            
            // Parse sanitizer output
            foreach (line; res.output.split("\n"))
            {
                if (line.canFind("ERROR:") || 
                    line.canFind("WARNING:") ||
                    line.canFind("Sanitizer"))
                {
                    result.issues ~= line;
                }
            }
        }
        
        result.success = true;
        return result;
    }
}

/// Code coverage tool
class CoverageTool
{
    /// Check if gcov is available
    static bool isGcovAvailable()
    {
        return Toolchain.isAvailable("gcov");
    }
    
    /// Check if llvm-cov is available
    static bool isLlvmCovAvailable()
    {
        return Toolchain.isAvailable("llvm-cov");
    }
    
    /// Generate coverage report
    static bool generateReport(
        string[] gcdaFiles,
        string outputDir,
        string format = "html"
    )
    {
        // Try lcov first (if available)
        if (Toolchain.isAvailable("lcov"))
        {
            return generateLcovReport(gcdaFiles, outputDir);
        }
        
        // Fallback to gcov
        if (isGcovAvailable())
        {
            return generateGcovReport(gcdaFiles, outputDir);
        }
        
        Logger.warning("No coverage tool available");
        return false;
    }
    
    private static bool generateGcovReport(string[] gcdaFiles, string outputDir)
    {
        Logger.info("Generating coverage report with gcov...");
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        foreach (gcda; gcdaFiles)
        {
            auto res = execute(["gcov", gcda]);
            if (res.status != 0)
            {
                Logger.error("gcov failed: " ~ res.output);
                return false;
            }
        }
        
        return true;
    }
    
    private static bool generateLcovReport(string[] gcdaFiles, string outputDir)
    {
        Logger.info("Generating coverage report with lcov...");
        
        if (!exists(outputDir))
            mkdirRecurse(outputDir);
        
        string infoFile = buildPath(outputDir, "coverage.info");
        string htmlDir = buildPath(outputDir, "html");
        
        // Generate .info file
        auto res = execute(["lcov", "--capture", "--directory", ".", "--output-file", infoFile]);
        if (res.status != 0)
        {
            Logger.error("lcov failed: " ~ res.output);
            return false;
        }
        
        // Generate HTML report
        if (Toolchain.isAvailable("genhtml"))
        {
            res = execute(["genhtml", infoFile, "--output-directory", htmlDir]);
            if (res.status != 0)
            {
                Logger.error("genhtml failed: " ~ res.output);
                return false;
            }
            
            Logger.info("Coverage report generated: " ~ htmlDir);
        }
        
        return true;
    }
}

