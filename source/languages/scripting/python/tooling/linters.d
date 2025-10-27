module languages.scripting.python.tooling.linters;

import std.process;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.python.core.config;
import languages.scripting.python.tooling.results;
import languages.scripting.python.tooling.detection;
import utils.logging.logger;

/// Code linting utilities
class PyLinters
{
    /// Lint Python code with ruff
    static ToolResult lintRuff(const string[] sources)
    {
        ToolResult result;
        
        if (!ToolDetection.isRuffAvailable())
        {
            result.warnings ~= "ruff not available (install: pip install ruff)";
            result.success = true;
            return result;
        }
        
        string[] cmd = ["ruff", "check"] ~ sources;
        
        Logger.debugLog("Running ruff check: " ~ cmd.join(" "));
        
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
    static ToolResult lintPylint(const string[] sources, string pythonCmd = "python3")
    {
        ToolResult result;
        
        if (!ToolDetection.isPylintAvailable(pythonCmd))
        {
            result.warnings ~= "pylint not available (install: pip install pylint)";
            result.success = true;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "pylint"] ~ sources;
        
        Logger.debugLog("Running pylint: " ~ cmd.join(" "));
        
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
    static ToolResult lintFlake8(const string[] sources, string pythonCmd = "python3")
    {
        ToolResult result;
        
        if (!ToolDetection.isFlake8Available(pythonCmd))
        {
            result.warnings ~= "flake8 not available (install: pip install flake8)";
            result.success = true;
            return result;
        }
        
        string[] cmd = [pythonCmd, "-m", "flake8"] ~ sources;
        
        Logger.debugLog("Running flake8: " ~ cmd.join(" "));
        
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
}

/// Linter factory and utilities
class Linter
{
    /// Lint code with configured linter
    static ToolResult lint(const string[] sources, PyLinter linter, string pythonCmd = "python3")
    {
        if (linter == PyLinter.None)
        {
            ToolResult result;
            result.success = true;
            return result;
        }
        
        final switch (linter)
        {
            case PyLinter.Auto:
                return lintAuto(sources, pythonCmd);
            case PyLinter.Ruff:
                return PyLinters.lintRuff(sources);
            case PyLinter.Pylint:
                return PyLinters.lintPylint(sources, pythonCmd);
            case PyLinter.Flake8:
                return PyLinters.lintFlake8(sources, pythonCmd);
            case PyLinter.Bandit:
                return lintBandit(sources, pythonCmd);
            case PyLinter.Pyflakes:
                return lintPyflakes(sources, pythonCmd);
            case PyLinter.None:
                ToolResult result;
                result.success = true;
                return result;
        }
    }
    
    /// Auto-detect and use best available linter
    private static ToolResult lintAuto(const string[] sources, string pythonCmd)
    {
        // Priority: ruff (fastest, most comprehensive) > pylint > flake8
        
        if (ToolDetection.isRuffAvailable())
        {
            Logger.debugLog("Using ruff for linting");
            return PyLinters.lintRuff(sources);
        }
        
        if (ToolDetection.isPylintAvailable(pythonCmd))
        {
            Logger.debugLog("Using pylint for linting");
            return PyLinters.lintPylint(sources, pythonCmd);
        }
        
        if (ToolDetection.isFlake8Available(pythonCmd))
        {
            Logger.debugLog("Using flake8 for linting");
            return PyLinters.lintFlake8(sources, pythonCmd);
        }
        
        // No linter available
        ToolResult result;
        result.success = true;
        Logger.info("No linter available (install ruff, pylint, or flake8)");
        
        return result;
    }
    
    /// Lint with bandit (security-focused)
    private static ToolResult lintBandit(const string[] sources, string pythonCmd)
    {
        ToolResult result;
        
        string[] cmd = [pythonCmd, "-m", "bandit", "-r"] ~ sources;
        
        Logger.info("Running bandit security checks");
        
        auto res = execute(cmd);
        result.output = res.output;
        
        // Bandit returns non-zero if issues found
        if (res.status != 0)
        {
            foreach (line; res.output.lineSplitter)
            {
                auto trimmed = line.strip;
                if (!trimmed.empty && (trimmed.canFind("Issue:") || trimmed.canFind("Severity:")))
                    result.warnings ~= trimmed;
            }
        }
        
        result.success = true; // Don't fail build on security warnings
        
        return result;
    }
    
    /// Lint with pyflakes
    private static ToolResult lintPyflakes(const string[] sources, string pythonCmd)
    {
        ToolResult result;
        
        string[] cmd = [pythonCmd, "-m", "pyflakes"] ~ sources;
        
        Logger.info("Running pyflakes");
        
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
}

