module languages.jvm.scala.tooling.checkers.scapegoat;

import std.stdio;
import languages.jvm.scala.tooling.checkers.base;
import languages.jvm.scala.core.config;
import utils.logging.logger;

/// Scapegoat checker - static analysis tool
class ScapegoatChecker : Checker
{
    override CheckResult check(string[] sources, LinterConfig config, string workingDir)
    {
        CheckResult result;
        
        // Scapegoat is typically integrated as a compiler plugin
        // Not a standalone tool - needs to be configured in build.sbt
        Logger.warning("Scapegoat requires sbt compiler plugin configuration");
        
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
        return "Scapegoat";
    }
}

