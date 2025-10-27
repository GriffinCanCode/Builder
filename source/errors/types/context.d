module errors.context;

import std.conv;
import std.datetime;
import std.array : empty;

/// Error context entry - represents one layer in the error chain
struct ErrorContext
{
    string operation;     // What operation was being performed
    string details;       // Additional details
    SysTime timestamp;    // When the error occurred
    string location;      // Source location (file:line)
    
    /// Constructor: Create error context with current timestamp
    /// 
    /// Safety: This constructor is @trusted because:
    /// 1. Clock.currTime() is system call (reads system clock)
    /// 2. All other operations are simple field assignments
    /// 3. String parameters are safely copied by value
    /// 4. SysTime is a safe D type with no pointers
    /// 
    /// Invariants:
    /// - timestamp is set to current system time at creation
    /// - All string fields are immutable after construction
    /// - No dynamic memory management beyond D's GC
    /// 
    /// What could go wrong:
    /// - Clock read fails: would throw exception (safe failure)
    /// - Timestamp precision varies by OS: acceptable variance
    this(string operation, string details = "", string location = "") @trusted
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

