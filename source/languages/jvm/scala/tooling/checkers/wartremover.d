module languages.jvm.scala.tooling.checkers.wartremover;

import std.stdio;
import languages.jvm.scala.tooling.checkers.base;
import languages.jvm.scala.core.config;
import utils.logging.logger;

/// WartRemover checker - functional purity linter
class WartRemoverChecker : Checker
{
    override CheckResult check(const string[] sources, LinterConfig config, string workingDir)
    {
        CheckResult result;
        
        // WartRemover is typically integrated as a compiler plugin
        // Not a standalone tool - needs to be configured in build.sbt
        Logger.warning("WartRemover requires sbt compiler plugin configuration");
        
        result.success = true;
        return result;
    }
    
    override bool isAvailable()
    {
        // Always false since it's not a standalone tool
        return false;
    }
    
    override string name() const
    {
        return "WartRemover";
    }
}

