module engine.distributed.protocol.messages;

import engine.distributed.protocol.protocol;
import engine.distributed.protocol.schema;
import engine.distributed.protocol.protocol : DistributedError;
import infrastructure.utils.serialization;
import infrastructure.errors : BuildError, Result, Ok, Err;

/// Message type enum for routing
enum MessageType : ubyte
{
    Registration = 0,
    ActionRequest = 1,
    ActionResult = 2,
    HeartBeat = 3,
    StealRequest = 4,
    StealResponse = 5,
    Shutdown = 6,
    WorkRequest = 7,
    PeerDiscovery = 8,
    PeerAnnounce = 9,
    PeerMetrics = 10
}

/// Worker registration message
struct WorkerRegistration
{
    string address;             // Worker address (host:port)
    Capabilities capabilities;  // Worker capabilities
    SystemMetrics metrics;      // Initial metrics
}

/// Work request message (worker → coordinator)
struct WorkRequest
{
    WorkerId worker;            // Requesting worker
    size_t desiredBatchSize;    // Number of actions requested
}

/// Peer discovery request (worker → coordinator)
struct PeerDiscoveryRequest
{
    WorkerId worker;            // Requesting worker
}

/// Peer discovery response (coordinator → worker)
struct PeerDiscoveryResponse
{
    PeerEntry[] peers;          // Available peer workers
}

/// Peer entry in discovery response
struct PeerEntry
{
    WorkerId id;                // Peer worker ID
    string address;             // Network address
    size_t queueDepth;          // Current queue depth
    float loadFactor;           // Load metric [0.0, 1.0]
}

/// Peer announce (worker → coordinator)
/// Workers announce themselves for peer discovery
struct PeerAnnounce
{
    WorkerId worker;            // Worker ID
    string address;             // Listen address for P2P
    size_t queueDepth;          // Current queue size
    float loadFactor;           // Current load [0.0, 1.0]
}

/// Peer metrics update (worker → coordinator)
struct PeerMetricsUpdate
{
    WorkerId worker;            // Worker ID
    size_t queueDepth;          // Current queue depth
    float loadFactor;           // Current load
    size_t activeActions;       // Currently executing
}

/// Serialize WorkerRegistration using high-performance Codec
ubyte[] serializeRegistration(WorkerRegistration reg) @trusted
{
    auto serializable = toSerializableRegistration(reg);
    return Codec.serialize(serializable);
}

/// Deserialize WorkerRegistration using high-performance Codec
Result!(WorkerRegistration, DistributedError) deserializeRegistration(const ubyte[] data) @system
{
    auto result = Codec.deserialize!SerializableWorkerRegistration(cast(ubyte[])data);
    
    if (result.isErr)
        return Err!(WorkerRegistration, DistributedError)(
            new NetworkError("Failed to deserialize registration: " ~ result.unwrapErr()));
    
    auto serializable = result.unwrap();
    
    WorkerRegistration reg;
    reg.address = cast(string)serializable.address;
    reg.capabilities = fromSerializableCapabilities!Capabilities(serializable.capabilities);
    reg.metrics = fromSerializableMetrics!SystemMetrics(serializable.metrics);
    
    return Ok!(WorkerRegistration, DistributedError)(reg);
}

/// Serialize WorkRequest using high-performance Codec
ubyte[] serializeWorkRequest(WorkRequest req) @trusted
{
    SerializableWorkRequest serializable;
    serializable.workerId = req.worker.value;
    serializable.desiredBatchSize = req.desiredBatchSize;
    
    return Codec.serialize(serializable);
}

/// Deserialize WorkRequest using high-performance Codec
Result!(WorkRequest, DistributedError) deserializeWorkRequest(const ubyte[] data) @system
{
    auto result = Codec.deserialize!SerializableWorkRequest(cast(ubyte[])data);
    
    if (result.isErr)
        return Err!(WorkRequest, DistributedError)(
            new NetworkError("Failed to deserialize WorkRequest: " ~ result.unwrapErr()));
    
    auto serializable = result.unwrap();
    
    WorkRequest req;
    req.worker = WorkerId(serializable.workerId);
    req.desiredBatchSize = cast(size_t)serializable.desiredBatchSize;
    
    return Ok!(WorkRequest, DistributedError)(req);
}

/// Serialize PeerDiscoveryRequest using high-performance Codec
ubyte[] serializePeerDiscoveryRequest(PeerDiscoveryRequest req) @trusted
{
    SerializablePeerDiscoveryRequest serializable;
    serializable.workerId = req.worker.value;
    
    return Codec.serialize(serializable);
}

/// Deserialize PeerDiscoveryRequest using high-performance Codec
Result!(PeerDiscoveryRequest, DistributedError) deserializePeerDiscoveryRequest(const ubyte[] data) @system
{
    auto result = Codec.deserialize!SerializablePeerDiscoveryRequest(cast(ubyte[])data);
    
    if (result.isErr)
        return Err!(PeerDiscoveryRequest, DistributedError)(
            new NetworkError("Failed to deserialize PeerDiscoveryRequest: " ~ result.unwrapErr()));
    
    auto serializable = result.unwrap();
    
    PeerDiscoveryRequest req;
    req.worker = WorkerId(serializable.workerId);
    
    return Ok!(PeerDiscoveryRequest, DistributedError)(req);
}

/// Serialize PeerDiscoveryResponse using high-performance Codec
ubyte[] serializePeerDiscoveryResponse(PeerDiscoveryResponse resp) @trusted
{
    SerializablePeerDiscoveryResponse serializable;
    
    foreach (peer; resp.peers)
    {
        SerializablePeerEntry entry;
        entry.workerId = peer.id.value;
        entry.address = peer.address;
        entry.queueDepth = peer.queueDepth;
        entry.loadFactor = peer.loadFactor;
        serializable.peers ~= entry;
    }
    
    return Codec.serialize(serializable);
}

/// Deserialize PeerDiscoveryResponse using high-performance Codec
Result!(PeerDiscoveryResponse, DistributedError) deserializePeerDiscoveryResponse(const ubyte[] data) @system
{
    auto result = Codec.deserialize!SerializablePeerDiscoveryResponse(cast(ubyte[])data);
    
    if (result.isErr)
        return Err!(PeerDiscoveryResponse, DistributedError)(
            new NetworkError("Failed to deserialize PeerDiscoveryResponse: " ~ result.unwrapErr()));
    
    auto serializable = result.unwrap();
    
    PeerDiscoveryResponse resp;
    
    foreach (ref entry; serializable.peers)
    {
        PeerEntry peer;
        peer.id = WorkerId(entry.workerId);
        peer.address = cast(string)entry.address;
        peer.queueDepth = cast(size_t)entry.queueDepth;
        peer.loadFactor = entry.loadFactor;
        resp.peers ~= peer;
    }
    
    return Ok!(PeerDiscoveryResponse, DistributedError)(resp);
}

/// Serialize PeerAnnounce using high-performance Codec
ubyte[] serializePeerAnnounce(PeerAnnounce announce) @trusted
{
    SerializablePeerAnnounce serializable;
    serializable.workerId = announce.worker.value;
    serializable.address = announce.address;
    serializable.queueDepth = announce.queueDepth;
    serializable.loadFactor = announce.loadFactor;
    
    return Codec.serialize(serializable);
}

/// Deserialize PeerAnnounce using high-performance Codec
Result!(PeerAnnounce, DistributedError) deserializePeerAnnounce(const ubyte[] data) @system
{
    auto result = Codec.deserialize!SerializablePeerAnnounce(cast(ubyte[])data);
    
    if (result.isErr)
        return Err!(PeerAnnounce, DistributedError)(
            new NetworkError("Failed to deserialize PeerAnnounce: " ~ result.unwrapErr()));
    
    auto serializable = result.unwrap();
    
    PeerAnnounce announce;
    announce.worker = WorkerId(serializable.workerId);
    announce.address = cast(string)serializable.address;
    announce.queueDepth = cast(size_t)serializable.queueDepth;
    announce.loadFactor = serializable.loadFactor;
    
    return Ok!(PeerAnnounce, DistributedError)(announce);
}

/// Serialize PeerMetricsUpdate using high-performance Codec
ubyte[] serializePeerMetricsUpdate(PeerMetricsUpdate update) @trusted
{
    SerializablePeerMetricsUpdate serializable;
    serializable.workerId = update.worker.value;
    serializable.queueDepth = update.queueDepth;
    serializable.loadFactor = update.loadFactor;
    serializable.activeActions = update.activeActions;
    
    return Codec.serialize(serializable);
}

/// Deserialize PeerMetricsUpdate using high-performance Codec
Result!(PeerMetricsUpdate, DistributedError) deserializePeerMetricsUpdate(const ubyte[] data) @system
{
    auto result = Codec.deserialize!SerializablePeerMetricsUpdate(cast(ubyte[])data);
    
    if (result.isErr)
        return Err!(PeerMetricsUpdate, DistributedError)(
            new NetworkError("Failed to deserialize PeerMetricsUpdate: " ~ result.unwrapErr()));
    
    auto serializable = result.unwrap();
    
    PeerMetricsUpdate update;
    update.worker = WorkerId(serializable.workerId);
    update.queueDepth = cast(size_t)serializable.queueDepth;
    update.loadFactor = serializable.loadFactor;
    update.activeActions = cast(size_t)serializable.activeActions;
    
    return Ok!(PeerMetricsUpdate, DistributedError)(update);
}
