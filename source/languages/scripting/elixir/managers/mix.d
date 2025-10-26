module languages.scripting.elixir.managers.mix;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import std.conv;
import utils.logging.logger;

/// Mix project information
struct MixProjectInfo
{
    string name;
    string app;
    string version_;
    string elixirVersion;
    string[] deps;
    bool isValid;
}

/// Mix project parser - extracts information from mix.exs
class MixProjectParser
{
    /// Parse mix.exs file
    static MixProjectInfo parse(string mixExsPath)
    {
        MixProjectInfo info;
        
        if (!exists(mixExsPath) || !isFile(mixExsPath))
            return info;
        
        try
        {
            auto content = readText(mixExsPath);
            
            // Extract project function
            auto projectMatch = content.matchFirst(regex(r"def\s+project\s+do\s*\[(.*?)\]", "s"));
            if (!projectMatch.empty)
            {
                string projectDef = projectMatch[1];
                
                // Extract app name
                auto appMatch = projectDef.matchFirst(regex(r"app:\s*:(\w+)"));
                if (!appMatch.empty)
                    info.app = appMatch[1];
                
                // Extract version
                auto versionMatch = projectDef.matchFirst(regex(`version:\s*"([^"]+)"`));
                if (!versionMatch.empty)
                    info.version_ = versionMatch[1];
                
                // Extract Elixir version
                auto elixirMatch = projectDef.matchFirst(regex(`elixir:\s*"([^"]+)"`));
                if (!elixirMatch.empty)
                    info.elixirVersion = elixirMatch[1];
            }
            
            // Extract dependencies
            auto depsMatch = content.matchFirst(regex(r"defp?\s+deps\s+do\s*\[(.*?)\]", "s"));
            if (!depsMatch.empty)
            {
                string depsDef = depsMatch[1];
                auto depMatches = depsDef.matchAll(regex(r"\{:(\w+)"));
                foreach (match; depMatches)
                {
                    info.deps ~= match[1];
                }
            }
            
            if (!info.app.empty)
            {
                info.name = info.app;
                info.isValid = true;
            }
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse mix.exs: " ~ e.msg);
        }
        
        return info;
    }
}

/// Mix command executor
class MixRunner
{
    private string mixCmd;
    private string workDir;
    
    this(string mixCmd = "mix", string workDir = ".")
    {
        this.mixCmd = mixCmd;
        this.workDir = workDir;
    }
    
    /// Run mix task
    auto runTask(string task, string[] args = [], string[string] env = null)
    {
        string[] cmd = [mixCmd, task] ~ args;
        
        Logger.debug_("Running: " ~ cmd.join(" "));
        
        return execute(cmd, env, Config.none, size_t.max, workDir);
    }
    
    /// Compile project
    bool compile(string[] opts = [])
    {
        auto res = runTask("compile", opts);
        return res.status == 0;
    }
    
    /// Get dependencies
    bool depsGet()
    {
        auto res = runTask("deps.get");
        return res.status == 0;
    }
    
    /// Compile dependencies
    bool depsCompile()
    {
        auto res = runTask("deps.compile");
        return res.status == 0;
    }
    
    /// Clean project
    bool clean()
    {
        auto res = runTask("clean");
        return res.status == 0;
    }
    
    /// Run tests
    bool test(string[] opts = [])
    {
        auto res = runTask("test", opts);
        return res.status == 0;
    }
    
    /// Format code
    bool format(string[] files = [])
    {
        auto res = runTask("format", files);
        return res.status == 0;
    }
    
    /// Check if code is formatted
    bool formatCheck(string[] files = [])
    {
        auto res = runTask("format", ["--check-formatted"] ~ files);
        return res.status == 0;
    }
    
    /// Build release
    bool release(string releaseName = "")
    {
        string[] args;
        if (!releaseName.empty)
            args = [releaseName];
        
        auto res = runTask("release", args);
        return res.status == 0;
    }
    
    /// Build escript
    bool escript()
    {
        auto res = runTask("escript.build");
        return res.status == 0;
    }
}

