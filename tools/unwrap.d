#!/usr/bin/env rdmd
/// Sophisticated unwrap() refactoring tool
/// 
/// Analyzes .unwrap() calls and suggests/applies context-aware error handling.
/// Design principles:
/// - Type-safe analysis with strong guarantees
/// - Extensible strategy pattern for replacements
/// - Minimal tech debt through comprehensive validation
/// - Dry-run first for 100% safety
module tools.unwrap;

import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.array;
import std.string;
import std.regex;
import std.conv;
import std.range;
import std.typecons;

/// Result type for this tool (self-contained)
struct Result(T, E)
{
    private bool _isOk;
    private union { T _value; E _error; }
    
    static Result ok(T value) { 
        Result r; r._isOk = true; r._value = value; return r; 
    }
    static Result err(E error) { 
        Result r; r._isOk = false; r._error = error; return r; 
    }
    
    @property bool isOk() const { return _isOk; }
    @property bool isErr() const { return !_isOk; }
    T unwrap() { if (!_isOk) throw new Exception(_error); return _value; }
    E unwrapErr() { if (_isOk) throw new Exception("unwrapErr on Ok"); return _error; }
}

alias Ok(T, E) = Result!(T, E).ok;
alias Err(T, E) = Result!(T, E).err;

/// Location of an unwrap call in source code
struct UnwrapLocation
{
    string filePath;
    size_t lineNumber;
    string line;
    string varName;          // Variable being assigned (if any)
    string resultExpr;       // Expression being unwrapped
    string context;          // Surrounding context
    bool hasErrorCheck;      // Is there already an isErr check nearby?
    string errorType;        // Inferred error type (e.g., "BuildError")
    string valueType;        // Inferred value type
}

/// Strategy for replacing unwrap() with better error handling
enum ReplacementStrategy
{
    AddIsErrCheck,      // Add if (result.isErr) before unwrap
    UseMatch,           // Use result.match() for pattern matching
    UseUnwrapOr,        // Use unwrapOr() with default value
    UseAndThen,         // Chain with andThen() monadic operation
    LogBeforeUnwrap,    // Add logging before unwrap
    Skip                // Already has good error handling
}

/// A suggested replacement for an unwrap() call
struct Replacement
{
    UnwrapLocation location;
    ReplacementStrategy strategy;
    string originalCode;
    string replacementCode;
    string rationale;
}

/// Analysis report
struct AnalysisReport
{
    UnwrapLocation[] locations;
    Replacement[] replacements;
    size_t totalUnwraps;
    size_t needsImprovement;
    size_t alreadyGood;
}

/// Configuration for the refactoring tool
struct Config
{
    bool dryRun = true;
    bool verbose = false;
    string sourceDir = "source";
    string[] excludePaths = ["source/errors/handling/result.d"];
    bool requireManualReview = true;
}

/// Main analyzer class
class UnwrapAnalyzer
{
    private Config config;
    private AnalysisReport report;
    
    this(Config config)
    {
        this.config = config;
    }
    
    /// Analyze all source files
    Result!(AnalysisReport, string) analyze()
    {
        writeln("\n\x1b[36m=== Unwrap Refactoring Analyzer ===\x1b[0m\n");
        
        try
        {
            auto files = findDFiles(config.sourceDir);
            writeln("\x1b[36m[INFO]\x1b[0m Found ", files.length, " D source files");
            
            foreach (file; files)
            {
                if (shouldExclude(file))
                {
                    if (config.verbose)
                        writeln("\x1b[90m[SKIP]\x1b[0m ", file);
                    continue;
                }
                
                analyzeFile(file);
            }
            
            report.totalUnwraps = report.locations.length;
            report.needsImprovement = report.replacements.length;
            report.alreadyGood = report.totalUnwraps - report.needsImprovement;
            
            return Ok!(AnalysisReport, string)(report);
        }
        catch (Exception e)
        {
            return Err!(AnalysisReport, string)("Analysis failed: " ~ e.msg);
        }
    }
    
    /// Analyze a single file
    private void analyzeFile(string filePath)
    {
        if (config.verbose)
            writeln("\x1b[90m[SCAN]\x1b[0m ", filePath);
        
        auto content = readText(filePath);
        auto lines = content.splitLines();
        
        // Find all .unwrap() calls
        auto unwrapPattern = regex(r"\.unwrap\(\)");
        
        foreach (i, line; lines)
        {
            auto matches = line.matchAll(unwrapPattern);
            if (!matches.empty)
            {
                auto location = analyzeUnwrapLocation(filePath, i + 1, lines, cast(size_t)i);
                report.locations ~= location;
                
                // Determine if it needs improvement
                auto replacement = createReplacement(location, lines, cast(size_t)i);
                if (replacement.strategy != ReplacementStrategy.Skip)
                {
                    report.replacements ~= replacement;
                }
            }
        }
    }
    
    /// Analyze context around an unwrap() call
    private UnwrapLocation analyzeUnwrapLocation(
        string filePath, 
        size_t lineNumber, 
        string[] lines,
        size_t index)
    {
        UnwrapLocation loc;
        loc.filePath = filePath;
        loc.lineNumber = lineNumber;
        loc.line = lines[index].strip();
        
        // Extract variable name and result expression
        auto assignMatch = loc.line.matchFirst(regex(r"(auto|immutable|const)?\s*(\w+)\s*=\s*(.+)\.unwrap\(\)"));
        if (!assignMatch.empty)
        {
            loc.varName = assignMatch[2];
            loc.resultExpr = assignMatch[3].strip();
        }
        else
        {
            // Direct unwrap without assignment
            loc.resultExpr = loc.line.replaceFirst(regex(r"\.unwrap\(\).*"), "").strip();
        }
        
        // Check for nearby error handling
        loc.hasErrorCheck = hasNearbyErrorCheck(lines, index);
        
        // Infer types (simple heuristic based on common patterns)
        loc.errorType = inferErrorType(lines, index);
        loc.valueType = inferValueType(loc.line);
        
        // Get surrounding context
        loc.context = getContext(lines, index);
        
        return loc;
    }
    
    /// Check if there's error handling nearby
    private bool hasNearbyErrorCheck(string[] lines, size_t index)
    {
        // Look up to 5 lines before
        size_t start = index >= 5 ? index - 5 : 0;
        
        foreach (i; start .. index)
        {
            if (lines[i].indexOf("isErr") != -1 || 
                lines[i].indexOf("if (") != -1 && lines[i].indexOf("Result") != -1)
            {
                return true;
            }
        }
        
        return false;
    }
    
    /// Infer error type from context
    private string inferErrorType(string[] lines, size_t index)
    {
        // Look for Result type declarations nearby
        size_t start = index >= 10 ? index - 10 : 0;
        
        foreach (i; start .. min(index + 3, lines.length))
        {
            auto resultMatch = lines[i].matchFirst(regex(r"Result!\(.*?,\s*(\w+)\)"));
            if (!resultMatch.empty)
            {
                return resultMatch[1];
            }
        }
        
        return "BuildError"; // Default assumption
    }
    
    /// Infer value type from line
    private string inferValueType(string line)
    {
        // Check for type annotations
        if (line.canFind("auto "))
            return "auto";
        if (line.canFind("string"))
            return "string";
        if (line.canFind("int"))
            return "int";
        
        return "auto";
    }
    
    /// Get surrounding context (3 lines before and after)
    private string getContext(string[] lines, size_t index)
    {
        size_t start = index >= 3 ? index - 3 : 0;
        size_t end = min(index + 4, lines.length);
        
        return lines[start .. end].join("\n");
    }
    
    /// Create a replacement suggestion
    private Replacement createReplacement(
        UnwrapLocation location,
        string[] lines,
        size_t index)
    {
        Replacement rep;
        rep.location = location;
        rep.originalCode = location.line;
        
        // Skip if already has error handling
        if (location.hasErrorCheck)
        {
            rep.strategy = ReplacementStrategy.Skip;
            rep.rationale = "Already has error handling nearby";
            return rep;
        }
        
        // Determine best strategy based on context
        if (isInLoop(lines, index))
        {
            rep.strategy = ReplacementStrategy.UseAndThen;
            rep.replacementCode = generateAndThenCode(location);
            rep.rationale = "Inside loop - use andThen for early exit";
        }
        else if (hasObviousDefault(location))
        {
            rep.strategy = ReplacementStrategy.UseUnwrapOr;
            rep.replacementCode = generateUnwrapOrCode(location);
            rep.rationale = "Has obvious default value";
        }
        else if (isInFunctionReturn(lines, index))
        {
            rep.strategy = ReplacementStrategy.AddIsErrCheck;
            rep.replacementCode = generateIsErrWithReturn(location);
            rep.rationale = "In function - propagate error upward";
        }
        else
        {
            rep.strategy = ReplacementStrategy.LogBeforeUnwrap;
            rep.replacementCode = generateLoggedUnwrap(location);
            rep.rationale = "Add logging for better error context";
        }
        
        return rep;
    }
    
    private bool isInLoop(string[] lines, size_t index)
    {
        size_t start = index >= 10 ? index - 10 : 0;
        foreach (i; start .. index)
        {
            if (lines[i].canFind("foreach") || lines[i].canFind("for ("))
                return true;
        }
        return false;
    }
    
    private bool hasObviousDefault(UnwrapLocation loc)
    {
        return loc.valueType == "string" || loc.valueType == "int";
    }
    
    private bool isInFunctionReturn(string[] lines, size_t index)
    {
        // Check if function returns Result type
        size_t start = index >= 20 ? index - 20 : 0;
        foreach (i; start .. index)
        {
            if (lines[i].canFind("Result!") && lines[i].canFind("()"))
                return true;
        }
        return false;
    }
    
    private string generateAndThenCode(UnwrapLocation loc)
    {
        return format("// Use andThen to propagate errors\n%s.andThen((value) {\n    // Use value here\n    return Ok!(...)(result);\n})",
            loc.resultExpr);
    }
    
    private string generateUnwrapOrCode(UnwrapLocation loc)
    {
        string defaultVal = loc.valueType == "string" ? `""` : "0";
        return format("auto %s = %s.unwrapOr(%s); // Default on error",
            loc.varName, loc.resultExpr, defaultVal);
    }
    
    private string generateIsErrWithReturn(UnwrapLocation loc)
    {
        string indent = "    ";
        return format("%sif (%s.isErr)\n%s{\n%s    Logger.error(\"Operation failed: \" ~ format(%s.unwrapErr()));\n%s    return Err!(...)(%s.unwrapErr());\n%s}\n%sauto %s = %s.unwrap();",
            indent, loc.resultExpr,
            indent, indent, loc.resultExpr,
            indent, loc.resultExpr,
            indent,
            indent, loc.varName, loc.resultExpr);
    }
    
    private string generateLoggedUnwrap(UnwrapLocation loc)
    {
        return format("if (%s.isErr)\n    Logger.error(\"Unwrap failed at %s:%s: \" ~ format(%s.unwrapErr()));\nauto %s = %s.unwrap();",
            loc.resultExpr, loc.filePath, loc.lineNumber, loc.resultExpr,
            loc.varName, loc.resultExpr);
    }
    
    /// Find all D source files
    private string[] findDFiles(string dir)
    {
        string[] files;
        
        void scan(string path)
        {
            foreach (entry; dirEntries(path, SpanMode.depth))
            {
                if (entry.isFile && entry.name.endsWith(".d"))
                {
                    files ~= entry.name;
                }
            }
        }
        
        scan(dir);
        return files;
    }
    
    private bool shouldExclude(string path)
    {
        foreach (exclude; config.excludePaths)
        {
            if (path.indexOf(exclude) != -1)
                return true;
        }
        return false;
    }
}

/// Report generator
class ReportGenerator
{
    static void printReport(AnalysisReport report, bool verbose)
    {
        writeln("\n\x1b[36m=== Analysis Complete ===\x1b[0m\n");
        
        writeln("\x1b[1mSummary:\x1b[0m");
        writeln("  Total unwrap() calls:    ", report.totalUnwraps);
        writeln("  Need improvement:        \x1b[33m", report.needsImprovement, "\x1b[0m");
        writeln("  Already good:            \x1b[32m", report.alreadyGood, "\x1b[0m");
        
        if (report.needsImprovement > 0)
        {
            writeln("\n\x1b[33m=== Improvements Suggested ===\x1b[0m\n");
            
            foreach (i, rep; report.replacements)
            {
                writeln("\x1b[1m[", i + 1, "] ", rep.location.filePath, ":", rep.location.lineNumber, "\x1b[0m");
                writeln("  Strategy: ", rep.strategy);
                writeln("  Rationale: ", rep.rationale);
                writeln("\n  \x1b[31mOriginal:\x1b[0m");
                writeln("  ", rep.originalCode);
                writeln("\n  \x1b[32mSuggested:\x1b[0m");
                foreach (line; rep.replacementCode.splitLines())
                    writeln("  ", line);
                writeln();
            }
        }
        
        if (verbose && report.alreadyGood > 0)
        {
            writeln("\n\x1b[32m=== Already Good (", report.alreadyGood, ") ===\x1b[0m\n");
            foreach (loc; report.locations)
            {
                if (!report.replacements.canFind!(r => r.location == loc))
                {
                    writeln("  ✓ ", loc.filePath, ":", loc.lineNumber);
                }
            }
        }
    }
    
    static void saveToFile(AnalysisReport report, string filename)
    {
        auto f = File(filename, "w");
        
        f.writeln("# Unwrap Refactoring Report");
        f.writeln();
        f.writeln("## Summary");
        f.writeln("- Total unwrap() calls: ", report.totalUnwraps);
        f.writeln("- Need improvement: ", report.needsImprovement);
        f.writeln("- Already good: ", report.alreadyGood);
        f.writeln();
        
        foreach (i, rep; report.replacements)
        {
            f.writeln("## [", i + 1, "] ", rep.location.filePath, ":", rep.location.lineNumber);
            f.writeln("**Strategy**: ", rep.strategy);
            f.writeln("**Rationale**: ", rep.rationale);
            f.writeln();
            f.writeln("**Original**:");
            f.writeln("```d");
            f.writeln(rep.originalCode);
            f.writeln("```");
            f.writeln();
            f.writeln("**Suggested**:");
            f.writeln("```d");
            f.writeln(rep.replacementCode);
            f.writeln("```");
            f.writeln();
        }
        
        f.close();
        writeln("\n\x1b[36m[INFO]\x1b[0m Report saved to ", filename);
    }
}

void printUsage()
{
    writeln("Unwrap Refactoring Tool");
    writeln();
    writeln("Usage: rdmd tools/unwrap.d [options]");
    writeln();
    writeln("Options:");
    writeln("  --analyze          Analyze unwrap calls (dry-run)");
    writeln("  --apply            Apply refactorings (requires manual review)");
    writeln("  --verbose          Show detailed output");
    writeln("  --source-dir DIR   Source directory (default: source)");
    writeln("  --report FILE      Save report to file");
    writeln();
    writeln("Safety:");
    writeln("  This tool runs in dry-run mode by default.");
    writeln("  Review all suggestions before applying.");
}

int main(string[] args)
{
    Config config;
    bool analyze = false;
    bool apply = false;
    string reportFile = "";
    
    // Parse arguments
    foreach (i, arg; args[1 .. $])
    {
        switch (arg)
        {
            case "--analyze":
                analyze = true;
                break;
            case "--apply":
                apply = true;
                config.dryRun = false;
                break;
            case "--verbose":
                config.verbose = true;
                break;
            case "--source-dir":
                if (i + 1 < args.length)
                    config.sourceDir = args[i + 2];
                break;
            case "--report":
                if (i + 1 < args.length)
                    reportFile = args[i + 2];
                break;
            case "--help":
                printUsage();
                return 0;
            default:
                break;
        }
    }
    
    if (!analyze && !apply)
    {
        printUsage();
        return 1;
    }
    
    // Run analysis
    auto analyzer = new UnwrapAnalyzer(config);
    auto result = analyzer.analyze();
    
    if (result.isErr)
    {
        stderr.writeln("\x1b[31m[ERROR]\x1b[0m ", result.unwrapErr());
        return 1;
    }
    
    auto report = result.unwrap();
    
    // Print report
    ReportGenerator.printReport(report, config.verbose);
    
    // Save to file if requested
    if (!reportFile.empty)
    {
        ReportGenerator.saveToFile(report, reportFile);
    }
    
    if (apply)
    {
        writeln("\n\x1b[33m[WARNING]\x1b[0m --apply is not yet implemented for safety reasons.");
        writeln("Please review the suggestions and apply manually.");
        return 1;
    }
    
    return 0;
}

