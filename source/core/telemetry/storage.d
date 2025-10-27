module core.telemetry.storage;

import std.file : exists, mkdirRecurse, read, write;
import std.path : buildPath;
import std.datetime : SysTime, Duration, Clock, dur;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import std.array : Appender, appender;
import std.algorithm : sort, filter;
import std.range : array;
import core.sync.mutex : Mutex;
import core.telemetry.collector;
import errors;

/// High-performance binary storage for telemetry data
/// Uses optimized binary format with versioning
/// Thread-safe with mutex protection
final class TelemetryStorage
{
    private enum uint MAGIC = 0x42544C4D; // "BTLM" (Builder Telemetry)
    private enum ubyte VERSION = 1;
    
    private string storageDir;
    private immutable string storageFile;
    private BuildSession[] sessions;
    private Mutex storageMutex;
    private TelemetryConfig config;
    
    this(string storageDir = ".builder-telemetry", TelemetryConfig config = TelemetryConfig.init) @safe
    {
        this.storageDir = storageDir;
        this.storageFile = buildPath(storageDir, "telemetry.bin");
        this.storageMutex = new Mutex();
        this.config = config;
        
        if (!exists(storageDir))
            mkdirRecurse(storageDir);
        
        loadSessions();
    }
    
    /// Add a new session - thread-safe
    Result!TelemetryError append(BuildSession session) @trusted
    {
        synchronized (storageMutex)
        {
            sessions ~= session;
            
            // Apply retention policy
            applyRetention();
            
            return persist();
        }
    }
    
    /// Get all sessions - thread-safe
    Result!(BuildSession[], TelemetryError) getSessions() @trusted
    {
        synchronized (storageMutex)
        {
            return Result!(BuildSession[], TelemetryError).ok(sessions.dup);
        }
    }
    
    /// Get recent sessions - thread-safe
    Result!(BuildSession[], TelemetryError) getRecent(size_t count) @trusted
    {
        synchronized (storageMutex)
        {
            immutable limit = count < sessions.length ? count : sessions.length;
            if (limit == 0)
                return Result!(BuildSession[], TelemetryError).ok([]);
            
            return Result!(BuildSession[], TelemetryError).ok(
                sessions[$ - limit .. $].dup
            );
        }
    }
    
    /// Clear all telemetry data - thread-safe
    Result!TelemetryError clear() @trusted
    {
        synchronized (storageMutex)
        {
            sessions = [];
            return persist();
        }
    }
    
    private void loadSessions() @trusted
    {
        if (!exists(storageFile))
            return;
        
        try
        {
            auto data = cast(ubyte[])read(storageFile);
            sessions = deserialize(data);
        }
        catch (Exception e)
        {
            // Corrupted file, start fresh
            sessions = [];
        }
    }
    
    private Result!TelemetryError persist() @trusted
    {
        try
        {
            auto data = serialize(sessions);
            write(storageFile, data);
            return Result!TelemetryError.ok();
        }
        catch (Exception e)
        {
            return Result!TelemetryError.err(
                TelemetryError.storageError(e.msg)
            );
        }
    }
    
    private void applyRetention() @safe
    {
        immutable now = Clock.currTime();
        
        // Remove sessions older than retention period
        if (config.retentionDays > 0)
        {
            sessions = sessions
                .filter!(s => (now - s.startTime).total!"days" <= config.retentionDays)
                .array;
        }
        
        // Limit total session count
        if (config.maxSessions > 0 && sessions.length > config.maxSessions)
        {
            immutable excess = sessions.length - config.maxSessions;
            sessions = sessions[excess .. $];
        }
    }
    
    private static ubyte[] serialize(BuildSession[] sessions) @trusted pure
    {
        auto buffer = appender!(ubyte[]);
        
        // Estimate size: ~512 bytes per session + target data
        immutable estimatedSize = sessions.length * 1024 + 64;
        buffer.reserve(estimatedSize);
        
        // Write header
        buffer.put(nativeToBigEndian(MAGIC)[]);
        buffer.put(VERSION);
        
        // Write session count
        buffer.put(nativeToBigEndian(cast(uint)sessions.length)[]);
        
        // Write each session
        foreach (ref session; sessions)
        {
            writeSession(buffer, session);
        }
        
        return buffer.data;
    }
    
    private static BuildSession[] deserialize(ubyte[] data) @trusted
    {
        if (data.length < 9)
            throw new Exception("Invalid telemetry file: too small");
        
        size_t offset = 0;
        
        // Read and validate header
        immutable ubyte[4] magicBytes = data[offset .. offset + 4][0 .. 4];
        immutable magic = bigEndianToNative!uint(magicBytes);
        offset += 4;
        
        if (magic != MAGIC)
            throw new Exception("Invalid telemetry file format");
        
        immutable version_ = data[offset++];
        if (version_ != VERSION)
            throw new Exception("Unsupported telemetry version");
        
        // Read session count
        immutable ubyte[4] countBytes = data[offset .. offset + 4][0 .. 4];
        immutable count = bigEndianToNative!uint(countBytes);
        offset += 4;
        
        BuildSession[] sessions;
        sessions.reserve(count);
        
        // Read sessions
        foreach (_; 0 .. count)
        {
            sessions ~= readSession(data, offset);
        }
        
        return sessions;
    }
    
    private static void writeSession(ref Appender!(ubyte[]) buffer, ref const BuildSession session) @trusted pure
    {
        // Write timestamps
        buffer.put(nativeToBigEndian(session.startTime.stdTime)[]);
        buffer.put(nativeToBigEndian(session.endTime.stdTime)[]);
        buffer.put(nativeToBigEndian(session.totalDuration.total!"msecs")[]);
        
        // Write counts
        buffer.put(nativeToBigEndian(cast(uint)session.totalTargets)[]);
        buffer.put(nativeToBigEndian(cast(uint)session.built)[]);
        buffer.put(nativeToBigEndian(cast(uint)session.cached)[]);
        buffer.put(nativeToBigEndian(cast(uint)session.failed)[]);
        buffer.put(nativeToBigEndian(cast(uint)session.maxParallelism)[]);
        
        // Write stats
        buffer.put(nativeToBigEndian(session.cacheHitRate)[]);
        buffer.put(nativeToBigEndian(cast(ulong)session.cacheHits)[]);
        buffer.put(nativeToBigEndian(cast(ulong)session.cacheMisses)[]);
        buffer.put(nativeToBigEndian(session.targetsPerSecond)[]);
        
        // Write flags
        buffer.put(cast(ubyte)(session.succeeded ? 1 : 0));
        
        // Write failure reason
        writeString(buffer, session.failureReason);
        
        // Write targets
        buffer.put(nativeToBigEndian(cast(uint)session.targets.length)[]);
        foreach (ref target; session.targets.byValue)
        {
            writeTarget(buffer, target);
        }
    }
    
    private static BuildSession readSession(ubyte[] data, ref size_t offset) @trusted
    {
        BuildSession session;
        
        // Read timestamps
        session.startTime = SysTime(readLong(data, offset));
        session.endTime = SysTime(readLong(data, offset));
        session.totalDuration = dur!"msecs"(readLong(data, offset));
        
        // Read counts
        session.totalTargets = readUint(data, offset);
        session.built = readUint(data, offset);
        session.cached = readUint(data, offset);
        session.failed = readUint(data, offset);
        session.maxParallelism = readUint(data, offset);
        
        // Read stats
        session.cacheHitRate = readDouble(data, offset);
        session.cacheHits = cast(size_t)readUlong(data, offset);
        session.cacheMisses = cast(size_t)readUlong(data, offset);
        session.targetsPerSecond = readDouble(data, offset);
        
        // Read flags
        session.succeeded = data[offset++] != 0;
        
        // Read failure reason
        session.failureReason = readString(data, offset);
        
        // Read targets
        immutable targetCount = readUint(data, offset);
        foreach (_; 0 .. targetCount)
        {
            auto target = readTarget(data, offset);
            session.targets[target.targetId] = target;
        }
        
        return session;
    }
    
    private static void writeTarget(ref Appender!(ubyte[]) buffer, ref const TargetMetric target) @trusted pure
    {
        writeString(buffer, target.targetId);
        buffer.put(nativeToBigEndian(target.startTime.stdTime)[]);
        buffer.put(nativeToBigEndian(target.endTime.stdTime)[]);
        buffer.put(nativeToBigEndian(target.duration.total!"msecs")[]);
        buffer.put(nativeToBigEndian(cast(ulong)target.outputSize)[]);
        buffer.put(cast(ubyte)target.status);
        writeString(buffer, target.error);
    }
    
    private static TargetMetric readTarget(ubyte[] data, ref size_t offset) @trusted
    {
        TargetMetric target;
        target.targetId = readString(data, offset);
        target.startTime = SysTime(readLong(data, offset));
        target.endTime = SysTime(readLong(data, offset));
        target.duration = dur!"msecs"(readLong(data, offset));
        target.outputSize = cast(size_t)readUlong(data, offset);
        target.status = cast(TargetStatus)data[offset++];
        target.error = readString(data, offset);
        return target;
    }
    
    private static void writeString(ref Appender!(ubyte[]) buffer, string str) @trusted pure
    {
        buffer.put(nativeToBigEndian(cast(uint)str.length)[]);
        buffer.put(cast(const(ubyte)[])str);
    }
    
    private static string readString(ubyte[] data, ref size_t offset) @trusted
    {
        immutable length = readUint(data, offset);
        auto slice = cast(string)data[offset .. offset + length];
        offset += length;
        return slice;
    }
    
    private static long readLong(ubyte[] data, ref size_t offset) @trusted
    {
        immutable ubyte[8] bytes = data[offset .. offset + 8][0 .. 8];
        offset += 8;
        return bigEndianToNative!long(bytes);
    }
    
    private static ulong readUlong(ubyte[] data, ref size_t offset) @trusted
    {
        immutable ubyte[8] bytes = data[offset .. offset + 8][0 .. 8];
        offset += 8;
        return bigEndianToNative!ulong(bytes);
    }
    
    private static uint readUint(ubyte[] data, ref size_t offset) @trusted
    {
        immutable ubyte[4] bytes = data[offset .. offset + 4][0 .. 4];
        offset += 4;
        return bigEndianToNative!uint(bytes);
    }
    
    private static double readDouble(ubyte[] data, ref size_t offset) @trusted
    {
        union Converter { ulong u; double d; }
        Converter conv;
        conv.u = readUlong(data, offset);
        return conv.d;
    }
}

/// Telemetry configuration
struct TelemetryConfig
{
    size_t maxSessions = 1000;      // Maximum sessions to retain
    size_t retentionDays = 90;      // Days to keep telemetry
    bool enabled = true;             // Enable/disable telemetry
    
    /// Load from environment variables
    static TelemetryConfig fromEnvironment() @safe
    {
        import std.process : environment;
        import std.conv : to;
        
        TelemetryConfig config;
        
        auto maxSessionsEnv = environment.get("BUILDER_TELEMETRY_MAX_SESSIONS");
        if (maxSessionsEnv)
            config.maxSessions = maxSessionsEnv.to!size_t;
        
        auto retentionEnv = environment.get("BUILDER_TELEMETRY_RETENTION_DAYS");
        if (retentionEnv)
            config.retentionDays = retentionEnv.to!size_t;
        
        auto enabledEnv = environment.get("BUILDER_TELEMETRY_ENABLED");
        if (enabledEnv)
            config.enabled = enabledEnv == "1" || enabledEnv == "true";
        
        return config;
    }
}

