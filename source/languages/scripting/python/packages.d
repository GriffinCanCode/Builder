module languages.scripting.python.packages;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.python.config;
import languages.scripting.python.tools;
import utils.logging.logger;

/// Package installation result
struct InstallResult
{
    bool success;
    string error;
    string[] installedPackages;
    float timeSeconds;
}

/// Base interface for Python package managers
interface PackageManager
{
    /// Install dependencies from file
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false);
    
    /// Install specific packages
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false);
    
    /// Check if package manager is available
    bool isAvailable();
    
    /// Get package manager name
    string name() const;
    
    /// Get version
    string getVersion();
}

/// Factory for creating package managers
class PackageManagerFactory
{
    /// Create package manager based on type
    static PackageManager create(PyPackageManager type, string pythonCmd = "python3", string venvPath = "")
    {
        final switch (type)
        {
            case PyPackageManager.Auto:
                return createAuto(pythonCmd, venvPath);
            case PyPackageManager.Pip:
                return new PipManager(pythonCmd, venvPath);
            case PyPackageManager.Uv:
                return new UvManager(pythonCmd, venvPath);
            case PyPackageManager.Poetry:
                return new PoetryManager();
            case PyPackageManager.PDM:
                return new PDMManager();
            case PyPackageManager.Hatch:
                return new HatchManager();
            case PyPackageManager.Conda:
                return new CondaManager();
            case PyPackageManager.Pipenv:
                return new PipenvManager();
            case PyPackageManager.None:
                return new NullManager();
        }
    }
    
    /// Auto-detect best available package manager
    private static PackageManager createAuto(string pythonCmd, string venvPath)
    {
        // Priority: uv (fastest) > poetry > pip
        
        // Check for uv (ultra-fast, Rust-based)
        if (PyTools.isUvAvailable())
            return new UvManager(pythonCmd, venvPath);
        
        // Check for poetry (if pyproject.toml with poetry config exists)
        if (PyTools.isPoetryAvailable())
        {
            // Only use poetry if we detect it's actually being used
            // Otherwise fallback to pip
        }
        
        // Default to pip
        if (PyTools.isPipAvailable(pythonCmd))
            return new PipManager(pythonCmd, venvPath);
        
        // Fallback to null manager
        return new NullManager();
    }
    
    /// Detect package manager from project structure
    static PyPackageManager detectFromProject(string projectDir)
    {
        // Check for poetry
        string pyprojectPath = buildPath(projectDir, "pyproject.toml");
        if (exists(pyprojectPath))
        {
            try
            {
                auto content = readText(pyprojectPath);
                if (content.canFind("[tool.poetry]"))
                    return PyPackageManager.Poetry;
                if (content.canFind("[tool.pdm]"))
                    return PyPackageManager.PDM;
                if (content.canFind("[tool.hatch]"))
                    return PyPackageManager.Hatch;
            }
            catch (Exception) {}
        }
        
        // Check for Pipfile
        if (exists(buildPath(projectDir, "Pipfile")))
            return PyPackageManager.Pipenv;
        
        // Check for conda
        if (exists(buildPath(projectDir, "environment.yml")) || 
            exists(buildPath(projectDir, "environment.yaml")))
            return PyPackageManager.Conda;
        
        // Check for uv
        if (PyTools.isUvAvailable())
            return PyPackageManager.Uv;
        
        // Default to pip
        return PyPackageManager.Pip;
    }
}

/// Pip package manager
class PipManager : PackageManager
{
    private string pythonCmd;
    private string venvPath;
    
    this(string pythonCmd = "python3", string venvPath = "")
    {
        this.pythonCmd = pythonCmd;
        this.venvPath = venvPath;
    }
    
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        if (!exists(file))
        {
            result.error = "Requirements file not found: " ~ file;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "pip", "install", "-r", file];
        if (upgrade)
            cmd ~= "--upgrade";
        
        Logger.info("Installing dependencies from " ~ file ~ " using pip");
        
        StopWatch sw;
        sw.start();
        
        auto env = venvPath.empty ? null : getVenvEnv();
        auto res = execute(cmd, env);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "pip install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Dependencies installed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        string[] cmd = [pythonCmd, "-m", "pip", "install"];
        if (upgrade)
            cmd ~= "--upgrade";
        if (editable)
            cmd ~= "-e";
        cmd ~= packages;
        
        Logger.info("Installing packages: " ~ packages.join(", "));
        
        StopWatch sw;
        sw.start();
        
        auto env = venvPath.empty ? null : getVenvEnv();
        auto res = execute(cmd, env);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "pip install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.installedPackages = packages;
        Logger.info("Packages installed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isPipAvailable(pythonCmd);
    }
    
    string name() const
    {
        return "pip";
    }
    
    string getVersion()
    {
        auto cmd = [pythonCmd, "-m", "pip", "--version"];
        auto res = execute(cmd);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    private string[string] getVenvEnv()
    {
        import languages.scripting.python.environments : VirtualEnv;
        return VirtualEnv.getVenvEnv(venvPath);
    }
}

/// UV package manager (ultra-fast, Rust-based)
class UvManager : PackageManager
{
    private string pythonCmd;
    private string venvPath;
    
    this(string pythonCmd = "python3", string venvPath = "")
    {
        this.pythonCmd = pythonCmd;
        this.venvPath = venvPath;
    }
    
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        if (!exists(file))
        {
            result.error = "Requirements file not found: " ~ file;
            return result;
        }
        
        string[] cmd = ["uv", "pip", "install", "-r", file];
        if (upgrade)
            cmd ~= "--upgrade";
        
        Logger.info("Installing dependencies from " ~ file ~ " using uv (fast!)");
        
        StopWatch sw;
        sw.start();
        
        auto env = venvPath.empty ? null : getVenvEnv();
        auto res = execute(cmd, env);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "uv install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Dependencies installed in %.2fs (uv is ~10-100x faster!)".format(result.timeSeconds));
        
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        string[] cmd = ["uv", "pip", "install"];
        if (upgrade)
            cmd ~= "--upgrade";
        if (editable)
            cmd ~= "-e";
        cmd ~= packages;
        
        Logger.info("Installing packages with uv: " ~ packages.join(", "));
        
        StopWatch sw;
        sw.start();
        
        auto env = venvPath.empty ? null : getVenvEnv();
        auto res = execute(cmd, env);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "uv install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.installedPackages = packages;
        Logger.info("Packages installed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isUvAvailable();
    }
    
    string name() const
    {
        return "uv";
    }
    
    string getVersion()
    {
        auto res = execute(["uv", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    private string[string] getVenvEnv()
    {
        import languages.scripting.python.environments : VirtualEnv;
        return VirtualEnv.getVenvEnv(venvPath);
    }
}

/// Poetry package manager
class PoetryManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.error = "Poetry uses pyproject.toml, use installPackages instead";
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        if (packages.empty)
        {
            // Install from pyproject.toml
            Logger.info("Installing dependencies with poetry");
            
            StopWatch sw;
            sw.start();
            
            auto res = execute(["poetry", "install"]);
            
            sw.stop();
            result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
            
            if (res.status != 0)
            {
                result.error = "poetry install failed: " ~ res.output;
                return result;
            }
            
            result.success = true;
        }
        else
        {
            // Add and install specific packages
            Logger.info("Installing packages with poetry: " ~ packages.join(", "));
            
            StopWatch sw;
            sw.start();
            
            foreach (pkg; packages)
            {
                auto cmd = ["poetry", "add", pkg];
                auto res = execute(cmd);
                
                if (res.status != 0)
                {
                    result.error = "poetry add failed for " ~ pkg ~ ": " ~ res.output;
                    return result;
                }
                
                result.installedPackages ~= pkg;
            }
            
            sw.stop();
            result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
            result.success = true;
        }
        
        Logger.info("Poetry installation completed in %.2fs".format(result.timeSeconds));
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isPoetryAvailable();
    }
    
    string name() const
    {
        return "poetry";
    }
    
    string getVersion()
    {
        auto res = execute(["poetry", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

/// PDM package manager
class PDMManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.error = "PDM uses pyproject.toml, use installPackages instead";
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        Logger.info("Installing with PDM");
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["pdm", "install"]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "pdm install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("PDM installation completed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isPDMAvailable();
    }
    
    string name() const
    {
        return "pdm";
    }
    
    string getVersion()
    {
        auto res = execute(["pdm", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

/// Hatch package manager
class HatchManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.error = "Hatch uses pyproject.toml, use installPackages instead";
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        Logger.info("Installing with Hatch");
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["hatch", "env", "create"]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "hatch env create failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Hatch environment created in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isHatchAvailable();
    }
    
    string name() const
    {
        return "hatch";
    }
    
    string getVersion()
    {
        auto res = execute(["hatch", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

/// Conda package manager
class CondaManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        if (!exists(file))
        {
            result.error = "Environment file not found: " ~ file;
            return result;
        }
        
        Logger.info("Installing conda environment from " ~ file);
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["conda", "env", "create", "-f", file]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "conda env create failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Conda environment created in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        string[] cmd = ["conda", "install", "-y"] ~ packages;
        
        Logger.info("Installing packages with conda: " ~ packages.join(", "));
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(cmd);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "conda install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.installedPackages = packages;
        Logger.info("Packages installed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isCondaAvailable();
    }
    
    string name() const
    {
        return "conda";
    }
    
    string getVersion()
    {
        auto res = execute(["conda", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

/// Pipenv package manager
class PipenvManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.error = "Pipenv uses Pipfile, use installPackages instead";
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        Logger.info("Installing with pipenv");
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["pipenv", "install"]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "pipenv install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Pipenv installation completed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isPipenvAvailable();
    }
    
    string name() const
    {
        return "pipenv";
    }
    
    string getVersion()
    {
        auto res = execute(["pipenv", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

/// Null package manager - no installation
class NullManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.success = true;
        Logger.warning("No package manager available, skipping installation");
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.success = true;
        Logger.warning("No package manager available, skipping installation");
        return result;
    }
    
    bool isAvailable()
    {
        return true;
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        return "n/a";
    }
}

