module languages.scripting.python.tooling.formatters;

import std.process;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.python.core.config;
import languages.scripting.python.tooling.results;
import languages.scripting.python.tooling.detection;
import utils.logging.logger;

/// Code formatter utilities
class PyFormatters
{
    /// Format Python code with ruff
    static ToolResult formatRuff(const string[] sources, bool check = false)
    {
        ToolResult result;
        result.success = true;
        
        if (!ToolDetection.isRuffAvailable())
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
    static ToolResult formatBlack(const string[] sources, string pythonCmd = "python3", bool check = false)
    {
        ToolResult result;
        result.success = true;
        
        if (!ToolDetection.isBlackAvailable(pythonCmd))
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
}

/// Code formatter factory and utilities
class Formatter
{
    /// Format code with configured formatter
    static FormatResult format(const string[] sources, PyFormatter formatter, string pythonCmd = "python3", bool check = false)
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
    private static FormatResult formatAuto(const string[] sources, string pythonCmd, bool check)
    {
        // Priority: ruff (fastest) > black (most popular) > others
        
        if (ToolDetection.isRuffAvailable())
        {
            Logger.debug_("Using ruff for formatting");
            return formatRuff(sources, check);
        }
        
        if (ToolDetection.isBlackAvailable(pythonCmd))
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
    private static FormatResult formatRuff(const string[] sources, bool check)
    {
        FormatResult result;
        
        if (!ToolDetection.isRuffAvailable())
        {
            result.success = true;
            result.issues ~= "ruff not available";
            return result;
        }
        
        auto toolResult = PyFormatters.formatRuff(sources, check);
        
        result.success = toolResult.success;
        result.issues = toolResult.warnings ~ toolResult.errors;
        result.hadChanges = !toolResult.warnings.empty || !check;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources.dup;
            Logger.info("Code formatted with ruff");
        }
        else if (check && !result.hadChanges)
        {
            Logger.info("Code formatting check passed (ruff)");
        }
        
        return result;
    }
    
    /// Format with black
    private static FormatResult formatBlack(const string[] sources, string pythonCmd, bool check)
    {
        FormatResult result;
        
        if (!ToolDetection.isBlackAvailable(pythonCmd))
        {
            result.success = true;
            result.issues ~= "black not available";
            return result;
        }
        
        auto toolResult = PyFormatters.formatBlack(sources, pythonCmd, check);
        
        result.success = toolResult.success;
        result.issues = toolResult.warnings ~ toolResult.errors;
        result.hadChanges = !toolResult.warnings.empty || !check;
        
        if (!check && result.success)
        {
            result.formattedFiles = sources.dup;
            Logger.info("Code formatted with black");
        }
        else if (check && !result.hadChanges)
        {
            Logger.info("Code formatting check passed (black)");
        }
        
        return result;
    }
    
    /// Format with blue
    private static FormatResult formatBlue(const string[] sources, string pythonCmd, bool check)
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
            result.formattedFiles = sources.dup;
        }
        
        return result;
    }
    
    /// Format with yapf
    private static FormatResult formatYapf(const string[] sources, string pythonCmd, bool check)
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
            result.formattedFiles = sources.dup;
        }
        
        return result;
    }
    
    /// Format with autopep8
    private static FormatResult formatAutopep8(const string[] sources, string pythonCmd, bool check)
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
            result.formattedFiles = sources.dup;
        }
        
        return result;
    }
}

