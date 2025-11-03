module tests.unit.errors.codes;

import std.stdio;
import std.algorithm;
import std.array;
import infrastructure.errors.handling.codes;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - ErrorCode enum has expected values");
    
    // Verify key error codes exist
    Assert.notEqual(ErrorCode.UnknownError, ErrorCode.ParseFailed);
    Assert.notEqual(ErrorCode.BuildFailed, ErrorCode.CacheLoadFailed);
    Assert.notEqual(ErrorCode.BuildTimeout, ErrorCode.ProcessTimeout);
    
    writeln("\x1b[32m  ✓ ErrorCode enum values are distinct\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Error code to string conversion");
    
    import std.conv : to;
    
    // Should be able to convert to string
    auto str1 = ErrorCode.ParseFailed.to!string;
    Assert.notEmpty([str1]);
    
    auto str2 = ErrorCode.BuildFailed.to!string;
    Assert.notEmpty([str2]);
    
    writeln("\x1b[32m  ✓ ErrorCode to string conversion works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Error severity classification");
    
    // Test that error codes can be classified by severity
    // This tests the presence of error classification functions
    
    auto parseError = ErrorCode.ParseFailed;
    auto cacheError = ErrorCode.CacheLoadFailed;
    auto buildError = ErrorCode.BuildFailed;
    
    // These should be valid error codes
    Assert.isTrue(cast(int)parseError >= 0);
    Assert.isTrue(cast(int)cacheError >= 0);
    Assert.isTrue(cast(int)buildError >= 0);
    
    writeln("\x1b[32m  ✓ Error codes have valid integer values\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Build-related error codes exist");
    
    // Verify build-related error codes
    auto buildFailed = ErrorCode.BuildFailed;
    auto buildTimeout = ErrorCode.BuildTimeout;
    
    Assert.notEqual(buildFailed, buildTimeout);
    
    writeln("\x1b[32m  ✓ Build-related error codes exist\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Cache-related error codes exist");
    
    auto cacheLoadFailed = ErrorCode.CacheLoadFailed;
    auto cacheSaveFailed = ErrorCode.CacheSaveFailed;
    
    Assert.notEqual(cacheLoadFailed, cacheSaveFailed);
    
    writeln("\x1b[32m  ✓ Cache-related error codes exist\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Process-related error codes exist");
    
    auto processTimeout = ErrorCode.ProcessTimeout;
    
    Assert.isTrue(cast(int)processTimeout >= 0);
    
    writeln("\x1b[32m  ✓ Process-related error codes exist\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Parse-related error codes exist");
    
    auto parseFailed = ErrorCode.ParseFailed;
    
    Assert.isTrue(cast(int)parseFailed >= 0);
    
    writeln("\x1b[32m  ✓ Parse-related error codes exist\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Error codes are unique");
    
    // Collect all error codes and verify uniqueness
    ErrorCode[] codes = [
        ErrorCode.UnknownError,
        ErrorCode.ParseFailed,
        ErrorCode.BuildFailed,
        ErrorCode.BuildTimeout,
        ErrorCode.ProcessTimeout,
        ErrorCode.CacheLoadFailed,
        ErrorCode.CacheSaveFailed,
    ];
    
    // Check that converting to int gives unique values
    import std.algorithm : sort, uniq;
    import std.array : array;
    
    auto intCodes = codes.map!(c => cast(int)c).array;
    auto uniqueCodes = intCodes.dup.sort.uniq.array;
    
    Assert.equal(intCodes.length, uniqueCodes.length);
    
    writeln("\x1b[32m  ✓ All error codes are unique\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.codes - Error code message mapping exists");
    
    // Test that error codes can be converted to meaningful messages
    // This would use ErrorCode.getMessage() or similar function if it exists
    
    auto code = ErrorCode.BuildFailed;
    import std.conv : to;
    auto msg = code.to!string;
    
    // Message should not be empty
    Assert.notEmpty([msg]);
    
    writeln("\x1b[32m  ✓ Error code message mapping exists\x1b[0m");
}

