module errors.types.types;

import std.conv;
import std.algorithm;
import std.array;
import errors.handling.codes;
import errors.context;

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
    
    this(ErrorCode code, string message)
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
    
    /// Add context to error chain
    void addContext(ErrorContext ctx) @trusted
    {
        _contexts ~= ctx;
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
    
    this(string targetId, string message, ErrorCode code = ErrorCode.BuildFailed) @trusted
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
    
    this(string filePath, string message, ErrorCode code = ErrorCode.ParseFailed)
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
    
    this(string targetName, string message, ErrorCode code = ErrorCode.AnalysisFailed)
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
    
    this(string message, ErrorCode code = ErrorCode.CacheLoadFailed)
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
    
    this(string path, string message, ErrorCode code = ErrorCode.FileNotFound)
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
    
    this(string message, ErrorCode code = ErrorCode.GraphInvalid)
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

/// Error builder for fluent API
struct ErrorBuilder(T : BaseBuildError)
{
    private T error;
    
    static ErrorBuilder create(Args...)(Args args)
    {
        ErrorBuilder builder;
        builder.error = new T(args);
        return builder;
    }
    
    ErrorBuilder withContext(string operation, string details = "")
    {
        error.addContext(ErrorContext(operation, details));
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

