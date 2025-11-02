module errors.types.network;

import errors.base;
import errors.handling.codes;
import errors.types.context;

/// Network communication error
/// Used for remote cache, HTTP requests, and network-related failures
final class NetworkError : BuildError
{
    /// Constructor with message
    this(string message, ErrorCode code = ErrorCode.NetworkError,
         string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(message, code, ErrorCategory.System, file, line);
    }
    
    /// Add host information
    NetworkError withHost(string host, ushort port) return @safe
    {
        addContext(ErrorContext("network host", format("%s:%d", host, port)));
        return this;
    }
    
    /// Add URL context
    NetworkError withUrl(string url) return @safe
    {
        addContext(ErrorContext("url", url));
        return this;
    }
    
    /// Add timeout context
    NetworkError withTimeout(Duration timeout) return @safe
    {
        import std.conv : to;
        addContext(ErrorContext("timeout", timeout.total!"msecs".to!string ~ " ms"));
        return this;
    }
    
    private import std.string : format;
    private import std.datetime : Duration;
}


