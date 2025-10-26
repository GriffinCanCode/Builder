module languages.scripting.python.checker;

import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.python.config;
import languages.scripting.python.tools;
import utils.logging.logger;

/// Type check result
struct TypeCheckResult
{
    bool success;
    string[] errors;
    string[] warnings;
    string[] notes;
    bool hasErrors;
    bool hasWarnings;
}

/// Type checker factory and utilities
class TypeChecker
{
    /// Run type checking with configured checker
    static TypeCheckResult check(string[] sources, TypeCheckConfig config, string pythonCmd = "python3")
    {
        if (!config.enabled)
        {
            TypeCheckResult result;
            result.success = true;
            return result;
        }
        
        final switch (config.checker)
        {
            case PyTypeChecker.Auto:
                return checkAuto(sources, config, pythonCmd);
            case PyTypeChecker.Mypy:
                return checkMypy(sources, config, pythonCmd);
            case PyTypeChecker.Pyright:
                return checkPyright(sources, config);
            case PyTypeChecker.Pytype:
                return checkPytype(sources, config, pythonCmd);
            case PyTypeChecker.Pyre:
                return checkPyre(sources, config);
            case PyTypeChecker.None:
                TypeCheckResult result;
                result.success = true;
                return result;
        }
    }
    
    /// Auto-detect and use best available type checker
    private static TypeCheckResult checkAuto(string[] sources, TypeCheckConfig config, string pythonCmd)
    {
        // Priority: pyright (fastest) > mypy (most complete) > pytype > pyre
        
        if (PyTools.isPyrightAvailable())
        {
            Logger.debug_("Using pyright for type checking");
            return checkPyright(sources, config);
        }
        
        if (PyTools.isMypyAvailable(pythonCmd))
        {
            Logger.debug_("Using mypy for type checking");
            return checkMypy(sources, config, pythonCmd);
        }
        
        if (PyTools.isPytypeAvailable(pythonCmd))
        {
            Logger.debug_("Using pytype for type checking");
            return checkPytype(sources, config, pythonCmd);
        }
        
        // No type checker available
        TypeCheckResult result;
        result.success = true;
        result.warnings ~= "No type checker available, skipping type checking";
        Logger.warning("No type checker available (install mypy, pyright, or pytype)");
        
        return result;
    }
    
    /// Type check with mypy
    private static TypeCheckResult checkMypy(string[] sources, TypeCheckConfig config, string pythonCmd)
    {
        TypeCheckResult result;
        
        string[] cmd = [pythonCmd, "-m", "mypy"];
        
        // Add configuration options
        if (config.strict)
            cmd ~= "--strict";
        
        if (config.ignoreMissingImports)
            cmd ~= "--ignore-missing-imports";
        
        if (config.warnUnusedIgnores)
            cmd ~= "--warn-unused-ignores";
        
        if (config.disallowUntypedDefs)
            cmd ~= "--disallow-untyped-defs";
        
        if (config.disallowUntypedCalls)
            cmd ~= "--disallow-untyped-calls";
        
        if (config.checkUntypedDefs)
            cmd ~= "--check-untyped-defs";
        
        // Add config file if specified
        if (!config.configFile.empty && exists(config.configFile))
            cmd ~= ["--config-file", config.configFile];
        
        // Add sources
        cmd ~= sources;
        
        Logger.info("Running mypy type checking");
        
        auto res = execute(cmd);
        
        // Parse mypy output
        foreach (line; res.output.lineSplitter)
        {
            auto trimmed = line.strip;
            if (trimmed.empty)
                continue;
            
            if (trimmed.canFind("error:"))
            {
                result.errors ~= trimmed;
                result.hasErrors = true;
            }
            else if (trimmed.canFind("warning:"))
            {
                result.warnings ~= trimmed;
                result.hasWarnings = true;
            }
            else if (trimmed.canFind("note:"))
            {
                result.notes ~= trimmed;
            }
        }
        
        result.success = res.status == 0;
        
        if (!result.success)
        {
            Logger.warning("Mypy found type errors");
        }
        else if (result.hasWarnings)
        {
            Logger.info("Mypy type checking passed with warnings");
        }
        else
        {
            Logger.info("Mypy type checking passed");
        }
        
        return result;
    }
    
    /// Type check with pyright
    private static TypeCheckResult checkPyright(string[] sources, TypeCheckConfig config)
    {
        TypeCheckResult result;
        
        string[] cmd = ["pyright"];
        
        // Add sources
        cmd ~= sources;
        
        Logger.info("Running pyright type checking");
        
        auto res = execute(cmd);
        
        // Parse pyright output (JSON mode would be better, but text for simplicity)
        foreach (line; res.output.lineSplitter)
        {
            auto trimmed = line.strip;
            if (trimmed.empty)
                continue;
            
            if (trimmed.canFind("error") && !trimmed.canFind("0 errors"))
            {
                result.errors ~= trimmed;
                result.hasErrors = true;
            }
            else if (trimmed.canFind("warning"))
            {
                result.warnings ~= trimmed;
                result.hasWarnings = true;
            }
            else if (trimmed.canFind("information"))
            {
                result.notes ~= trimmed;
            }
        }
        
        result.success = res.status == 0;
        
        if (!result.success)
        {
            Logger.warning("Pyright found type errors");
        }
        else if (result.hasWarnings)
        {
            Logger.info("Pyright type checking passed with warnings");
        }
        else
        {
            Logger.info("Pyright type checking passed");
        }
        
        return result;
    }
    
    /// Type check with pytype
    private static TypeCheckResult checkPytype(string[] sources, TypeCheckConfig config, string pythonCmd)
    {
        TypeCheckResult result;
        
        string[] cmd = [pythonCmd, "-m", "pytype"];
        
        // Add sources
        cmd ~= sources;
        
        Logger.info("Running pytype type checking");
        
        auto res = execute(cmd);
        
        // Parse pytype output
        foreach (line; res.output.lineSplitter)
        {
            auto trimmed = line.strip;
            if (trimmed.empty)
                continue;
            
            if (trimmed.canFind("[error]"))
            {
                result.errors ~= trimmed;
                result.hasErrors = true;
            }
            else if (trimmed.canFind("[warning]"))
            {
                result.warnings ~= trimmed;
                result.hasWarnings = true;
            }
        }
        
        result.success = res.status == 0;
        
        if (!result.success)
        {
            Logger.warning("Pytype found type errors");
        }
        else
        {
            Logger.info("Pytype type checking passed");
        }
        
        return result;
    }
    
    /// Type check with pyre
    private static TypeCheckResult checkPyre(string[] sources, TypeCheckConfig config)
    {
        TypeCheckResult result;
        
        string[] cmd = ["pyre", "check"];
        
        Logger.info("Running pyre type checking");
        
        auto res = execute(cmd);
        
        // Parse pyre output
        foreach (line; res.output.lineSplitter)
        {
            auto trimmed = line.strip;
            if (trimmed.empty)
                continue;
            
            if (trimmed.canFind("Error"))
            {
                result.errors ~= trimmed;
                result.hasErrors = true;
            }
        }
        
        result.success = res.status == 0;
        
        if (!result.success)
        {
            Logger.warning("Pyre found type errors");
        }
        else
        {
            Logger.info("Pyre type checking passed");
        }
        
        return result;
    }
}

