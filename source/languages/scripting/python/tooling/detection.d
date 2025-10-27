module languages.scripting.python.tooling.detection;

import std.process : Config;
import utils.security : execute;  // SECURITY: Auto-migrated
import std.string;
import std.array;
import utils.process : isCommandAvailable;

/// Tool detection utilities
class ToolDetection
{
    /// Get Python version string
    static string getPythonVersion(string pythonCmd = "python3")
    {
        auto res = execute([pythonCmd, "--version"]);
        if (res.status == 0)
        {
            return res.output.strip;
        }
        return "Unknown";
    }
    
    
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
}

