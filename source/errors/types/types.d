module errors.types.types;

import std.conv;
import std.algorithm;
import std.array;
import errors.handling.codes;
import errors.types.context;

/// Base error interface - all errors implement this
interface BuildError
{
    /// Get error code for programmatic handling
    ErrorCode code() const pure nothrow;
    
    /// Get error category
    ErrorCategory category() const pure nothrow;
    
    /// Get primary error message
    string message() const;
    
    /// Get error context chain
    const(ErrorContext)[] contexts() const;
    
    /// Check if error is recoverable
    bool recoverable() const pure nothrow;
    
    /// Get full formatted error string
    string toString() const;
}

/// Base implementation with context chain
abstract class BaseBuildError : BuildError
{
    private ErrorCode _code;
    private string _message;
    private ErrorContext[] _contexts;
    private ErrorSuggestion[] _suggestions;
    
    this(ErrorCode code, string message) @trusted
    {
        _code = code;
        _message = message;
    }
    
    ErrorCode code() const pure nothrow
    {
        return _code;
    }
    
    ErrorCategory category() const pure nothrow
    {
        return categoryOf(_code);
    }
    
    string message() const
    {
        return _message;
    }
    
    const(ErrorContext)[] contexts() const
    {
        return _contexts;
    }
    
    bool recoverable() const pure nothrow
    {
        return isRecoverable(_code);
    }
    
    /// Get strongly-typed suggestions for this specific error instance
    const(ErrorSuggestion)[] suggestions() const
    {
        return _suggestions;
    }
    
    /// DEPRECATED: Get custom suggestions as strings (for backward compatibility)
    const(string)[] customSuggestions() const
    {
        import std.algorithm : map;
        import std.array : array;
        return _suggestions.map!(s => s.toString()).array;
    }
    
    /// Add context to error chain
    void addContext(ErrorContext ctx) @safe
    {
        _contexts ~= ctx;
    }
    
    /// Add a strongly-typed suggestion
    void addSuggestion(ErrorSuggestion suggestion) @safe
    {
        _suggestions ~= suggestion;
    }
    
    /// Add a string suggestion (converted to General type for backward compatibility)
    void addSuggestion(string suggestion) @safe
    {
        _suggestions ~= ErrorSuggestion(suggestion);
    }
    
    override string toString() const
    {
        string result = "[" ~ category.to!string ~ ":" ~ _code.to!string ~ "] " ~ _message;
        
        foreach (ctx; _contexts)
        {
            result ~= "\n  " ~ ctx.toString();
        }
        
        return result;
    }
}

/// Build execution error
class BuildFailureError : BaseBuildError
{
    string targetId;
    string[] failedDeps;
    
    this(string targetId, string message, ErrorCode code = ErrorCode.BuildFailed) @safe
    {
        super(code, message);
        this.targetId = targetId;
    }
    
    override string toString() const
    {
        string result = super.toString();
        result ~= "\n  Target: " ~ targetId;
        
        if (!failedDeps.empty)
            result ~= "\n  Failed dependencies: " ~ failedDeps.join(", ");
        
        return result;
    }
}

/// Parse/configuration error
class ParseError : BaseBuildError
{
    string filePath;
    size_t line;
    size_t column;
    string snippet;
    
    this(string filePath, string message, ErrorCode code = ErrorCode.ParseFailed) @trusted
    {
        super(code, message);
        this.filePath = filePath;
    }
    
    override string toString() const
    {
        string result = super.toString();
        
        if (!filePath.empty)
        {
            result ~= "\n  File: " ~ filePath;
            if (line > 0)
                result ~= ":" ~ line.to!string;
            if (column > 0)
                result ~= ":" ~ column.to!string;
        }
        
        if (!snippet.empty)
            result ~= "\n  " ~ snippet;
        
        return result;
    }
}

/// Analysis error
class AnalysisError : BaseBuildError
{
    string targetName;
    string[] unresolvedImports;
    string[] cyclePath;
    
    this(string targetName, string message, ErrorCode code = ErrorCode.AnalysisFailed) @safe
    {
        super(code, message);
        this.targetName = targetName;
    }
    
    override string toString() const
    {
        string result = super.toString();
        result ~= "\n  Target: " ~ targetName;
        
        if (!unresolvedImports.empty)
            result ~= "\n  Unresolved: " ~ unresolvedImports.join(", ");
        
        if (!cyclePath.empty)
            result ~= "\n  Cycle: " ~ cyclePath.join(" -> ");
        
        return result;
    }
}

/// Cache operation error
class CacheError : BaseBuildError
{
    string cachePath;
    
    this(string message, ErrorCode code = ErrorCode.CacheLoadFailed) @safe
    {
        super(code, message);
    }
    
    override string toString() const
    {
        string result = super.toString();
        
        if (!cachePath.empty)
            result ~= "\n  Cache: " ~ cachePath;
        
        return result;
    }
}

/// IO operation error
class IOError : BaseBuildError
{
    string path;
    
    this(string path, string message, ErrorCode code = ErrorCode.FileNotFound) @safe
    {
        super(code, message);
        this.path = path;
    }
    
    override string toString() const
    {
        string result = super.toString();
        result ~= "\n  Path: " ~ path;
        return result;
    }
}

/// Graph operation error
class GraphError : BaseBuildError
{
    string[] nodePath;
    
    this(string message, ErrorCode code = ErrorCode.GraphInvalid) @safe
    {
        super(code, message);
    }
    
    override string toString() const
    {
        string result = super.toString();
        
        if (!nodePath.empty)
            result ~= "\n  Path: " ~ nodePath.join(" -> ");
        
        return result;
    }
}

/// Language-specific error
class LanguageError : BaseBuildError
{
    string language;
    string filePath;
    size_t line;
    string compilerOutput;
    
    this(string language, string message, ErrorCode code = ErrorCode.CompilationFailed)
    {
        super(code, message);
        this.language = language;
    }
    
    override string toString() const
    {
        string result = super.toString();
        result ~= "\n  Language: " ~ language;
        
        if (!filePath.empty)
        {
            result ~= "\n  File: " ~ filePath;
            if (line > 0)
                result ~= ":" ~ line.to!string;
        }
        
        if (!compilerOutput.empty)
            result ~= "\n  Output:\n" ~ compilerOutput;
        
        return result;
    }
}

/// System-level error
class SystemError : BaseBuildError
{
    string command;
    int exitCode;
    
    this(string message, ErrorCode code = ErrorCode.ProcessSpawnFailed)
    {
        super(code, message);
    }
    
    override string toString() const
    {
        string result = super.toString();
        
        if (!command.empty)
            result ~= "\n  Command: " ~ command;
        if (exitCode != 0)
            result ~= "\n  Exit code: " ~ exitCode.to!string;
        
        return result;
    }
}

/// Internal/unexpected error
class InternalError : BaseBuildError
{
    string stackTrace;
    
    this(string message, ErrorCode code = ErrorCode.InternalError)
    {
        super(code, message);
    }
    
    override string toString() const
    {
        string result = super.toString();
        
        if (!stackTrace.empty)
            result ~= "\n  Stack trace:\n" ~ stackTrace;
        
        return result;
    }
}

/// Generic error for simple use cases and testing
class GenericError : BaseBuildError
{
    this(string message, ErrorCode code = ErrorCode.UnknownError)
    {
        super(code, message);
    }
}

/// Alias for backward compatibility and convenience
alias BuildError_Impl = GenericError;

/// Error builder for fluent API with strong type safety
struct ErrorBuilder(T : BaseBuildError)
{
    private T error;
    
    static ErrorBuilder create(Args...)(Args args)
    {
        ErrorBuilder builder;
        builder.error = new T(args);
        return builder;
    }
    
    /// Add context to the error
    ErrorBuilder withContext(string operation, string details = "")
    {
        error.addContext(ErrorContext(operation, details));
        return this;
    }
    
    /// Add a strongly-typed suggestion
    ErrorBuilder withSuggestion(ErrorSuggestion suggestion)
    {
        error.addSuggestion(suggestion);
        return this;
    }
    
    /// Add a string suggestion (convenience method)
    ErrorBuilder withSuggestion(string suggestion)
    {
        error.addSuggestion(suggestion);
        return this;
    }
    
    /// Add a command suggestion
    ErrorBuilder withCommand(string description, string cmd)
    {
        error.addSuggestion(ErrorSuggestion.command(description, cmd));
        return this;
    }
    
    /// Add a documentation suggestion
    ErrorBuilder withDocs(string description, string url = "")
    {
        error.addSuggestion(ErrorSuggestion.docs(description, url));
        return this;
    }
    
    /// Add a file check suggestion
    ErrorBuilder withFileCheck(string description, string path = "")
    {
        error.addSuggestion(ErrorSuggestion.fileCheck(description, path));
        return this;
    }
    
    /// Add a configuration suggestion
    ErrorBuilder withConfig(string description, string setting = "")
    {
        error.addSuggestion(ErrorSuggestion.config(description, setting));
        return this;
    }
    
    T build()
    {
        return error;
    }
}

/// Convenience constructors
BuildFailureError buildError(string targetId, string message)
{
    return new BuildFailureError(targetId, message);
}

ParseError parseError(string filePath, string message)
{
    return new ParseError(filePath, message);
}

AnalysisError analysisError(string targetName, string message)
{
    return new AnalysisError(targetName, message);
}

CacheError cacheError(string message)
{
    return new CacheError(message);
}

IOError ioError(string path, string message)
{
    return new IOError(path, message);
}

GraphError graphError(string message)
{
    return new GraphError(message);
}

LanguageError languageError(string language, string message)
{
    return new LanguageError(language, message);
}

SystemError systemError(string message)
{
    return new SystemError(message);
}

InternalError internalError(string message)
{
    return new InternalError(message);
}

/// Smart error constructors with built-in suggestions

/// Create a file not found error with helpful suggestions
IOError fileNotFoundError(string path, string context = "") @safe
{
    auto error = new IOError(path, "File not found: " ~ path, ErrorCode.FileNotFound);
    
    import std.path : baseName;
    string fileName = baseName(path);
    
    if (fileName == "Builderfile")
    {
        error.addSuggestion(ErrorSuggestion.command("Create a Builderfile", "builder init"));
        error.addSuggestion(ErrorSuggestion.fileCheck("Check if you're in the correct directory"));
        error.addSuggestion(ErrorSuggestion.docs("See Builderfile documentation", "docs/user-guides/EXAMPLES.md"));
    }
    else if (fileName == "Builderspace")
    {
        error.addSuggestion(ErrorSuggestion.command("Create a workspace", "builder init --workspace"));
        error.addSuggestion(ErrorSuggestion.fileCheck("Check if you're in the workspace root"));
        error.addSuggestion(ErrorSuggestion.docs("See workspace documentation", "docs/architecture/DSL.md"));
    }
    else
    {
        error.addSuggestion(ErrorSuggestion.fileCheck("Verify the file path", path));
        error.addSuggestion(ErrorSuggestion.fileCheck("Check for typos in file path"));
        error.addSuggestion(ErrorSuggestion.fileCheck("Ensure file is not excluded by .builderignore"));
        error.addSuggestion(ErrorSuggestion.command("Check if file exists", "ls " ~ path));
    }
    
    if (!context.empty)
        error.addContext(ErrorContext(context));
    
    return error;
}

/// Create a file read error with helpful suggestions
IOError fileReadError(string path, string errorMsg, string context = "") @safe
{
    auto error = new IOError(path, "Failed to read file: " ~ errorMsg, ErrorCode.FileReadFailed);
    
    error.addSuggestion(ErrorSuggestion.command("Check file permissions", "ls -la " ~ path));
    error.addSuggestion(ErrorSuggestion.fileCheck("Ensure file is readable"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Verify file is not locked by another process"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Check if file is corrupted"));
    
    if (!context.empty)
        error.addContext(ErrorContext(context));
    
    return error;
}

/// Create a parse error with helpful suggestions
ParseError parseErrorWithContext(string filePath, string message, size_t line = 0, string context = "") @safe
{
    auto error = new ParseError(filePath, message, ErrorCode.ParseFailed);
    error.line = line;
    
    import std.path : baseName;
    string fileName = baseName(filePath);
    
    if (fileName == "Builderfile")
    {
        error.addSuggestion(ErrorSuggestion.docs("Check Builderfile syntax", "docs/user-guides/EXAMPLES.md"));
        error.addSuggestion(ErrorSuggestion.command("Validate JSON syntax", "jsonlint " ~ filePath));
        error.addSuggestion(ErrorSuggestion.fileCheck("Ensure all braces and brackets are matched"));
    }
    else if (fileName == "Builderspace")
    {
        error.addSuggestion(ErrorSuggestion.docs("Check Builderspace syntax", "docs/architecture/DSL.md"));
        error.addSuggestion(ErrorSuggestion.fileCheck("Review examples in examples/ directory"));
        error.addSuggestion(ErrorSuggestion.fileCheck("Ensure all declarations are properly formatted"));
    }
    else
    {
        error.addSuggestion(ErrorSuggestion.fileCheck("Check file syntax"));
        error.addSuggestion(ErrorSuggestion.docs("See documentation for file format"));
    }
    
    if (!context.empty)
        error.addContext(ErrorContext(context));
    
    return error;
}

/// Create a build failure error with helpful suggestions
BuildFailureError buildFailureError(string targetId, string message, string[] failedDeps = null) @safe
{
    auto error = new BuildFailureError(targetId, message);
    
    if (failedDeps !is null)
        error.failedDeps = failedDeps;
    
    error.addSuggestion(ErrorSuggestion("Review build output above for specific errors"));
    error.addSuggestion(ErrorSuggestion.command("Run with verbose output", "builder build --verbose"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Check that all dependencies are installed"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Verify source files have no errors"));
    error.addSuggestion(ErrorSuggestion.command("View dependency graph", "builder graph"));
    
    return error;
}

/// Create a target not found error with helpful suggestions
AnalysisError targetNotFoundError(string targetName) @safe
{
    auto error = new AnalysisError(targetName, "Target not found: " ~ targetName, ErrorCode.TargetNotFound);
    
    error.addSuggestion(ErrorSuggestion.fileCheck("Check that target name is spelled correctly"));
    error.addSuggestion(ErrorSuggestion.command("View available targets", "builder graph"));
    error.addSuggestion(ErrorSuggestion.command("List all targets", "builder list"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Verify target is defined in Builderfile"));
    error.addSuggestion(ErrorSuggestion.docs("See target documentation", "docs/user-guides/EXAMPLES.md"));
    
    return error;
}

/// Create a cache error with helpful suggestions
CacheError cacheLoadError(string cachePath, string message) @safe
{
    auto error = new CacheError("Cache load failed: " ~ message, ErrorCode.CacheLoadFailed);
    error.cachePath = cachePath;
    
    error.addSuggestion(ErrorSuggestion.command("Clear cache and rebuild", "builder clean"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Cache may be from incompatible version"));
    error.addSuggestion(ErrorSuggestion.command("Check cache permissions", "ls -la .builder-cache/"));
    error.addSuggestion(ErrorSuggestion.fileCheck("Check available disk space"));
    
    return error;
}

