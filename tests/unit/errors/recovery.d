module tests.unit.errors.recovery;

import std.stdio;
import core.time;
import infrastructure.errors.handling.recovery;
import infrastructure.errors.types.types;
import infrastructure.errors.handling.codes;
import tests.harness;

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RetryStrategy basic functionality");
    
    // Create retry strategy with short delays for testing
    auto strategy = new RetryStrategy(3, 1.msecs, 1.5);
    
    // Create recoverable error
    auto cacheError = new CacheError("Temporary failure", ErrorCode.CacheLoadFailed);
    
    // First 3 retries should succeed
    Assert.isTrue(strategy.recover(cacheError));
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 1);
    
    Assert.isTrue(strategy.recover(cacheError));
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 2);
    
    Assert.isTrue(strategy.recover(cacheError));
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 3);
    
    // 4th retry should fail (max attempts reached)
    Assert.isFalse(strategy.recover(cacheError));
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 0); // Counter reset
    
    writeln("\x1b[32m  ✓ RetryStrategy basic functionality works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RetryStrategy with non-recoverable error");
    
    auto strategy = new RetryStrategy(3, 1.msecs, 2.0);
    
    // ParseError is not recoverable
    auto parseError = new ParseError("file.txt", "Syntax error", ErrorCode.ParseFailed);
    
    // Should immediately return false for non-recoverable error
    Assert.isFalse(strategy.recover(parseError));
    Assert.equal(strategy.getAttemptCount(ErrorCode.ParseFailed), 0);
    
    writeln("\x1b[32m  ✓ RetryStrategy correctly handles non-recoverable errors\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RetryStrategy reset functionality");
    
    auto strategy = new RetryStrategy(3, 1.msecs, 2.0);
    auto cacheError = new CacheError("Error", ErrorCode.CacheLoadFailed);
    
    // Use up some attempts
    strategy.recover(cacheError);
    strategy.recover(cacheError);
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 2);
    
    // Reset should clear counters
    strategy.reset();
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 0);
    
    // Should be able to retry again
    Assert.isTrue(strategy.recover(cacheError));
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 1);
    
    writeln("\x1b[32m  ✓ RetryStrategy reset functionality works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RetryStrategy tracks different error codes separately");
    
    auto strategy = new RetryStrategy(3, 1.msecs, 2.0);
    
    auto cacheError = new CacheError("Cache error", ErrorCode.CacheLoadFailed);
    auto timeoutError = new GenericError("Timeout", ErrorCode.BuildTimeout);
    
    // Recover from different error types
    strategy.recover(cacheError);
    strategy.recover(cacheError);
    strategy.recover(timeoutError);
    
    // Should track separately
    Assert.equal(strategy.getAttemptCount(ErrorCode.CacheLoadFailed), 2);
    Assert.equal(strategy.getAttemptCount(ErrorCode.BuildTimeout), 1);
    
    writeln("\x1b[32m  ✓ RetryStrategy tracks different error codes separately\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - FallbackStrategy basic functionality");
    
    bool fallbackCalled = false;
    auto strategy = new FallbackStrategy(() {
        fallbackCalled = true;
        return true;
    });
    
    auto error = new GenericError("Some error", ErrorCode.UnknownError);
    
    Assert.isTrue(strategy.recover(error));
    Assert.isTrue(fallbackCalled);
    
    writeln("\x1b[32m  ✓ FallbackStrategy basic functionality works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - FallbackStrategy handles exceptions");
    
    auto strategy = new FallbackStrategy(() {
        throw new Exception("Fallback failed");
        return true;
    });
    
    auto error = new GenericError("Some error", ErrorCode.UnknownError);
    
    // Should catch exception and return false
    Assert.isFalse(strategy.recover(error));
    
    writeln("\x1b[32m  ✓ FallbackStrategy handles exceptions correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - IgnoreStrategy always succeeds");
    
    auto strategy = new IgnoreStrategy(null);
    
    auto error = new GenericError("Any error", ErrorCode.UnknownError);
    
    // Should always return true (ignore the error)
    Assert.isTrue(strategy.recover(error));
    
    writeln("\x1b[32m  ✓ IgnoreStrategy always succeeds\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - IgnoreStrategy with conditional");
    
    auto strategy = new IgnoreStrategy((BuildError err) {
        // Only ignore cache errors
        return err.code() == ErrorCode.CacheLoadFailed;
    });
    
    auto cacheError = new CacheError("Cache error", ErrorCode.CacheLoadFailed);
    auto parseError = new ParseError("file", "Parse error", ErrorCode.ParseFailed);
    
    Assert.isTrue(strategy.recover(cacheError));
    Assert.isFalse(strategy.recover(parseError));
    
    writeln("\x1b[32m  ✓ IgnoreStrategy with conditional works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RecoveryManager registration and retrieval");
    
    auto manager = new RecoveryManager();
    auto retryStrategy = new RetryStrategy(3, 1.msecs, 2.0);
    
    manager.registerStrategy(ErrorCode.CacheLoadFailed, retryStrategy);
    
    auto retrieved = manager.getStrategy(ErrorCode.CacheLoadFailed);
    Assert.isTrue(retrieved !is null);
    Assert.equal(retrieved, retryStrategy);
    
    // Non-registered error should return null
    Assert.isTrue(manager.getStrategy(ErrorCode.ParseFailed) is null);
    
    writeln("\x1b[32m  ✓ RecoveryManager registration and retrieval works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RecoveryManager multiple error codes");
    
    auto manager = new RecoveryManager();
    auto retryStrategy = new RetryStrategy(3, 1.msecs, 2.0);
    
    manager.registerStrategyForCodes([
        ErrorCode.CacheLoadFailed,
        ErrorCode.BuildTimeout,
        ErrorCode.ProcessTimeout
    ], retryStrategy);
    
    // All three should have the same strategy
    Assert.isTrue(manager.getStrategy(ErrorCode.CacheLoadFailed) !is null);
    Assert.isTrue(manager.getStrategy(ErrorCode.BuildTimeout) !is null);
    Assert.isTrue(manager.getStrategy(ErrorCode.ProcessTimeout) !is null);
    Assert.equal(manager.getStrategy(ErrorCode.CacheLoadFailed), retryStrategy);
    
    writeln("\x1b[32m  ✓ RecoveryManager multiple error codes registration works\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - RecoveryManager attemptRecovery");
    
    auto manager = new RecoveryManager();
    auto retryStrategy = new RetryStrategy(3, 1.msecs, 2.0);
    
    manager.registerStrategy(ErrorCode.CacheLoadFailed, retryStrategy);
    
    auto cacheError = new CacheError("Cache error", ErrorCode.CacheLoadFailed);
    auto parseError = new ParseError("file", "Parse error", ErrorCode.ParseFailed);
    
    // Cache error should be recoverable (has strategy)
    Assert.isTrue(manager.attemptRecovery(cacheError));
    
    // Parse error should not be recoverable (no strategy)
    Assert.isFalse(manager.attemptRecovery(parseError));
    
    writeln("\x1b[32m  ✓ RecoveryManager attemptRecovery works correctly\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - Default recovery manager has expected strategies");
    
    auto manager = createDefaultRecoveryManager();
    
    // Should have strategies for common transient errors
    Assert.isTrue(manager.getStrategy(ErrorCode.BuildTimeout) !is null);
    Assert.isTrue(manager.getStrategy(ErrorCode.ProcessTimeout) !is null);
    Assert.isTrue(manager.getStrategy(ErrorCode.CacheLoadFailed) !is null);
    
    writeln("\x1b[32m  ✓ Default recovery manager has expected strategies\x1b[0m");
}

unittest
{
    writeln("\x1b[36m[TEST]\x1b[0m errors.recovery - Strategy descriptions");
    
    auto retryStrategy = new RetryStrategy(3, 100.msecs, 2.0);
    Assert.notEmpty([retryStrategy.description()]);
    
    auto fallbackStrategy = new FallbackStrategy(() => true);
    Assert.notEmpty([fallbackStrategy.description()]);
    
    auto ignoreStrategy = new IgnoreStrategy(null);
    Assert.notEmpty([ignoreStrategy.description()]);
    
    writeln("\x1b[32m  ✓ Strategy descriptions are non-empty\x1b[0m");
}

