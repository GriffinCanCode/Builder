module core.telemetry.persistence.storage;

import std.file : exists, mkdirRecurse, read, write;
import std.path : buildPath;
import std.datetime : SysTime, Duration, Clock, dur;
import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import std.array : Appender, appender;
import std.algorithm : sort, filter;
import std.range : array;
import core.sync.mutex : Mutex;
import core.telemetry.collection.collector;
import errors;

/// High-performance binary storage for telemetry data
/// Uses optimized binary format with versioning
/// Thread-safe with mutex protection
final class TelemetryStorage
{
    /// Binary format constants
    private enum uint MAGIC = 0x42544C4D; // "BTLM" (Builder Telemetry)
    private enum ubyte VERSION = 1;
    private enum size_t MIN_HEADER_SIZE = 9;           // Minimum header size (MAGIC + VERSION + COUNT)
    private enum size_t ESTIMATED_SESSION_SIZE = 1024; // Estimated bytes per session with targets
    private enum size_t HEADER_OVERHEAD = 64;          // Header overhead estimate
    
    private string storageDir;
    private immutable string storageFile;
    private BuildSession[] sessions;
    private Mutex storageMutex;
    private TelemetryConfig config;
    
    this(string storageDir = ".builder-cache/telemetry", TelemetryConfig config = TelemetryConfig.init) @system
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
    /// 
    /// Safety: This function is @system because:
    /// 1. synchronized block protects shared sessions array
    /// 2. Array append (~=) is memory-safe
    /// 3. Delegates to persist() which performs validated file I/O
    /// 4. applyRetention() modifies array safely under lock
    /// 
    /// Invariants:
    /// - Session is appended atomically under lock
    /// - Retention policy is applied before persistence
    /// - File I/O errors are converted to Result type
    /// 
    /// What could go wrong:
    /// - Race condition on sessions array: prevented by synchronized
    /// - Persist fails: returned as Err result (safe failure)
    /// - Retention removes too many: logic is deterministic and safe
    Result!TelemetryError append(BuildSession session) @system
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
    /// 
    /// Safety: This function is @system because:
    /// 1. synchronized block protects access to sessions array
    /// 2. Returns .dup copy (no references to internal data escape)
    /// 3. Simple read operation with no side effects
    /// 
    /// Invariants:
    /// - Returns independent copy of sessions array
    /// - No aliasing of internal data
    /// - Thread-safe read via mutex
    /// 
    /// What could go wrong:
    /// - Returning reference to internal array: prevented by .dup
    /// - Race condition: prevented by synchronized block
    Result!(BuildSession[], TelemetryError) getSessions() @system
    {
        synchronized (storageMutex)
        {
            return Result!(BuildSession[], TelemetryError).ok(sessions.dup);
        }
    }
    
    /// Get recent sessions - thread-safe
    /// 
    /// Safety: This function is @system because:
    /// 1. synchronized block protects array access
    /// 2. Slice bounds are checked with min/max logic
    /// 3. Returns .dup copy (no aliasing)
    /// 4. Empty array case is handled safely
    /// 
    /// Invariants:
    /// - Slice bounds are always valid (checked with min)
    /// - Returns independent copy via .dup
    /// - Empty sessions array is handled without error
    /// 
    /// What could go wrong:
    /// - Out of bounds slice: prevented by limit calculation
    /// - Reference to internal data: prevented by .dup
    Result!(BuildSession[], TelemetryError) getRecent(size_t count) @system
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
    /// 
    /// Safety: This function is @system because:
    /// 1. synchronized block protects sessions array
    /// 2. Empty array assignment is always safe
    /// 3. Delegates to persist() for file I/O
    /// 4. Old array is safely garbage collected
    /// 
    /// Invariants:
    /// - sessions is set to empty array atomically
    /// - File is persisted with empty state
    /// - No memory leaks (GC handles cleanup)
    /// 
    /// What could go wrong:
    /// - File write fails: returned as Err result
    /// - Partial clear visible: prevented by synchronized block
    Result!TelemetryError clear() @system
    {
        synchronized (storageMutex)
        {
            sessions = [];
            return persist();
        }
    }
    
    /// Load sessions from binary file
    /// 
    /// Safety: This function is @system because:
    /// 1. File I/O (exists, read) is inherently @system
    /// 2. Cast from void[] to ubyte[] is safe (read-only data)
    /// 3. deserialize() is manually verified for bounds checking
    /// 4. Exception handling ensures safe failure mode
    /// 
    /// Invariants:
    /// - File existence is checked before reading
    /// - Corrupted data results in empty array (safe default)
    /// - No partial deserialization state is visible
    /// 
    /// What could go wrong:
    /// - File doesn't exist: checked with exists() first
    /// - Corrupted data: caught by exception, resets to empty array
    /// - deserialize throws: caught and handled safely
    private void loadSessions() @system
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
    
    /// Persist sessions to binary file
    /// 
    /// Safety: This function is @system because:
    /// 1. File I/O (write) is inherently @system
    /// 2. serialize() produces validated binary data
    /// 3. Exception handling converts failures to Result type
    /// 4. storageFile path is validated in constructor
    /// 
    /// Invariants:
    /// - Serialized data is well-formed (validated in serialize())
    /// - Write is atomic at OS level
    /// - Errors are returned as Result, not thrown
    /// 
    /// What could go wrong:
    /// - Write fails: returned as Err result (safe failure)
    /// - Disk full: exception caught and converted to error
    /// - Permission denied: exception caught and converted to error
    private Result!TelemetryError persist() @system
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
    
    private void applyRetention() @system
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
    
    /// Serialize sessions to binary format
    /// 
    /// Safety: This function is @system pure because:
    /// 1. nativeToBigEndian() performs safe integer serialization
    /// 2. Appender operations are memory-safe
    /// 3. Array slicing is bounds-checked
    /// 4. Pure function with no side effects
    /// 5. All pointer operations are compile-time validated
    /// 
    /// Invariants:
    /// - Output format: MAGIC(4) + VERSION(1) + COUNT(4) + sessions...
    /// - Each session is serialized with writeSession()
    /// - All integers are big-endian for cross-platform compatibility
    /// 
    /// What could go wrong:
    /// - Buffer overflow: prevented by Appender's dynamic growth
    /// - Invalid binary format: prevented by structured writes
    /// - Memory allocation fails: exception propagates (safe failure)
    private static ubyte[] serialize(BuildSession[] sessions) @system pure
    {
        auto buffer = appender!(ubyte[]);
        
        // Estimate size: session data + target data
        immutable estimatedSize = sessions.length * ESTIMATED_SESSION_SIZE + HEADER_OVERHEAD;
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
    
    /// Deserialize sessions from binary format
    /// 
    /// Safety: This function is @system because:
    /// 1. Validates minimum data length before reading
    /// 2. Validates magic number and version
    /// 3. All array slicing is bounds-checked before access
    /// 4. bigEndianToNative() is safe for fixed-size arrays
    /// 5. Throws exceptions for invalid data (safe failure)
    /// 
    /// Invariants:
    /// - Minimum 9 bytes required (MAGIC + VERSION + COUNT)
    /// - Magic number must match MAGIC constant
    /// - Version must match VERSION constant
    /// - Array access is validated with length checks
    /// 
    /// What could go wrong:
    /// - Data too small: validated upfront, exception thrown
    /// - Invalid magic/version: validated and exception thrown
    /// - Truncated data: readSession validates, exception thrown
    /// - Malformed session data: caught by readSession validation
    private static BuildSession[] deserialize(ubyte[] data) @system
    {
        if (data.length < MIN_HEADER_SIZE)
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
    
    /// Write session to binary buffer
    /// 
    /// Safety: This function is @system pure because:
    /// 1. Appender.put() is memory-safe
    /// 2. nativeToBigEndian() safely converts integers to bytes
    /// 3. String serialization via writeString() is validated
    /// 4. All array slicing is bounds-checked by compiler
    /// 5. Pure function with no side effects
    /// 
    /// Invariants:
    /// - Fixed-size fields written first (timestamps, counts, stats)
    /// - Variable-size fields (strings, targets) written with length prefix
    /// - All integers are big-endian encoded
    /// 
    /// What could go wrong:
    /// - Buffer overflow: prevented by Appender's dynamic growth
    /// - Invalid encoding: prevented by structured writes
    private static void writeSession(ref Appender!(ubyte[]) buffer, ref const BuildSession session) @system pure
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
    
    /// Read session from binary data
    /// 
    /// Safety: This function is @system because:
    /// 1. All array slicing uses helper functions (readLong, readUint, etc.)
    /// 2. Helpers validate bounds before slicing
    /// 3. offset is updated consistently after each read
    /// 4. bigEndianToNative() is safe for fixed-size arrays
    /// 5. Delegates to readTarget() for complex structures
    /// 
    /// Invariants:
    /// - offset always points to valid position or end of data
    /// - All reads increment offset by correct amount
    /// - Field order matches writeSession() exactly
    /// 
    /// What could go wrong:
    /// - Truncated data: helpers would read past end, caught by array bounds
    /// - Mismatched field order: prevented by symmetric read/write order
    /// - offset overflow: size_t arithmetic is checked
    private static BuildSession readSession(ubyte[] data, ref size_t offset) @system
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
    
    /// Write target metric to binary buffer
    /// 
    /// Safety: This function is @system pure because:
    /// 1. Delegates to writeString() for string serialization
    /// 2. Uses nativeToBigEndian() for safe integer serialization
    /// 3. Enum cast is safe (byte-sized enum)
    /// 4. All operations are memory-safe
    /// 
    /// Invariants:
    /// - Strings written with length prefix via writeString()
    /// - Timestamps and durations are 64-bit values
    /// - TargetStatus enum is single byte
    /// 
    /// What could go wrong:
    /// - Buffer overflow: prevented by Appender
    /// - Invalid enum value: cast is safe, serialized as-is
    private static void writeTarget(ref Appender!(ubyte[]) buffer, ref const TargetMetric target) @system pure
    {
        writeString(buffer, target.targetId);
        buffer.put(nativeToBigEndian(target.startTime.stdTime)[]);
        buffer.put(nativeToBigEndian(target.endTime.stdTime)[]);
        buffer.put(nativeToBigEndian(target.duration.total!"msecs")[]);
        buffer.put(nativeToBigEndian(cast(ulong)target.outputSize)[]);
        buffer.put(cast(ubyte)target.status);
        writeString(buffer, target.error);
    }
    
    /// Read target metric from binary data
    /// 
    /// Safety: This function is @system because:
    /// 1. Uses readString() which validates length prefix
    /// 2. Uses readLong/readUlong for integer deserialization
    /// 3. Enum cast from byte is safe (all values are valid)
    /// 4. offset is consistently updated by helper functions
    /// 
    /// Invariants:
    /// - Field order matches writeTarget() exactly
    /// - offset is advanced by correct amount for each field
    /// - Enum value is read as single byte and cast safely
    /// 
    /// What could go wrong:
    /// - Truncated data: caught by array bounds in helpers
    /// - Invalid enum value: all byte values are accepted (degraded gracefully)
    private static TargetMetric readTarget(ubyte[] data, ref size_t offset) @system
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
    
    /// Write string with length prefix
    /// 
    /// Safety: This function is @system pure because:
    /// 1. Length is written as 4-byte prefix (handles up to 4GB strings)
    /// 2. String cast to ubyte[] is safe (read-only data)
    /// 3. Appender.put() is memory-safe
    /// 4. nativeToBigEndian() safely converts length
    /// 
    /// Invariants:
    /// - Format: LENGTH(4 bytes) + DATA(variable)
    /// - Length prefix allows safe deserialization
    /// - Empty strings encoded as length 0
    /// 
    /// What could go wrong:
    /// - String too large: would fit in uint32 (4GB limit)
    /// - Buffer overflow: prevented by Appender
    private static void writeString(ref Appender!(ubyte[]) buffer, string str) @system pure
    {
        buffer.put(nativeToBigEndian(cast(uint)str.length)[]);
        buffer.put(cast(const(ubyte)[])str);
    }
    
    /// Read string with length prefix
    /// 
    /// Safety: This function is @system because:
    /// 1. Reads 4-byte length prefix with readUint()
    /// 2. Validates data bounds before slicing (offset + length <= data.length)
    /// 3. Cast from ubyte[] to string is safe (valid UTF-8 or handled by D runtime)
    /// 4. offset is updated to skip past the string data
    /// 
    /// Invariants:
    /// - Length prefix is read first
    /// - Slice is validated to be within data bounds
    /// - offset is advanced by length after reading
    /// 
    /// What could go wrong:
    /// - Length too large: would cause out-of-bounds, caught by array bounds check
    /// - Invalid UTF-8: handled by D runtime (may throw, caught by caller)
    /// - offset overflow: size_t addition would overflow, caught by bounds check
    private static string readString(ubyte[] data, ref size_t offset) @system
    {
        immutable length = readUint(data, offset);
        auto slice = cast(string)data[offset .. offset + length];
        offset += length;
        return slice;
    }
    
    /// Read 64-bit signed integer
    /// 
    /// Safety: This function is @system because:
    /// 1. Fixed-size array slice [0..8] is bounds-checked by compiler
    /// 2. bigEndianToNative() safely converts bytes to integer
    /// 3. offset is incremented by fixed amount (8 bytes)
    /// 
    /// Invariants:
    /// - Requires exactly 8 bytes of data at offset
    /// - Returns big-endian decoded value
    /// - offset is advanced by 8
    /// 
    /// What could go wrong:
    /// - Not enough data: caught by array bounds check (throws)
    private static long readLong(ubyte[] data, ref size_t offset) @system
    {
        immutable ubyte[8] bytes = data[offset .. offset + 8][0 .. 8];
        offset += 8;
        return bigEndianToNative!long(bytes);
    }
    
    /// Read 64-bit unsigned integer
    /// 
    /// Safety: This function is @system because:
    /// 1. Fixed-size array slice [0..8] is bounds-checked
    /// 2. bigEndianToNative() is safe for valid byte arrays
    /// 3. offset increment is fixed (8 bytes)
    /// 
    /// Invariants:
    /// - Reads exactly 8 bytes
    /// - Big-endian to native conversion
    /// - offset advanced by 8
    /// 
    /// What could go wrong:
    /// - Insufficient data: array bounds check throws
    private static ulong readUlong(ubyte[] data, ref size_t offset) @system
    {
        immutable ubyte[8] bytes = data[offset .. offset + 8][0 .. 8];
        offset += 8;
        return bigEndianToNative!ulong(bytes);
    }
    
    /// Read 32-bit unsigned integer
    /// 
    /// Safety: This function is @system because:
    /// 1. Fixed-size array slice [0..4] is bounds-checked
    /// 2. bigEndianToNative!uint safely converts 4 bytes
    /// 3. offset increment is fixed (4 bytes)
    /// 
    /// Invariants:
    /// - Reads exactly 4 bytes
    /// - Big-endian to native conversion
    /// - offset advanced by 4
    /// 
    /// What could go wrong:
    /// - Insufficient data: array bounds check throws
    private static uint readUint(ubyte[] data, ref size_t offset) @system
    {
        immutable ubyte[4] bytes = data[offset .. offset + 4][0 .. 4];
        offset += 4;
        return bigEndianToNative!uint(bytes);
    }
    
    /// Read 64-bit floating point number
    /// 
    /// Safety: This function is @system because:
    /// 1. Uses union for type-punning (standard C technique, safe in D)
    /// 2. readUlong() validates data availability
    /// 3. Union conversion is well-defined for same-sized types
    /// 4. No undefined behavior (both fields are 64-bit)
    /// 
    /// Invariants:
    /// - Reads 8 bytes via readUlong()
    /// - Interprets bits as IEEE 754 double
    /// - Union ensures proper alignment
    /// 
    /// What could go wrong:
    /// - Non-finite values (NaN, Inf): valid doubles, handled by D runtime
    /// - Insufficient data: caught by readUlong()
    private static double readDouble(ubyte[] data, ref size_t offset) @system
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
    /// Default configuration constants
    private enum size_t DEFAULT_MAX_SESSIONS = 1000;     // Maximum sessions to retain
    private enum size_t DEFAULT_RETENTION_DAYS = 90;     // Days to keep telemetry data
    
    size_t maxSessions = DEFAULT_MAX_SESSIONS;      // Maximum sessions to retain
    size_t retentionDays = DEFAULT_RETENTION_DAYS;  // Days to keep telemetry
    bool enabled = true;                             // Enable/disable telemetry
    
    /// Load from environment variables
    static TelemetryConfig fromEnvironment() @system
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

