module engine.distributed.coordinator.messages;

import std.socket : Socket, SocketShutdown;
import engine.distributed.protocol.protocol;
import engine.distributed.protocol.messages;
import engine.distributed.protocol.transport : HttpTransport;
import engine.distributed.coordinator.registry : WorkerRegistry;
import engine.distributed.coordinator.scheduler : DistributedScheduler;
import infrastructure.errors;
import infrastructure.utils.logging.logger;

/// Coordinator message handler - single responsibility: handle incoming messages
/// 
/// Separation of concerns:
/// - Coordinator: orchestrates distributed execution, manages lifecycle
/// - CoordinatorMessageHandler: handles message routing and deserialization
/// - WorkerRegistry: manages worker state
/// - DistributedScheduler: manages action scheduling
final class CoordinatorMessageHandler
{
    private WorkerRegistry registry;
    private DistributedScheduler scheduler;
    
    this(WorkerRegistry registry, DistributedScheduler scheduler) @safe
    {
        this.registry = registry;
        this.scheduler = scheduler;
    }
    
    /// Handle incoming client connection (Responsibility: Route message to appropriate handler based on type)
    void handleClient(Socket client) @trusted
    {
        scope(exit) cleanupSocket(client);
        
        try
        {
            ubyte[1] typeBytes;
            if (client.receive(typeBytes) != 1) return;
            
            final switch (cast(MessageType)typeBytes[0])
            {
                case MessageType.Registration: handleRegistration(client); break;
                case MessageType.HeartBeat: handleHeartBeat(client); break;
                case MessageType.ActionResult: handleActionResult(client); break;
                case MessageType.WorkRequest: handleWorkRequest(client); break;
                case MessageType.PeerDiscovery, MessageType.PeerAnnounce, MessageType.PeerMetrics:
                    Logger.info("Peer message received"); break;
                case MessageType.ActionRequest, MessageType.StealRequest, MessageType.StealResponse, MessageType.Shutdown:
                    Logger.warning("Unexpected message type from client"); break;
            }
        }
        catch (Exception e) { Logger.error("Client handler failed: " ~ e.msg); }
    }
    
    /// Handle worker registration message (Responsibility: Parse registration and delegate to registry)
    private void handleRegistration(Socket client) @trusted
    {
        try
        {
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4) return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length) return;
            
            auto regResult = deserializeRegistration(data);
            if (regResult.isErr) { Logger.error("Failed to deserialize registration: " ~ regResult.unwrapErr().message()); return; }
            
            auto registration = regResult.unwrap();
            auto workerIdResult = registry.register(registration.address);
            if (workerIdResult.isErr) { Logger.error("Failed to register worker: " ~ workerIdResult.unwrapErr().message()); return; }
            
            auto workerId = workerIdResult.unwrap();
            ubyte[8] idBytes;
            *cast(ulong*)idBytes.ptr = workerId.value;
            client.send(idBytes);
            
            Logger.info("Worker registered: " ~ workerId.toString() ~ " (" ~ registration.address ~ ")");
        }
        catch (Exception e) { Logger.error("Registration handling failed: " ~ e.msg); }
    }
    
    /// Handle heartbeat message (Responsibility: Parse heartbeat and delegate to registry)
    private void handleHeartBeat(Socket client) @trusted
    {
        try
        {
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4) return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length) return;
            
            auto http = new HttpTransport("", 0);
            auto envResult = http.deserializeMessage!HeartBeat(data);
            if (envResult.isErr) return;
            
            auto envelope = envResult.unwrap();
            registry.updateHeartbeat(envelope.payload.worker, envelope.payload);
            Logger.debugLog("Heartbeat from worker " ~ envelope.payload.worker.toString());
        }
        catch (Exception e) { Logger.error("Heartbeat handling failed: " ~ e.msg); }
    }
    
    /// Handle action result message (Responsibility: Parse action result and delegate to scheduler)
    private void handleActionResult(Socket client) @trusted
    {
        try
        {
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4) return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length) return;
            
            auto http = new HttpTransport("", 0);
            auto envResult = http.deserializeMessage!ActionResult(data);
            if (envResult.isErr) { Logger.error("Failed to deserialize result"); return; }
            
            auto result = envResult.unwrap().payload;
            if (result.status == ResultStatus.Success) scheduler.onComplete(result.id, result);
            else scheduler.onFailure(result.id, result.stderr);
            
            Logger.info("Action completed: " ~ result.id.toString());
        }
        catch (Exception e) { Logger.error("Result handling failed: " ~ e.msg); }
    }
    
    /// Handle work request message (Responsibility: Parse work request and delegate to scheduler)
    void handleWorkRequest(Socket client) @trusted
    {
        try
        {
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4) return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length) return;
            
            auto reqResult = deserializeWorkRequest(data);
            if (reqResult.isErr) return;
            
            auto request = reqResult.unwrap();
            ActionRequest[] actions;
            foreach (_; 0 .. request.desiredBatchSize)
            {
                auto actionResult = scheduler.dequeueReady();
                if (actionResult.isErr) break;
                actions ~= actionResult.unwrap();
            }
            
            ubyte[4] countBytes;
            *cast(uint*)countBytes.ptr = cast(uint)actions.length;
            client.send(countBytes);
            
            if (actions.length > 0)
            {
                foreach (action; actions)
                {
                    scheduler.assign(action.id, request.worker);
                    auto serialized = action.serialize();
                    ubyte[4] lenBytes;
                    *cast(uint*)lenBytes.ptr = cast(uint)serialized.length;
                    client.send(lenBytes);
                    client.send(serialized);
                }
                import std.conv : to;
                Logger.debugLog("Sent " ~ actions.length.to!string ~ " actions to worker " ~ request.worker.toString());
            }
        }
        catch (Exception e) { Logger.error("Work request handling failed: " ~ e.msg); }
    }
    
    private void cleanupSocket(Socket client) nothrow
    {
        try { client.shutdown(SocketShutdown.BOTH); client.close(); } 
        catch (Exception) {}
    }
}

