module errors.context;

import std.conv;
import std.datetime;

/// Error context entry - represents one layer in the error chain
struct ErrorContext
{
    string operation;     // What operation was being performed
    string details;       // Additional details
    SysTime timestamp;    // When the error occurred
    string location;      // Source location (file:line)
    
    this(string operation, string details = "", string location = "")
    {
        this.operation = operation;
        this.details = details;
        this.timestamp = Clock.currTime();
        this.location = location;
    }
    
    string toString() const
    {
        string result = "during: " ~ operation;
        
        if (!details.empty)
            result ~= " (" ~ details ~ ")";
        
        if (!location.empty)
            result ~= " at " ~ location;
        
        return result;
    }
}

/// Add context to an error
auto withContext(E)(E error, string operation, string details = "")
{
    error.addContext(ErrorContext(operation, details));
    return error;
}

/// Create context from source location
ErrorContext sourceContext(string file = __FILE__, size_t line = __LINE__)(string operation)
{
    import std.path : baseName;
    return ErrorContext(operation, "", baseName(file) ~ ":" ~ line.to!string);
}

/// Mixin for automatic context tracking
mixin template ErrorContextTracking()
{
    private ErrorContext[] _errorContexts;
    
    void addContext(ErrorContext ctx)
    {
        _errorContexts ~= ctx;
    }
    
    const(ErrorContext)[] contexts() const
    {
        return _errorContexts;
    }
}

