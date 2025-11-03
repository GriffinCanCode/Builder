module migration.common;

import std.array;
import errors;
import config.schema.schema : Target, TargetType, TargetLanguage;

/// Intermediate representation of a build target
/// Agnostic to source and destination build systems
struct MigrationTarget
{
    string name;
    TargetType type;
    TargetLanguage language;
    string[] sources;
    string[] dependencies;
    string[] flags;
    string[] includes;
    string output;
    string[string] env;
    string[string] metadata;  // System-specific data preserved
    
    /// Convert to Builder Target
    Target toTarget() const
    {
        Target target;
        target.name = name;
        target.type = type;
        target.language = language;
        target.sources = sources.dup;
        target.deps = dependencies.dup;
        target.flags = flags.dup;
        target.includes = includes.dup;
        target.outputPath = output;
        // Create a mutable copy of env
        foreach (k, v; env)
            target.env[k] = v;
        return target;
    }
}

/// Warning level for migration issues
enum WarningLevel
{
    Info,      // Informational, no action needed
    Warning,   // Should review, but migration succeeds
    Error      // Critical issue, migration may be incomplete
}

/// Migration warning or issue
struct MigrationWarning
{
    WarningLevel level;
    string message;
    string context;        // Where in the file
    string[] suggestions;  // How to fix
    
    this(WarningLevel level, string message, string context = "")
    {
        this.level = level;
        this.message = message;
        this.context = context;
    }
    
    void addSuggestion(string suggestion)
    {
        suggestions ~= suggestion;
    }
}

/// Result of a migration operation
struct MigrationResult
{
    MigrationTarget[] targets;
    MigrationWarning[] warnings;
    string[string] globalConfig;  // Workspace-level settings
    bool success;
    
    /// Check if migration has any errors
    bool hasErrors() const
    {
        import std.algorithm : any;
        return warnings.any!(w => w.level == WarningLevel.Error);
    }
    
    /// Check if migration has warnings
    bool hasWarnings() const
    {
        import std.algorithm : any;
        return warnings.any!(w => w.level == WarningLevel.Warning);
    }
    
    /// Get all errors
    MigrationWarning[] errors() const
    {
        import std.algorithm : filter;
        import std.array : array;
        MigrationWarning[] result;
        foreach (w; warnings)
            if (w.level == WarningLevel.Error)
                result ~= cast(MigrationWarning)w;
        return result;
    }
    
    /// Add warning
    void addWarning(MigrationWarning warning)
    {
        warnings ~= warning;
    }
    
    /// Add error
    void addError(string message, string context = "")
    {
        warnings ~= MigrationWarning(WarningLevel.Error, message, context);
        success = false;
    }
    
    /// Add info
    void addInfo(string message, string context = "")
    {
        warnings ~= MigrationWarning(WarningLevel.Info, message, context);
    }
}

/// Statistics about migration
struct MigrationStats
{
    size_t targetsConverted;
    size_t dependenciesResolved;
    size_t filesProcessed;
    size_t warningsGenerated;
    size_t errorsGenerated;
    string[] unsupportedFeatures;  // Features that couldn't be migrated
}

