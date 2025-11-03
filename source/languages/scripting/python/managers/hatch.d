module languages.scripting.python.managers.hatch;

import std.process : Config;
import infrastructure.utils.security : execute;  // SECURITY: Auto-migrated
import std.string;
import std.conv;
import languages.scripting.python.managers.base;
import languages.scripting.python.tooling.detection : ToolDetection;
alias PyTools = ToolDetection;
import infrastructure.utils.logging.logger;

/// Hatch package manager
class HatchManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.error = "Hatch uses pyproject.toml, use installPackages instead";
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        Logger.info("Installing with Hatch");
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["hatch", "env", "create"]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "hatch env create failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Hatch environment created in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isHatchAvailable();
    }
    
    string name() const
    {
        return "hatch";
    }
    
    string getVersion()
    {
        auto res = execute(["hatch", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

