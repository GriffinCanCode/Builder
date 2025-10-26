module languages.scripting.r.analysis.dependencies;

import std.stdio;
import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.json;
import std.regex;
import std.conv;
import languages.scripting.r.core.config;
import utils.logging.logger;

/// Parse dependencies from DESCRIPTION file
RPackageDep[] parseDESCRIPTION(string descPath)
{
    if (!exists(descPath))
    {
        Logger.warning("DESCRIPTION file not found: " ~ descPath);
        return [];
    }
    
    RPackageDep[] deps;
    string content = readText(descPath);
    
    // Parse different dependency sections
    deps ~= parseDependencySection(content, "Depends", RRepository.CRAN);
    deps ~= parseDependencySection(content, "Imports", RRepository.CRAN);
    deps ~= parseDependencySection(content, "Suggests", RRepository.CRAN);
    deps ~= parseDependencySection(content, "LinkingTo", RRepository.CRAN);
    
    Logger.debug_("Parsed " ~ deps.length.to!string ~ " dependencies from DESCRIPTION");
    return deps;
}

/// Parse a specific dependency section from DESCRIPTION
private RPackageDep[] parseDependencySection(string content, string sectionName, RRepository defaultRepo)
{
    RPackageDep[] deps;
    
    // Match section: "SectionName: pkg1, pkg2 (>= 1.0.0), pkg3"
    // Can span multiple lines with indentation
    auto sectionRegex = regex(sectionName ~ r":\s*([^\n]*(?:\n\s+[^\n]+)*)", "m");
    auto match = matchFirst(content, sectionRegex);
    
    if (!match.empty)
    {
        string depStr = match[1].strip();
        
        // Remove line breaks and extra spaces
        depStr = depStr.replaceAll(regex(`\s+`), " ");
        
        // Split by comma
        auto depParts = depStr.split(",");
        
        foreach (part; depParts)
        {
            auto dep = parseDependencySpec(part.strip(), defaultRepo);
            if (dep.name != "R") // Exclude R itself
            {
                deps ~= dep;
            }
        }
    }
    
    return deps;
}

/// Parse individual dependency specification
private RPackageDep parseDependencySpec(string spec, RRepository defaultRepo)
{
    RPackageDep dep;
    dep.repository = defaultRepo;
    
    // Match "package (>= 1.0.0)" or just "package"
    auto versionRegex = regex(`^([^\s(]+)\s*(?:\(([^)]+)\))?`);
    auto match = matchFirst(spec, versionRegex);
    
    if (!match.empty)
    {
        dep.name = match[1].strip();
        if (match.length > 2 && !match[2].empty)
        {
            dep.version_ = match[2].strip();
        }
    }
    else
    {
        dep.name = spec.strip();
    }
    
    return dep;
}

/// Parse dependencies from renv.lock
RPackageDep[] parseRenvLock(string lockPath)
{
    if (!exists(lockPath))
    {
        Logger.warning("renv.lock file not found: " ~ lockPath);
        return [];
    }
    
    RPackageDep[] deps;
    
    try
    {
        string content = readText(lockPath);
        auto json = parseJSON(content);
        
        if ("Packages" in json && json["Packages"].type == JSONType.object)
        {
            foreach (string pkgName, pkgInfo; json["Packages"].object)
            {
                RPackageDep dep;
                dep.name = pkgName;
                
                if ("Version" in pkgInfo)
                {
                    dep.version_ = "== " ~ pkgInfo["Version"].str;
                }
                
                if ("Repository" in pkgInfo)
                {
                    string repo = pkgInfo["Repository"].str.toLower();
                    if (repo == "cran")
                        dep.repository = RRepository.CRAN;
                    else if (repo.canFind("bioc"))
                        dep.repository = RRepository.Bioconductor;
                    else
                        dep.repository = RRepository.Custom;
                }
                else
                {
                    dep.repository = RRepository.CRAN;
                }
                
                // Check for GitHub source
                if ("RemoteType" in pkgInfo && pkgInfo["RemoteType"].str == "github")
                {
                    dep.repository = RRepository.GitHub;
                    if ("RemoteUsername" in pkgInfo && "RemoteRepo" in pkgInfo)
                    {
                        dep.customUrl = pkgInfo["RemoteUsername"].str ~ "/" ~ pkgInfo["RemoteRepo"].str;
                    }
                    if ("RemoteRef" in pkgInfo)
                    {
                        dep.gitRef = pkgInfo["RemoteRef"].str;
                    }
                }
                
                deps ~= dep;
            }
        }
        
        Logger.debug_("Parsed " ~ deps.length.to!string ~ " dependencies from renv.lock");
    }
    catch (Exception e)
    {
        Logger.error("Failed to parse renv.lock: " ~ e.msg);
    }
    
    return deps;
}

/// Parse dependencies from packrat.lock
RPackageDep[] parsePackratLock(string lockPath)
{
    if (!exists(lockPath))
    {
        Logger.warning("packrat.lock file not found: " ~ lockPath);
        return [];
    }
    
    RPackageDep[] deps;
    
    try
    {
        string content = readText(lockPath);
        
        // packrat.lock has a custom format:
        // PackratFormat: 1.4
        // PackratVersion: 0.5.0
        // RVersion: 4.0.0
        // Repos: CRAN=https://cran.rstudio.com/
        //
        // Package: packagename
        // Source: CRAN
        // Version: 1.0.0
        // Hash: xxxxx
        //
        // Package: another
        // ...
        
        auto packageRegex = regex(`Package:\s*(\S+)`, "m");
        auto sourceRegex = regex(`Source:\s*(\S+)`, "m");
        auto versionRegex = regex(`Version:\s*(\S+)`, "m");
        
        // Split by double newline to get package blocks
        auto blocks = content.split("\n\n");
        
        foreach (block; blocks)
        {
            auto pkgMatch = matchFirst(block, packageRegex);
            if (!pkgMatch.empty)
            {
                RPackageDep dep;
                dep.name = pkgMatch[1];
                
                auto verMatch = matchFirst(block, versionRegex);
                if (!verMatch.empty)
                {
                    dep.version_ = "== " ~ verMatch[1];
                }
                
                auto srcMatch = matchFirst(block, sourceRegex);
                if (!srcMatch.empty)
                {
                    string source = srcMatch[1].toLower();
                    if (source == "cran")
                        dep.repository = RRepository.CRAN;
                    else if (source.canFind("bioc"))
                        dep.repository = RRepository.Bioconductor;
                    else if (source == "github")
                        dep.repository = RRepository.GitHub;
                    else
                        dep.repository = RRepository.Custom;
                }
                else
                {
                    dep.repository = RRepository.CRAN;
                }
                
                deps ~= dep;
            }
        }
        
        Logger.debug_("Parsed " ~ deps.length.to!string ~ " dependencies from packrat.lock");
    }
    catch (Exception e)
    {
        Logger.error("Failed to parse packrat.lock: " ~ e.msg);
    }
    
    return deps;
}

/// Detect and parse dependencies from project
RPackageDep[] detectDependencies(string projectDir)
{
    Logger.debug_("Detecting dependencies in: " ~ projectDir);
    
    // Try renv.lock first (most specific)
    string renvLock = buildPath(projectDir, "renv.lock");
    if (exists(renvLock))
    {
        Logger.debug_("Found renv.lock, parsing...");
        return parseRenvLock(renvLock);
    }
    
    // Try packrat.lock
    string packratLock = buildPath(projectDir, "packrat", "packrat.lock");
    if (exists(packratLock))
    {
        Logger.debug_("Found packrat.lock, parsing...");
        return parsePackratLock(packratLock);
    }
    
    // Try DESCRIPTION file
    string descPath = buildPath(projectDir, "DESCRIPTION");
    if (exists(descPath))
    {
        Logger.debug_("Found DESCRIPTION, parsing...");
        return parseDESCRIPTION(descPath);
    }
    
    // Scan R files for library() calls
    Logger.debug_("No lock files or DESCRIPTION found, scanning R files...");
    return scanRFilesForDependencies(projectDir);
}

/// Scan R files for library()/require() calls
RPackageDep[] scanRFilesForDependencies(string projectDir)
{
    import std.file : dirEntries, SpanMode;
    
    RPackageDep[string] depsMap; // Use map to deduplicate
    
    try
    {
        foreach (entry; dirEntries(projectDir, "*.{R,r}", SpanMode.shallow))
        {
            if (entry.isFile)
            {
                auto fileDeps = scanRFile(entry.name);
                foreach (dep; fileDeps)
                {
                    depsMap[dep.name] = dep;
                }
            }
        }
    }
    catch (Exception e)
    {
        Logger.warning("Error scanning R files: " ~ e.msg);
    }
    
    auto deps = depsMap.values;
    Logger.debug_("Scanned R files, found " ~ deps.length.to!string ~ " unique dependencies");
    return deps;
}

/// Scan a single R file for dependencies
RPackageDep[] scanRFile(string filePath)
{
    RPackageDep[] deps;
    
    try
    {
        string content = readText(filePath);
        
        // Match library() and require() calls
        // library(pkg) or library("pkg") or library('pkg')
        auto libraryRegex = regex(`(?:library|require)\s*\(\s*['\"]?([a-zA-Z0-9.]+)['\"]?\s*\)`, "g");
        
        foreach (match; matchAll(content, libraryRegex))
        {
            RPackageDep dep;
            dep.name = match[1];
            dep.repository = RRepository.CRAN;
            deps ~= dep;
        }
    }
    catch (Exception e)
    {
        Logger.warning("Error scanning file " ~ filePath ~ ": " ~ e.msg);
    }
    
    return deps;
}

/// Find R package root (directory containing DESCRIPTION)
string findPackageRoot(string startDir)
{
    string dir = startDir;
    
    while (dir != "/" && dir.length > 1)
    {
        string descPath = buildPath(dir, "DESCRIPTION");
        if (exists(descPath) && isFile(descPath))
        {
            return dir;
        }
        
        dir = dirName(dir);
    }
    
    return "";
}

/// Check if directory is an R package
bool isRPackage(string dir)
{
    string descPath = buildPath(dir, "DESCRIPTION");
    return exists(descPath) && isFile(descPath);
}

/// Check if directory uses renv
bool usesRenv(string dir)
{
    string renvLock = buildPath(dir, "renv.lock");
    string renvDir = buildPath(dir, "renv");
    return exists(renvLock) || (exists(renvDir) && isDir(renvDir));
}

/// Check if directory uses packrat
bool usesPackrat(string dir)
{
    string packratDir = buildPath(dir, "packrat");
    return exists(packratDir) && isDir(packratDir);
}

/// Get minimum R version from DESCRIPTION
string getMinimumRVersion(string descPath)
{
    if (!exists(descPath))
        return "";
    
    try
    {
        string content = readText(descPath);
        
        // Look for "Depends: R (>= x.y.z)"
        auto rVersionRegex = regex(`Depends:.*\bR\s*\(>=?\s*([\d.]+)\)`, "m");
        auto match = matchFirst(content, rVersionRegex);
        
        if (!match.empty)
        {
            return match[1];
        }
    }
    catch (Exception e)
    {
        Logger.warning("Error parsing R version from DESCRIPTION: " ~ e.msg);
    }
    
    return "";
}

/// Get package version from DESCRIPTION
string getPackageVersion(string descPath)
{
    if (!exists(descPath))
        return "";
    
    try
    {
        string content = readText(descPath);
        
        // Look for "Version: x.y.z"
        auto versionRegex = regex(`Version:\s*([\d.]+)`, "m");
        auto match = matchFirst(content, versionRegex);
        
        if (!match.empty)
        {
            return match[1];
        }
    }
    catch (Exception e)
    {
        Logger.warning("Error parsing package version from DESCRIPTION: " ~ e.msg);
    }
    
    return "";
}

/// Get package name from DESCRIPTION
string getPackageName(string descPath)
{
    if (!exists(descPath))
        return "";
    
    try
    {
        string content = readText(descPath);
        
        // Look for "Package: name"
        auto nameRegex = regex(`Package:\s*(\S+)`, "m");
        auto match = matchFirst(content, nameRegex);
        
        if (!match.empty)
        {
            return match[1];
        }
    }
    catch (Exception e)
    {
        Logger.warning("Error parsing package name from DESCRIPTION: " ~ e.msg);
    }
    
    return "";
}

/// Parse package metadata from DESCRIPTION
struct PackageMetadata
{
    string name;
    string version_;
    string title;
    string description;
    string[] authors;
    string maintainer;
    string license;
    string rVersion;
    RPackageDep[] depends;
    RPackageDep[] imports;
    RPackageDep[] suggests;
    RPackageDep[] linkingTo;
}

/// Get full package metadata from DESCRIPTION
PackageMetadata getPackageMetadata(string descPath)
{
    PackageMetadata metadata;
    
    if (!exists(descPath))
    {
        return metadata;
    }
    
    try
    {
        string content = readText(descPath);
        
        // Parse basic fields
        metadata.name = getPackageName(descPath);
        metadata.version_ = getPackageVersion(descPath);
        metadata.rVersion = getMinimumRVersion(descPath);
        
        // Parse title
        auto titleMatch = matchFirst(content, regex(`Title:\s*([^\n]+)`, "m"));
        if (!titleMatch.empty)
            metadata.title = titleMatch[1].strip();
        
        // Parse description (can be multi-line)
        auto descMatch = matchFirst(content, regex(`Description:\s*([^\n]*(?:\n\s+[^\n]+)*)`, "m"));
        if (!descMatch.empty)
        {
            metadata.description = descMatch[1].replaceAll(regex(`\s+`), " ").strip();
        }
        
        // Parse license
        auto licenseMatch = matchFirst(content, regex(`License:\s*([^\n]+)`, "m"));
        if (!licenseMatch.empty)
            metadata.license = licenseMatch[1].strip();
        
        // Parse maintainer
        auto maintainerMatch = matchFirst(content, regex(`Maintainer:\s*([^\n]+)`, "m"));
        if (!maintainerMatch.empty)
            metadata.maintainer = maintainerMatch[1].strip();
        
        // Parse dependencies
        metadata.depends = parseDependencySection(content, "Depends", RRepository.CRAN);
        metadata.imports = parseDependencySection(content, "Imports", RRepository.CRAN);
        metadata.suggests = parseDependencySection(content, "Suggests", RRepository.CRAN);
        metadata.linkingTo = parseDependencySection(content, "LinkingTo", RRepository.CRAN);
        
        Logger.debug_("Parsed package metadata: " ~ metadata.name ~ " " ~ metadata.version_);
    }
    catch (Exception e)
    {
        Logger.error("Failed to parse DESCRIPTION metadata: " ~ e.msg);
    }
    
    return metadata;
}

/// Generate DESCRIPTION file from package config
void generateDESCRIPTION(string outputPath, const ref RPackageConfig config)
{
    string desc = "Package: " ~ config.name ~ "\n";
    desc ~= "Type: Package\n";
    desc ~= "Title: " ~ (config.title.empty ? config.name : config.title) ~ "\n";
    desc ~= "Version: " ~ config.version_ ~ "\n";
    
    if (!config.authors.empty)
        desc ~= "Authors@R: " ~ config.authors.join(", ") ~ "\n";
    
    if (!config.maintainer.empty)
        desc ~= "Maintainer: " ~ config.maintainer ~ "\n";
    
    if (!config.description.empty)
        desc ~= "Description: " ~ config.description ~ "\n";
    
    desc ~= "License: " ~ config.license ~ "\n";
    desc ~= "Encoding: UTF-8\n";
    
    if (config.lazyData)
        desc ~= "LazyData: true\n";
    
    if (config.roxygen2Markdown)
        desc ~= "Roxygen: list(markdown = TRUE)\n";
    
    desc ~= "Depends: R (>= " ~ config.rVersion ~ ")";
    
    // Add package dependencies
    if (!config.depends.empty)
    {
        desc ~= formatDependencyList("Depends", config.depends, config.rVersion);
    }
    
    if (!config.imports.empty)
    {
        desc ~= formatDependencyList("Imports", config.imports);
    }
    
    if (!config.suggests.empty)
    {
        desc ~= formatDependencyList("Suggests", config.suggests);
    }
    
    if (!config.linkingTo.empty)
    {
        desc ~= formatDependencyList("LinkingTo", config.linkingTo);
    }
    
    std.file.write(outputPath, desc);
    Logger.info("Generated DESCRIPTION file at: " ~ outputPath);
}

/// Format dependency list for DESCRIPTION file
private string formatDependencyList(string sectionName, const RPackageDep[] deps, string rVersion = "")
{
    string result = "\n" ~ sectionName ~ ":\n";
    
    // Add R version if this is Depends section
    if (sectionName == "Depends" && !rVersion.empty)
    {
        result ~= "    R (>= " ~ rVersion ~ ")";
        if (!deps.empty)
            result ~= ",\n";
    }
    
    foreach (i, dep; deps)
    {
        result ~= "    " ~ dep.name;
        if (!dep.version_.empty)
            result ~= " (" ~ dep.version_ ~ ")";
        if (i < deps.length - 1)
            result ~= ",";
        result ~= "\n";
    }
    
    return result;
}

