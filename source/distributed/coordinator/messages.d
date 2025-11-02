module distributed.coordinator.messages;

import std.socket : Socket, SocketShutdown;
import distributed.protocol.protocol;
import distributed.protocol.messages;
import distributed.protocol.transport : HttpTransport;
import distributed.coordinator.registry : WorkerRegistry;
import distributed.coordinator.scheduler : DistributedScheduler;
import errors;
import utils.logging.logger;

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
    
    /// Handle incoming client connection
    /// 
    /// Responsibility: Route message to appropriate handler based on type
    void handleClient(Socket client) @trusted
    {
        scope(exit)
        {
            cleanupSocket(client);
        }
        
        try
        {
            // Receive message type
            ubyte[1] typeBytes;
            auto received = client.receive(typeBytes);
            if (received != 1)
                return;
            
            immutable msgType = cast(MessageType)typeBytes[0];
            
            // Route to appropriate handler
            final switch (msgType)
            {
                case MessageType.Registration:
                    handleRegistration(client);
                    break;
                    
                case MessageType.HeartBeat:
                    handleHeartBeat(client);
                    break;
                    
                case MessageType.ActionResult:
                    handleActionResult(client);
                    break;
                    
                case MessageType.WorkRequest:
                    handleWorkRequest(client);
                    break;
                    
                case MessageType.PeerDiscovery:
                case MessageType.PeerAnnounce:
                case MessageType.PeerMetrics:
                    // Peer-related messages handled separately
                    Logger.info("Peer message received");
                    break;
                    
                case MessageType.ActionRequest:
                case MessageType.StealRequest:
                case MessageType.StealResponse:
                case MessageType.Shutdown:
                    // Coordinator → worker messages, not expected here
                    Logger.warning("Unexpected message type from client");
                    break;
            }
        }
        catch (Exception e)
        {
            Logger.error("Client handler failed: " ~ e.msg);
        }
    }
    
    /// Handle worker registration message
    /// 
    /// Responsibility: Parse registration and delegate to registry
    private void handleRegistration(Socket client) @trusted
    {
        try
        {
            // Receive message length
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            
            // Receive registration data
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto regResult = deserializeRegistration(data);
            if (regResult.isErr)
            {
                Logger.error("Failed to deserialize registration: " ~ 
                           regResult.unwrapErr().message());
                return;
            }
            
            auto registration = regResult.unwrap();
            
            // Delegate to registry (SRP: registry owns worker registration)
            auto workerIdResult = registry.register(registration.address);
            if (workerIdResult.isErr)
            {
                Logger.error("Failed to register worker: " ~ 
                           workerIdResult.unwrapErr().message());
                return;
            }
            
            auto workerId = workerIdResult.unwrap();
            
            // Send worker ID back
            ubyte[8] idBytes;
            *cast(ulong*)idBytes.ptr = workerId.value;
            client.send(idBytes);
            
            Logger.info("Worker registered: " ~ workerId.toString() ~ 
                       " (" ~ registration.address ~ ")");
        }
        catch (Exception e)
        {
            Logger.error("Registration handling failed: " ~ e.msg);
        }
    }
    
    /// Handle heartbeat message
    /// 
    /// Responsibility: Parse heartbeat and delegate to registry
    private void handleHeartBeat(Socket client) @trusted
    {
        try
        {
            // Receive message
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto http = new HttpTransport("", 0);
            auto envResult = http.deserializeMessage!HeartBeat(data);
            if (envResult.isErr)
                return;
            
            auto envelope = envResult.unwrap();
            
            // Delegate to registry (SRP: registry owns worker state)
            registry.updateHeartbeat(envelope.payload.worker, envelope.payload);
            
            Logger.debugLog("Heartbeat from worker " ~ 
                          envelope.payload.worker.toString());
        }
        catch (Exception e)
        {
            Logger.error("Heartbeat handling failed: " ~ e.msg);
        }
    }
    
    /// Handle action result message
    /// 
    /// Responsibility: Parse action result and delegate to scheduler
    private void handleActionResult(Socket client) @trusted
    {
        try
        {
            // Receive message
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto http = new HttpTransport("", 0);
            auto envResult = http.deserializeMessage!ActionResult(data);
            if (envResult.isErr)
            {
                Logger.error("Failed to deserialize result");
                return;
            }
            
            auto envelope = envResult.unwrap();
            auto result = envelope.payload;
            
            // Delegate to scheduler (SRP: scheduler owns action state)
            if (result.status == ResultStatus.Success)
                scheduler.onComplete(result.id, result);
            else
                scheduler.onFailure(result.id, result.stderr);
            
            Logger.info("Action completed: " ~ result.id.toString());
        }
        catch (Exception e)
        {
            Logger.error("Result handling failed: " ~ e.msg);
        }
    }
    
    /// Handle work request message
    /// 
    /// Responsibility: Parse work request and delegate to scheduler
    void handleWorkRequest(Socket client) @trusted
    {
        try
        {
            // Receive message
            ubyte[4] lengthBytes;
            if (client.receive(lengthBytes) != 4)
                return;
            
            immutable length = *cast(uint*)lengthBytes.ptr;
            auto data = new ubyte[length];
            if (client.receive(data) != length)
                return;
            
            // Deserialize
            auto reqResult = deserializeWorkRequest(data);
            if (reqResult.isErr)
                return;
            
            auto request = reqResult.unwrap();
            
            // Get ready actions from scheduler
            ActionRequest[] actions;
            foreach (_; 0 .. request.desiredBatchSize)
            {
                auto actionResult = scheduler.dequeueReady();
                if (actionResult.isErr)
                    break;
                actions ~= actionResult.unwrap();
            }
            
            // Send batch response
            if (actions.length > 0)
            {
                // Send count
                ubyte[4] countBytes;
                *cast(uint*)countBytes.ptr = cast(uint)actions.length;
                client.send(countBytes);
                
                // Send each action
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
                Logger.debugLog("Sent " ~ actions.length.to!string ~ 
                              " actions to worker " ~ request.worker.toString());
            }
            else
            {
                // No work available
                ubyte[4] countBytes;
                *cast(uint*)countBytes.ptr = 0;
                client.send(countBytes);
            }
        }
        catch (Exception e)
        {
            Logger.error("Work request handling failed: " ~ e.msg);
        }
    }
    
    /// Cleanup socket connection
    private void cleanupSocket(Socket client) nothrow
    {
        try { client.shutdown(SocketShutdown.BOTH); } catch (Exception) {}
        try { client.close(); } catch (Exception) {}
    }
}

