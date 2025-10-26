module languages.scripting.ruby.managers.base;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import languages.scripting.ruby.core.config;

/// Installation result
struct InstallResult
{
    bool success;
    string error;
    string output;
    string[] installedGems;
}

/// Package manager interface
interface PackageManager
{
    /// Install gems/dependencies
    InstallResult install(string[] gems, bool development = false);
    
    /// Install from Gemfile
    InstallResult installFromFile(string gemfilePath, bool deployment = false);
    
    /// Update dependencies
    InstallResult update(string[] gems = []);
    
    /// Check if package manager is available
    bool isAvailable();
    
    /// Get package manager name
    string name() const;
    
    /// Get version
    string getVersion();
    
    /// Check if lockfile exists
    bool hasLockfile() const;
}


