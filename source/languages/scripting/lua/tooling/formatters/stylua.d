module languages.scripting.lua.tooling.formatters.stylua;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.regex;
import std.conv;
import languages.scripting.lua.tooling.formatters.base;
import languages.scripting.lua.tooling.detection;
import languages.scripting.lua.core.config;
import utils.logging.logger;

/// StyLua formatter - modern, opinionated Lua formatter
class StyLuaFormatter : Formatter
{
    override FormatResult format(string[] sources, LuaConfig config)
    {
        FormatResult result;
        
        if (!isAvailable())
        {
            result.error = "StyLua is not installed";
            return result;
        }
        
        string[] cmd = ["stylua"];
        
        // Add config file if specified
        if (!config.format.configFile.empty && exists(config.format.configFile))
        {
            cmd ~= "--config-path";
            cmd ~= config.format.configFile;
        }
        else
        {
            // Add inline configuration options
            if (config.format.stylua.columnWidth > 0)
            {
                cmd ~= "--column-width";
                cmd ~= config.format.stylua.columnWidth.to!string;
            }
            
            if (!config.format.stylua.lineEndings.empty)
            {
                cmd ~= "--line-endings";
                cmd ~= config.format.stylua.lineEndings;
            }
            
            if (!config.format.stylua.indentType.empty)
            {
                cmd ~= "--indent-type";
                cmd ~= config.format.stylua.indentType;
            }
            
            if (config.format.stylua.indentWidth > 0)
            {
                cmd ~= "--indent-width";
                cmd ~= config.format.stylua.indentWidth.to!string;
            }
            
            if (!config.format.stylua.quoteStyle.empty)
            {
                cmd ~= "--quote-style";
                cmd ~= config.format.stylua.quoteStyle;
            }
            
            if (!config.format.stylua.callParentheses.empty)
            {
                cmd ~= "--call-parentheses";
                cmd ~= config.format.stylua.callParentheses;
            }
        }
        
        // Check mode
        if (config.format.checkOnly)
        {
            cmd ~= "--check";
        }
        
        // Add source files
        cmd ~= sources;
        
        Logger.debug_("Running StyLua: " ~ cmd.join(" "));
        
        auto res = execute(cmd);
        
        if (res.status != 0)
        {
            if (config.format.checkOnly)
            {
                result.error = "Formatting check failed:\n" ~ res.output;
            }
            else
            {
                result.error = "Formatting failed:\n" ~ res.output;
            }
            return result;
        }
        
        result.success = true;
        result.modifiedFiles = sources.dup;
        
        return result;
    }
    
    override bool isAvailable()
    {
        return isStyLuaAvailable();
    }
    
    override string name() const
    {
        return "StyLua";
    }
    
    override string getVersion()
    {
        try
        {
            auto res = execute(["stylua", "--version"]);
            if (res.status == 0)
            {
                auto output = res.output.strip;
                auto match = matchFirst(output, regex(`(\d+\.\d+\.\d+)`));
                if (!match.empty)
                {
                    return match[1];
                }
            }
        }
        catch (Exception) {}
        
        return "unknown";
    }
}

