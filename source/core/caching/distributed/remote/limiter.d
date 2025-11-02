module core.caching.distributed.remote.limiter;

import std.datetime : Clock, SysTime, Duration, seconds, msecs;
import core.atomic;
import core.sync.mutex : Mutex;
import std.algorithm : min;

/// Token bucket rate limiter with atomic operations
/// Implements hierarchical rate limiting with reputation tracking
final class RateLimiter
{
    private shared long tokens;
    private shared long maxTokens;
    private shared long refillRate;  // tokens per second
    private shared long lastRefill;  // stdTime
    private Mutex mutex;
    
    /// Constructor
    this(size_t maxTokens, size_t refillRate) @trusted
    {
        atomicStore(this.tokens, cast(long)maxTokens);
        atomicStore(this.maxTokens, cast(long)maxTokens);
        atomicStore(this.refillRate, cast(long)refillRate);
        atomicStore(this.lastRefill, Clock.currStdTime());
        this.mutex = new Mutex();
    }
    
    /// Try to consume tokens (returns true if allowed)
    bool tryConsume(size_t count = 1) @trusted
    {
        refillTokens();
        
        while (true)
        {
            immutable current = atomicLoad(tokens);
            if (current < count)
                return false;
            
            immutable updated = current - count;
            if (cas(&tokens, current, updated))
                return true;
        }
    }
    
    /// Get remaining tokens
    size_t remaining() @trusted nothrow @nogc
    {
        immutable current = atomicLoad(tokens);
        return current > 0 ? cast(size_t)current : 0;
    }
    
    /// Calculate time until next token available
    Duration timeUntilAvailable(size_t count = 1) @trusted
    {
        refillTokens();
        
        immutable current = atomicLoad(tokens);
        if (current >= count)
            return Duration.zero;
        
        immutable needed = count - current;
        immutable rate = atomicLoad(refillRate);
        if (rate == 0)
            return Duration.max;
        
        immutable secondsNeeded = (needed + rate - 1) / rate;
        return secondsNeeded.seconds;
    }
    
    private void refillTokens() @trusted nothrow
    {
        try
        {
            immutable now = Clock.currStdTime();
            immutable last = atomicLoad(lastRefill);
            immutable elapsed = (now - last) / 10_000_000; // Convert to seconds
            
            if (elapsed == 0)
                return;
            
            immutable rate = atomicLoad(refillRate);
            immutable toAdd = elapsed * rate;
            
            if (toAdd > 0)
            {
                while (true)
                {
                    immutable current = atomicLoad(tokens);
                    immutable max = atomicLoad(maxTokens);
                    immutable updated = min(current + toAdd, max);
                    
                    if (cas(&tokens, current, updated))
                    {
                        atomicStore(lastRefill, now);
                        break;
                    }
                }
            }
        }
        catch (Exception) {}
    }
}

/// Hierarchical rate limiter with per-IP and per-token limits
final class HierarchicalLimiter
{
    private Mutex mutex;
    private RateLimiter globalLimiter;
    private RateLimiter[string] ipLimiters;
    private RateLimiter[string] tokenLimiters;
    private ReputationTracker reputation;
    
    // Configuration
    private size_t globalMax;
    private size_t globalRate;
    private size_t ipMax;
    private size_t ipRate;
    private size_t tokenMax;
    private size_t tokenRate;
    
    /// Constructor with configurable limits
    this(
        size_t globalMax = 10_000,
        size_t globalRate = 1_000,
        size_t ipMax = 100,
        size_t ipRate = 10,
        size_t tokenMax = 500,
        size_t tokenRate = 50
    ) @trusted
    {
        this.mutex = new Mutex();
        this.globalMax = globalMax;
        this.globalRate = globalRate;
        this.ipMax = ipMax;
        this.ipRate = ipRate;
        this.tokenMax = tokenMax;
        this.tokenRate = tokenRate;
        
        this.globalLimiter = new RateLimiter(globalMax, globalRate);
        this.reputation = new ReputationTracker();
    }
    
    /// Check if request is allowed
    bool allow(string ip, string token, size_t cost = 1) @trusted
    {
        // Check global limit first
        if (!globalLimiter.tryConsume(cost))
            return false;
        
        // Check IP limit
        auto ipLimiter = getIpLimiter(ip);
        if (!ipLimiter.tryConsume(cost))
            return false;
        
        // Check token limit (if authenticated)
        if (token.length > 0)
        {
            auto tokenLimiter = getTokenLimiter(token);
            if (!tokenLimiter.tryConsume(cost))
                return false;
        }
        
        // Update reputation on success
        reputation.recordSuccess(ip);
        
        return true;
    }
    
    /// Get time until request allowed
    Duration retryAfter(string ip, string token, size_t cost = 1) @trusted
    {
        auto ipLimiter = getIpLimiter(ip);
        auto ipWait = ipLimiter.timeUntilAvailable(cost);
        
        if (token.length == 0)
            return ipWait;
        
        auto tokenLimiter = getTokenLimiter(token);
        auto tokenWait = tokenLimiter.timeUntilAvailable(cost);
        
        return ipWait > tokenWait ? ipWait : tokenWait;
    }
    
    /// Record failed request (for reputation)
    void recordFailure(string ip) @trusted
    {
        reputation.recordFailure(ip);
    }
    
    /// Get IP reputation score (0.0-1.0)
    float getReputation(string ip) @trusted
    {
        return reputation.getScore(ip);
    }
    
    private RateLimiter getIpLimiter(string ip) @trusted
    {
        synchronized (mutex)
        {
            auto limiter = ipLimiters.get(ip, null);
            if (limiter is null)
            {
                // Adjust limits based on reputation
                immutable score = reputation.getScore(ip);
                immutable adjustedMax = cast(size_t)(ipMax * (0.5 + score * 0.5));
                immutable adjustedRate = cast(size_t)(ipRate * (0.5 + score * 0.5));
                
                limiter = new RateLimiter(adjustedMax, adjustedRate);
                ipLimiters[ip] = limiter;
            }
            return limiter;
        }
    }
    
    private RateLimiter getTokenLimiter(string token) @trusted
    {
        synchronized (mutex)
        {
            auto limiter = tokenLimiters.get(token, null);
            if (limiter is null)
            {
                limiter = new RateLimiter(tokenMax, tokenRate);
                tokenLimiters[token] = limiter;
            }
            return limiter;
        }
    }
    
    /// Cleanup old limiters (call periodically)
    void cleanup() @trusted
    {
        synchronized (mutex)
        {
            // Remove limiters with full tokens (unused)
            string[] toRemove;
            
            foreach (ip, limiter; ipLimiters)
            {
                if (limiter.remaining() >= ipMax)
                    toRemove ~= ip;
            }
            
            foreach (ip; toRemove)
                ipLimiters.remove(ip);
        }
    }
}

/// Simple reputation tracker for adaptive rate limiting
private final class ReputationTracker
{
    private struct Score
    {
        size_t successes;
        size_t failures;
        SysTime lastUpdate;
        
        float compute() const pure nothrow @safe @nogc
        {
            immutable total = successes + failures;
            if (total == 0)
                return 0.5; // Neutral
            
            return cast(float)successes / cast(float)total;
        }
    }
    
    private Score[string] scores;
    private Mutex mutex;
    
    this() @trusted
    {
        mutex = new Mutex();
    }
    
    void recordSuccess(string ip) @trusted
    {
        synchronized (mutex)
        {
            auto score = scores.get(ip, Score.init);
            score.successes++;
            score.lastUpdate = Clock.currTime();
            scores[ip] = score;
        }
    }
    
    void recordFailure(string ip) @trusted
    {
        synchronized (mutex)
        {
            auto score = scores.get(ip, Score.init);
            score.failures++;
            score.lastUpdate = Clock.currTime();
            scores[ip] = score;
        }
    }
    
    float getScore(string ip) @trusted
    {
        synchronized (mutex)
        {
            auto score = scores.get(ip, Score.init);
            return score.compute();
        }
    }
}

