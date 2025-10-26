module languages.scripting.elixir.managers.releases;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.conv;
import languages.scripting.elixir.core.config;
import utils.logging.logger;

/// Base interface for release builders
interface ReleaseBuilder
{
    /// Build release
    bool buildRelease(ReleaseConfig config, string mixCmd);
    
    /// Check if builder is available
    bool isAvailable();
    
    /// Get builder name
    string name() const;
}

/// Mix Release builder (Elixir 1.9+)
class MixReleaseBuilder : ReleaseBuilder
{
    override bool buildRelease(ReleaseConfig config, string mixCmd)
    {
        Logger.info("Building Mix release: " ~ config.name);
        
        string[] cmd = [mixCmd, "release"];
        
        if (!config.name.empty)
            cmd ~= config.name;
        
        if (config.quiet)
            cmd ~= "--quiet";
        
        auto res = execute(cmd);
        if (res.status != 0)
        {
            Logger.error("Release build failed: " ~ res.output);
            return false;
        }
        
        Logger.info("Release built successfully");
        return true;
    }
    
    override bool isAvailable()
    {
        auto res = execute(["mix", "help", "release"]);
        return res.status == 0;
    }
    
    override string name() const
    {
        return "Mix Release";
    }
}

/// Distillery release builder (legacy)
class DistilleryBuilder : ReleaseBuilder
{
    override bool buildRelease(ReleaseConfig config, string mixCmd)
    {
        Logger.info("Building Distillery release");
        
        string[] cmd = [mixCmd, "distillery.release"];
        
        auto res = execute(cmd);
        if (res.status != 0)
        {
            Logger.error("Distillery release failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    override bool isAvailable()
    {
        auto res = execute(["mix", "help", "distillery.release"]);
        return res.status == 0;
    }
    
    override string name() const
    {
        return "Distillery";
    }
}

/// Burrito builder - cross-platform wrapped executables
class BurritoBuilder : ReleaseBuilder
{
    override bool buildRelease(ReleaseConfig config, string mixCmd)
    {
        Logger.info("Building Burrito release");
        
        auto res = execute([mixCmd, "release"]);
        if (res.status != 0)
        {
            Logger.error("Burrito release failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    override bool isAvailable()
    {
        // Check if burrito is in dependencies
        if (exists("mix.exs"))
        {
            auto content = readText("mix.exs");
            return content.canFind(":burrito");
        }
        return false;
    }
    
    override string name() const
    {
        return "Burrito";
    }
}

/// Bakeware builder - self-extracting executables
class BakewareBuilder : ReleaseBuilder
{
    override bool buildRelease(ReleaseConfig config, string mixCmd)
    {
        Logger.info("Building Bakeware executable");
        
        auto res = execute([mixCmd, "release"]);
        if (res.status != 0)
        {
            Logger.error("Bakeware build failed: " ~ res.output);
            return false;
        }
        
        return true;
    }
    
    override bool isAvailable()
    {
        // Check if bakeware is in dependencies
        if (exists("mix.exs"))
        {
            auto content = readText("mix.exs");
            return content.canFind(":bakeware");
        }
        return false;
    }
    
    override string name() const
    {
        return "Bakeware";
    }
}

/// Release manager - factory for creating release builders
class ReleaseManager
{
    /// Create release builder based on type
    static ReleaseBuilder createBuilder(ReleaseType type)
    {
        final switch (type)
        {
            case ReleaseType.None:
                return null;
            case ReleaseType.MixRelease:
                return new MixReleaseBuilder();
            case ReleaseType.Distillery:
                return new DistilleryBuilder();
            case ReleaseType.Burrito:
                return new BurritoBuilder();
            case ReleaseType.Bakeware:
                return new BakewareBuilder();
        }
    }
    
    /// Auto-detect best available release builder
    static ReleaseBuilder detectBestBuilder()
    {
        // Try Mix Release first (modern Elixir)
        auto mixRelease = new MixReleaseBuilder();
        if (mixRelease.isAvailable())
            return mixRelease;
        
        // Try Burrito
        auto burrito = new BurritoBuilder();
        if (burrito.isAvailable())
            return burrito;
        
        // Try Bakeware
        auto bakeware = new BakewareBuilder();
        if (bakeware.isAvailable())
            return bakeware;
        
        // Try Distillery (legacy)
        auto distillery = new DistilleryBuilder();
        if (distillery.isAvailable())
            return distillery;
        
        return null;
    }
}

