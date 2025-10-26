module languages.scripting.python.formatter;

import std.process;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.python.config;
import languages.scripting.python.tools;
import utils.logging.logger;

/// Format result
struct FormatResult
{
    bool success;
    string[] formattedFiles;
    string[] issues;
    bool hadChanges;
}

/// Code formatter factory and utilities
class Formatter
{
    /// Format code with configured formatter
    static FormatResult format(string[] sources, PyFormatter formatter, string pythonCmd = "python3", bool check = false)
    {
        if (formatter == PyFormatter.None)
        {
            FormatResult result;
            result.success = true;
            return result;
        }
        
        final switch (formatter)
        {
            case PyFormatter.Auto:
                return formatAuto(sources, pythonCmd, check);
            case PyFormatter.Ruff:
                return formatRuff(sources, check);
            case PyFormatter.Black:
                return formatBlack(sources, pythonCmd, check);
            case PyFormatter.Blue:
                return formatBlue(sources, pythonCmd, check);
            case PyFormatter.Yapf:
                return formatYapf(sources, pythonCmd, check);
            case PyFormatter.Autopep8:
                return formatAutopep8(sources, pythonCmd, check);
            case PyFormatter.None:
                FormatResult result;
                result.success = true;
                return result;
        }
    }
    
    /// Auto-detect and use best available formatter
    private static FormatResult formatAuto(string[] sources, string pythonCmd, bool check)
    {
        // Priority: ruff (fastest) > black (most popular) > others
        
        if (PyTools.isRuffAvailable())
        {
            Logger.debug_("Using ruff for formatting");
            return formatRuff(sources, check);
        }
        
        if (PyTools.isBlackAvailable(pythonCmd))
        {
            Logger.debug_("Using black for formatting");
            return formatBlack(sources, pythonCmd, check);
        }
        
        // No formatter available
        FormatResult result;
        result.success = true;
        Logger.info("No formatter available (install ruff or black)");
        
        return result;
    }
    
    /// Format with ruff
    private static FormatResult formatRuff(string[] sources, bool check)
    {
        FormatResult result;
        
        if (!PyTools.isRuffAvailable())
        {
            result.success = true;
            result.issues ~= "ruff not available";
            return result;
        }
        
        auto toolResult = PyTools.formatRuff(sources, check);
        
        result.success = toolResult.success;
        result.issues = toolResult.warnings ~ toolResult.errors;
        result.hadChanges = !toolResult.warnings.empty || !check;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources;
            Logger.info("Code formatted with ruff");
        }
        else if (check && !result.hadChanges)
        {
            Logger.info("Code formatting check passed (ruff)");
        }
        
        return result;
    }
    
    /// Format with black
    private static FormatResult formatBlack(string[] sources, string pythonCmd, bool check)
    {
        FormatResult result;
        
        if (!PyTools.isBlackAvailable(pythonCmd))
        {
            result.success = true;
            result.issues ~= "black not available";
            return result;
        }
        
        auto toolResult = PyTools.formatBlack(sources, pythonCmd, check);
        
        result.success = toolResult.success;
        result.issues = toolResult.warnings ~ toolResult.errors;
        result.hadChanges = !toolResult.warnings.empty || !check;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources;
            Logger.info("Code formatted with black");
        }
        else if (check && !result.hadChanges)
        {
            Logger.info("Code formatting check passed (black)");
        }
        
        return result;
    }
    
    /// Format with blue
    private static FormatResult formatBlue(string[] sources, string pythonCmd, bool check)
    {
        FormatResult result;
        
        string[] cmd = [pythonCmd, "-m", "blue"];
        if (check)
            cmd ~= "--check";
        cmd ~= sources;
        
        Logger.info("Formatting with blue");
        
        auto res = execute(cmd);
        
        result.success = res.status == 0 || check;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources;
        }
        
        return result;
    }
    
    /// Format with yapf
    private static FormatResult formatYapf(string[] sources, string pythonCmd, bool check)
    {
        FormatResult result;
        
        string[] cmd = [pythonCmd, "-m", "yapf"];
        if (!check)
            cmd ~= "-i"; // in-place
        else
            cmd ~= "--diff";
        cmd ~= sources;
        
        Logger.info("Formatting with yapf");
        
        auto res = execute(cmd);
        
        result.success = res.status == 0 || check;
        result.hadChanges = !res.output.strip.empty;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources;
        }
        
        return result;
    }
    
    /// Format with autopep8
    private static FormatResult formatAutopep8(string[] sources, string pythonCmd, bool check)
    {
        FormatResult result;
        
        string[] cmd = [pythonCmd, "-m", "autopep8"];
        if (!check)
            cmd ~= "-i"; // in-place
        else
            cmd ~= "--diff";
        cmd ~= sources;
        
        Logger.info("Formatting with autopep8");
        
        auto res = execute(cmd);
        
        result.success = res.status == 0 || check;
        result.hadChanges = !res.output.strip.empty;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources;
        }
        
        return result;
    }
}

/// Linter factory and utilities
class Linter
{
    /// Lint code with configured linter
    static ToolResult lint(string[] sources, PyLinter linter, string pythonCmd = "python3")
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
                return PyTools.lintRuff(sources);
            case PyLinter.Pylint:
                return PyTools.lintPylint(sources, pythonCmd);
            case PyLinter.Flake8:
                return PyTools.lintFlake8(sources, pythonCmd);
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
    private static ToolResult lintAuto(string[] sources, string pythonCmd)
    {
        // Priority: ruff (fastest, most comprehensive) > pylint > flake8
        
        if (PyTools.isRuffAvailable())
        {
            Logger.debug_("Using ruff for linting");
            return PyTools.lintRuff(sources);
        }
        
        if (PyTools.isPylintAvailable(pythonCmd))
        {
            Logger.debug_("Using pylint for linting");
            return PyTools.lintPylint(sources, pythonCmd);
        }
        
        if (PyTools.isFlake8Available(pythonCmd))
        {
            Logger.debug_("Using flake8 for linting");
            return PyTools.lintFlake8(sources, pythonCmd);
        }
        
        // No linter available
        ToolResult result;
        result.success = true;
        Logger.info("No linter available (install ruff, pylint, or flake8)");
        
        return result;
    }
    
    /// Lint with bandit (security-focused)
    private static ToolResult lintBandit(string[] sources, string pythonCmd)
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
    private static ToolResult lintPyflakes(string[] sources, string pythonCmd)
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

