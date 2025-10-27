module errors.handling.codes;

import std.conv;

/// Error category hierarchy for systematic classification
enum ErrorCategory
{
    Build,      // Build execution errors
    Parse,      // Configuration parsing errors
    Analysis,   // Dependency analysis errors
    Cache,      // Cache operation errors
    IO,         // File system errors
    Graph,      // Dependency graph errors
    Language,   // Language handler errors
    System,     // System-level errors
    Internal    // Internal/unexpected errors
}

/// Specific error codes for programmatic handling
enum ErrorCode
{
    // Build errors (1000-1999)
    BuildFailed = 1000,
    BuildTimeout,
    BuildCancelled,
    TargetNotFound,
    HandlerNotFound,
    OutputMissing,
    
    // Parse errors (2000-2999)
    ParseFailed = 2000,
    InvalidJson,
    InvalidBuildFile,
    MissingField,
    InvalidFieldValue,
    InvalidGlob,
    
    // Analysis errors (3000-3999)
    AnalysisFailed = 3000,
    ImportResolutionFailed,
    CircularDependency,
    MissingDependency,
    InvalidImport,
    
    // Cache errors (4000-4999)
    CacheLoadFailed = 4000,
    CacheSaveFailed,
    CacheCorrupted,
    CacheEvictionFailed,
    
    // IO errors (5000-5999)
    FileNotFound = 5000,
    FileReadFailed,
    FileWriteFailed,
    DirectoryNotFound,
    PermissionDenied,
    
    // Graph errors (6000-6999)
    GraphCycle = 6000,
    GraphInvalid,
    NodeNotFound,
    EdgeInvalid,
    
    // Language errors (7000-7999)
    SyntaxError = 7000,
    CompilationFailed,
    ValidationFailed,
    UnsupportedLanguage,
    MissingCompiler,
    
    // System errors (8000-8999)
    ProcessSpawnFailed = 8000,
    ProcessTimeout,
    ProcessCrashed,
    OutOfMemory,
    ThreadPoolError,
    
    // Internal errors (9000-9999)
    InternalError = 9000,
    NotImplemented,
    AssertionFailed,
    UnreachableCode,
    
    // Telemetry errors (10000-10999)
    TelemetryNoSession = 10000,
    TelemetryStorage,
    TelemetryInvalid
}

/// Get error category from error code
ErrorCategory categoryOf(ErrorCode code) pure nothrow @nogc
{
    final switch (code / 1000)
    {
        case 1: return ErrorCategory.Build;
        case 2: return ErrorCategory.Parse;
        case 3: return ErrorCategory.Analysis;
        case 4: return ErrorCategory.Cache;
        case 5: return ErrorCategory.IO;
        case 6: return ErrorCategory.Graph;
        case 7: return ErrorCategory.Language;
        case 8: return ErrorCategory.System;
        case 9: return ErrorCategory.Internal;
        case 10: return ErrorCategory.Internal;
        case 0: return ErrorCategory.Internal;
    }
}

/// Check if error is recoverable
bool isRecoverable(ErrorCode code) pure nothrow @nogc
{
    final switch (code)
    {
        // Recoverable errors
        case ErrorCode.BuildTimeout:
        case ErrorCode.CacheLoadFailed:
        case ErrorCode.CacheEvictionFailed:
        case ErrorCode.ProcessTimeout:
            return true;
            
        // Non-recoverable errors
        case ErrorCode.BuildFailed:
        case ErrorCode.BuildCancelled:
        case ErrorCode.TargetNotFound:
        case ErrorCode.HandlerNotFound:
        case ErrorCode.OutputMissing:
        case ErrorCode.ParseFailed:
        case ErrorCode.InvalidJson:
        case ErrorCode.InvalidBuildFile:
        case ErrorCode.MissingField:
        case ErrorCode.InvalidFieldValue:
        case ErrorCode.InvalidGlob:
        case ErrorCode.AnalysisFailed:
        case ErrorCode.ImportResolutionFailed:
        case ErrorCode.CircularDependency:
        case ErrorCode.MissingDependency:
        case ErrorCode.InvalidImport:
        case ErrorCode.CacheSaveFailed:
        case ErrorCode.CacheCorrupted:
        case ErrorCode.FileNotFound:
        case ErrorCode.FileReadFailed:
        case ErrorCode.FileWriteFailed:
        case ErrorCode.DirectoryNotFound:
        case ErrorCode.PermissionDenied:
        case ErrorCode.GraphCycle:
        case ErrorCode.GraphInvalid:
        case ErrorCode.NodeNotFound:
        case ErrorCode.EdgeInvalid:
        case ErrorCode.SyntaxError:
        case ErrorCode.CompilationFailed:
        case ErrorCode.ValidationFailed:
        case ErrorCode.UnsupportedLanguage:
        case ErrorCode.MissingCompiler:
        case ErrorCode.ProcessSpawnFailed:
        case ErrorCode.ProcessCrashed:
        case ErrorCode.OutOfMemory:
        case ErrorCode.ThreadPoolError:
        case ErrorCode.InternalError:
        case ErrorCode.NotImplemented:
        case ErrorCode.AssertionFailed:
        case ErrorCode.UnreachableCode:
        case ErrorCode.TelemetryNoSession:
        case ErrorCode.TelemetryStorage:
        case ErrorCode.TelemetryInvalid:
            return false;
    }
}

/// Get human-readable error message template
string messageTemplate(ErrorCode code) pure nothrow
{
    final switch (code)
    {
        case ErrorCode.BuildFailed: return "Build failed";
        case ErrorCode.BuildTimeout: return "Build timed out";
        case ErrorCode.BuildCancelled: return "Build was cancelled";
        case ErrorCode.TargetNotFound: return "Target not found";
        case ErrorCode.HandlerNotFound: return "Language handler not found";
        case ErrorCode.OutputMissing: return "Expected output not found";
        case ErrorCode.ParseFailed: return "Failed to parse configuration";
        case ErrorCode.InvalidJson: return "Invalid JSON syntax";
        case ErrorCode.InvalidBuildFile: return "Invalid Builderfile";
        case ErrorCode.MissingField: return "Required field missing";
        case ErrorCode.InvalidFieldValue: return "Invalid field value";
        case ErrorCode.InvalidGlob: return "Invalid glob pattern";
        case ErrorCode.AnalysisFailed: return "Dependency analysis failed";
        case ErrorCode.ImportResolutionFailed: return "Failed to resolve import";
        case ErrorCode.CircularDependency: return "Circular dependency detected";
        case ErrorCode.MissingDependency: return "Dependency not found";
        case ErrorCode.InvalidImport: return "Invalid import statement";
        case ErrorCode.CacheLoadFailed: return "Failed to load cache";
        case ErrorCode.CacheSaveFailed: return "Failed to save cache";
        case ErrorCode.CacheCorrupted: return "Cache data corrupted";
        case ErrorCode.CacheEvictionFailed: return "Cache eviction failed";
        case ErrorCode.FileNotFound: return "File not found";
        case ErrorCode.FileReadFailed: return "Failed to read file";
        case ErrorCode.FileWriteFailed: return "Failed to write file";
        case ErrorCode.DirectoryNotFound: return "Directory not found";
        case ErrorCode.PermissionDenied: return "Permission denied";
        case ErrorCode.GraphCycle: return "Dependency cycle detected";
        case ErrorCode.GraphInvalid: return "Invalid dependency graph";
        case ErrorCode.NodeNotFound: return "Graph node not found";
        case ErrorCode.EdgeInvalid: return "Invalid graph edge";
        case ErrorCode.SyntaxError: return "Syntax error";
        case ErrorCode.CompilationFailed: return "Compilation failed";
        case ErrorCode.ValidationFailed: return "Validation failed";
        case ErrorCode.UnsupportedLanguage: return "Unsupported language";
        case ErrorCode.MissingCompiler: return "Compiler not found";
        case ErrorCode.ProcessSpawnFailed: return "Failed to spawn process";
        case ErrorCode.ProcessTimeout: return "Process timed out";
        case ErrorCode.ProcessCrashed: return "Process crashed";
        case ErrorCode.OutOfMemory: return "Out of memory";
        case ErrorCode.ThreadPoolError: return "Thread pool error";
        case ErrorCode.InternalError: return "Internal error";
        case ErrorCode.NotImplemented: return "Not implemented";
        case ErrorCode.AssertionFailed: return "Assertion failed";
        case ErrorCode.UnreachableCode: return "Unreachable code reached";
        case ErrorCode.TelemetryNoSession: return "No active telemetry session";
        case ErrorCode.TelemetryStorage: return "Telemetry storage error";
        case ErrorCode.TelemetryInvalid: return "Invalid telemetry data";
    }
}

