module languages.scripting.elixir.tooling.tools;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import utils.logging.logger;

/// Elixir tools availability and version checking
class ElixirTools
{
    /// Check if Elixir is available
    static bool isElixirAvailable(string elixirCmd = "elixir")
    {
        auto res = execute([elixirCmd, "--version"]);
        return res.status == 0;
    }
    
    /// Get Elixir version
    static string getElixirVersion(string elixirCmd = "elixir")
    {
        auto res = execute([elixirCmd, "--version"]);
        if (res.status == 0)
        {
            // Parse version from output
            // Format: Elixir X.Y.Z (compiled with Erlang/OTP XX)
            auto match = res.output.matchFirst(regex(r"Elixir\s+(\d+\.\d+\.\d+)"));
            if (!match.empty)
                return match[1];
        }
        return "unknown";
    }
    
    /// Check if Mix is available
    static bool isMixAvailable(string mixCmd = "mix")
    {
        auto res = execute([mixCmd, "--version"]);
        return res.status == 0;
    }
    
    /// Get Mix version
    static string getMixVersion(string mixCmd = "mix")
    {
        auto res = execute([mixCmd, "--version"]);
        if (res.status == 0)
        {
            // Parse version from output
            auto match = res.output.matchFirst(regex(r"Mix\s+(\d+\.\d+\.\d+)"));
            if (!match.empty)
                return match[1];
        }
        return "unknown";
    }
    
    /// Check if IEx is available
    static bool isIExAvailable(string iexCmd = "iex")
    {
        auto res = execute([iexCmd, "--version"]);
        return res.status == 0;
    }
    
    /// Get Erlang/OTP version
    static string getOTPVersion()
    {
        auto res = execute(["erl", "-eval", "erlang:display(erlang:system_info(otp_release)), halt().", "-noshell"]);
        if (res.status == 0)
        {
            return res.output.strip.strip('"');
        }
        return "unknown";
    }
    
    /// Check if command is available in PATH
    static bool isCommandAvailable(string command)
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

