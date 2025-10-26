module languages.scripting.python.tooling.results;

/// Result of running a Python tool
struct ToolResult
{
    bool success;
    string output;
    string[] warnings;
    string[] errors;
    
    /// Check if tool found issues
    bool hasIssues() const pure nothrow
    {
        return !warnings.empty || !errors.empty;
    }
}

/// Format result
struct FormatResult
{
    bool success;
    string[] formattedFiles;
    string[] issues;
    bool hadChanges;
}

/// Type check result
struct TypeCheckResult
{
    bool success;
    string[] errors;
    string[] warnings;
    string[] notes;
    bool hasErrors;
    bool hasWarnings;
}

