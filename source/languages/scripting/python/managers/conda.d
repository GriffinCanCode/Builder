module languages.scripting.python.managers.conda;

import std.process;
import std.file;
import std.algorithm;
import std.array;
import std.string;
import std.conv;
import languages.scripting.python.managers.base;
import languages.scripting.python.tooling.detection : ToolDetection;
alias PyTools = ToolDetection;
import infrastructure.utils.logging.logger;

/// Conda package manager
class CondaManager : PackageManager
{
    InstallResult installFromFile(string file, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        if (!exists(file))
        {
            result.error = "Environment file not found: " ~ file;
            return result;
        }
        
        Logger.info("Installing conda environment from " ~ file);
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(["conda", "env", "create", "-f", file]);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "conda env create failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        Logger.info("Conda environment created in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    InstallResult installPackages(string[] packages, bool upgrade = false, bool editable = false)
    {
        import std.datetime.stopwatch : StopWatch;
        
        InstallResult result;
        
        string[] cmd = ["conda", "install", "-y"] ~ packages;
        
        Logger.info("Installing packages with conda: " ~ packages.join(", "));
        
        StopWatch sw;
        sw.start();
        
        auto res = execute(cmd);
        
        sw.stop();
        result.timeSeconds = sw.peek().total!"msecs" / 1000.0;
        
        if (res.status != 0)
        {
            result.error = "conda install failed: " ~ res.output;
            return result;
        }
        
        result.success = true;
        result.installedPackages = packages;
        Logger.info("Packages installed in %.2fs".format(result.timeSeconds));
        
        return result;
    }
    
    bool isAvailable()
    {
        return PyTools.isCondaAvailable();
    }
    
    string name() const
    {
        return "conda";
    }
    
    string getVersion()
    {
        auto res = execute(["conda", "--version"]);
        if (res.status == 0)
            return res.output.strip;
        return "unknown";
    }
}

