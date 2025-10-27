module languages.web.shared_.utils;

import std.process;
import std.file;
import std.path;
import std.json;
import std.string;
import utils.logging.logger;
import utils.process : isCommandAvailable;

/// Find package.json in source tree
string findPackageJson(const(string[]) sources)
{
    if (sources.empty)
        return "";
    
    string dir = dirName(sources[0]);
    
    while (dir != "/" && dir.length > 1)
    {
        string packagePath = buildPath(dir, "package.json");
        if (exists(packagePath))
            return packagePath;
        
        dir = dirName(dir);
    }
    
    return "";
}

/// Detect test command from package.json
string[] detectTestCommand(string packageJsonPath)
{
    try
    {
        auto content = readText(packageJsonPath);
        auto json = parseJSON(content);
        
        if ("scripts" in json && "test" in json["scripts"].object)
        {
            string testScript = json["scripts"]["test"].str;
            if (testScript != "echo \"Error: no test specified\" && exit 1")
            {
                return ["npm", "test"];
            }
        }
    }
    catch (Exception e)
    {
        Logger.warning("Failed to parse package.json: " ~ e.msg);
    }
    
    return [];
}

/// Install npm dependencies  
void installDependencies(const(string[]) sources, string packageManager)
{
    string packageJsonPath = findPackageJson(sources);
    if (packageJsonPath.empty || !exists(packageJsonPath))
    {
        Logger.warning("No package.json found, skipping dependency installation");
        return;
    }
    
    string packageDir = dirName(packageJsonPath);
    Logger.info("Installing dependencies with " ~ packageManager ~ "...");
    
    string[] cmd = [packageManager, "install"];
    auto res = execute(cmd, null, std.process.Config.none, size_t.max, packageDir);
    
    if (res.status != 0)
    {
        Logger.warning("Failed to install dependencies: " ~ res.output);
    }
    else
    {
        Logger.info("Dependencies installed successfully");
    }
}

