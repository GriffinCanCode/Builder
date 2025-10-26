module languages.jvm.scala.tooling.checkers.base;

import languages.jvm.scala.core.config;

/// Checker/linter result
struct CheckResult
{
    bool success = false;
    string error;
    string[] warnings;
    string[] violations;
    int issuesFound = 0;
}

/// Base interface for Scala checkers/linters
interface Checker
{
    /// Check/lint Scala sources
    CheckResult check(string[] sources, LinterConfig config, string workingDir);
    
    /// Check if checker is available
    bool isAvailable();
    
    /// Get checker name
    string name() const;
}

/// Factory for creating checkers
class CheckerFactory
{
    static Checker create(ScalaLinter type, string workingDir = ".")
    {
        import languages.jvm.scala.tooling.checkers.scalafix;
        import languages.jvm.scala.tooling.checkers.wartremover;
        import languages.jvm.scala.tooling.checkers.scapegoat;
        
        final switch (type)
        {
            case ScalaLinter.Auto:
                return createAuto(workingDir);
            case ScalaLinter.Scalafix:
                return new ScalafixChecker();
            case ScalaLinter.WartRemover:
                return new WartRemoverChecker();
            case ScalaLinter.Scapegoat:
                return new ScapegoatChecker();
            case ScalaLinter.Scalastyle:
                return new NullChecker();
            case ScalaLinter.None:
                return new NullChecker();
        }
    }
    
    private static Checker createAuto(string workingDir)
    {
        import languages.jvm.scala.tooling.checkers.scalafix;
        import languages.jvm.scala.tooling.checkers.wartremover;
        import languages.jvm.scala.tooling.checkers.scapegoat;
        
        // Try Scalafix first
        auto scalafix = new ScalafixChecker();
        if (scalafix.isAvailable())
            return scalafix;
        
        // Try Scapegoat
        auto scapegoat = new ScapegoatChecker();
        if (scapegoat.isAvailable())
            return scapegoat;
        
        // Try WartRemover
        auto wart = new WartRemoverChecker();
        if (wart.isAvailable())
            return wart;
        
        return new NullChecker();
    }
}

/// Null checker (does nothing)
class NullChecker : Checker
{
    override CheckResult check(string[] sources, LinterConfig config, string workingDir)
    {
        CheckResult result;
        result.success = true;
        return result;
    }
    
    override bool isAvailable()
    {
        return true;
    }
    
    override string name() const
    {
        return "None";
    }
}

