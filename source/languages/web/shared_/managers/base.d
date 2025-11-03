module languages.web.shared_.managers.base;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.json;
import infrastructure.utils.process : isCommandAvailable;

/// Base interface for Node.js package managers
interface PackageManager
{
    /// Get package manager name
    string name() const;
    
    /// Check if package manager is available
    bool isAvailable();
    
    /// Get version string
    string getVersion();
    
    /// Install dependencies in a directory
    InstallResult install(string projectDir, InstallOptions options = InstallOptions.init);
    
    /// Add a package
    InstallResult add(string projectDir, string packageName, AddOptions options = AddOptions.init);
    
    /// Remove a package
    InstallResult remove(string projectDir, string packageName);
    
    /// Run a script from package.json
    ExecuteResult runScript(string projectDir, string scriptName);
    
    /// Get lockfile name
    string lockfileName() const;
    
    /// Check if lockfile exists
    bool hasLockfile(string projectDir);
}

/// Installation options
struct InstallOptions
{
    /// Install dev dependencies
    bool dev = true;
    
    /// Install only production dependencies
    bool production = false;
    
    /// Frozen lockfile (CI mode)
    bool frozen = false;
    
    /// Silent output
    bool silent = false;
}

/// Add package options
struct AddOptions
{
    /// Add as dev dependency
    bool dev = false;
    
    /// Add as peer dependency
    bool peer = false;
    
    /// Add as optional dependency
    bool optional = false;
    
    /// Exact version
    bool exact = false;
}

/// Installation result
struct InstallResult
{
    bool success;
    string error;
    string output;
    int exitCode;
}

/// Script execution result
struct ExecuteResult
{
    bool success;
    string output;
    int exitCode;
}

/// Find package.json in directory tree
string findPackageJson(string startDir)
{
    if (!exists(startDir) || !isDir(startDir))
        return "";
    
    string dir = buildNormalizedPath(absolutePath(startDir));
    
    while (dir != "/" && dir.length > 1)
    {
        string packagePath = buildPath(dir, "package.json");
        if (exists(packagePath) && isFile(packagePath))
            return packagePath;
        
        string parent = dirName(dir);
        if (parent == dir)
            break;
        
        dir = parent;
    }
    
    return "";
}

/// Find package.json from source files
string findPackageJsonFromSources(string[] sources)
{
    if (sources.empty)
        return "";
    
    return findPackageJson(dirName(sources[0]));
}

/// Parse package.json
PackageJsonInfo parsePackageJson(string packageJsonPath)
{
    PackageJsonInfo info;
    
    if (!exists(packageJsonPath))
        return info;
    
    try
    {
        auto content = readText(packageJsonPath);
        auto json = parseJSON(content);
        
        if ("name" in json)
            info.name = json["name"].str;
        
        if ("version" in json)
            info.version_ = json["version"].str;
        
        if ("type" in json)
            info.type = json["type"].str;
        
        if ("main" in json)
            info.main = json["main"].str;
        
        if ("module" in json)
            info.module_ = json["module"].str;
        
        if ("browser" in json)
            info.browser = json["browser"].str;
        
        if ("scripts" in json && json["scripts"].type == JSONType.object)
        {
            foreach (string key, value; json["scripts"].object)
            {
                info.scripts[key] = value.str;
            }
        }
        
        if ("dependencies" in json && json["dependencies"].type == JSONType.object)
        {
            foreach (string key, value; json["dependencies"].object)
            {
                info.dependencies[key] = value.str;
            }
        }
        
        if ("devDependencies" in json && json["devDependencies"].type == JSONType.object)
        {
            foreach (string key, value; json["devDependencies"].object)
            {
                info.devDependencies[key] = value.str;
            }
        }
        
        if ("peerDependencies" in json && json["peerDependencies"].type == JSONType.object)
        {
            foreach (string key, value; json["peerDependencies"].object)
            {
                info.peerDependencies[key] = value.str;
            }
        }
        
        info.exists = true;
        info.directory = dirName(packageJsonPath);
    }
    catch (Exception e)
    {
        // Failed to parse
    }
    
    return info;
}

/// Package.json information
struct PackageJsonInfo
{
    bool exists;
    string directory;
    string name;
    string version_;
    string type; // "module" or "commonjs"
    string main;
    string module_;
    string browser;
    string[string] scripts;
    string[string] dependencies;
    string[string] devDependencies;
    string[string] peerDependencies;
    
    /// Check if a script exists
    bool hasScript(string scriptName) const
    {
        return (scriptName in scripts) !is null;
    }
    
    /// Check if a dependency exists
    bool hasDependency(string packageName) const
    {
        return (packageName in dependencies) !is null ||
               (packageName in devDependencies) !is null ||
               (packageName in peerDependencies) !is null;
    }
    
    /// Is ES module
    bool isESM() const
    {
        return type == "module";
    }
}

