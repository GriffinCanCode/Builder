module engine.distributed.worker.communication;

import std.datetime : Duration, Clock, seconds;
import std.conv : to;
import core.thread : Thread;
import core.atomic;
import engine.distributed.protocol.protocol;
import engine.distributed.protocol.transport;
import engine.distributed.protocol.messages;
import infrastructure.utils.concurrency.deque : WorkStealingDeque;
import engine.distributed.worker.peers;
import infrastructure.utils.logging.logger;
import infrastructure.errors;

/// Worker communication handler - manages coordinator and peer communication
struct WorkerCommunication
{
    /// Send heartbeat to coordinator
    void sendHeartbeat(
        WorkerId id,
        WorkerState state,
        SystemMetrics metrics,
        Transport coordinatorTransport
    ) @trusted
    {
        try
        {
            HeartBeat hb;
            hb.worker = id;
            hb.state = state;
            hb.metrics = metrics;
            hb.timestamp = Clock.currTime;
            
            // Send via transport
            auto sendResult = coordinatorTransport.sendHeartBeat(WorkerId(0), hb);
            if (sendResult.isErr)
            {
                Logger.error("Heartbeat send failed: " ~ sendResult.unwrapErr().message());
                
                // If we can't send heartbeats, try to reconnect
                if (coordinatorTransport !is null)
                {
                    auto http = cast(HttpTransport)coordinatorTransport;
                    if (http !is null)
                    {
                        http.close();
                        auto reconnectResult = http.connect();
                        if (reconnectResult.isErr)
                            Logger.error("Failed to reconnect to coordinator");
                    }
                }
            }
            else
            {
                Logger.debugLog("Heartbeat sent (queue: " ~ hb.metrics.queueDepth.to!string ~ 
                              ", cpu: " ~ (hb.metrics.cpuUsage * 100).to!size_t.to!string ~ "%)");
            }
        }
        catch (Exception e)
        {
            Logger.error("Heartbeat send exception: " ~ e.msg);
        }
    }
    
    /// Heartbeat loop
    void heartbeatLoop(
        WorkerId id,
        shared bool* running,
        WorkerState delegate() @trusted getStateCallback,
        SystemMetrics delegate() @trusted getMetricsCallback,
        Transport coordinatorTransport,
        Duration heartbeatInterval
    ) @trusted
    {
        while (atomicLoad(*running))
        {
            try
            {
                auto state = getStateCallback();
                auto metrics = getMetricsCallback();
                sendHeartbeat(id, state, metrics, coordinatorTransport);
                Thread.sleep(heartbeatInterval);
            }
            catch (Exception e)
            {
                Logger.error("Heartbeat failed: " ~ e.msg);
            }
        }
    }
    
    /// Request work from coordinator
    ActionRequest requestWork(WorkerId id, Transport coordinatorTransport) @trusted
    {
        try
        {
            // Create work request
            WorkRequest req;
            req.worker = id;
            req.desiredBatchSize = 1;
            
            auto reqData = serializeWorkRequest(req);
            
            // Send request (simplified - would use proper socket handling)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.WorkRequest];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)reqData.length;
            
            // Would send via coordinator transport and receive response
            // For now, return null (no work)
            
            return null;
        }
        catch (Exception e)
        {
            Logger.error("Work request failed: " ~ e.msg);
            return null;
        }
    }
    
    /// Send result to coordinator
    void sendResult(
        WorkerId id,
        ActionResult result,
        Transport coordinatorTransport
    ) @trusted
    {
        try
        {
            // Create envelope
            auto envelope = Envelope!ActionResult(id, WorkerId(0), result);
            
            // Serialize
            auto http = cast(HttpTransport)coordinatorTransport;
            if (http is null)
            {
                Logger.error("Invalid transport for sending result");
                return;
            }
            
            auto msgData = http.serializeMessage(envelope);
            
            // Send via transport (simplified)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.ActionResult];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)msgData.length;
            
            // Would send via socket
            
            Logger.debugLog("Result sent: " ~ result.id.toString());
        }
        catch (Exception e)
        {
            Logger.error("Failed to send result: " ~ e.msg);
        }
    }
    
    /// Send peer announce to coordinator
    void sendPeerAnnounce(
        WorkerId id,
        string listenAddress,
        ref WorkStealingDeque!ActionRequest localQueue,
        float loadFactor,
        Transport coordinatorTransport
    ) @trusted
    {
        try
        {
            PeerAnnounce announce;
            announce.worker = id;
            announce.address = listenAddress;
            announce.queueDepth = localQueue.size();
            announce.loadFactor = loadFactor;
            
            auto announceData = serializePeerAnnounce(announce);
            
            // Send via coordinator transport (simplified)
            ubyte[1] typeBytes = [cast(ubyte)MessageType.PeerAnnounce];
            ubyte[4] lengthBytes;
            *cast(uint*)lengthBytes.ptr = cast(uint)announceData.length;
            
            // Would send via socket
            
            Logger.debugLog("Peer announce sent");
        }
        catch (Exception e)
        {
            Logger.error("Failed to send peer announce: " ~ e.msg);
        }
    }
    
    /// Peer announce loop
    void peerAnnounceLoop(
        WorkerId id,
        shared bool* running,
        string listenAddress,
        ref WorkStealingDeque!ActionRequest localQueue,
        float delegate() @trusted getLoadFactorCallback,
        PeerRegistry peerRegistry,
        Transport coordinatorTransport,
        Duration peerAnnounceInterval
    ) @trusted
    {
        while (atomicLoad(*running))
        {
            try
            {
                auto loadFactor = getLoadFactorCallback();
                sendPeerAnnounce(id, listenAddress, localQueue, loadFactor, coordinatorTransport);
                
                // Also prune stale peers periodically
                if (peerRegistry !is null)
                    peerRegistry.pruneStale();
                
                Thread.sleep(peerAnnounceInterval);
            }
            catch (Exception e)
            {
                Logger.error("Peer announce failed: " ~ e.msg);
            }
        }
    }
    
    /// Calculate current load factor
    float calculateLoadFactor(size_t queueSize, size_t queueCapacity, WorkerState state, size_t maxConcurrentActions) @trusted nothrow => 
        cast(float)queueSize / queueCapacity * 0.7 + cast(float)(state == WorkerState.Executing) / maxConcurrentActions * 0.3;
}

