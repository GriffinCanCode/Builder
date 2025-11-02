module languages.compiled.swift.config.quality;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// SwiftLint configuration
struct SwiftLintConfig
{
    /// Enable SwiftLint
    bool enabled = false;
    
    /// Config file path
    string configFile = ".swiftlint.yml";
    
    /// Strict mode (warnings as errors)
    bool strict = false;
    
    /// Lint mode (lint, analyze)
    string mode = "lint";
    
    /// Rules to enable
    string[] enableRules;
    
    /// Rules to disable
    string[] disableRules;
    
    /// Paths to lint
    string[] includePaths;
    
    /// Paths to exclude
    string[] excludePaths;
    
    /// Reporter format
    string reporter = "xcode";
    
    /// Quiet mode
    bool quiet = false;
    
    /// Force exclude
    bool forceExclude = false;
    
    /// Autocorrect
    bool autocorrect = false;
}

/// SwiftFormat configuration
struct SwiftFormatConfig
{
    /// Enable SwiftFormat
    bool enabled = false;
    
    /// Config file path
    string configFile = ".swift-format.json";
    
    /// Check only (don't format)
    bool checkOnly = false;
    
    /// In-place formatting
    bool inPlace = true;
    
    /// Rules
    string[] rules;
    
    /// Indent width
    int indentWidth = 4;
    
    /// Use tabs
    bool useTabs = false;
    
    /// Line length
    int lineLength = 100;
    
    /// Respect existing line breaks
    bool respectsExistingLineBreaks = true;
}

/// Swift-DocC documentation configuration
struct DocCConfig
{
    /// Enable documentation generation
    bool enabled = false;
    
    /// Output path
    string outputPath = ".docs";
    
    /// Hosting base path
    string hostingBasePath;
    
    /// Transform for archive
    bool transformForStaticHosting = false;
    
    /// Additional symbol graph options
    string[] symbolGraphOptions;
    
    /// Enable experimental features
    bool experimentalFeatures = false;
    
    /// Enable diagnostics
    bool enableDiagnostics = true;
}

/// Swift Quality Configuration
struct SwiftQualityConfig
{
    /// SwiftLint configuration
    SwiftLintConfig swiftlint;
    
    /// SwiftFormat configuration
    SwiftFormatConfig swiftformat;
    
    /// Documentation configuration
    DocCConfig documentation;
}

