module engine.distributed.protocol.messages;

import engine.distributed.protocol.protocol;
import engine.distributed.protocol.protocol : DistributedError;
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

/// Serialize WorkerRegistration
ubyte[] serializeRegistration(WorkerRegistration reg) @trusted
{
    import std.bitmanip : write;
    
    ubyte[] buffer;
    buffer.reserve(512);
    
    // Address
    buffer.write!uint(cast(uint)reg.address.length, buffer.length);
    buffer ~= cast(ubyte[])reg.address;
    
    // Capabilities
    buffer ~= reg.capabilities.serialize();
    
    // Metrics
    buffer.write!float(reg.metrics.cpuUsage, buffer.length);
    buffer.write!float(reg.metrics.memoryUsage, buffer.length);
    buffer.write!float(reg.metrics.diskUsage, buffer.length);
    buffer.write!ulong(reg.metrics.queueDepth, buffer.length);
    buffer.write!ulong(reg.metrics.activeActions, buffer.length);
    
    return buffer;
}

/// Deserialize WorkerRegistration
Result!(WorkerRegistration, DistributedError) deserializeRegistration(const ubyte[] data) @system
{
    import std.bitmanip : read;
    
    if (data.length < 4)
        return Err!(WorkerRegistration, DistributedError)(
            new NetworkError("Registration data too short"));
    
    try
    {
        ubyte[] mutableData = cast(ubyte[])data.dup;
        size_t offset = 0;
        
        WorkerRegistration reg;
        
        // Address
        auto addrLenSlice = mutableData[offset .. offset + 4];
        immutable addrLen = addrLenSlice.read!uint();
        offset += 4;
        reg.address = cast(string)data[offset .. offset + addrLen];
        offset += addrLen;
        
        // Capabilities (need to know size, simplified for now)
        auto capsResult = Capabilities.deserialize(data[offset .. $]);
        if (capsResult.isErr)
        {
            auto err = capsResult.unwrapErr();
            return Err!(WorkerRegistration, DistributedError)(
                new DistributedError(err.message()));
        }
        
        reg.capabilities = capsResult.unwrap();
        
        // Skip capabilities bytes (simplified, would track actual size)
        offset = cast(size_t)(data.length - 28);  // Last 28 bytes are metrics
        
        // Metrics
        auto cpuSlice = mutableData[offset .. offset + 4];
        reg.metrics.cpuUsage = cpuSlice.read!float();
        offset += 4;
        
        auto memSlice = mutableData[offset .. offset + 4];
        reg.metrics.memoryUsage = memSlice.read!float();
        offset += 4;
        
        auto diskSlice = mutableData[offset .. offset + 4];
        reg.metrics.diskUsage = diskSlice.read!float();
        offset += 4;
        
        auto queueSlice = mutableData[offset .. offset + 8];
        reg.metrics.queueDepth = queueSlice.read!ulong();
        offset += 8;
        
        auto activeSlice = mutableData[offset .. offset + 8];
        reg.metrics.activeActions = activeSlice.read!ulong();
        
        return Ok!(WorkerRegistration, DistributedError)(reg);
    }
    catch (Exception e)
    {
        return Err!(WorkerRegistration, DistributedError)(
            new NetworkError("Failed to deserialize registration: " ~ e.msg));
    }
}

/// Serialize WorkRequest
ubyte[] serializeWorkRequest(WorkRequest req) @trusted
{
    import std.bitmanip : write;
    
    ubyte[] buffer;
    buffer.write!ulong(req.worker.value, buffer.length);
    buffer.write!ulong(req.desiredBatchSize, buffer.length);
    
    return buffer;
}

/// Deserialize WorkRequest
Result!(WorkRequest, DistributedError) deserializeWorkRequest(const ubyte[] data) @system
{
    import std.bitmanip : read;
    
    if (data.length < 16)
        return Err!(WorkRequest, DistributedError)(
            new NetworkError("WorkRequest data too short"));
    
    try
    {
        ubyte[] mutableData = cast(ubyte[])data.dup;
        
        WorkRequest req;
        
        auto workerSlice = mutableData[0 .. 8];
        req.worker = WorkerId(workerSlice.read!ulong());
        
        auto sizeSlice = mutableData[8 .. 16];
        req.desiredBatchSize = sizeSlice.read!ulong();
        
        return Ok!(WorkRequest, DistributedError)(req);
    }
    catch (Exception e)
    {
        return Err!(WorkRequest, DistributedError)(
            new NetworkError("Failed to deserialize WorkRequest: " ~ e.msg));
    }
}

/// Serialize PeerAnnounce
ubyte[] serializePeerAnnounce(PeerAnnounce announce) @trusted
{
    import std.bitmanip : write;
    
    ubyte[] buffer;
    buffer.reserve(512);
    
    buffer.write!ulong(announce.worker.value, buffer.length);
    buffer.write!uint(cast(uint)announce.address.length, buffer.length);
    buffer ~= cast(ubyte[])announce.address;
    buffer.write!ulong(announce.queueDepth, buffer.length);
    buffer.write!float(announce.loadFactor, buffer.length);
    
    return buffer;
}

/// Deserialize PeerAnnounce
Result!(PeerAnnounce, DistributedError) deserializePeerAnnounce(const ubyte[] data) @system
{
    import std.bitmanip : read;
    
    if (data.length < 20)
        return Err!(PeerAnnounce, DistributedError)(
            new NetworkError("PeerAnnounce data too short"));
    
    try
    {
        ubyte[] mutableData = cast(ubyte[])data.dup;
        size_t offset = 0;
        
        PeerAnnounce announce;
        
        auto workerSlice = mutableData[offset .. offset + 8];
        announce.worker = WorkerId(workerSlice.read!ulong());
        offset += 8;
        
        auto lenSlice = mutableData[offset .. offset + 4];
        immutable addrLen = lenSlice.read!uint();
        offset += 4;
        
        announce.address = cast(string)data[offset .. offset + addrLen];
        offset += addrLen;
        
        auto queueSlice = mutableData[offset .. offset + 8];
        announce.queueDepth = queueSlice.read!ulong();
        offset += 8;
        
        auto loadSlice = mutableData[offset .. offset + 4];
        announce.loadFactor = loadSlice.read!float();
        
        return Ok!(PeerAnnounce, DistributedError)(announce);
    }
    catch (Exception e)
    {
        return Err!(PeerAnnounce, DistributedError)(
            new NetworkError("Failed to deserialize PeerAnnounce: " ~ e.msg));
    }
}



