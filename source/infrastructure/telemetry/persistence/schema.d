module infrastructure.telemetry.persistence.schema;

import std.datetime : SysTime;
import infrastructure.utils.serialization;

/// Serializable build environment
@Serializable(SchemaVersion(1, 0))
struct SerializableBuildEnvironment
{
    @Field(1) string compilerVersion;
    @Field(2) string os;
    @Field(3) string arch;
    @Field(4) string hostname;
    @Field(5) string username;
    @Field(6) string workingDirectory;
    @Field(7) string[] envKeys;
    @Field(8) string[] envValues;
}

/// Serializable target metric
@Serializable(SchemaVersion(1, 0))
struct SerializableTargetMetric
{
    @Field(1) string targetId;
    @Field(2) @Packed long startTime;
    @Field(3) @Packed long endTime;
    @Field(4) @Packed long duration;
    @Field(5) uint status;  // TargetStatus enum
    @Field(6) @Optional string error;
}

/// Serializable build session
@Serializable(SchemaVersion(1, 0), 0x42534553) // "BSES" - Build Session
struct SerializableBuildSession
{
    @Field(1) @Packed long startTime;
    @Field(2) @Packed long endTime;
    @Field(3) @Packed long totalDuration;
    @Field(4) @Packed ulong totalTargets;
    @Field(5) @Packed ulong built;
    @Field(6) @Packed ulong cached;
    @Field(7) @Packed ulong failed;
    @Field(8) @Packed ulong maxParallelism;
    @Field(9) double cacheHitRate;
    @Field(10) @Packed ulong cacheHits;
    @Field(11) @Packed ulong cacheMisses;
    @Field(12) double targetsPerSecond;
    @Field(13) bool succeeded;
    @Field(14) @Optional string failureReason;
    @Field(15) SerializableBuildEnvironment environment;
    @Field(16) SerializableTargetMetric[] targets;
}

/// Serializable telemetry container
@Serializable(SchemaVersion(1, 0), 0x544C4D59) // "TLMY" - Telemetry
struct SerializableTelemetryContainer
{
    @Field(1) uint version_ = 1;
    @Field(2) SerializableBuildSession[] sessions;
}

/// Convert BuildEnvironment to serializable format
SerializableBuildEnvironment toSerializableEnvironment(T)(auto ref const T env) @trusted
{
    SerializableBuildEnvironment serializable;
    
    static if (__traits(hasMember, T, "compilerVersion"))
        serializable.compilerVersion = env.compilerVersion;
    static if (__traits(hasMember, T, "os"))
        serializable.os = env.os;
    static if (__traits(hasMember, T, "arch"))
        serializable.arch = env.arch;
    static if (__traits(hasMember, T, "hostname"))
        serializable.hostname = env.hostname;
    static if (__traits(hasMember, T, "username"))
        serializable.username = env.username;
    static if (__traits(hasMember, T, "workingDirectory"))
        serializable.workingDirectory = env.workingDirectory;
    
    static if (__traits(hasMember, T, "environment"))
    {
        foreach (key, value; env.environment)
        {
            serializable.envKeys ~= key;
            serializable.envValues ~= value;
        }
    }
    
    return serializable;
}

/// Convert TargetMetric to serializable format
SerializableTargetMetric toSerializableMetric(T)(auto ref const T metric) @trusted
{
    SerializableTargetMetric serializable;
    serializable.targetId = metric.targetId;
    serializable.startTime = metric.startTime.stdTime;
    serializable.endTime = metric.endTime.stdTime;
    serializable.duration = metric.duration.total!"hnsecs";
    serializable.status = cast(uint)metric.status;
    serializable.error = metric.error;
    return serializable;
}

/// Convert BuildSession to serializable format
SerializableBuildSession toSerializable(T)(auto ref const T session) @trusted
{
    SerializableBuildSession serializable;
    serializable.startTime = session.startTime.stdTime;
    serializable.endTime = session.endTime.stdTime;
    serializable.totalDuration = session.totalDuration.total!"hnsecs";
    serializable.totalTargets = session.totalTargets;
    serializable.built = session.built;
    serializable.cached = session.cached;
    serializable.failed = session.failed;
    serializable.maxParallelism = session.maxParallelism;
    serializable.cacheHitRate = session.cacheHitRate;
    serializable.cacheHits = session.cacheHits;
    serializable.cacheMisses = session.cacheMisses;
    serializable.targetsPerSecond = session.targetsPerSecond;
    serializable.succeeded = session.succeeded;
    serializable.failureReason = session.failureReason;
    serializable.environment = toSerializableEnvironment(session.environment);
    
    foreach (targetId, metric; session.targets)
    {
        serializable.targets ~= toSerializableMetric(metric);
    }
    
    return serializable;
}

/// Convert from serializable BuildEnvironment to runtime format
TEnv fromSerializableEnvironment(TEnv)(auto ref const SerializableBuildEnvironment serializable) @trusted
{
    TEnv env;
    
    static if (__traits(hasMember, TEnv, "compilerVersion"))
        env.compilerVersion = cast(string)serializable.compilerVersion;
    static if (__traits(hasMember, TEnv, "os"))
        env.os = cast(string)serializable.os;
    static if (__traits(hasMember, TEnv, "arch"))
        env.arch = cast(string)serializable.arch;
    static if (__traits(hasMember, TEnv, "hostname"))
        env.hostname = cast(string)serializable.hostname;
    static if (__traits(hasMember, TEnv, "username"))
        env.username = cast(string)serializable.username;
    static if (__traits(hasMember, TEnv, "workingDirectory"))
        env.workingDirectory = cast(string)serializable.workingDirectory;
    
    static if (__traits(hasMember, TEnv, "environment"))
    {
        foreach (i; 0 .. serializable.envKeys.length)
        {
            env.environment[serializable.envKeys[i]] = serializable.envValues[i];
        }
    }
    
    return env;
}

/// Convert from serializable TargetMetric to runtime format
TMetric fromSerializableMetric(TMetric, TStatus)(auto ref const SerializableTargetMetric serializable) @trusted
{
    import core.time : hnsecs;
    
    TMetric metric;
    metric.targetId = cast(string)serializable.targetId;
    metric.startTime = SysTime(serializable.startTime);
    metric.endTime = SysTime(serializable.endTime);
    metric.duration = hnsecs(serializable.duration);
    metric.status = cast(TStatus)serializable.status;
    metric.error = cast(string)serializable.error;
    return metric;
}

/// Convert from serializable BuildSession to runtime format
TSession fromSerializable(TSession, TEnv, TMetric, TStatus)(auto ref const SerializableBuildSession serializable) @trusted
{
    import core.time : hnsecs;
    
    TSession session;
    session.startTime = SysTime(serializable.startTime);
    session.endTime = SysTime(serializable.endTime);
    session.totalDuration = hnsecs(serializable.totalDuration);
    session.totalTargets = cast(size_t)serializable.totalTargets;
    session.built = cast(size_t)serializable.built;
    session.cached = cast(size_t)serializable.cached;
    session.failed = cast(size_t)serializable.failed;
    session.maxParallelism = cast(size_t)serializable.maxParallelism;
    session.cacheHitRate = serializable.cacheHitRate;
    session.cacheHits = cast(size_t)serializable.cacheHits;
    session.cacheMisses = cast(size_t)serializable.cacheMisses;
    session.targetsPerSecond = serializable.targetsPerSecond;
    session.succeeded = serializable.succeeded;
    session.failureReason = cast(string)serializable.failureReason;
    session.environment = fromSerializableEnvironment!TEnv(serializable.environment);
    
    foreach (ref serialMetric; serializable.targets)
    {
        auto metric = fromSerializableMetric!(TMetric, TStatus)(serialMetric);
        session.targets[metric.targetId] = metric;
    }
    
    return session;
}

