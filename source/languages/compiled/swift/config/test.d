module languages.compiled.swift.config.test;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Sanitizer options
enum SwiftSanitizer
{
    /// No sanitizer
    None,
    /// Address sanitizer
    Address,
    /// Thread sanitizer
    Thread,
    /// Undefined behavior sanitizer
    Undefined
}

/// Code coverage mode
enum SwiftCoverage
{
    /// No coverage
    None,
    /// Generate coverage data
    Generate,
    /// Show coverage
    Show
}

/// Testing configuration
struct SwiftTestConfig
{
    /// Test filter (run specific tests)
    string[] filter;
    
    /// Skip tests
    string[] skip;
    
    /// Enable code coverage
    bool enableCodeCoverage = false;
    
    /// Parallel testing
    bool parallel = true;
    
    /// Number of workers
    int numWorkers = 0; // 0 = auto
    
    /// Repeat tests
    int repeat = 1;
    
    /// Test product
    string testProduct;
    
    /// XCTest arguments
    string[] xctestArgs;
    
    /// Enable test discovery
    bool enableTestDiscovery = true;
    
    /// Enable experimental test output
    bool experimentalTestOutput = false;
    
    /// Sanitizer
    SwiftSanitizer sanitizer = SwiftSanitizer.None;
    
    /// Code coverage
    SwiftCoverage coverage = SwiftCoverage.None;
}

