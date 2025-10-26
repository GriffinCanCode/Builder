module languages.scripting.python.tools;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import std.conv;
import utils.logging.logger;

/// Result of running a Python tool
struct ToolResult
{
    bool success;
    string output;
    string[] warnings;
    string[] errors;
    
    /// Check if tool found issues
    bool hasIssues() const pure nothrow
    {
        return !warnings.empty || !errors.empty;
    }
}

/// Python interpreter information
struct PythonInfo
{
    string path;
    string version_;
    int majorVersion;
    int minorVersion;
    int patchVersion;
    bool isVirtualEnv;
    string sitePackages;
}

/// Python tooling wrapper - integrates formatters, linters, type checkers
class PyTools
{
    /// Check if python3 is available
    static bool isPythonAvailable()
    {
        return isPython3Available() || isPythonCommandAvailable("python");
    }
    
    /// Check if python3 command is available
    static bool isPython3Available()
    {
        return isPythonCommandAvailable("python3");
    }
    
    /// Check if specific python command is available
    static bool isPythonCommandAvailable(string command)
    {
        auto res = execute([command, "--version"]);
        return res.status == 0;
    }
    
    /// Get Python version
    static string getPythonVersion(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
    
    /// Get detailed Python information
    static PythonInfo getPythonInfo(string pythonCmd = "python3")
    {
        PythonInfo info;
        info.path = getPythonPath(pythonCmd);
        
        // Get version
        auto versionOutput = getPythonVersion(pythonCmd);
        auto versionMatch = matchFirst(versionOutput, regex(`Python (\d+)\.(\d+)\.(\d+)`));
        if (versionMatch)
        {
            info.version_ = versionMatch[1] ~ "." ~ versionMatch[2] ~ "." ~ versionMatch[3];
            info.majorVersion = versionMatch[1].to!int;
            info.minorVersion = versionMatch[2].to!int;
            info.patchVersion = versionMatch[3].to!int;
        }
        
        // Check if in virtual environment
        info.isVirtualEnv = isInVirtualEnv(pythonCmd);
        
        // Get site packages
        auto siteCmd = [pythonCmd, "-c", "import site; print(site.getsitepackages()[0])"];
        auto siteRes = execute(siteCmd);
        if (siteRes.status == 0)
            info.sitePackages = siteRes.output.strip;
        
        return info;
    }
    
    /// Get Python interpreter path
    static string getPythonPath(string pythonCmd = "python3")
    {
        version(Windows)
        {
            auto res = execute(["where", pythonCmd]);
        }
        else
        {
            auto res = execute(["which", pythonCmd]);
        }
        
        if (res.status == 0)
            return res.output.strip.split("\n")[0].strip;
        return "";
    }
    
    /// Check if running in a virtual environment
    static bool isInVirtualEnv(string pythonCmd = "python3")
    {
        auto cmd = [pythonCmd, "-c", "import sys; print(hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix))"];
        auto res = execute(cmd);
        if (res.status == 0)
            return res.output.strip == "True";
        return false;
    }
    
    /// Check if pip is available
    static bool isPipAvailable(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "pip", "--version"]);
        return res.status == 0;
    }
    
    /// Check if uv is available (fastest Python package installer)
    static bool isUvAvailable()
    {
        return isCommandAvailable("uv");
    }
    
    /// Check if poetry is available
    static bool isPoetryAvailable()
    {
        return isCommandAvailable("poetry");
    }
    
    /// Check if PDM is available
    static bool isPDMAvailable()
    {
        return isCommandAvailable("pdm");
    }
    
    /// Check if hatch is available
    static bool isHatchAvailable()
    {
        return isCommandAvailable("hatch");
    }
    
    /// Check if conda is available
    static bool isCondaAvailable()
    {
        return isCommandAvailable("conda");
    }
    
    /// Check if pipenv is available
    static bool isPipenvAvailable()
    {
        return isCommandAvailable("pipenv");
    }
    
    /// Check if mypy is available
    static bool isMypyAvailable(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "mypy", "--version"]);
        return res.status == 0;
    }
    
    /// Check if pyright is available
    static bool isPyrightAvailable()
    {
        return isCommandAvailable("pyright");
    }
    
    /// Check if pytype is available
    static bool isPytypeAvailable(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "pytype", "--version"]);
        return res.status == 0;
    }
    
    /// Check if ruff is available (fast linter/formatter)
    static bool isRuffAvailable()
    {
        return isCommandAvailable("ruff");
    }
    
    /// Check if black is available
    static bool isBlackAvailable(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "black", "--version"]);
        return res.status == 0;
    }
    
    /// Check if pylint is available
    static bool isPylintAvailable(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "pylint", "--version"]);
        return res.status == 0;
    }
    
    /// Check if flake8 is available
    static bool isFlake8Available(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "flake8", "--version"]);
        return res.status == 0;
    }
    
    /// Check if pytest is available
    static bool isPytestAvailable(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "-m", "pytest", "--version"]);
        return res.status == 0;
    }
    
    /// Format Python code with ruff
    static ToolResult formatRuff(string[] sources, bool check = false)
    {
        ToolResult result;
        result.success = true;
        
        if (!isRuffAvailable())
        {
            result.warnings ~= "ruff not available (install: pip install ruff)";
            return result;
        }
        
        string[] cmd = ["ruff", "format"];
        if (check)
            cmd ~= "--check";
        cmd ~= sources;
        
        Logger.debug_("Running ruff format: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            if (check)
            {
                // Check mode - files need formatting
                foreach (line; res.output.lineSplitter)
                {
                    auto trimmed = line.strip;
                    if (!trimmed.empty)
                        result.warnings ~= trimmed;
                }
                result.success = true; // Don't fail on format checks
            }
            else
            {
                result.success = false;
                result.errors ~= "ruff format failed: " ~ res.output;
            }
        }
        
        return result;
    }
    
    /// Format Python code with black
    static ToolResult formatBlack(string[] sources, string pythonCmd = "python3", bool check = false)
    {
        ToolResult result;
        result.success = true;
        
        if (!isBlackAvailable(pythonCmd))
        {
            result.warnings ~= "black not available (install: pip install black)";
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "black"];
        if (check)
            cmd ~= "--check";
        cmd ~= sources;
        
        Logger.debug_("Running black: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            if (check)
            {
                foreach (line; res.output.lineSplitter)
                {
                    auto trimmed = line.strip;
                    if (!trimmed.empty && trimmed.canFind("would be reformatted"))
                        result.warnings ~= trimmed;
                }
                result.success = true;
            }
            else
            {
                result.success = false;
                result.errors ~= "black failed: " ~ res.output;
            }
        }
        
        return result;
    }
    
    /// Lint Python code with ruff
    static ToolResult lintRuff(string[] sources)
    {
        ToolResult result;
        
        if (!isRuffAvailable())
        {
            result.warnings ~= "ruff not available (install: pip install ruff)";
            result.success = true;
            return result;
        }
        
        string[] cmd = ["ruff", "check"] ~ sources;
        
        Logger.debug_("Running ruff check: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        // ruff returns non-zero if issues found
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                    result.warnings ~= trimmed;
            }
        }
        
        result.success = true; // Don't fail build on lint warnings
        
        return result;
    }
    
    /// Lint Python code with pylint
    static ToolResult lintPylint(string[] sources, string pythonCmd = "python3")
    {
        ToolResult result;
        
        if (!isPylintAvailable(pythonCmd))
        {
            result.warnings ~= "pylint not available (install: pip install pylint)";
            result.success = true;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "pylint"] ~ sources;
        
        Logger.debug_("Running pylint: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty && !trimmed.startsWith("---") && !trimmed.startsWith("Your code"))
                    result.warnings ~= trimmed;
            }
        }
        
        result.success = true;
        
        return result;
    }
    
    /// Lint Python code with flake8
    static ToolResult lintFlake8(string[] sources, string pythonCmd = "python3")
    {
        ToolResult result;
        
        if (!isFlake8Available(pythonCmd))
        {
            result.warnings ~= "flake8 not available (install: pip install flake8)";
            result.success = true;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "flake8"] ~ sources;
        
        Logger.debug_("Running flake8: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                    result.warnings ~= trimmed;
            }
        }
        
        result.success = true;
        
        return result;
    }
    
    /// Type check Python code with mypy
    static ToolResult typeCheckMypy(string[] sources, string pythonCmd = "python3", string[] extraArgs = [])
    {
        ToolResult result;
        
        if (!isMypyAvailable(pythonCmd))
        {
            result.warnings ~= "mypy not available (install: pip install mypy)";
            result.success = true;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "mypy"] ~ extraArgs ~ sources;
        
        Logger.debug_("Running mypy: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                {
                    if (trimmed.canFind("error:"))
                        result.errors ~= trimmed;
                    else if (trimmed.canFind("warning:") || trimmed.canFind("note:"))
                        result.warnings ~= trimmed;
                }
            }
            result.success = result.errors.empty; // Fail only on errors, not warnings
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Type check Python code with pyright
    static ToolResult typeCheckPyright(string[] sources, string[] extraArgs = [])
    {
        ToolResult result;
        
        if (!isPyrightAvailable())
        {
            result.warnings ~= "pyright not available (install: npm install -g pyright)";
            result.success = true;
            return result;
        }
        
        string[] cmd = ["pyright"] ~ extraArgs ~ sources;
        
        Logger.debug_("Running pyright: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty)
                {
                    if (trimmed.canFind("error") && !trimmed.canFind("0 errors"))
                        result.errors ~= trimmed;
                    else if (trimmed.canFind("warning"))
                        result.warnings ~= trimmed;
                }
            }
            result.success = result.errors.empty;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Install package using pip
    static ToolResult pipInstall(string[] packages, string pythonCmd = "python3", bool upgrade = false, bool editable = false)
    {
        ToolResult result;
        
        if (!isPipAvailable(pythonCmd))
        {
            result.errors ~= "pip not available";
            result.success = false;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "pip", "install"];
        if (upgrade)
            cmd ~= "--upgrade";
        if (editable)
            cmd ~= "-e";
        cmd ~= packages;
        
        Logger.info("Installing packages: " ~ packages.join(", "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            result.success = false;
            result.errors ~= "pip install failed: " ~ res.output;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Install package using uv (ultra-fast)
    static ToolResult uvInstall(string[] packages, bool upgrade = false)
    {
        ToolResult result;
        
        if (!isUvAvailable())
        {
            result.errors ~= "uv not available (install: pip install uv)";
            result.success = false;
            return result;
        }
        
        string[] cmd = ["uv", "pip", "install"];
        if (upgrade)
            cmd ~= "--upgrade";
        cmd ~= packages;
        
        Logger.info("Installing packages with uv: " ~ packages.join(", "));
        
        auto res = execute(cmd);
        result.output = res.output;
        
        if (res.status != 0)
        {
            result.success = false;
            result.errors ~= "uv install failed: " ~ res.output;
        }
        else
        {
            result.success = true;
        }
        
        return result;
    }
    
    /// Check if a command is available in PATH
    private static bool isCommandAvailable(string command)
    {
        version(Windows)
        {
            auto res = execute(["where", command]);
        }
        else
        {
            auto res = execute(["which", command]);
        }
        
        return res.status == 0;
    }
}

