module languages.scripting.ruby.managers.environments;

import std.stdio;
import std.process;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.scripting.ruby.core.config;
import utils.logging.logger;

/// Ruby version manager interface
interface VersionManager
{
    /// Get Ruby executable path
    string getRubyPath(string version_ = "");
    
    /// Check if version is installed
    bool isVersionInstalled(string version_);
    
    /// Install Ruby version (if supported)
    bool installVersion(string version_);
    
    /// Get current Ruby version
    string getCurrentVersion();
    
    /// Check if version manager is available
    bool isAvailable();
    
    /// Get version manager name
    string name() const;
}

/// Version manager factory
final class VersionManagerFactory
{
    /// Create version manager based on configuration
    static VersionManager create(RubyVersionManager type, string projectRoot = ".") @safe
    {
        final switch (type)
        {
            case RubyVersionManager.Auto:
                return detectBest(projectRoot);
            case RubyVersionManager.Rbenv:
                return new RbenvManager(projectRoot);
            case RubyVersionManager.RVM:
                return new RVMManager(projectRoot);
            case RubyVersionManager.Chruby:
                return new ChrubyManager(projectRoot);
            case RubyVersionManager.ASDF:
                return new ASDFManager(projectRoot);
            case RubyVersionManager.System:
            case RubyVersionManager.None:
                return new SystemRubyManager();
        }
    }
    
    /// Detect best available version manager
    static VersionManager detectBest(string projectRoot) @safe
    {
        // Priority order: rbenv > chruby > rvm > asdf > system
        
        // Check for .ruby-version file and corresponding manager
        immutable versionFile = buildPath(projectRoot, ".ruby-version");
        if (exists(versionFile))
        {
            // Try rbenv first (most common with .ruby-version)
            scope rbenv = new RbenvManager(projectRoot);
            if (rbenv.isAvailable())
            {
                Logger.debug_("Detected rbenv from .ruby-version");
                return rbenv;
            }
            
            // Try chruby
            scope chruby = new ChrubyManager(projectRoot);
            if (chruby.isAvailable())
            {
                Logger.debug_("Detected chruby from .ruby-version");
                return chruby;
            }
        }
        
        // Check for .rvmrc or .ruby-gemset (RVM)
        immutable rvmrc = buildPath(projectRoot, ".rvmrc");
        immutable gemset = buildPath(projectRoot, ".ruby-gemset");
        if (exists(rvmrc) || exists(gemset))
        {
            scope rvm = new RVMManager(projectRoot);
            if (rvm.isAvailable())
            {
                Logger.debug_("Detected RVM from .rvmrc");
                return rvm;
            }
        }
        
        // Check for .tool-versions (asdf)
        immutable toolVersions = buildPath(projectRoot, ".tool-versions");
        if (exists(toolVersions))
        {
            scope asdf = new ASDFManager(projectRoot);
            if (asdf.isAvailable())
            {
                Logger.debug_("Detected asdf from .tool-versions");
                return asdf;
            }
        }
        
        // Try detecting by availability
        {
            scope rbenv = new RbenvManager(projectRoot);
            if (rbenv.isAvailable())
                return rbenv;
        }
        
        {
            scope chruby = new ChrubyManager(projectRoot);
            if (chruby.isAvailable())
                return chruby;
        }
        
        {
            scope rvm = new RVMManager(projectRoot);
            if (rvm.isAvailable())
                return rvm;
        }
        
        {
            scope asdf = new ASDFManager(projectRoot);
            if (asdf.isAvailable())
                return asdf;
        }
        
        // Fallback to system Ruby
        Logger.debug_("No Ruby version manager detected, using system Ruby");
        return new SystemRubyManager();
    }
}

/// rbenv version manager (lightweight, shim-based)
final class RbenvManager : VersionManager
{
    private string projectRoot;
    
    this(string projectRoot = ".") @safe pure nothrow @nogc
    {
        this.projectRoot = projectRoot;
    }
    
    override string getRubyPath(string version_ = "") const
    {
        if (!version_.empty)
        {
            // Get path for specific version
            const res = execute(["rbenv", "prefix", version_]);
            if (res.status == 0)
                return buildPath(res.output.strip, "bin", "ruby");
        }
        
        // Get current version's path
        const res = execute(["rbenv", "which", "ruby"], null, Config.none, size_t.max, projectRoot);
        if (res.status == 0)
            return res.output.strip;
        
        return "ruby";
    }
    
    override bool isVersionInstalled(string version_) const
    {
        const res = execute(["rbenv", "versions", "--bare"]);
        if (res.status != 0)
            return false;
        
        foreach (line; res.output.lineSplitter)
        {
            if (line.strip == version_)
                return true;
        }
        return false;
    }
    
    override bool installVersion(string version_)
    {
        Logger.info("Installing Ruby " ~ version_ ~ " with rbenv");
        
        // Check if ruby-build is available
        auto buildCheck = execute(["rbenv", "install", "--list"]);
        if (buildCheck.status != 0)
        {
            Logger.error("ruby-build not available. Install: https://github.com/rbenv/ruby-build");
            return false;
        }
        
        auto res = execute(["rbenv", "install", version_]);
        if (res.status != 0)
        {
            Logger.error("Failed to install Ruby " ~ version_);
            return false;
        }
        
        // Rehash after installation
        execute(["rbenv", "rehash"]);
        
        return true;
    }
    
    override string getCurrentVersion()
    {
        auto res = execute(["rbenv", "version-name"], null, Config.none, size_t.max, projectRoot);
        if (res.status == 0)
            return res.output.strip;
        return "";
    }
    
    override bool isAvailable()
    {
        try
        {
            auto res = execute(["rbenv", "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    override string name() const
    {
        return "rbenv";
    }
    
    /// Set local Ruby version
    bool setLocalVersion(string version_)
    {
        auto res = execute(["rbenv", "local", version_], null, Config.none, size_t.max, projectRoot);
        return res.status == 0;
    }
    
    /// Set global Ruby version
    bool setGlobalVersion(string version_)
    {
        auto res = execute(["rbenv", "global", version_]);
        return res.status == 0;
    }
    
    /// List available Ruby versions
    string[] listVersions() const
    {
        const res = execute(["rbenv", "versions", "--bare"]);
        if (res.status != 0)
            return [];
        
        return res.output.lineSplitter.map!(s => s.strip).array;
    }
}

/// RVM version manager (full-featured, function-based)
final class RVMManager : VersionManager
{
    private string projectRoot;
    
    this(string projectRoot = ".") @safe pure nothrow @nogc
    {
        this.projectRoot = projectRoot;
    }
    
    override string getRubyPath(string version_ = "")
    {
        // RVM uses shell functions, so we need to source it first
        string cmd;
        if (!version_.empty)
            cmd = "source ~/.rvm/scripts/rvm && rvm use " ~ version_ ~ " && which ruby";
        else
            cmd = "source ~/.rvm/scripts/rvm && which ruby";
        
        auto res = executeShell(cmd, null, Config.none, size_t.max, projectRoot);
        if (res.status == 0)
            return res.output.strip;
        
        return "ruby";
    }
    
    override bool isVersionInstalled(string version_)
    {
        auto cmd = "source ~/.rvm/scripts/rvm && rvm list strings";
        auto res = executeShell(cmd);
        
        if (res.status != 0)
            return false;
        
        foreach (line; res.output.lineSplitter)
        {
            if (line.strip.canFind(version_))
                return true;
        }
        return false;
    }
    
    override bool installVersion(string version_)
    {
        Logger.info("Installing Ruby " ~ version_ ~ " with RVM");
        
        auto cmd = "source ~/.rvm/scripts/rvm && rvm install " ~ version_;
        auto res = executeShell(cmd);
        
        if (res.status != 0)
        {
            Logger.error("Failed to install Ruby " ~ version_);
            return false;
        }
        
        return true;
    }
    
    override string getCurrentVersion()
    {
        auto cmd = "source ~/.rvm/scripts/rvm && rvm current";
        auto res = executeShell(cmd, null, Config.none, size_t.max, projectRoot);
        
        if (res.status == 0)
            return res.output.strip;
        return "";
    }
    
    override bool isAvailable()
    {
        try
        {
            auto cmd = "source ~/.rvm/scripts/rvm && rvm --version";
            auto res = executeShell(cmd);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    override string name() const
    {
        return "RVM";
    }
    
    /// Use specific Ruby version
    bool useVersion(string version_)
    {
        auto cmd = "source ~/.rvm/scripts/rvm && rvm use " ~ version_;
        auto res = executeShell(cmd, null, Config.none, size_t.max, projectRoot);
        return res.status == 0;
    }
    
    /// Create gemset
    bool createGemset(string name)
    {
        auto cmd = "source ~/.rvm/scripts/rvm && rvm gemset create " ~ name;
        auto res = executeShell(cmd, null, Config.none, size_t.max, projectRoot);
        return res.status == 0;
    }
    
    /// Use gemset
    bool useGemset(string name)
    {
        auto cmd = "source ~/.rvm/scripts/rvm && rvm gemset use " ~ name;
        auto res = executeShell(cmd, null, Config.none, size_t.max, projectRoot);
        return res.status == 0;
    }
}

/// chruby version manager (minimal, elegant)
final class ChrubyManager : VersionManager
{
    private string projectRoot;
    
    this(string projectRoot = ".") @safe pure nothrow @nogc
    {
        this.projectRoot = projectRoot;
    }
    
    override string getRubyPath(string version_ = "")
    {
        // chruby modifies PATH, so we source it and get ruby path
        string cmd;
        if (!version_.empty)
            cmd = "source /usr/local/share/chruby/chruby.sh && chruby " ~ version_ ~ " && which ruby";
        else
            cmd = "source /usr/local/share/chruby/chruby.sh && which ruby";
        
        auto res = executeShell(cmd, null, Config.none, size_t.max, projectRoot);
        if (res.status == 0)
            return res.output.strip;
        
        return "ruby";
    }
    
    override bool isVersionInstalled(string version_)
    {
        // chruby looks for Rubies in ~/.rubies and /opt/rubies
        auto rubiesDirs = [
            expandTilde("~/.rubies"),
            "/opt/rubies"
        ];
        
        foreach (dir; rubiesDirs)
        {
            if (exists(dir))
            {
                try
                {
                    foreach (entry; dirEntries(dir, SpanMode.shallow))
                    {
                        if (entry.isDir && baseName(entry.name).canFind(version_))
                            return true;
                    }
                }
                catch (Exception e) {}
            }
        }
        
        return false;
    }
    
    override bool installVersion(string version_)
    {
        Logger.error("chruby doesn't support automatic installation. Use ruby-install:");
        Logger.error("  ruby-install ruby " ~ version_);
        return false;
    }
    
    override string getCurrentVersion()
    {
        // Check .ruby-version file
        auto versionFile = buildPath(projectRoot, ".ruby-version");
        if (exists(versionFile))
        {
            try
            {
                return readText(versionFile).strip;
            }
            catch (Exception e) {}
        }
        
        // Get from environment
        auto rubyVersion = environment.get("RUBY_VERSION", "");
        if (!rubyVersion.empty)
            return rubyVersion;
        
        return "";
    }
    
    override bool isAvailable()
    {
        // chruby is just a shell function, check if script exists
        return exists("/usr/local/share/chruby/chruby.sh") ||
               exists("/usr/share/chruby/chruby.sh") ||
               exists(expandTilde("~/.local/share/chruby/chruby.sh"));
    }
    
    override string name() const
    {
        return "chruby";
    }
}

/// asdf version manager (multi-language)
final class ASDFManager : VersionManager
{
    private string projectRoot;
    
    this(string projectRoot = ".") @safe pure nothrow @nogc
    {
        this.projectRoot = projectRoot;
    }
    
    override string getRubyPath(string version_ = "")
    {
        if (!version_.empty)
        {
            auto res = execute(["asdf", "where", "ruby", version_]);
            if (res.status == 0)
                return buildPath(res.output.strip, "bin", "ruby");
        }
        
        auto res = execute(["asdf", "which", "ruby"], null, Config.none, size_t.max, projectRoot);
        if (res.status == 0)
            return res.output.strip;
        
        return "ruby";
    }
    
    override bool isVersionInstalled(string version_)
    {
        auto res = execute(["asdf", "list", "ruby"]);
        if (res.status != 0)
            return false;
        
        foreach (line; res.output.lineSplitter)
        {
            if (line.strip.canFind(version_))
                return true;
        }
        return false;
    }
    
    override bool installVersion(string version_)
    {
        Logger.info("Installing Ruby " ~ version_ ~ " with asdf");
        
        // Ensure ruby plugin is installed
        auto pluginRes = execute(["asdf", "plugin", "add", "ruby"]);
        // Ignore error if plugin already exists
        
        auto res = execute(["asdf", "install", "ruby", version_]);
        if (res.status != 0)
        {
            Logger.error("Failed to install Ruby " ~ version_);
            return false;
        }
        
        return true;
    }
    
    override string getCurrentVersion()
    {
        auto res = execute(["asdf", "current", "ruby"], null, Config.none, size_t.max, projectRoot);
        if (res.status == 0)
        {
            // Parse output like "ruby 3.3.0 (set by ...)"
            auto parts = res.output.strip.split;
            if (parts.length >= 2)
                return parts[1];
        }
        return "";
    }
    
    override bool isAvailable()
    {
        try
        {
            auto res = execute(["asdf", "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    override string name() const
    {
        return "asdf";
    }
    
    /// Set local Ruby version
    bool setLocalVersion(string version_)
    {
        auto res = execute(["asdf", "local", "ruby", version_], null, Config.none, size_t.max, projectRoot);
        return res.status == 0;
    }
    
    /// Set global Ruby version
    bool setGlobalVersion(string version_)
    {
        auto res = execute(["asdf", "global", "ruby", version_]);
        return res.status == 0;
    }
}

/// System Ruby (no version manager)
final class SystemRubyManager : VersionManager
{
    override string getRubyPath(string version_ = "") const pure nothrow @nogc
    {
        return "ruby";
    }
    
    override bool isVersionInstalled(string version_) const
    {
        // Check if system Ruby matches requested version
        const res = execute(["ruby", "--version"]);
        if (res.status == 0)
        {
            return res.output.canFind(version_);
        }
        return false;
    }
    
    override bool installVersion(string version_)
    {
        Logger.error("Cannot install Ruby versions without a version manager");
        Logger.error("Consider installing rbenv, chruby, or RVM");
        return false;
    }
    
    override string getCurrentVersion()
    {
        auto res = execute(["ruby", "--version"]);
        if (res.status == 0)
        {
            // Parse "ruby 3.3.0 (2023-12-25 revision ...) [x86_64-darwin22]"
            auto parts = res.output.split;
            if (parts.length >= 2)
                return parts[1];
        }
        return "";
    }
    
    override bool isAvailable()
    {
        try
        {
            auto res = execute(["ruby", "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    override string name() const
    {
        return "System Ruby";
    }
}

/// Ruby version utilities
final class RubyVersionUtil
{
    /// Parse .ruby-version file
    static string parseVersionFile(string filePath) @safe
    {
        if (!exists(filePath))
            return "";
        
        try
        {
            string content = readText(filePath).strip;
            
            // Handle different formats:
            // "3.3.0"
            // "ruby-3.3.0"
            // "3.3.0@gemset" (RVM format)
            
            if (content.startsWith("ruby-"))
                content = content[5..$];
            
            immutable atPos = content.indexOf("@");
            if (atPos > 0)
                content = content[0..atPos];
            
            return content;
        }
        catch (Exception e)
        {
            Logger.warning("Failed to parse .ruby-version: " ~ e.msg);
            return "";
        }
    }
    
    /// Write .ruby-version file
    static bool writeVersionFile(string filePath, string version_) @safe
    {
        try
        {
            std.file.write(filePath, version_ ~ "\n");
            return true;
        }
        catch (Exception e)
        {
            Logger.error("Failed to write .ruby-version: " ~ e.msg);
            return false;
        }
    }
    
    /// Compare versions
    static int compareVersions(string v1, string v2) @safe
    {
        immutable parts1 = v1.split(".").map!(to!int).array;
        immutable parts2 = v2.split(".").map!(to!int).array;
        
        immutable len = min(parts1.length, parts2.length);
        
        foreach (i; 0..len)
        {
            if (parts1[i] < parts2[i])
                return -1;
            if (parts1[i] > parts2[i])
                return 1;
        }
        
        if (parts1.length < parts2.length)
            return -1;
        if (parts1.length > parts2.length)
            return 1;
        
        return 0;
    }
    
    /// Check if version satisfies requirement
    static bool satisfiesRequirement(string version_, string requirement) @safe
    {
        // Simple version matching
        // Supports: "3.3", "3.3.0", ">= 3.0", "~> 3.3"
        
        immutable req = requirement.strip;
        
        if (req.startsWith("~>"))
        {
            // Pessimistic version constraint
            immutable reqVer = req[2..$].strip;
            return version_.startsWith(reqVer);
        }
        else if (req.startsWith(">="))
        {
            immutable reqVer = req[2..$].strip;
            return compareVersions(version_, reqVer) >= 0;
        }
        else if (req.startsWith("<="))
        {
            immutable reqVer = req[2..$].strip;
            return compareVersions(version_, reqVer) <= 0;
        }
        else if (req.startsWith(">"))
        {
            immutable reqVer = req[1..$].strip;
            return compareVersions(version_, reqVer) > 0;
        }
        else if (req.startsWith("<"))
        {
            immutable reqVer = req[1..$].strip;
            return compareVersions(version_, reqVer) < 0;
        }
        else
        {
            // Exact match or prefix match
            return version_.startsWith(req);
        }
    }
    
    /// Get Ruby version from executable
    static string getRubyVersion(string rubyCmd = "ruby") @safe
    {
        const res = execute([rubyCmd, "--version"]);
        if (res.status == 0)
        {
            immutable parts = res.output.split;
            if (parts.length >= 2)
                return parts[1];
        }
        return "";
    }
    
    /// Check if Ruby command is available
    static bool isRubyAvailable(string rubyCmd = "ruby") nothrow
    {
        try
        {
            const res = execute([rubyCmd, "--version"]);
            return res.status == 0;
        }
        catch (Exception e)
        {
            return false;
        }
    }
}


