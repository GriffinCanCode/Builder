module infrastructure.analysis.targets.types;

import std.path;
import std.algorithm;

/// Represents a single import statement in source code
struct Import
{
    string moduleName;      // e.g., "os.path" or "./utils.js"
    ImportKind kind;
    SourceLocation location;
    
    /// Check if this is an external package import
    bool isExternal() const pure nothrow
    {
        final switch (kind)
        {
            case ImportKind.External:
                return true;
            case ImportKind.Relative:
            case ImportKind.Absolute:
                return false;
        }
    }
    
    /// Normalize import path for comparison
    string normalized() const
    {
        return moduleName.buildNormalizedPath;
    }
}

/// Type of import statement
enum ImportKind
{
    Relative,   // e.g., "./module" or "from . import x"
    Absolute,   // e.g., "/path/to/module" or "mypackage.module"
    External    // e.g., "std" or "lodash" (not part of workspace)
}

/// Source code location for error reporting
struct SourceLocation
{
    string file;
    size_t line;
    size_t column;
    
    string toString() const
    {
        import std.conv : to;
        return file ~ ":" ~ line.to!string ~ ":" ~ column.to!string;
    }
}

/// Represents a resolved dependency between targets
struct Dependency
{
    string targetName;      // Fully qualified target name
    DependencyKind kind;
    string[] sourceImports; // Original import statements that resolved to this
    
    /// Create a direct dependency
    static Dependency direct(string target, string importStmt)
    {
        return Dependency(target, DependencyKind.Direct, [importStmt]);
    }
    
    /// Create a transitive dependency
    static Dependency transitive(string target)
    {
        return Dependency(target, DependencyKind.Transitive, []);
    }
}

/// Type of dependency relationship
enum DependencyKind
{
    Direct,      // Explicitly declared or directly imported
    Transitive,  // Pulled in through another dependency
    Implicit     // Inferred from imports (not in deps list)
}

/// Result of analyzing a single source file
struct FileAnalysis
{
    string path;
    Import[] imports;
    string contentHash;
    bool hasErrors;
    string[] errors;
    
    /// Check if analysis is valid
    bool isValid() const pure nothrow
    {
        return !hasErrors;
    }
}

/// Result of analyzing an entire target
struct TargetAnalysis
{
    string targetName;
    FileAnalysis[] files;
    Dependency[] dependencies;
    AnalysisMetrics metrics;
    
    /// Get all unique imports across all files
    Import[] allImports() const
    {
        Import[] result;
        bool[string] seen;
        
        foreach (file; files)
        {
            foreach (imp; file.imports)
            {
                auto key = imp.moduleName;
                if (key !in seen)
                {
                    seen[key] = true;
                    result ~= imp;
                }
            }
        }
        
        return result;
    }
    
    /// Check if all files analyzed successfully
    bool isValid() const pure nothrow
    {
        return files.all!(f => f.isValid);
    }
}

/// Performance metrics for analysis
struct AnalysisMetrics
{
    size_t filesScanned;
    size_t importsFound;
    size_t dependenciesResolved;
    ulong scanTimeMs;
    ulong resolveTimeMs;
    
    ulong totalTimeMs() const pure nothrow
    {
        return scanTimeMs + resolveTimeMs;
    }
}

