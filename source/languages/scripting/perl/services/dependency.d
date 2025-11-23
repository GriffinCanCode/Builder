module languages.scripting.perl.services.dependency;

import languages.scripting.perl.core.config;
import engine.caching.actions.action;
import infrastructure.utils.files.hash;
import infrastructure.utils.logging.logger;
import std.range : empty;

/// Dependency management service interface
interface IPerlDependencyService
{
    /// Install all configured dependencies
    bool install(in PerlConfig config, string projectRoot, ActionCache cache);
}

/// Concrete Perl dependency service
final class PerlDependencyService : IPerlDependencyService
{
    bool install(in PerlConfig config, string projectRoot, ActionCache cache) @trusted
    {
        import std.process : execute, Config;
        import std.conv : to;
        
        if (config.modules.empty)
            return true;
        
        auto pm = detectPackageManager(config);
        if (pm == PerlPackageManager.None)
            return true;
        
        string pmCmd = getPackageManagerCommand(pm);
        if (pmCmd.empty)
            return false;
        
        Logger.info("Installing dependencies with " ~ pmCmd);
        
        // Install each module with caching
        foreach (mod; config.modules)
        {
            if (!installModule(mod, pmCmd, config, projectRoot, cache))
            {
                if (!mod.optional)
                    return false;
            }
        }
        
        return true;
    }
    
    private PerlPackageManager detectPackageManager(in PerlConfig config) @trusted
    {
        auto pm = config.packageManager;
        
        if (pm != PerlPackageManager.Auto)
            return pm;
        
        // Auto-detect best available
        if (isCommandAvailable("cpanm"))
            return PerlPackageManager.CPANMinus;
        else if (isCommandAvailable("cpm"))
            return PerlPackageManager.CPM;
        else if (isCommandAvailable("cpan"))
            return PerlPackageManager.CPAN;
        
        Logger.error("No CPAN package manager found");
        return PerlPackageManager.None;
    }
    
    private string getPackageManagerCommand(PerlPackageManager pm) @safe pure
    {
        final switch (pm)
        {
            case PerlPackageManager.Auto:
            case PerlPackageManager.None:
                return "";
            case PerlPackageManager.CPANMinus:
                return "cpanm";
            case PerlPackageManager.CPM:
                return "cpm";
            case PerlPackageManager.CPAN:
                return "cpan";
            case PerlPackageManager.Carton:
                return "carton";
        }
    }
    
    private bool installModule(
        in CPANModule mod,
        string pmCmd,
        in PerlConfig config,
        string projectRoot,
        ActionCache cache
    ) @trusted
    {
        import std.process : execute, Config;
        import std.conv : to;
        
        // Build module specifier with version
        string modSpec = mod.name;
        if (!mod.version_.empty)
            modSpec ~= "@" ~ mod.version_;
        
        // Create cache metadata
        string[string] metadata;
        metadata["packageManager"] = pmCmd;
        metadata["useLocalLib"] = config.cpan.useLocalLib.to!string;
        metadata["localLibDir"] = config.cpan.localLibDir;
        metadata["version"] = mod.version_;
        
        // Create action ID
        ActionId actionId;
        actionId.targetId = "perl_deps";
        actionId.type = ActionType.Package;
        actionId.subId = mod.name;
        actionId.inputHash = FastHash.hashString(modSpec);
        
        // Check cache
        if (cache.isCached(actionId, [], metadata))
        {
            Logger.debugLog("  [Cached] Module: " ~ modSpec);
            return true;
        }
        
        // Build install command
        string[] cmd = [pmCmd];
        
        if (config.cpan.useLocalLib && !config.cpan.localLibDir.empty)
        {
            cmd ~= ["-L", config.cpan.localLibDir];
        }
        
        cmd ~= modSpec;
        
        Logger.debugLog("Installing: " ~ modSpec);
        
        // Execute installation
        bool success = false;
        try
        {
            auto res = execute(cmd, null, Config.none, size_t.max, projectRoot);
            success = (res.status == 0);
            
            if (!success)
            {
                Logger.error("Failed to install " ~ modSpec);
                Logger.error("  Output: " ~ res.output);
            }
        }
        catch (Exception e)
        {
            Logger.error("Failed to install " ~ modSpec ~ ": " ~ e.msg);
        }
        
        // Update cache
        cache.update(actionId, [], [], metadata, success);
        
        return success;
    }
    
    private bool isCommandAvailable(string cmd) @trusted
    {
        import std.process : execute;
        
        try
        {
            version(Windows)
            {
                auto res = execute(["where", cmd]);
                return res.status == 0;
            }
            else
            {
                auto res = execute(["which", cmd]);
                return res.status == 0;
            }
        }
        catch (Exception e)
        {
            return false;
        }
    }
}

