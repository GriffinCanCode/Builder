module errors.result;

import std.traits;
import std.conv;

/// Algebraic result type representing either success (Ok) or failure (Err)
/// Inspired by Rust's Result<T, E> with D-specific optimizations
struct Result(T, E)
{
    private bool _isOk;
    private union
    {
        T _value;
        E _error;
    }
    
    /// Create a successful result
    static Result ok(T value)
    {
        Result r;
        r._isOk = true;
        r._value = value;
        return r;
    }
    
    /// Create an error result
    static Result err(E error)
    {
        Result r;
        r._isOk = false;
        r._error = error;
        return r;
    }
    
    /// Check if result is Ok
    @property bool isOk() const pure nothrow @nogc
    {
        return _isOk;
    }
    
    /// Check if result is Err
    @property bool isErr() const pure nothrow @nogc
    {
        return !_isOk;
    }
    
    /// Unwrap value (throws if error)
    T unwrap()
    {
        if (!_isOk)
        {
            static if (is(typeof(_error.toString()) : string))
                throw new Exception("Called unwrap on an error: " ~ _error.toString());
            else
                throw new Exception("Called unwrap on an error");
        }
        return _value;
    }
    
    /// Unwrap or return default value
    T unwrapOr(T defaultValue)
    {
        return _isOk ? _value : defaultValue;
    }
    
    /// Unwrap or compute default value lazily
    T unwrapOrElse(T delegate() fn)
    {
        return _isOk ? _value : fn();
    }
    
    /// Get error (throws if ok)
    E unwrapErr()
    {
        if (_isOk)
            throw new Exception("Called unwrapErr on an Ok value");
        return _error;
    }
    
    /// Map success value to new type
    Result!(U, E) map(U)(U delegate(T) fn)
    {
        if (_isOk)
            return Result!(U, E).ok(fn(_value));
        else
            return Result!(U, E).err(_error);
    }
    
    /// Map error to new type
    Result!(T, F) mapErr(F)(F delegate(E) fn)
    {
        if (_isOk)
            return Result!(T, F).ok(_value);
        else
            return Result!(T, F).err(fn(_error));
    }
    
    /// Chain operations (flatMap/bind)
    Result!(U, E) andThen(U)(Result!(U, E) delegate(T) fn)
    {
        if (_isOk)
            return fn(_value);
        else
            return Result!(U, E).err(_error);
    }
    
    /// Apply function if error
    Result!(T, E) orElse(Result!(T, E) delegate(E) fn)
    {
        if (_isOk)
            return Result!(T, E).ok(_value);
        else
            return fn(_error);
    }
    
    /// Inspect value without consuming (for debugging)
    ref Result inspect(void delegate(ref const T) fn) return
    {
        if (_isOk)
            fn(_value);
        return this;
    }
    
    /// Inspect error without consuming (for debugging)
    ref Result inspectErr(void delegate(ref const E) fn) return
    {
        if (!_isOk)
            fn(_error);
        return this;
    }
    
    /// Match on result (pattern matching style)
    U match(U)(U delegate(T) onOk, U delegate(E) onErr)
    {
        if (_isOk)
            return onOk(_value);
        else
            return onErr(_error);
    }
}

/// Helper to create Ok result
Result!(T, E) Ok(T, E)(T value)
{
    return Result!(T, E).ok(value);
}

/// Helper to create Err result
Result!(T, E) Err(T, E)(E error)
{
    return Result!(T, E).err(error);
}

/// Void result type (for operations that don't return a value)
alias VoidResult(E) = Result!(void, E);

/// Create a successful void result
VoidResult!E success(E)()
{
    return VoidResult!E.ok();
}

/// Create an error void result
VoidResult!E failure(E)(E error)
{
    return VoidResult!E.err(error);
}

/// Collect results into a single result (stops at first error)
Result!(T[], E) collect(T, E)(Result!(T, E)[] results)
{
    T[] values;
    values.reserve(results.length);
    
    foreach (result; results)
    {
        if (result.isErr)
            return Result!(T[], E).err(result.unwrapErr());
        values ~= result.unwrap();
    }
    
    return Result!(T[], E).ok(values);
}

/// Try to execute a function and catch exceptions as errors
Result!(T, E) trying(T, E)(T delegate() fn, E delegate(Exception) errorMapper)
{
    try
    {
        return Result!(T, E).ok(fn());
    }
    catch (Exception e)
    {
        return Result!(T, E).err(errorMapper(e));
    }
}

unittest
{
    // Test Ok path
    auto r1 = Result!(int, string).ok(42);
    assert(r1.isOk);
    assert(r1.unwrap() == 42);
    
    // Test Err path
    auto r2 = Result!(int, string).err("failed");
    assert(r2.isErr);
    assert(r2.unwrapErr() == "failed");
    
    // Test map
    auto r3 = r1.map((int x) => x * 2);
    assert(r3.unwrap() == 84);
    
    // Test andThen
    auto r4 = r1.andThen((int x) => Result!(string, string).ok(x.to!string));
    assert(r4.unwrap() == "42");
}

