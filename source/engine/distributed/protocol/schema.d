module engine.distributed.protocol.schema;

import std.datetime : SysTime;
import infrastructure.utils.serialization;

/// Serializable capabilities for distributed workers
@Serializable(SchemaVersion(1, 0))
struct SerializableCapabilities
{
    @Field(1) bool network;
    @Field(2) bool writeHome;
    @Field(3) bool writeTmp;
    @Field(4) string[] readPaths;
    @Field(5) string[] writePaths;
    @Field(6) @Packed ulong maxCpu;
    @Field(7) @Packed ulong maxMemory;
    @Field(8) @Packed long timeoutMs;  // Duration in milliseconds
}

/// Serializable system metrics
@Serializable(SchemaVersion(1, 0))
struct SerializableSystemMetrics
{
    @Field(1) float cpuUsage;        // [0.0, 1.0]
    @Field(2) float memoryUsage;     // [0.0, 1.0]
    @Field(3) float diskUsage;       // [0.0, 1.0]
    @Field(4) @Packed ulong queueDepth;
    @Field(5) @Packed ulong activeActions;
}

/// Serializable worker registration message
@Serializable(SchemaVersion(1, 0), 0x57524547) // "WREG" - Worker Registration
struct SerializableWorkerRegistration
{
    @Field(1) string address;
    @Field(2) SerializableCapabilities capabilities;
    @Field(3) SerializableSystemMetrics metrics;
}

/// Serializable work request message
@Serializable(SchemaVersion(1, 0), 0x57525154) // "WRQT" - Work Request
struct SerializableWorkRequest
{
    @Field(1) @Packed ulong workerId;
    @Field(2) @Packed ulong desiredBatchSize;
}

/// Serializable peer entry
@Serializable(SchemaVersion(1, 0))
struct SerializablePeerEntry
{
    @Field(1) @Packed ulong workerId;
    @Field(2) string address;
    @Field(3) @Packed ulong queueDepth;
    @Field(4) float loadFactor;
}

/// Serializable peer discovery request
@Serializable(SchemaVersion(1, 0), 0x50445251) // "PDRQ" - Peer Discovery Request
struct SerializablePeerDiscoveryRequest
{
    @Field(1) @Packed ulong workerId;
}

/// Serializable peer discovery response
@Serializable(SchemaVersion(1, 0), 0x50445253) // "PDRS" - Peer Discovery Response
struct SerializablePeerDiscoveryResponse
{
    @Field(1) SerializablePeerEntry[] peers;
}

/// Serializable peer announce
@Serializable(SchemaVersion(1, 0), 0x50414E4E) // "PANN" - Peer Announce
struct SerializablePeerAnnounce
{
    @Field(1) @Packed ulong workerId;
    @Field(2) string address;
    @Field(3) @Packed ulong queueDepth;
    @Field(4) float loadFactor;
}

/// Serializable peer metrics update
@Serializable(SchemaVersion(1, 0), 0x504D5452) // "PMTR" - Peer Metrics
struct SerializablePeerMetricsUpdate
{
    @Field(1) @Packed ulong workerId;
    @Field(2) @Packed ulong queueDepth;
    @Field(3) float loadFactor;
    @Field(4) @Packed ulong activeActions;
}

/// Conversion utilities

/// Convert Capabilities to serializable format
SerializableCapabilities toSerializable(T)(auto ref const T cap) @trusted
{
    import core.time : Duration;
    
    SerializableCapabilities serializable;
    serializable.network = cap.network;
    serializable.writeHome = cap.writeHome;
    serializable.writeTmp = cap.writeTmp;
    serializable.readPaths = cap.readPaths.dup;
    serializable.writePaths = cap.writePaths.dup;
    serializable.maxCpu = cap.maxCpu;
    serializable.maxMemory = cap.maxMemory;
    
    static if (__traits(hasMember, T, "timeout"))
    {
        serializable.timeoutMs = cap.timeout.total!"msecs";
    }
    
    return serializable;
}

/// Convert SystemMetrics to serializable format
SerializableSystemMetrics toSerializableMetrics(T)(auto ref const T metrics) @trusted
{
    SerializableSystemMetrics serializable;
    serializable.cpuUsage = metrics.cpuUsage;
    serializable.memoryUsage = metrics.memoryUsage;
    serializable.diskUsage = metrics.diskUsage;
    serializable.queueDepth = metrics.queueDepth;
    serializable.activeActions = metrics.activeActions;
    return serializable;
}

/// Convert WorkerRegistration to serializable format
SerializableWorkerRegistration toSerializableRegistration(T)(auto ref const T reg) @trusted
{
    SerializableWorkerRegistration serializable;
    serializable.address = reg.address;
    serializable.capabilities = toSerializable(reg.capabilities);
    serializable.metrics = toSerializableMetrics(reg.metrics);
    return serializable;
}

/// Convert from serializable Capabilities to runtime format
TCapabilities fromSerializableCapabilities(TCapabilities)(auto ref const SerializableCapabilities serializable) @trusted
{
    import core.time : msecs;
    
    TCapabilities cap;
    cap.network = serializable.network;
    cap.writeHome = serializable.writeHome;
    cap.writeTmp = serializable.writeTmp;
    cap.readPaths = serializable.readPaths.dup;
    cap.writePaths = serializable.writePaths.dup;
    cap.maxCpu = cast(size_t)serializable.maxCpu;
    cap.maxMemory = cast(size_t)serializable.maxMemory;
    
    static if (__traits(hasMember, TCapabilities, "timeout"))
    {
        cap.timeout = serializable.timeoutMs.msecs;
    }
    
    return cap;
}

/// Convert from serializable SystemMetrics to runtime format
TMetrics fromSerializableMetrics(TMetrics)(auto ref const SerializableSystemMetrics serializable) @trusted
{
    TMetrics metrics;
    metrics.cpuUsage = serializable.cpuUsage;
    metrics.memoryUsage = serializable.memoryUsage;
    metrics.diskUsage = serializable.diskUsage;
    metrics.queueDepth = cast(size_t)serializable.queueDepth;
    metrics.activeActions = cast(size_t)serializable.activeActions;
    return metrics;
}

