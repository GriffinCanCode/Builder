module languages.scripting.elixir.config.dependency;

import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.string;

/// Umbrella project configuration
struct UmbrellaConfig
{
    /// Apps directory
    string appsDir = "apps";
    
    /// Individual app paths
    string[] apps;
    
    /// Shared dependencies
    bool sharedDeps = true;
    
    /// Build all apps
    bool buildAll = true;
    
    /// Apps to exclude from build
    string[] excludeApps;
}

/// Hex package configuration
struct HexConfig
{
    /// Package name (for publishing)
    string packageName;
    
    /// Organization (for private packages)
    string organization;
    
    /// Description
    string description;
    
    /// Files to include in package
    string[] files;
    
    /// Licenses
    string[] licenses;
    
    /// Links (source, homepage, etc.)
    string[string] links;
    
    /// Maintainers
    string[] maintainers;
    
    /// API key path
    string apiKeyPath;
    
    /// Publish to Hex
    bool publish = false;
    
    /// Build docs for Hex
    bool buildDocs = true;
}

/// Elixir Dependency Configuration
struct ElixirDependencyConfig
{
    /// Umbrella configuration
    UmbrellaConfig umbrella;
    
    /// Hex configuration
    HexConfig hex;
}

