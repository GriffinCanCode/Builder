module core.distributed.worker.steal;

import std.datetime : Duration, MonoTime, msecs, seconds;
import std.algorithm : min, max;
import std.random : uniform;
import core.atomic;
import core.thread : Thread;
import core.distributed.protocol.protocol;
import core.distributed.protocol.protocol : NetworkError, DistributedError;
import core.distributed.protocol.transport;
import core.distributed.worker.peers;
import errors : BuildError, Result, Ok, Err;
import utils.logging.logger;

/// Work-stealing strategy
enum StealStrategy
{
    Random,         // Random victim selection
    LeastLoaded,    // Target least loaded peer
    MostLoaded,     // Target most loaded peer
    PowerOfTwo,     // Power-of-two-choices (default)
    Adaptive        // Dynamically adjust based on success rate
}

/// Work-stealing configuration
struct StealConfig
{
    StealStrategy strategy = StealStrategy.PowerOfTwo;
    Duration stealTimeout = 100.msecs;      // Timeout for steal attempt
    Duration retryBackoff = 50.msecs;       // Backoff between retries
    size_t maxRetries = 3;                  // Max steal attempts
    size_t minLocalQueue = 2;               // Min local work before stealing
    float stealThreshold = 0.5;             // Load threshold to trigger steal
}

/// Work-stealing metrics
struct StealMetrics
{
    shared size_t attempts;         // Total steal attempts
    shared size_t successes;        // Successful steals
    shared size_t failures;         // Failed steals
    shared size_t timeouts;         // Timed out steals
    shared size_t networkErrors;    // Network errors
    
    /// Calculate success rate
    float successRate() const @trusted nothrow @nogc
    {
        immutable total = atomicLoad(attempts);
        if (total == 0)
            return 0.0;
        
        immutable success = atomicLoad(successes);
        return cast(float)success / cast(float)total;
    }
}

/// Work-stealing engine
/// Implements distributed work-stealing protocol between peers
final class StealEngine
{
    private PeerRegistry peers;
    private StealConfig config;
    private StealMetrics metrics;
    private WorkerId selfId;
    
    this(WorkerId selfId, PeerRegistry peers, StealConfig config = StealConfig.init) @safe
    {
        this.selfId = selfId;
        this.peers = peers;
        this.config = config;
    }
    
    /// Attempt to steal work from a peer
    /// Returns ActionRequest if successful, null otherwise
    ActionRequest steal() @trusted
    {
        atomicOp!"+="(metrics.attempts, 1);
        
        // Select victim using configured strategy
        auto victimResult = selectVictim();
        if (victimResult.isErr)
        {
            atomicOp!"+="(metrics.failures, 1);
            return null;
        }
        
        auto victimId = victimResult.unwrap();
        
        // Try to steal from victim with retries
        for (size_t attempt = 0; attempt < config.maxRetries; attempt++)
        {
            auto result = trySteal(victimId);
            
            if (result.isOk)
            {
                auto action = result.unwrap();
                if (action !is null)
                {
                    atomicOp!"+="(metrics.successes, 1);
                    Logger.debugLog("Stole work from " ~ victimId.toString());
                    return action;
                }
            }
            else
            {
                auto err = result.unwrapErr();
                
                // Handle specific error types
                if (cast(NetworkError)err !is null)
                {
                    atomicOp!"+="(metrics.networkErrors, 1);
                    peers.markDead(victimId);
                    break;  // Don't retry on network errors
                }
            }
            
            // Backoff before retry
            if (attempt < config.maxRetries - 1)
            {
                immutable delay = config.retryBackoff * (1 << attempt);  // Exponential backoff
                Thread.sleep(delay);
            }
        }
        
        atomicOp!"+="(metrics.failures, 1);
        return null;
    }
    
    /// Handle steal request from another worker
    /// Returns ActionRequest if available, null otherwise
    ActionRequest handleStealRequest(WorkerId thiefId, size_t localQueueSize) @trusted
    {
        // Only allow stealing if we have enough work
        if (localQueueSize <= config.minLocalQueue)
            return null;
        
        // Implementation depends on queue structure
        // This would integrate with WorkStealingDeque
        // For now, return null (will be implemented when integrated with worker)
        
        Logger.debugLog("Steal request from " ~ thiefId.toString());
        return null;
    }
    
    /// Get metrics
    StealMetrics getMetrics() @trusted const nothrow @nogc
    {
        return metrics;
    }
    
    /// Reset metrics
    void resetMetrics() @trusted nothrow @nogc
    {
        atomicStore(metrics.attempts, cast(size_t)0);
        atomicStore(metrics.successes, cast(size_t)0);
        atomicStore(metrics.failures, cast(size_t)0);
        atomicStore(metrics.timeouts, cast(size_t)0);
        atomicStore(metrics.networkErrors, cast(size_t)0);
    }
    
    private:
    
    /// Select victim based on strategy
    Result!(WorkerId, DistributedError) selectVictim() @trusted
    {
        final switch (config.strategy)
        {
            case StealStrategy.Random:
                return selectRandom();
            
            case StealStrategy.LeastLoaded:
                return selectLeastLoaded();
            
            case StealStrategy.MostLoaded:
                return selectMostLoaded();
            
            case StealStrategy.PowerOfTwo:
                return peers.selectVictim();  // Uses power-of-two-choices
            
            case StealStrategy.Adaptive:
                return selectAdaptive();
        }
    }
    
    /// Random victim selection
    Result!(WorkerId, DistributedError) selectRandom() @trusted
    {
        auto alivePeers = peers.getAlivePeers();
        
        if (alivePeers.length == 0)
            return Err!(WorkerId, DistributedError)(
                new DistributedError("No alive peers"));
        
        immutable idx = uniform(0, alivePeers.length);
        return Ok!(WorkerId, DistributedError)(alivePeers[idx].id);
    }
    
    /// Select least loaded peer
    Result!(WorkerId, DistributedError) selectLeastLoaded() @trusted
    {
        auto alivePeers = peers.getAlivePeers();
        
        if (alivePeers.length == 0)
            return Err!(WorkerId, DistributedError)(
                new DistributedError("No alive peers"));
        
        PeerInfo best = alivePeers[0];
        foreach (peer; alivePeers[1 .. $])
        {
            if (atomicLoad(peer.loadFactor) < atomicLoad(best.loadFactor))
                best = peer;
        }
        
        return Ok!(WorkerId, DistributedError)(best.id);
    }
    
    /// Select most loaded peer (best victim)
    Result!(WorkerId, DistributedError) selectMostLoaded() @trusted
    {
        auto alivePeers = peers.getAlivePeers();
        
        if (alivePeers.length == 0)
            return Err!(WorkerId, DistributedError)(
                new DistributedError("No alive peers"));
        
        PeerInfo best = alivePeers[0];
        foreach (peer; alivePeers[1 .. $])
        {
            if (atomicLoad(peer.queueDepth) > atomicLoad(best.queueDepth))
                best = peer;
        }
        
        // Only steal if victim has significant work
        if (atomicLoad(best.queueDepth) < 4)
            return Err!(WorkerId, DistributedError)(
                new DistributedError("No suitable victims"));
        
        return Ok!(WorkerId, DistributedError)(best.id);
    }
    
    /// Adaptive strategy - switch based on success rate
    Result!(WorkerId, DistributedError) selectAdaptive() @trusted
    {
        immutable successRate = metrics.successRate();
        
        // If success rate is low, try most loaded (more aggressive)
        if (successRate < 0.3)
            return selectMostLoaded();
        
        // If success rate is good, use power-of-two (balanced)
        return peers.selectVictim();
    }
    
    /// Try to steal from specific victim
    Result!(ActionRequest, DistributedError) trySteal(WorkerId victimId) @trusted
    {
        // Get victim address
        auto peerResult = peers.getPeer(victimId);
        if (peerResult.isErr)
            return Err!(ActionRequest, DistributedError)(peerResult.unwrapErr());
        
        auto peer = peerResult.unwrap();
        
        // Create steal request
        StealRequest req;
        req.thief = selfId;
        req.victim = victimId;
        req.minPriority = Priority.Low;
        
        // Send steal request via transport
        // This would use the transport layer to send the request
        // For now, simplified implementation
        
        // Timeout handling
        auto startTime = MonoTime.currTime;
        auto deadline = startTime + config.stealTimeout;
        
        // Would actually send request and wait for response
        // For now, return null (no work stolen)
        
        if (MonoTime.currTime >= deadline)
        {
            atomicOp!"+="(metrics.timeouts, 1);
            return Err!(ActionRequest, DistributedError)(
                new DistributedError("Steal timeout"));
        }
        
        return Ok!(ActionRequest, DistributedError)(null);
    }
}

/// Exponential backoff for failed steal attempts
/// Reduces contention and network load
struct BackoffStrategy
{
    private size_t attempt;
    private Duration baseDelay = 10.msecs;
    private Duration maxDelay = 1000.msecs;
    
    this(Duration baseDelay, Duration maxDelay) pure @safe nothrow @nogc
    {
        this.baseDelay = baseDelay;
        this.maxDelay = maxDelay;
        this.attempt = 0;
    }
    
    /// Create with default parameters
    static BackoffStrategy create() pure @safe nothrow @nogc
    {
        return BackoffStrategy(10.msecs, 1000.msecs);
    }
    
    /// Get next backoff duration
    Duration next() @safe nothrow @nogc
    {
        immutable delay = min(
            baseDelay * (1 << attempt),
            maxDelay
        );
        
        attempt++;
        return delay;
    }
    
    /// Reset backoff
    void reset() pure @safe nothrow @nogc
    {
        attempt = 0;
    }
    
    /// Get current attempt count
    size_t currentAttempt() const pure @safe nothrow @nogc
    {
        return attempt;
    }
}



