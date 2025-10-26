module languages.scripting.ruby.tooling.results;

/// Build result specific to builders
struct BuildResult
{
    bool success;
    string error;
    string[] outputs;
    string outputHash;
    string[] toolWarnings;
}

/// Type check result
struct TypeCheckResult
{
    bool success;
    string[] errors;
    string[] warnings;
    string output;
    
    bool hasErrors() const
    {
        return !errors.empty;
    }
    
    bool hasWarnings() const
    {
        return !warnings.empty;
    }
}

/// Format/lint result
struct FormatResult
{
    bool success;
    string[] errors;
    string[] warnings;
    string[] offenses; // Style violations
    string output;
    int offenseCount;
    bool autoFixed;
    
    bool hasErrors() const
    {
        return !errors.empty;
    }
    
    bool hasWarnings() const
    {
        return !warnings.empty;
    }
    
    bool hasOffenses() const
    {
        return !offenses.empty || offenseCount > 0;
    }
}


