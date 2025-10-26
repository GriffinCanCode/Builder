module languages.scripting.php.tooling.packagers.base;

import languages.scripting.php.core.config;
import std.process;
import std.path;
import std.file;

/// Package result
struct PackageResult
{
    bool success;
    string output;
    string[] errors;
    string[] warnings;
    string[] artifacts;
    long artifactSize;
    
    /// Check if packaging succeeded
    bool hasArtifacts() const pure nothrow
    {
        return !artifacts.empty;
    }
}

/// Base interface for PHP packagers
interface Packager
{
    /// Package PHP application
    PackageResult package(
        string[] sources,
        PHARConfig config,
        string projectRoot
    );
    
    /// Check if packager is available on system
    bool isAvailable();
    
    /// Get packager name
    string name() const;
    
    /// Get packager version
    string getVersion();
}

/// Factory for creating packagers
class PackagerFactory
{
    /// Create packager based on type
    static Packager create(PHPPharTool type)
    {
        import languages.scripting.php.tooling.packagers.box;
        import languages.scripting.php.tooling.packagers.phar;
        import languages.scripting.php.tooling.packagers.pharcc;
        
        final switch (type)
        {
            case PHPPharTool.Auto:
                return createAuto();
            case PHPPharTool.Box:
                return new BoxPackager();
            case PHPPharTool.Pharcc:
                return new PharccPackager();
            case PHPPharTool.Native:
                return new NativePharPackager();
            case PHPPharTool.None:
                return new NullPackager();
        }
    }
    
    /// Auto-detect best available packager
    private static Packager createAuto()
    {
        import languages.scripting.php.tooling.packagers.box;
        import languages.scripting.php.tooling.packagers.pharcc;
        import languages.scripting.php.tooling.packagers.phar;
        
        // Priority: Box > pharcc > Native PHAR
        // Box is the most modern and feature-rich
        
        auto box = new BoxPackager();
        if (box.isAvailable())
            return box;
        
        auto pharcc = new PharccPackager();
        if (pharcc.isAvailable())
            return pharcc;
        
        // Native PHAR is always available (built into PHP)
        return new NativePharPackager();
    }
}

/// Null packager - does nothing
class NullPackager : Packager
{
    PackageResult package(
        string[] sources,
        PHARConfig config,
        string projectRoot
    )
    {
        PackageResult result;
        result.success = true;
        result.output = "No packager configured";
        return result;
    }
    
    bool isAvailable()
    {
        return true;
    }
    
    string name() const
    {
        return "none";
    }
    
    string getVersion()
    {
        return "n/a";
    }
}

