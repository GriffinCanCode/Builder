module languages.compiled.swift.config.dependency;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Package.swift manifest information
struct PackageManifest
{
    /// Package name
    string name;
    
    /// Tools version
    string toolsVersion;
    
    /// Platforms
    string[] platforms;
    
    /// Products (libraries, executables)
    string[] products;
    
    /// Dependencies
    Dependency[] dependencies;
    
    /// Targets
    string[] targets;
    
    /// Swift language versions
    string[] swiftLanguageVersions;
    
    /// C language standard
    string cLanguageStandard;
    
    /// C++ language standard
    string cxxLanguageStandard;
    
    /// Manifest path
    string manifestPath = "Package.swift";
}

/// Dependency specification
struct Dependency
{
    /// Package name
    string name;
    
    /// Source URL (git, local path)
    string url;
    
    /// Version requirement
    string version_;
    
    /// Branch name (if using branch)
    string branch;
    
    /// Revision/commit (if using exact revision)
    string revision;
    
    /// Local path dependency
    string path;
    
    /// From version
    string from;
    
    /// Exact version
    string exact;
    
    /// Version range (e.g., "1.0.0"..<"2.0.0")
    string range;
}

/// Swift Dependency Configuration
struct SwiftDependencyConfig
{
    /// Package manifest
    PackageManifest manifest;
    
    /// Dependencies
    Dependency[] dependencies;
}

