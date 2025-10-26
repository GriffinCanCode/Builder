module languages.compiled.nim.managers.nimble;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.compiled.nim.analysis.nimble;
import utils.logging.logger;

/// Nimble package manager operations
class NimbleManager
{
    /// Install package dependencies
    static bool installDependencies(
        string projectDir,
        bool devMode = false,
        bool verbose = false
    )
    {
        string nimbleFile = NimbleParser.findNimbleFile(projectDir);
        
        if (nimbleFile.empty)
        {
            Logger.warning("No nimble file found, skipping dependency installation");
            return true;
        }
        
        Logger.info("Installing nimble dependencies...");
        
        string[] cmd = ["nimble", "install", "-y"];
        
        if (devMode)
            cmd ~= "--depsOnly";
        
        if (verbose)
            cmd ~= "--verbose";
        
        string workDir = dirName(nimbleFile);
        
        auto res = execute(cmd, null, std.process.Config.none, size_t.max, workDir);
        
        if (res.status != 0)
        {
            Logger.error("Dependency installation failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Dependencies installed successfully");
        return true;
    }
    
    /// Update package dependencies
    static bool updateDependencies(string projectDir, bool verbose = false)
    {
        Logger.info("Updating nimble dependencies...");
        
        string[] cmd = ["nimble", "update"];
        
        if (verbose)
            cmd ~= "--verbose";
        
        auto res = execute(cmd, null, std.process.Config.none, size_t.max, projectDir);
        
        if (res.status != 0)
        {
            Logger.error("Dependency update failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Dependencies updated successfully");
        return true;
    }
    
    /// Install a specific package
    static bool installPackage(
        string packageName,
        string versionConstraint = "",
        bool verbose = false
    )
    {
        Logger.info("Installing package: " ~ packageName);
        
        string[] cmd = ["nimble", "install", "-y"];
        
        if (!versionConstraint.empty)
            cmd ~= packageName ~ "@" ~ versionConstraint;
        else
            cmd ~= packageName;
        
        if (verbose)
            cmd ~= "--verbose";
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Package installation failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Package installed successfully");
        return true;
    }
    
    /// List installed packages
    static string[] listPackages()
    {
        string[] packages;
        
        auto res = execute(["nimble", "list", "-i"]);
        
        if (res.status == 0)
        {
            // Parse output
            foreach (line; res.output.split("\n"))
            {
                line = line.strip();
                if (!line.empty && !line.startsWith("#"))
                {
                    // Extract package name (format: "package [version]")
                    auto parts = line.split(" ");
                    if (!parts.empty)
                        packages ~= parts[0];
                }
            }
        }
        
        return packages;
    }
    
    /// Search for packages
    static PackageInfo[] search(string query)
    {
        PackageInfo[] results;
        
        auto res = execute(["nimble", "search", query]);
        
        if (res.status == 0)
        {
            // Parse search results
            // Format varies, just collect package names for now
            foreach (line; res.output.split("\n"))
            {
                line = line.strip();
                if (!line.empty && !line.startsWith("#"))
                {
                    PackageInfo pkg;
                    auto parts = line.split("-");
                    if (!parts.empty)
                    {
                        pkg.name = parts[0].strip();
                        if (parts.length > 1)
                            pkg.description = parts[1 .. $].join("-").strip();
                        results ~= pkg;
                    }
                }
            }
        }
        
        return results;
    }
    
    /// Uninstall a package
    static bool uninstallPackage(string packageName)
    {
        Logger.info("Uninstalling package: " ~ packageName);
        
        auto res = execute(["nimble", "uninstall", "-y", packageName]);
        
        if (res.status != 0)
        {
            Logger.error("Package uninstallation failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Package uninstalled successfully");
        return true;
    }
    
    /// Initialize a new nimble package
    static bool initPackage(string dir, string packageName, bool isLibrary = false)
    {
        Logger.info("Initializing nimble package: " ~ packageName);
        
        string[] cmd = ["nimble", "init"];
        
        if (isLibrary)
            cmd ~= "-l";
        
        cmd ~= packageName;
        
        auto res = execute(cmd, null, std.process.Config.none, size_t.max, dir);
        
        if (res.status != 0)
        {
            Logger.error("Package initialization failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Package initialized successfully");
        return true;
    }
}

/// Package information from search
struct PackageInfo
{
    string name;
    string description;
    string version_;
    string url;
}

