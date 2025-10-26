module languages.scripting.r.tooling.info;

import std.stdio;
import std.process;
import std.string;
import std.algorithm;
import std.array;
import std.regex;
import std.conv;
import std.typecons;
import languages.scripting.r.core.config;
import utils.logging.logger;

/// R tool availability and version information
struct RToolInfo
{
    string executable;
    bool available;
    string version_;
    string path;
    
    /// Check if tool meets version requirement
    bool meetsVersion(string requirement) const
    {
        if (requirement.empty || version_.empty)
            return available;
        
        return compareVersions(version_, requirement);
    }
}

/// Detect R installation
RToolInfo detectR(string executable = "R")
{
    RToolInfo info;
    info.executable = executable;
    
    version(Windows)
    {
        auto res = execute(["where", executable]);
        if (res.status == 0)
        {
            info.available = true;
            info.path = res.output.strip();
        }
    }
    else
    {
        auto res = execute(["which", executable]);
        if (res.status == 0)
        {
            info.available = true;
            info.path = res.output.strip();
        }
    }
    
    if (info.available)
    {
        info.version_ = getRVersion(executable);
    }
    
    return info;
}

/// Detect Rscript installation
RToolInfo detectRscript(string executable = "Rscript")
{
    RToolInfo info;
    info.executable = executable;
    
    version(Windows)
    {
        auto res = execute(["where", executable]);
        if (res.status == 0)
        {
            info.available = true;
            info.path = res.output.strip();
        }
    }
    else
    {
        auto res = execute(["which", executable]);
        if (res.status == 0)
        {
            info.available = true;
            info.path = res.output.strip();
        }
    }
    
    if (info.available)
    {
        info.version_ = getRscriptVersion(executable);
    }
    
    return info;
}

/// Get R version
string getRVersion(string rCmd = "R")
{
    auto res = execute([rCmd, "--version"]);
    if (res.status == 0 && !res.output.empty)
    {
        // Extract version from output: "R version 4.3.1 (2023-06-16)"
        auto versionMatch = matchFirst(res.output, regex(r"R version (\d+\.\d+\.\d+)"));
        if (versionMatch)
            return versionMatch[1];
    }
    return "";
}

/// Get Rscript version
string getRscriptVersion(string rscriptCmd = "Rscript")
{
    auto res = execute([rscriptCmd, "--version"]);
    if (res.status == 0 && !res.output.empty)
    {
        // Extract version from stderr output
        auto versionMatch = matchFirst(res.output, regex(r"R scripting front-end version (\d+\.\d+\.\d+)"));
        if (versionMatch)
            return versionMatch[1];
        
        // Try alternative format
        versionMatch = matchFirst(res.output, regex(r"(\d+\.\d+\.\d+)"));
        if (versionMatch)
            return versionMatch[1];
    }
    return "";
}

/// Check if R package is installed
bool isRPackageInstalled(string packageName, string rCmd = "Rscript")
{
    string checkCode = `tryCatch({library(` ~ packageName ~ `, quietly=TRUE); quit(status=0)}, error=function(e) quit(status=1))`;
    auto res = execute([rCmd, "-e", checkCode]);
    return res.status == 0;
}

/// Get installed R package version
string getRPackageVersion(string packageName, string rCmd = "Rscript")
{
    string versionCode = `cat(as.character(packageVersion('` ~ packageName ~ `')))`;
    auto res = execute([rCmd, "-e", versionCode]);
    if (res.status == 0)
        return res.output.strip();
    return "";
}

/// Detect package manager availability
RToolInfo detectPackageManager(RPackageManager manager, string rCmd = "Rscript")
{
    RToolInfo info;
    
    final switch (manager)
    {
        case RPackageManager.Auto:
            // Will be resolved later
            info.available = true;
            return info;
            
        case RPackageManager.InstallPackages:
            // Always available with base R
            info.available = true;
            info.executable = "install.packages";
            return info;
            
        case RPackageManager.Pak:
            info.executable = "pak";
            info.available = isRPackageInstalled("pak", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("pak", rCmd);
            return info;
            
        case RPackageManager.Renv:
            info.executable = "renv";
            info.available = isRPackageInstalled("renv", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("renv", rCmd);
            return info;
            
        case RPackageManager.Packrat:
            info.executable = "packrat";
            info.available = isRPackageInstalled("packrat", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("packrat", rCmd);
            return info;
            
        case RPackageManager.Remotes:
            info.executable = "remotes";
            info.available = isRPackageInstalled("remotes", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("remotes", rCmd);
            return info;
            
        case RPackageManager.None:
            info.available = false;
            return info;
    }
}

/// Auto-detect best available package manager
RPackageManager detectBestPackageManager(string rCmd = "Rscript")
{
    // Priority: pak > renv (if project uses it) > install.packages
    
    if (isRPackageInstalled("pak", rCmd))
    {
        Logger.debug_("Detected pak package manager");
        return RPackageManager.Pak;
    }
    
    // Check for renv project structure
    import std.file : exists;
    if (exists("renv.lock") && isRPackageInstalled("renv", rCmd))
    {
        Logger.debug_("Detected renv project");
        return RPackageManager.Renv;
    }
    
    // Default to standard install.packages
    Logger.debug_("Using standard install.packages");
    return RPackageManager.InstallPackages;
}

/// Detect linter availability
RToolInfo detectLinter(RLinter linter, string rCmd = "Rscript")
{
    RToolInfo info;
    
    final switch (linter)
    {
        case RLinter.Auto:
            // Will be resolved later
            info.available = true;
            return info;
            
        case RLinter.Lintr:
            info.executable = "lintr";
            info.available = isRPackageInstalled("lintr", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("lintr", rCmd);
            return info;
            
        case RLinter.Goodpractice:
            info.executable = "goodpractice";
            info.available = isRPackageInstalled("goodpractice", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("goodpractice", rCmd);
            return info;
            
        case RLinter.None:
            info.available = false;
            return info;
    }
}

/// Auto-detect best available linter
RLinter detectBestLinter(string rCmd = "Rscript")
{
    if (isRPackageInstalled("lintr", rCmd))
    {
        Logger.debug_("Detected lintr");
        return RLinter.Lintr;
    }
    
    Logger.debug_("No linter detected");
    return RLinter.None;
}

/// Detect formatter availability
RToolInfo detectFormatter(RFormatter formatter, string rCmd = "Rscript")
{
    RToolInfo info;
    
    final switch (formatter)
    {
        case RFormatter.Auto:
            // Will be resolved later
            info.available = true;
            return info;
            
        case RFormatter.Styler:
            info.executable = "styler";
            info.available = isRPackageInstalled("styler", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("styler", rCmd);
            return info;
            
        case RFormatter.FormatR:
            info.executable = "formatR";
            info.available = isRPackageInstalled("formatR", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("formatR", rCmd);
            return info;
            
        case RFormatter.None:
            info.available = false;
            return info;
    }
}

/// Auto-detect best available formatter
RFormatter detectBestFormatter(string rCmd = "Rscript")
{
    if (isRPackageInstalled("styler", rCmd))
    {
        Logger.debug_("Detected styler");
        return RFormatter.Styler;
    }
    
    if (isRPackageInstalled("formatR", rCmd))
    {
        Logger.debug_("Detected formatR");
        return RFormatter.FormatR;
    }
    
    Logger.debug_("No formatter detected");
    return RFormatter.None;
}

/// Detect test framework availability
RToolInfo detectTestFramework(RTestFramework framework, string rCmd = "Rscript")
{
    RToolInfo info;
    
    final switch (framework)
    {
        case RTestFramework.Auto:
            // Will be resolved later
            info.available = true;
            return info;
            
        case RTestFramework.Testthat:
            info.executable = "testthat";
            info.available = isRPackageInstalled("testthat", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("testthat", rCmd);
            return info;
            
        case RTestFramework.Tinytest:
            info.executable = "tinytest";
            info.available = isRPackageInstalled("tinytest", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("tinytest", rCmd);
            return info;
            
        case RTestFramework.RUnit:
            info.executable = "RUnit";
            info.available = isRPackageInstalled("RUnit", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("RUnit", rCmd);
            return info;
            
        case RTestFramework.None:
            info.available = false;
            return info;
    }
}

/// Auto-detect best available test framework
RTestFramework detectBestTestFramework(string rCmd = "Rscript")
{
    import std.file : exists;
    
    // Check for testthat directory structure
    if (exists("tests/testthat") && isRPackageInstalled("testthat", rCmd))
    {
        Logger.debug_("Detected testthat framework");
        return RTestFramework.Testthat;
    }
    
    if (isRPackageInstalled("testthat", rCmd))
    {
        Logger.debug_("Detected testthat (installed)");
        return RTestFramework.Testthat;
    }
    
    if (isRPackageInstalled("tinytest", rCmd))
    {
        Logger.debug_("Detected tinytest");
        return RTestFramework.Tinytest;
    }
    
    if (isRPackageInstalled("RUnit", rCmd))
    {
        Logger.debug_("Detected RUnit");
        return RTestFramework.RUnit;
    }
    
    Logger.debug_("No test framework detected");
    return RTestFramework.None;
}

/// Detect documentation generator availability
RToolInfo detectDocGenerator(RDocGenerator generator, string rCmd = "Rscript")
{
    RToolInfo info;
    
    final switch (generator)
    {
        case RDocGenerator.Auto:
        case RDocGenerator.Both:
            // Will be resolved later
            info.available = true;
            return info;
            
        case RDocGenerator.Roxygen2:
            info.executable = "roxygen2";
            info.available = isRPackageInstalled("roxygen2", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("roxygen2", rCmd);
            return info;
            
        case RDocGenerator.Pkgdown:
            info.executable = "pkgdown";
            info.available = isRPackageInstalled("pkgdown", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("pkgdown", rCmd);
            return info;
            
        case RDocGenerator.None:
            info.available = false;
            return info;
    }
}

/// Auto-detect best available doc generator
RDocGenerator detectBestDocGenerator(string rCmd = "Rscript")
{
    bool hasRoxygen = isRPackageInstalled("roxygen2", rCmd);
    bool hasPkgdown = isRPackageInstalled("pkgdown", rCmd);
    
    if (hasRoxygen && hasPkgdown)
    {
        Logger.debug_("Detected roxygen2 and pkgdown");
        return RDocGenerator.Both;
    }
    
    if (hasRoxygen)
    {
        Logger.debug_("Detected roxygen2");
        return RDocGenerator.Roxygen2;
    }
    
    if (hasPkgdown)
    {
        Logger.debug_("Detected pkgdown");
        return RDocGenerator.Pkgdown;
    }
    
    Logger.debug_("No doc generator detected");
    return RDocGenerator.None;
}

/// Detect environment manager availability
RToolInfo detectEnvManager(REnvManager manager, string rCmd = "Rscript")
{
    RToolInfo info;
    
    final switch (manager)
    {
        case REnvManager.Auto:
            // Will be resolved later
            info.available = true;
            return info;
            
        case REnvManager.Renv:
            info.executable = "renv";
            info.available = isRPackageInstalled("renv", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("renv", rCmd);
            return info;
            
        case REnvManager.Packrat:
            info.executable = "packrat";
            info.available = isRPackageInstalled("packrat", rCmd);
            if (info.available)
                info.version_ = getRPackageVersion("packrat", rCmd);
            return info;
            
        case REnvManager.None:
            info.available = false;
            return info;
    }
}

/// Auto-detect best available environment manager
REnvManager detectBestEnvManager(string rCmd = "Rscript")
{
    import std.file : exists;
    
    // Check for renv project
    if (exists("renv.lock") || exists("renv"))
    {
        if (isRPackageInstalled("renv", rCmd))
        {
            Logger.debug_("Detected renv environment");
            return REnvManager.Renv;
        }
    }
    
    // Check for packrat project
    if (exists("packrat/packrat.lock"))
    {
        if (isRPackageInstalled("packrat", rCmd))
        {
            Logger.debug_("Detected packrat environment");
            return REnvManager.Packrat;
        }
    }
    
    Logger.debug_("No environment manager detected");
    return REnvManager.None;
}

/// Check if devtools is available
bool isDevtoolsAvailable(string rCmd = "Rscript")
{
    return isRPackageInstalled("devtools", rCmd);
}

/// Check if BiocManager is available
bool isBiocManagerAvailable(string rCmd = "Rscript")
{
    return isRPackageInstalled("BiocManager", rCmd);
}

/// Check if coverage tools are available
bool isCoverageAvailable(string rCmd = "Rscript")
{
    return isRPackageInstalled("covr", rCmd);
}

/// Compare version strings
private bool compareVersions(string actual, string requirement)
{
    // Parse requirement operator
    string op = ">=";
    string reqVer = requirement;
    
    if (requirement.startsWith(">="))
    {
        op = ">=";
        reqVer = requirement[2..$].strip();
    }
    else if (requirement.startsWith("<="))
    {
        op = "<=";
        reqVer = requirement[2..$].strip();
    }
    else if (requirement.startsWith(">"))
    {
        op = ">";
        reqVer = requirement[1..$].strip();
    }
    else if (requirement.startsWith("<"))
    {
        op = "<";
        reqVer = requirement[1..$].strip();
    }
    else if (requirement.startsWith("=="))
    {
        op = "==";
        reqVer = requirement[2..$].strip();
    }
    else if (requirement.startsWith("="))
    {
        op = "==";
        reqVer = requirement[1..$].strip();
    }
    
    // Parse version numbers
    auto actualParts = actual.split(".").map!(p => p.to!int).array;
    auto reqParts = reqVer.split(".").map!(p => p.to!int).array;
    
    // Pad to same length
    while (actualParts.length < reqParts.length)
        actualParts ~= 0;
    while (reqParts.length < actualParts.length)
        reqParts ~= 0;
    
    // Compare
    int cmp = 0;
    foreach (i; 0..actualParts.length)
    {
        if (actualParts[i] < reqParts[i])
        {
            cmp = -1;
            break;
        }
        else if (actualParts[i] > reqParts[i])
        {
            cmp = 1;
            break;
        }
    }
    
    // Apply operator
    switch (op)
    {
        case "==": return cmp == 0;
        case ">=": return cmp >= 0;
        case "<=": return cmp <= 0;
        case ">": return cmp > 0;
        case "<": return cmp < 0;
        default: return true;
    }
}

/// Get R library paths
string[] getRLibPaths(string rCmd = "Rscript")
{
    string code = `cat(.libPaths(), sep="\n")`;
    auto res = execute([rCmd, "-e", code]);
    if (res.status == 0)
    {
        return res.output.strip().split("\n").map!(s => s.strip()).array;
    }
    return [];
}

/// Get R environment variables
string[string] getREnvironment(string rCmd = "Rscript")
{
    string[string] env;
    
    string code = `e <- Sys.getenv(); cat(paste(names(e), e, sep="="), sep="\n")`;
    auto res = execute([rCmd, "-e", code]);
    if (res.status == 0)
    {
        foreach (line; res.output.strip().split("\n"))
        {
            auto parts = line.split("=");
            if (parts.length >= 2)
            {
                env[parts[0]] = parts[1..$].join("=");
            }
        }
    }
    
    return env;
}

/// Get R capabilities (what features R was compiled with)
string[string] getRCapabilities(string rCmd = "R")
{
    string[string] caps;
    
    string code = `caps <- capabilities(); cat(paste(names(caps), caps, sep="="), sep="\n")`;
    auto res = execute([rCmd, "--vanilla", "--slave", "-e", code]);
    if (res.status == 0)
    {
        foreach (line; res.output.strip().split("\n"))
        {
            auto parts = line.split("=");
            if (parts.length == 2)
            {
                caps[parts[0]] = parts[1];
            }
        }
    }
    
    return caps;
}

