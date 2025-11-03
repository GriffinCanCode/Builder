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
    Internal,   // Internal/unexpected errors
    Plugin,     // Plugin system errors
    LSP,        // LSP server errors
    Watch,      // Watch mode errors
    Config      // Configuration/Validation errors
}

/// Specific error codes for programmatic handling
enum ErrorCode
{
    // General errors (0-999)
    UnknownError = 0,
    
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
    InvalidConfiguration,
    
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
    CacheNotFound,
    CacheDisabled,
    CacheUnauthorized,
    CacheTooLarge,
    CacheTimeout,
    CacheWriteFailed,
    CacheInUse,
    CacheDeleteFailed,
    CacheGCFailed,
    NetworkError,
    
    // Repository errors (4500-4599)
    RepositoryError = 4500,
    RepositoryNotFound,
    RepositoryFetchFailed,
    RepositoryVerificationFailed,
    VerificationFailed,
    RepositoryInvalid,
    RepositoryTimeout,
    
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
    MacroExpansionFailed,
    MacroLoadFailed,
    
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
    InitializationFailed,
    NotInitialized,
    NotSupported,
    
    // Telemetry errors (10000-10999)
    TelemetryNoSession = 10000,
    TelemetryStorage,
    TelemetryInvalid,
    
    // Tracing errors (11000-11999)
    TraceInvalidFormat = 11000,
    TraceNoActiveSpan,
    TraceExportFailed,
    
    // Distributed build errors (12000-12999)
    DistributedError = 12000,
    CoordinatorNotFound,
    CoordinatorTimeout,
    WorkerTimeout,
    WorkerFailed,
    ActionSchedulingFailed,
    SandboxError,
    ArtifactTransferFailed,
    
    // Plugin errors (13000-13999)
    PluginError = 13000,
    PluginNotFound,
    PluginLoadFailed,
    PluginCrashed,
    PluginTimeout,
    PluginInvalidResponse,
    PluginProtocolError,
    PluginVersionMismatch,
    PluginCapabilityMissing,
    PluginValidationFailed,
    PluginExecutionFailed,
    InvalidMessage,
    ToolNotFound,
    IncompatibleVersion,
    
    // LSP errors (14000-14999)
    LSPError = 14000,
    LSPInitializationFailed,
    LSPInvalidRequest,
    LSPMethodNotFound,
    LSPInvalidParams,
    LSPDocumentNotFound,
    LSPParseError,
    LSPServerCrashed,
    LSPTimeout,
    LSPInvalidPosition,
    LSPWorkspaceNotInitialized,
    
    // Watch mode errors (15000-15999)
    WatchError = 15000,
    WatcherInitFailed,
    WatcherNotSupported,
    WatcherCrashed,
    FileWatchFailed,
    DebounceError,
    TooManyWatchTargets,
    
    // Configuration/Validation errors (16000-16999)
    ConfigError = 16000,
    InvalidWorkspace,
    InvalidTarget,
    InvalidInput,
    SchemaValidationFailed,
    DeprecatedField,
    RequiredFieldMissing,
    DuplicateTarget,
    ConfigConflict
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
        case 10: return ErrorCategory.Internal;  // Telemetry
        case 11: return ErrorCategory.Internal;  // Tracing
        case 12: return ErrorCategory.System;    // Distributed builds
        case 13: return ErrorCategory.Plugin;    // Plugin errors
        case 14: return ErrorCategory.LSP;       // LSP errors
        case 15: return ErrorCategory.Watch;     // Watch mode errors
        case 16: return ErrorCategory.Config;    // Configuration/Validation errors
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
        case ErrorCode.CacheTimeout:
        case ErrorCode.NetworkError:
        case ErrorCode.ProcessTimeout:
        case ErrorCode.CoordinatorTimeout:
        case ErrorCode.WorkerTimeout:
        case ErrorCode.ArtifactTransferFailed:
        case ErrorCode.PluginTimeout:
        case ErrorCode.LSPTimeout:
        case ErrorCode.WatcherCrashed:
        case ErrorCode.FileWatchFailed:
        case ErrorCode.RepositoryFetchFailed:
            return true;
            
        // Non-recoverable errors
        case ErrorCode.UnknownError:
        case ErrorCode.RepositoryError:
        case ErrorCode.RepositoryNotFound:
        case ErrorCode.RepositoryVerificationFailed:
        case ErrorCode.VerificationFailed:
        case ErrorCode.RepositoryInvalid:
        case ErrorCode.RepositoryAlreadyAdded:
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
        case ErrorCode.CacheNotFound:
        case ErrorCode.CacheDisabled:
        case ErrorCode.CacheUnauthorized:
        case ErrorCode.CacheTooLarge:
        case ErrorCode.CacheWriteFailed:
        case ErrorCode.CacheInUse:
        case ErrorCode.CacheDeleteFailed:
        case ErrorCode.CacheGCFailed:
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
        case ErrorCode.MacroExpansionFailed:
        case ErrorCode.MacroLoadFailed:
        case ErrorCode.ProcessSpawnFailed:
        case ErrorCode.ProcessCrashed:
        case ErrorCode.OutOfMemory:
        case ErrorCode.ThreadPoolError:
        case ErrorCode.InternalError:
        case ErrorCode.NotImplemented:
        case ErrorCode.AssertionFailed:
        case ErrorCode.UnreachableCode:
        case ErrorCode.InitializationFailed:
        case ErrorCode.NotInitialized:
        case ErrorCode.NotSupported:
        case ErrorCode.InvalidConfiguration:
        case ErrorCode.TelemetryNoSession:
        case ErrorCode.TelemetryStorage:
        case ErrorCode.TelemetryInvalid:
        case ErrorCode.TraceInvalidFormat:
        case ErrorCode.TraceNoActiveSpan:
        case ErrorCode.TraceExportFailed:
        case ErrorCode.DistributedError:
        case ErrorCode.CoordinatorNotFound:
        case ErrorCode.WorkerFailed:
        case ErrorCode.ActionSchedulingFailed:
        case ErrorCode.SandboxError:
        case ErrorCode.PluginError:
        case ErrorCode.PluginNotFound:
        case ErrorCode.PluginLoadFailed:
        case ErrorCode.PluginCrashed:
        case ErrorCode.PluginInvalidResponse:
        case ErrorCode.PluginProtocolError:
        case ErrorCode.PluginVersionMismatch:
        case ErrorCode.PluginCapabilityMissing:
        case ErrorCode.PluginValidationFailed:
        case ErrorCode.PluginExecutionFailed:
        case ErrorCode.InvalidMessage:
        case ErrorCode.ToolNotFound:
        case ErrorCode.IncompatibleVersion:
        case ErrorCode.LSPError:
        case ErrorCode.LSPInitializationFailed:
        case ErrorCode.LSPInvalidRequest:
        case ErrorCode.LSPMethodNotFound:
        case ErrorCode.LSPInvalidParams:
        case ErrorCode.LSPDocumentNotFound:
        case ErrorCode.LSPParseError:
        case ErrorCode.LSPServerCrashed:
        case ErrorCode.LSPInvalidPosition:
        case ErrorCode.LSPWorkspaceNotInitialized:
        case ErrorCode.WatchError:
        case ErrorCode.WatcherInitFailed:
        case ErrorCode.WatcherNotSupported:
        case ErrorCode.DebounceError:
        case ErrorCode.TooManyWatchTargets:
        case ErrorCode.ConfigError:
        case ErrorCode.InvalidWorkspace:
        case ErrorCode.InvalidTarget:
        case ErrorCode.InvalidInput:
        case ErrorCode.SchemaValidationFailed:
        case ErrorCode.DeprecatedField:
        case ErrorCode.RequiredFieldMissing:
        case ErrorCode.DuplicateTarget:
        case ErrorCode.ConfigConflict:
        case ErrorCode.RepositoryTimeout:
            return false;
    }
}

/// Get human-readable error message template
string messageTemplate(ErrorCode code) pure nothrow
{
    final switch (code)
    {
        case ErrorCode.UnknownError: return "Unknown error";
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
        case ErrorCode.CacheNotFound: return "Artifact not found in cache";
        case ErrorCode.CacheDisabled: return "Remote cache not configured";
        case ErrorCode.CacheUnauthorized: return "Cache authentication failed";
        case ErrorCode.CacheTooLarge: return "Artifact exceeds maximum size";
        case ErrorCode.CacheTimeout: return "Cache operation timed out";
        case ErrorCode.CacheWriteFailed: return "Failed to write to cache";
        case ErrorCode.CacheInUse: return "Cache is in use by another process";
        case ErrorCode.CacheDeleteFailed: return "Failed to delete cache entry";
        case ErrorCode.CacheGCFailed: return "Cache garbage collection failed";
        case ErrorCode.NetworkError: return "Network communication error";
        case ErrorCode.RepositoryError: return "Repository operation failed";
        case ErrorCode.RepositoryNotFound: return "Repository not found";
        case ErrorCode.RepositoryFetchFailed: return "Failed to fetch repository";
        case ErrorCode.RepositoryVerificationFailed: return "Repository verification failed";
        case ErrorCode.VerificationFailed: return "Verification failed";
        case ErrorCode.RepositoryInvalid: return "Invalid repository";
        case ErrorCode.RepositoryTimeout: return "Repository operation timed out";
        case ErrorCode.RepositoryAlreadyAdded: return "Repository already added";
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
        case ErrorCode.MacroExpansionFailed: return "Macro expansion failed";
        case ErrorCode.MacroLoadFailed: return "Failed to load macro";
        case ErrorCode.ProcessSpawnFailed: return "Failed to spawn process";
        case ErrorCode.ProcessTimeout: return "Process timed out";
        case ErrorCode.ProcessCrashed: return "Process crashed";
        case ErrorCode.OutOfMemory: return "Out of memory";
        case ErrorCode.ThreadPoolError: return "Thread pool error";
        case ErrorCode.InternalError: return "Internal error";
        case ErrorCode.NotImplemented: return "Not implemented";
        case ErrorCode.AssertionFailed: return "Assertion failed";
        case ErrorCode.UnreachableCode: return "Unreachable code reached";
        case ErrorCode.InitializationFailed: return "Initialization failed";
        case ErrorCode.NotInitialized: return "Component not initialized";
        case ErrorCode.NotSupported: return "Operation not supported";
        case ErrorCode.TelemetryNoSession: return "No active telemetry session";
        case ErrorCode.TelemetryStorage: return "Telemetry storage error";
        case ErrorCode.TelemetryInvalid: return "Invalid telemetry data";
        case ErrorCode.TraceInvalidFormat: return "Invalid trace format";
        case ErrorCode.TraceNoActiveSpan: return "No active span";
        case ErrorCode.TraceExportFailed: return "Trace export failed";
        case ErrorCode.DistributedError: return "Distributed build error";
        case ErrorCode.CoordinatorNotFound: return "Build coordinator not found";
        case ErrorCode.CoordinatorTimeout: return "Coordinator connection timeout";
        case ErrorCode.WorkerTimeout: return "Worker timeout";
        case ErrorCode.WorkerFailed: return "Worker failure";
        case ErrorCode.ActionSchedulingFailed: return "Failed to schedule action";
        case ErrorCode.SandboxError: return "Sandbox execution error";
        case ErrorCode.ArtifactTransferFailed: return "Artifact transfer failed";
        case ErrorCode.PluginError: return "Plugin error";
        case ErrorCode.PluginNotFound: return "Plugin not found";
        case ErrorCode.PluginLoadFailed: return "Failed to load plugin";
        case ErrorCode.PluginCrashed: return "Plugin crashed";
        case ErrorCode.PluginTimeout: return "Plugin operation timed out";
        case ErrorCode.PluginInvalidResponse: return "Plugin returned invalid response";
        case ErrorCode.PluginProtocolError: return "Plugin protocol error";
        case ErrorCode.PluginVersionMismatch: return "Plugin version mismatch";
        case ErrorCode.PluginCapabilityMissing: return "Plugin missing required capability";
        case ErrorCode.PluginValidationFailed: return "Plugin validation failed";
        case ErrorCode.PluginExecutionFailed: return "Plugin execution failed";
        case ErrorCode.InvalidMessage: return "Invalid message format";
        case ErrorCode.ToolNotFound: return "Tool not found";
        case ErrorCode.IncompatibleVersion: return "Incompatible version";
        case ErrorCode.LSPError: return "LSP error";
        case ErrorCode.LSPInitializationFailed: return "LSP initialization failed";
        case ErrorCode.LSPInvalidRequest: return "Invalid LSP request";
        case ErrorCode.LSPMethodNotFound: return "LSP method not found";
        case ErrorCode.LSPInvalidParams: return "Invalid LSP parameters";
        case ErrorCode.LSPDocumentNotFound: return "LSP document not found";
        case ErrorCode.LSPParseError: return "LSP parse error";
        case ErrorCode.LSPServerCrashed: return "LSP server crashed";
        case ErrorCode.LSPTimeout: return "LSP operation timed out";
        case ErrorCode.LSPInvalidPosition: return "Invalid LSP position";
        case ErrorCode.LSPWorkspaceNotInitialized: return "LSP workspace not initialized";
        case ErrorCode.WatchError: return "Watch mode error";
        case ErrorCode.WatcherInitFailed: return "Failed to initialize file watcher";
        case ErrorCode.WatcherNotSupported: return "File watcher not supported on this platform";
        case ErrorCode.WatcherCrashed: return "File watcher crashed";
        case ErrorCode.FileWatchFailed: return "Failed to watch file";
        case ErrorCode.DebounceError: return "Debounce error";
        case ErrorCode.TooManyWatchTargets: return "Too many watch targets";
        case ErrorCode.InvalidConfiguration: return "Invalid configuration";
        case ErrorCode.ConfigError: return "Configuration error";
        case ErrorCode.InvalidWorkspace: return "Invalid workspace configuration";
        case ErrorCode.InvalidTarget: return "Invalid target configuration";
        case ErrorCode.InvalidInput: return "Invalid input";
        case ErrorCode.SchemaValidationFailed: return "Schema validation failed";
        case ErrorCode.DeprecatedField: return "Deprecated field used";
        case ErrorCode.RequiredFieldMissing: return "Required field missing";
        case ErrorCode.DuplicateTarget: return "Duplicate target name";
        case ErrorCode.ConfigConflict: return "Configuration conflict";
    }
}

