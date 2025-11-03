module infrastructure.resilience.policy;

import std.datetime;
import infrastructure.resilience.breaker;
import infrastructure.resilience.limiter;
import infrastructure.errors;

/// Resilience policy combining circuit breaker and rate limiter
struct ResiliencePolicy
{
    BreakerConfig breakerConfig;
    LimiterConfig limiterConfig;
    bool enableBreaker = true;
    bool enableLimiter = true;
}

/// Policy presets for common scenarios
struct PolicyPresets
{
    /// Aggressive policy for critical services (strict limits)
    static ResiliencePolicy critical() pure @safe nothrow
    {
        ResiliencePolicy policy;
        
        // Circuit breaker: fail fast
        policy.breakerConfig.failureThreshold = 0.3;
        policy.breakerConfig.minRequests = 5;
        policy.breakerConfig.windowSize = 15.seconds;
        policy.breakerConfig.timeout = 30.seconds;
        
        // Rate limiter: conservative
        policy.limiterConfig.ratePerSecond = 50;
        policy.limiterConfig.burstCapacity = 75;
        policy.limiterConfig.adaptive = true;
        policy.limiterConfig.minRate = 0.2;
        policy.limiterConfig.maxRate = 1.2;
        
        return policy;
    }
    
    /// Balanced policy for normal services
    static ResiliencePolicy standard() pure @safe nothrow
    {
        ResiliencePolicy policy;
        
        // Circuit breaker: moderate
        policy.breakerConfig.failureThreshold = 0.5;
        policy.breakerConfig.minRequests = 10;
        policy.breakerConfig.windowSize = 30.seconds;
        policy.breakerConfig.timeout = 60.seconds;
        
        // Rate limiter: balanced
        policy.limiterConfig.ratePerSecond = 100;
        policy.limiterConfig.burstCapacity = 200;
        policy.limiterConfig.adaptive = true;
        
        return policy;
    }
    
    /// Relaxed policy for best-effort services
    static ResiliencePolicy relaxed() pure @safe nothrow
    {
        ResiliencePolicy policy;
        
        // Circuit breaker: tolerant
        policy.breakerConfig.failureThreshold = 0.7;
        policy.breakerConfig.minRequests = 20;
        policy.breakerConfig.windowSize = 60.seconds;
        policy.breakerConfig.timeout = 120.seconds;
        
        // Rate limiter: generous
        policy.limiterConfig.ratePerSecond = 200;
        policy.limiterConfig.burstCapacity = 500;
        policy.limiterConfig.adaptive = true;
        policy.limiterConfig.maxRate = 2.0;
        
        return policy;
    }
    
    /// Network-optimized for remote cache/distributed systems
    static ResiliencePolicy network() pure @safe nothrow
    {
        ResiliencePolicy policy;
        
        // Circuit breaker: network-aware
        policy.breakerConfig.failureThreshold = 0.4;
        policy.breakerConfig.minRequests = 8;
        policy.breakerConfig.windowSize = 20.seconds;
        policy.breakerConfig.timeout = 45.seconds;
        policy.breakerConfig.onlyCountNetworkErrors = true;
        
        // Rate limiter: burst-friendly for batching
        policy.limiterConfig.ratePerSecond = 150;
        policy.limiterConfig.burstCapacity = 300;
        policy.limiterConfig.adaptive = true;
        policy.limiterConfig.minRate = 0.1;
        
        return policy;
    }
    
    /// High-throughput for worker communication
    static ResiliencePolicy highThroughput() pure @safe nothrow
    {
        ResiliencePolicy policy;
        
        // Circuit breaker: fail fast but tolerant of transient issues
        policy.breakerConfig.failureThreshold = 0.6;
        policy.breakerConfig.minRequests = 15;
        policy.breakerConfig.windowSize = 45.seconds;
        policy.breakerConfig.timeout = 60.seconds;
        
        // Rate limiter: high capacity
        policy.limiterConfig.ratePerSecond = 500;
        policy.limiterConfig.burstCapacity = 1000;
        policy.limiterConfig.adaptive = true;
        policy.limiterConfig.adjustmentSpeed = 0.1;
        
        return policy;
    }
    
    /// Disable all protections (for testing/debugging)
    static ResiliencePolicy none() pure @safe nothrow
    {
        ResiliencePolicy policy;
        policy.enableBreaker = false;
        policy.enableLimiter = false;
        return policy;
    }
}

/// Per-endpoint resilience configuration
struct EndpointPolicy
{
    string endpoint;
    ResiliencePolicy policy;
    Priority defaultPriority = Priority.Normal;
}

/// Policy configuration builder
struct PolicyBuilder
{
    private ResiliencePolicy policy;
    
    static PolicyBuilder create() pure @safe nothrow
    {
        PolicyBuilder builder;
        builder.policy = PolicyPresets.standard();
        return builder;
    }
    
    static PolicyBuilder fromPreset(ResiliencePolicy preset) pure @safe nothrow
    {
        PolicyBuilder builder;
        builder.policy = preset;
        return builder;
    }
    
    ref PolicyBuilder withBreakerThreshold(float threshold) return pure @safe nothrow
    {
        policy.breakerConfig.failureThreshold = threshold;
        return this;
    }
    
    ref PolicyBuilder withBreakerWindow(Duration window) return pure @safe nothrow
    {
        policy.breakerConfig.windowSize = window;
        return this;
    }
    
    ref PolicyBuilder withBreakerTimeout(Duration timeout) return pure @safe nothrow
    {
        policy.breakerConfig.timeout = timeout;
        return this;
    }
    
    ref PolicyBuilder withRateLimit(size_t rps) return pure @safe nothrow
    {
        policy.limiterConfig.ratePerSecond = rps;
        return this;
    }
    
    ref PolicyBuilder withBurstCapacity(size_t capacity) return pure @safe nothrow
    {
        policy.limiterConfig.burstCapacity = capacity;
        return this;
    }
    
    ref PolicyBuilder adaptive(bool enable) return pure @safe nothrow
    {
        policy.limiterConfig.adaptive = enable;
        return this;
    }
    
    ref PolicyBuilder enableBreaker(bool enable) return pure @safe nothrow
    {
        policy.enableBreaker = enable;
        return this;
    }
    
    ref PolicyBuilder enableLimiter(bool enable) return pure @safe nothrow
    {
        policy.enableLimiter = enable;
        return this;
    }
    
    ResiliencePolicy build() pure @safe nothrow
    {
        return policy;
    }
}

