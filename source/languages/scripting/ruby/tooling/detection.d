module languages.scripting.ruby.tooling.detection;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import languages.scripting.ruby.core.config;

/// Ruby project structure detection
class ProjectDetector
{
    /// Check if directory is a Rails project
    static bool isRailsProject(string dir)
    {
        return exists(buildPath(dir, "config", "application.rb")) &&
               exists(buildPath(dir, "config", "environment.rb")) &&
               exists(buildPath(dir, "Gemfile"));
    }
    
    /// Check if directory is a gem project
    static bool isGemProject(string dir)
    {
        auto gemspecs = findGemspecs(dir);
        return !gemspecs.empty;
    }
    
    /// Check if directory uses Bundler
    static bool usesBundler(string dir)
    {
        return exists(buildPath(dir, "Gemfile"));
    }
    
    /// Check if directory has tests
    static bool hasTests(string dir)
    {
        return exists(buildPath(dir, "test")) ||
               exists(buildPath(dir, "spec"));
    }
    
    /// Check if uses RSpec
    static bool usesRSpec(string dir)
    {
        return exists(buildPath(dir, "spec")) &&
               exists(buildPath(dir, ".rspec"));
    }
    
    /// Check if uses Minitest
    static bool usesMinitest(string dir)
    {
        return exists(buildPath(dir, "test"));
    }
    
    /// Detect project type
    static RubyBuildMode detectProjectType(string dir)
    {
        if (isRailsProject(dir))
            return RubyBuildMode.Rails;
        
        if (isGemProject(dir))
            return RubyBuildMode.Gem;
        
        // Check for Rack config
        if (exists(buildPath(dir, "config.ru")))
            return RubyBuildMode.Rack;
        
        // Check for CLI-style bin directory
        auto binDir = buildPath(dir, "bin");
        if (exists(binDir))
        {
            try
            {
                auto files = dirEntries(binDir, SpanMode.shallow);
                if (!files.empty)
                    return RubyBuildMode.CLI;
            }
            catch (Exception e) {}
        }
        
        // Check if it's a library (has lib/ directory)
        if (exists(buildPath(dir, "lib")))
            return RubyBuildMode.Library;
        
        // Default to script
        return RubyBuildMode.Script;
    }
    
    private static string[] findGemspecs(string dir)
    {
        string[] gemspecs;
        
        if (!exists(dir))
            return gemspecs;
        
        try
        {
            foreach (entry; dirEntries(dir, "*.gemspec", SpanMode.shallow))
            {
                if (entry.isFile)
                    gemspecs ~= entry.name;
            }
        }
        catch (Exception e) {}
        
        return gemspecs;
    }
}


