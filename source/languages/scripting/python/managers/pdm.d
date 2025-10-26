module languages.scripting.python.managers.pdm;

import std.process;
import std.string;
import std.conv;
import languages.scripting.python.managers.base;
import languages.scripting.python.tooling.detection : ToolDetection;
alias PyTools = ToolDetection;
import utils.logging.logger;

/// PDM package manager
class PDMManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        InstallResult result;
        result.error = "PDM uses pyproject.toml, use installPackages instead";
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        Logger.info("Installing with PDM");
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["pdm", "install"]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "pdm install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("PDM installation completed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isPDMAvailable();
    }
    
    string name() const
    {
        return "pdm";
    }
    
    string getVersion()
    {
        auto res = execute(["pdm", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

