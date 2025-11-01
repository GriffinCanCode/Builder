module errors.adaptation.adapt;

import std.conv;
import std.exception;
import errors.handling.result;
import errors.types.types;
import errors.handling.codes;
import config.schema.schema : LanguageBuildResult;

/// Adapters for integrating new error system with legacy code

/// Convert exception to BuildError
BuildError fromException(Exception e, ErrorCode code = ErrorCode.InternalError)
{
    auto error = new InternalError("Internal error: " ~ e.msg, code);
    
    // Try to extract stack trace
    static if (__traits(compiles, e.info))
    {
        if (e.info)
            error.stackTrace = e.info.toString();
    }
    
    error.addSuggestion("This is likely a bug in Builder");
    error.addSuggestion("Please report this with full error details and reproduction steps");
    error.addSuggestion("Try running with --verbose for more information");
    
    return error;
}

/// Convert LanguageBuildResult to Result type
Result!(string, BuildError) toResult(LanguageBuildResult buildResult, string targetId = "")
{
    if (buildResult.success)
    {
        return Ok!(string, BuildError)(buildResult.outputHash);
    }
    else
    {
        auto error = new BuildFailureError(targetId, "Build failed: " ~ buildResult.error);
        error.addSuggestion("Review the build output above for specific errors");
        error.addSuggestion("Check that all dependencies are installed");
        error.addSuggestion("Verify the build configuration is correct");
        return Err!(string, BuildError)(error);
    }
}

/// Convert Result back to LanguageBuildResult (for gradual migration)
LanguageBuildResult fromResult(Result!(string, BuildError) result)
{
    LanguageBuildResult buildResult;
    
    if (result.isOk)
    {
        buildResult.success = true;
        buildResult.outputHash = result.unwrap();
    }
    else
    {
        buildResult.success = false;
        buildResult.error = result.unwrapErr().message();
    }
    
    return buildResult;
}

/// Wrap a function that may throw into a Result
Result!(T, BuildError) wrap(T)(lazy T expression, string operation = "")
{
    try
    {
        return Ok!(T, BuildError)(expression);
    }
    catch (Exception e)
    {
        auto error = fromException(e);
        if (!operation.empty)
            error.addContext(ErrorContext(operation));
        return Err!(T, BuildError)(error);
    }
}

/// Execute and convert to Result with specific error type
Result!(T, E) wrapAs(T, E : BaseBuildError)(lazy T expression, E delegate(Exception) errorMapper)
{
    try
    {
        return Ok!(T, E)(expression);
    }
    catch (Exception e)
    {
        return Err!(T, E)(errorMapper(e));
    }
}

/// Assert with error result
Result!BuildError ensure(bool condition, lazy BuildError error)
{
    if (!condition)
        return Result!BuildError.err(error);
    return Result!BuildError.ok();
}

/// Create error result from condition
Result!(T, BuildError) check(T)(bool condition, T value, lazy BuildError error)
{
    if (condition)
        return Ok!(T, BuildError)(value);
    return Err!(T, BuildError)(error);
}

/// Create void result from condition
Result!BuildError checkVoid(bool condition, lazy BuildError error)
{
    if (condition)
        return Result!BuildError.ok();
    return Result!BuildError.err(error);
}

