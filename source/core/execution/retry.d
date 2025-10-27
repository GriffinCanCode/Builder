module core.execution.retry;

import std.datetime;
import std.algorithm;
import std.random;
import std.math : pow;
import core.atomic;
import errors;

/// Retry policy configuration
struct RetryPolicy
{
    size_t maxAttempts = 3;
    Duration initialDelay = 100.msecs;
    Duration maxDelay = 30.seconds;
    float backoffMultiplier = 2.0;
    float jitterFactor = 0.1;  // 10% random jitter
    bool exponential = true;
    
    /// Create policy for specific error category
    static RetryPolicy forCategory(ErrorCategory category) pure @safe
    {
        final switch (category)
        {
            case ErrorCategory.System:
                // Network, process issues - aggressive retry
                return RetryPolicy(5, 200.msecs, 60.seconds, 2.0, 0.15, true);
            
            case ErrorCategory.Cache:
                // Cache issues - moderate retry
                return RetryPolicy(3, 100.msecs, 10.seconds, 1.5, 0.1, true);
            
            case ErrorCategory.IO:
                // File system issues - quick retry
                return RetryPolicy(3, 50.msecs, 5.seconds, 2.0, 0.05, true);
            
            case ErrorCategory.Build:
            case ErrorCategory.Parse:
            case ErrorCategory.Analysis:
            case ErrorCategory.Graph:
            case ErrorCategory.Language:
            case ErrorCategory.Internal:
                // Syntax, logic errors - no retry
                return RetryPolicy(1, Duration.zero, Duration.zero, 1.0, 0.0, false);
        }
    }
    
    /// Calculate delay for given attempt with jitter
    Duration delayFor(size_t attempt) const @safe
    {
        if (attempt == 0 || !exponential)
            return Duration.zero;
        
        // Exponential: delay = initial * (multiplier ^ (attempt - 1))
        immutable base = initialDelay.total!"msecs";
        immutable exponent = attempt - 1;
        immutable calculated = cast(long)(base * pow(backoffMultiplier, exponent));
        
        // Cap at max delay
        immutable capped = min(calculated, maxDelay.total!"msecs");
        
        // Add jitter: ±jitterFactor * delay
        auto rng = Mt19937(unpredictableSeed);
        immutable jitter = uniform(-jitterFactor, jitterFactor, rng);
        immutable withJitter = cast(long)(capped * (1.0 + jitter));
        
        return max(withJitter, 0).msecs;
    }
    
    /// Check if should retry based on attempt count
    bool shouldRetry(size_t attempt) const pure nothrow @nogc @safe
    {
        return attempt < maxAttempts;
    }
}

/// Retry statistics for observability
struct RetryStats
{
    size_t totalRetries;
    size_t successfulRetries;
    size_t failedRetries;
    size_t[ErrorCode] retriesByCode;
    Duration totalDelay;
    
    /// Record a retry attempt
    void recordAttempt(ErrorCode code, Duration delay, bool success) @safe
    {
        totalRetries++;
        if (success)
            successfulRetries++;
        else
            failedRetries++;
        
        retriesByCode[code] = retriesByCode.get(code, 0) + 1;
        totalDelay += delay;
    }
    
    /// Get success rate
    float successRate() const pure nothrow @nogc @safe
    {
        if (totalRetries == 0)
            return 0.0;
        return cast(float)successfulRetries / cast(float)totalRetries;
    }
}

/// Retry context - tracks state for single operation
struct RetryContext
{
    string operationId;      // Target ID
    size_t currentAttempt;   // Current attempt number (0-indexed)
    BuildError lastError;    // Last error encountered
    RetryPolicy policy;      // Policy for this operation
    SysTime startTime;       // When retry sequence started
    
    this(string operationId, RetryPolicy policy) @safe
    {
        this.operationId = operationId;
        this.policy = policy;
        this.startTime = Clock.currTime();
        this.currentAttempt = 0;
    }
    
    /// Check if should retry
    bool shouldRetry() const pure nothrow @nogc @safe
    {
        return policy.shouldRetry(currentAttempt);
    }
    
    /// Get next delay
    Duration nextDelay() const @safe
    {
        return policy.delayFor(currentAttempt + 1);
    }
    
    /// Record attempt
    void recordAttempt(BuildError error) @safe
    {
        currentAttempt++;
        lastError = error;
    }
    
    /// Get total elapsed time
    Duration elapsed() const @safe
    {
        return Clock.currTime() - startTime;
    }
}

/// Retry orchestrator - coordinates retry logic
final class RetryOrchestrator
{
    private RetryStats stats;
    private shared bool enabled;
    private RetryPolicy defaultPolicy;
    private RetryPolicy[ErrorCode] customPolicies;
    
    this(RetryPolicy defaultPolicy = RetryPolicy.init) @safe
    {
        this.defaultPolicy = defaultPolicy;
        atomicStore(enabled, true);
        
        // Register transient error codes
        registerTransientErrors();
    }
    
    /// Enable/disable retry system
    void setEnabled(bool value) nothrow @trusted @nogc
    {
        atomicStore(enabled, value);
    }
    
    /// Check if enabled
    bool isEnabled() const nothrow @trusted @nogc
    {
        return atomicLoad(enabled);
    }
    
    /// Register custom policy for specific error code
    void registerPolicy(ErrorCode code, RetryPolicy policy) @safe
    {
        customPolicies[code] = policy;
    }
    
    /// Get policy for error
    RetryPolicy policyFor(BuildError error) const @trusted
    {
        // Check custom policy
        if (auto policy = error.code() in customPolicies)
            return *policy;
        
        // Use category-based policy
        return RetryPolicy.forCategory(error.category());
    }
    
    /// Execute operation with retry
    Result!(T, BuildError) withRetry(T)(
        string operationId,
        Result!(T, BuildError) delegate() operation,
        RetryPolicy policy = RetryPolicy.init
    ) @trusted
    {
        if (!isEnabled() || policy.maxAttempts <= 1)
            return operation();
        
        auto ctx = RetryContext(operationId, policy);
        
        while (true)
        {
            auto result = operation();
            
            if (result.isOk)
            {
                // Success - record if retried
                if (ctx.currentAttempt > 0)
                {
                    stats.recordAttempt(
                        ctx.lastError ? ctx.lastError.code() : ErrorCode.InternalError,
                        ctx.elapsed(),
                        true
                    );
                }
                return result;
            }
            
            auto error = result.unwrapErr();
            ctx.recordAttempt(error);
            
            // Check if recoverable
            if (!error.recoverable())
            {
                // Not recoverable - fail immediately
                return result;
            }
            
            // Check retry limit
            if (!ctx.shouldRetry())
            {
                // Max attempts exceeded
                stats.recordAttempt(error.code(), ctx.elapsed(), false);
                return result;
            }
            
            // Wait before retry
            immutable delay = ctx.nextDelay();
            if (delay > Duration.zero)
            {
                import core.thread : Thread;
                Thread.sleep(delay);
            }
        }
    }
    
    /// Get current statistics
    RetryStats getStats() const @trusted
    {
        return cast(RetryStats)stats;
    }
    
    /// Reset statistics
    void resetStats() @safe
    {
        stats = RetryStats.init;
    }
    
    private void registerTransientErrors() @safe
    {
        // Network/IO transient errors
        registerPolicy(ErrorCode.ProcessTimeout, 
            RetryPolicy(3, 200.msecs, 10.seconds, 2.0, 0.1, true));
        
        registerPolicy(ErrorCode.BuildTimeout,
            RetryPolicy(2, 1.seconds, 30.seconds, 2.0, 0.15, true));
        
        // Cache transient errors
        registerPolicy(ErrorCode.CacheLoadFailed,
            RetryPolicy(3, 100.msecs, 5.seconds, 1.5, 0.1, true));
        
        registerPolicy(ErrorCode.CacheEvictionFailed,
            RetryPolicy(2, 50.msecs, 2.seconds, 1.5, 0.05, true));
        
        // File system transient errors (NFS, network drives)
        registerPolicy(ErrorCode.FileReadFailed,
            RetryPolicy(3, 50.msecs, 2.seconds, 2.0, 0.1, true));
        
        registerPolicy(ErrorCode.FileWriteFailed,
            RetryPolicy(3, 50.msecs, 2.seconds, 2.0, 0.1, true));
    }
}

/// Convenience function for retry with default orchestrator
private __gshared RetryOrchestrator defaultOrchestrator;

shared static this()
{
    defaultOrchestrator = new RetryOrchestrator();
}

/// Execute with automatic retry using default orchestrator
Result!(T, BuildError) retry(T)(
    string operationId,
    Result!(T, BuildError) delegate() operation
) @trusted
{
    return defaultOrchestrator.withRetry(operationId, operation);
}

