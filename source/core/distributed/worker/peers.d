module core.distributed.worker.peers;

import std.datetime : Duration, Clock, SysTime, seconds;
import std.algorithm : filter, map, remove;
import std.array : array;
import std.random : uniform;
import core.sync.mutex : Mutex;
import core.atomic;
import core.distributed.protocol.protocol;
import errors : BuildError, DistributedError, Result, Ok, Err;
import utils.logging.logger;

/// Peer worker information for work-stealing
struct PeerInfo
{
    WorkerId id;                    // Peer worker ID
    string address;                 // Network address
    SysTime lastSeen;               // Last heartbeat
    shared size_t queueDepth;       // Approximate queue size
    shared float loadFactor;        // Load metric [0.0, 1.0]
    shared bool alive;              // Connection health
}

/// Peer discovery and management for distributed work-stealing
/// Thread-safe: All operations protected by mutex or atomic operations
final class PeerRegistry
{
    private PeerInfo[WorkerId] peers;
    private Mutex mutex;
    private WorkerId selfId;
    private Duration staleThreshold;
    
    private enum size_t MAX_PEERS = 1024;
    private enum Duration DEFAULT_STALE = 30.seconds;
    
    this(WorkerId selfId, Duration staleThreshold = DEFAULT_STALE) @trusted
    {
        this.selfId = selfId;
        this.staleThreshold = staleThreshold;
        this.mutex = new Mutex();
    }
    
    /// Register peer worker
    Result!DistributedError register(WorkerId id, string address) @trusted
    {
        if (id.value == selfId.value)
            return Ok!DistributedError();  // Don't register self
        
        synchronized (mutex)
        {
            if (peers.length >= MAX_PEERS)
                return Err!DistributedError(
                    new DistributedError("Peer registry full"));
            
            PeerInfo info;
            info.id = id;
            info.address = address;
            info.lastSeen = Clock.currTime;
            atomicStore(info.queueDepth, cast(size_t)0);
            atomicStore(info.loadFactor, 0.0f);
            atomicStore(info.alive, true);
            
            peers[id] = info;
            
            Logger.debugLog("Peer registered: " ~ id.toString() ~ " @ " ~ address);
        }
        
        return Ok!DistributedError();
    }
    
    /// Unregister peer worker
    void unregister(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            peers.remove(id);
            Logger.debugLog("Peer unregistered: " ~ id.toString());
        }
    }
    
    /// Update peer metrics
    void updateMetrics(WorkerId id, size_t queueDepth, float loadFactor) @trusted
    {
        synchronized (mutex)
        {
            if (auto peer = id in peers)
            {
                peer.lastSeen = Clock.currTime;
                atomicStore(peer.queueDepth, queueDepth);
                atomicStore(peer.loadFactor, loadFactor);
                atomicStore(peer.alive, true);
            }
        }
    }
    
    /// Mark peer as dead/unreachable
    void markDead(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto peer = id in peers)
            {
                atomicStore(peer.alive, false);
                Logger.warning("Peer marked dead: " ~ id.toString());
            }
        }
    }
    
    /// Select best victim for work-stealing using power-of-two-choices
    /// Returns WorkerId of victim, or null result if none suitable
    Result!(WorkerId, DistributedError) selectVictim() @trusted
    {
        import std.algorithm : maxElement;
        
        synchronized (mutex)
        {
            // Filter to alive peers with work
            auto candidates = peers.values
                .filter!(p => atomicLoad(p.alive))
                .filter!(p => atomicLoad(p.queueDepth) >= MIN_QUEUE_FOR_STEAL)
                .array;
            
            if (candidates.length == 0)
                return Err!(WorkerId, DistributedError)(
                    new DistributedError("No suitable victims"));
            
            // Power-of-two-choices: sample 2 random peers, pick best
            if (candidates.length == 1)
            {
                return Ok!(WorkerId, DistributedError)(candidates[0].id);
            }
            else if (candidates.length == 2)
            {
                auto p1 = candidates[0];
                auto p2 = candidates[1];
                immutable score1 = calculateStealScore(p1);
                immutable score2 = calculateStealScore(p2);
                return Ok!(WorkerId, DistributedError)(
                    score1 > score2 ? p1.id : p2.id);
            }
            else
            {
                // Sample 2 random
                immutable idx1 = uniform(0, candidates.length);
                size_t idx2 = uniform(0, candidates.length);
                while (idx2 == idx1)
                    idx2 = uniform(0, candidates.length);
                
                auto p1 = candidates[idx1];
                auto p2 = candidates[idx2];
                
                immutable score1 = calculateStealScore(p1);
                immutable score2 = calculateStealScore(p2);
                
                return Ok!(WorkerId, DistributedError)(
                    score1 > score2 ? p1.id : p2.id);
            }
        }
    }
    
    /// Get peer information
    Result!(PeerInfo, DistributedError) getPeer(WorkerId id) @trusted
    {
        synchronized (mutex)
        {
            if (auto peer = id in peers)
                return Ok!(PeerInfo, DistributedError)(*peer);
            
            return Err!(PeerInfo, DistributedError)(
                new DistributedError("Peer not found: " ~ id.toString()));
        }
    }
    
    /// Get all alive peers
    PeerInfo[] getAlivePeers() @trusted
    {
        synchronized (mutex)
        {
            return peers.values
                .filter!(p => atomicLoad(p.alive))
                .array;
        }
    }
    
    /// Prune stale peers (call periodically)
    size_t pruneStale() @trusted
    {
        import std.datetime : Clock;
        
        synchronized (mutex)
        {
            immutable now = Clock.currTime;
            size_t pruned = 0;
            
            WorkerId[] toRemove;
            foreach (id, peer; peers)
            {
                if (now - peer.lastSeen > staleThreshold)
                {
                    toRemove ~= id;
                    pruned++;
                }
            }
            
            foreach (id; toRemove)
            {
                peers.remove(id);
                Logger.info("Pruned stale peer: " ~ id.toString());
            }
            
            return pruned;
        }
    }
    
    /// Get peer count
    size_t peerCount() @trusted
    {
        synchronized (mutex)
        {
            return peers.length;
        }
    }
    
    /// Get registry statistics
    struct RegistryStats
    {
        size_t totalPeers;
        size_t alivePeers;
        size_t deadPeers;
        size_t totalQueueDepth;
        float avgLoadFactor;
    }
    
    RegistryStats getStats() @trusted
    {
        synchronized (mutex)
        {
            RegistryStats stats;
            stats.totalPeers = peers.length;
            
            float totalLoad = 0.0;
            foreach (peer; peers.values)
            {
                if (atomicLoad(peer.alive))
                {
                    stats.alivePeers++;
                    stats.totalQueueDepth += atomicLoad(peer.queueDepth);
                    totalLoad += atomicLoad(peer.loadFactor);
                }
                else
                {
                    stats.deadPeers++;
                }
            }
            
            if (stats.alivePeers > 0)
                stats.avgLoadFactor = totalLoad / stats.alivePeers;
            
            return stats;
        }
    }
    
    private:
    
    enum size_t MIN_QUEUE_FOR_STEAL = 4;  // Min queue size to be steal victim
    
    /// Calculate steal score (higher = better victim)
    /// Balances queue depth and load factor
    float calculateStealScore(ref PeerInfo peer) pure @trusted nothrow @nogc
    {
        immutable queueDepth = atomicLoad(peer.queueDepth);
        immutable loadFactor = atomicLoad(peer.loadFactor);
        
        // Weight factors for selection
        enum QUEUE_WEIGHT = 10.0f;
        enum LOAD_WEIGHT = 5.0f;
        
        // Prefer peers with deep queues but not overloaded
        immutable queueScore = queueDepth * QUEUE_WEIGHT;
        immutable loadPenalty = loadFactor * LOAD_WEIGHT;
        
        return queueScore - loadPenalty;
    }
}



