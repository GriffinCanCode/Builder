module errors.recovery;

import std.datetime;
import errors.types;
import errors.codes;

/// Recovery strategy for handling errors
interface RecoveryStrategy
{
    /// Attempt to recover from an error
    /// Returns true if recovery was successful
    bool recover(BuildError error);
    
    /// Get human-readable description of this strategy
    string description() const;
}

/// Retry strategy with exponential backoff
class RetryStrategy : RecoveryStrategy
{
    private size_t maxAttempts;
    private Duration initialDelay;
    private float backoffMultiplier;
    
    this(size_t maxAttempts = 3, Duration initialDelay = 1.seconds, float backoffMultiplier = 2.0)
    {
        this.maxAttempts = maxAttempts;
        this.initialDelay = initialDelay;
        this.backoffMultiplier = backoffMultiplier;
    }
    
    bool recover(BuildError error)
    {
        if (!error.recoverable())
            return false;
        
        // Retry logic would go here
        // This is a placeholder - actual implementation would retry the operation
        return false;
    }
    
    string description() const
    {
        import std.conv;
        return "Retry up to " ~ maxAttempts.to!string ~ " times with exponential backoff";
    }
}

/// Fallback strategy - try alternative approach
class FallbackStrategy : RecoveryStrategy
{
    private bool delegate() fallbackAction;
    
    this(bool delegate() fallbackAction)
    {
        this.fallbackAction = fallbackAction;
    }
    
    bool recover(BuildError error)
    {
        try
        {
            return fallbackAction();
        }
        catch (Exception e)
        {
            return false;
        }
    }
    
    string description() const
    {
        return "Attempt fallback operation";
    }
}

/// Ignore strategy - log and continue
class IgnoreStrategy : RecoveryStrategy
{
    private bool delegate(BuildError) shouldIgnore;
    
    this(bool delegate(BuildError) shouldIgnore = null)
    {
        this.shouldIgnore = shouldIgnore;
    }
    
    bool recover(BuildError error)
    {
        if (shouldIgnore is null)
            return true;
        
        return shouldIgnore(error);
    }
    
    string description() const
    {
        return "Ignore error and continue";
    }
}

/// Recovery manager - applies strategies to errors
class RecoveryManager
{
    private RecoveryStrategy[ErrorCode] strategies;
    
    /// Register a strategy for specific error code
    void registerStrategy(ErrorCode code, RecoveryStrategy strategy)
    {
        strategies[code] = strategy;
    }
    
    /// Register a strategy for multiple error codes
    void registerStrategyForCodes(ErrorCode[] codes, RecoveryStrategy strategy)
    {
        foreach (code; codes)
            strategies[code] = strategy;
    }
    
    /// Attempt to recover from an error
    bool attemptRecovery(BuildError error)
    {
        auto strategy = strategies.get(error.code(), null);
        
        if (strategy is null)
            return false;
        
        return strategy.recover(error);
    }
    
    /// Get recovery strategy for an error
    RecoveryStrategy getStrategy(ErrorCode code)
    {
        return strategies.get(code, null);
    }
}

/// Default recovery manager with common strategies
RecoveryManager createDefaultRecoveryManager()
{
    auto manager = new RecoveryManager();
    
    // Retry transient errors
    auto retryStrategy = new RetryStrategy(3, 1.seconds, 2.0);
    manager.registerStrategyForCodes([
        ErrorCode.BuildTimeout,
        ErrorCode.ProcessTimeout,
        ErrorCode.CacheLoadFailed
    ], retryStrategy);
    
    return manager;
}

/// Execute function with automatic error recovery
auto withRecovery(T)(T delegate() fn, RecoveryManager manager = null)
{
    import errors.result;
    
    if (manager is null)
        manager = createDefaultRecoveryManager();
    
    size_t attempts = 0;
    enum maxAttempts = 3;
    
    while (attempts < maxAttempts)
    {
        try
        {
            return Result!(T, BuildError).ok(fn());
        }
        catch (Exception e)
        {
            // Convert exception to BuildError
            auto error = new InternalError(e.msg);
            
            if (attempts < maxAttempts - 1 && manager.attemptRecovery(error))
            {
                attempts++;
                continue;
            }
            
            return Result!(T, BuildError).err(error);
        }
    }
    
    return Result!(T, BuildError).err(new InternalError("Max recovery attempts exceeded"));
}

