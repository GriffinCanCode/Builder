module languages.scripting.elixir.config.quality;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Dialyzer type analysis configuration
struct DialyzerConfig
{
    /// Enable Dialyzer
    bool enabled = false;
    
    /// PLT file path
    string pltFile = "_build/dialyzer.plt";
    
    /// PLT add apps
    string[] pltApps;
    
    /// Flags
    string[] flags;
    
    /// Warnings to enable
    string[] warnings;
    
    /// Paths to check
    string[] paths;
    
    /// Remove defaults
    bool removeDefaults = false;
    
    /// List unused filters
    bool listUnusedFilters = false;
    
    /// Ignore warnings
    string ignoreWarnings;
    
    /// Format (short, long, dialyxir, github)
    string format = "dialyxir";
}

/// Credo static analysis configuration
struct CredoConfig
{
    /// Enable Credo
    bool enabled = false;
    
    /// Strict mode
    bool strict = false;
    
    /// All checks (including disabled)
    bool all = false;
    
    /// Config file
    string configFile = ".credo.exs";
    
    /// Checks to run
    string[] checks;
    
    /// Files to check
    string[] files;
    
    /// Min priority (higher, high, normal, low, lower)
    string minPriority;
    
    /// Format (flycheck, oneline, json)
    string format;
    
    /// Enable explanations
    bool enableExplanations = true;
}

/// Mix format configuration
struct FormatConfig
{
    /// Enable auto-format
    bool enabled = false;
    
    /// Format file patterns
    string[] inputs = ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"];
    
    /// Check formatted (don't format, just check)
    bool checkFormatted = false;
    
    /// Formatter plugins
    string[] plugins;
    
    /// Import deps
    bool importDeps = true;
    
    /// Export locals without parens
    bool exportLocalsWithoutParens = true;
    
    /// Dot formatter path
    string dotFormatterPath = ".formatter.exs";
}

/// ExDoc documentation configuration
struct DocConfig
{
    /// Generate documentation
    bool enabled = false;
    
    /// Main module
    string main;
    
    /// Source URL
    string sourceUrl;
    
    /// Homepage URL
    string homepageUrl;
    
    /// Logo path
    string logo;
    
    /// Output format (html, epub)
    string[] formatters = ["html"];
    
    /// Output directory
    string output = "doc";
    
    /// Extra pages
    string[] extras;
    
    /// Groups
    string[string] groups;
    
    /// API reference
    bool api = true;
    
    /// Canonical URL
    string canonical;
    
    /// Language
    string language = "en";
}

/// Elixir Quality Configuration
struct ElixirQualityConfig
{
    /// Dialyzer type analysis
    DialyzerConfig dialyzer;
    
    /// Credo static analysis
    CredoConfig credo;
    
    /// Mix format
    FormatConfig format;
    
    /// ExDoc documentation
    DocConfig documentation;
}

