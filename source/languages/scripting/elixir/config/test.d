module languages.scripting.elixir.config.test;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// ExUnit testing configuration
struct ExUnitConfig
{
    /// Test paths
    string[] testPaths = ["test"];
    
    /// Test pattern
    string testPattern = "*_test.exs";
    
    /// Test coverage tool
    string coverageTool;
    
    /// Enable trace
    bool trace = false;
    
    /// Max cases (parallel tests)
    int maxCases = 0;
    
    /// Exclude tags
    string[] exclude;
    
    /// Include tags
    string[] include;
    
    /// Only tags (run only these)
    string[] only;
    
    /// Seed for randomization
    int seed = 0;
    
    /// Timeout (ms)
    int timeout = 60000;
    
    /// Slow test threshold (ms)
    int slowTestThreshold = 0;
    
    /// Capture log
    bool captureLog = true;
    
    /// Colors
    bool colors = true;
    
    /// Formatters
    string[] formatters = ["ExUnit.CLIFormatter"];
}

/// ExCoveralls coverage configuration
struct CoverallsConfig
{
    /// Enable coverage
    bool enabled = false;
    
    /// Service name (travis-ci, circle-ci, github)
    string service;
    
    /// Treat no relevant lines as success
    bool treatNoRelevantLinesAsSuccess = true;
    
    /// Output directory
    string outputDir = "cover";
    
    /// Coverage options
    string coverageOptions;
    
    /// Post to service
    bool post = false;
    
    /// Ignore modules
    string[] ignoreModules;
    
    /// Stop words
    string[] stopWords;
    
    /// Minimum coverage
    float minCoverage = 0.0;
}

/// Elixir Testing Configuration
struct ElixirTestConfig
{
    /// ExUnit configuration
    ExUnitConfig exunit;
    
    /// ExCoveralls coverage
    CoverallsConfig coveralls;
}

