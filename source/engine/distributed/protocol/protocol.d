module engine.distributed.protocol.protocol;

import std.datetime : Duration, SysTime, Clock, seconds, dur;
import std.conv : to;
import std.digest : toHexString;
import std.bitmanip : write, read;
import std.string : toLower;
import infrastructure.errors;

/// Protocol version for compatibility checking
enum ProtocolVersion : ubyte
{
    V1 = 1
}

/// Unique identifier for messages (for correlation and deduplication)
struct MessageId
{
    ulong value;
    
    static MessageId generate() @trusted
    {
        import std.random : uniform;
        return MessageId(uniform!ulong());
    }
    
    string toString() const pure @safe
    {
        return value.to!string;
    }
}

/// Worker identifier (unique per worker instance)
struct WorkerId
{
    ulong value;
    
    /// Broadcast sentinel (0 = all workers)
    static WorkerId broadcast() pure nothrow @safe @nogc
    {
        return WorkerId(0);
    }
    
    bool isBroadcast() const pure nothrow @safe @nogc
    {
        return value == 0;
    }
    
    string toString() const pure @safe
    {
        return value.to!string;
    }
}

/// Action identifier (content-addressed via BLAKE3)
struct ActionId
{
    ubyte[32] hash;  // BLAKE3 output
    
    this(const ubyte[32] hash) pure nothrow @safe @nogc
    {
        this.hash = hash;
    }
    
    this(const ubyte[] hash) pure @safe
    {
        assert(hash.length == 32, "ActionId requires 32-byte hash");
        this.hash[0 .. 32] = hash[0 .. 32];
    }
    
    string toString() const @trusted
    {
        return toHexString(hash[]).toLower();
    }
    
    bool opEquals(const ActionId other) const pure nothrow @safe @nogc
    {
        return hash == other.hash;
    }
    
    size_t toHash() const pure nothrow @trusted @nogc
    {
        // Use first 8 bytes as hash
        return *cast(size_t*)hash.ptr;
    }
}

/// Artifact identifier (content-addressed via BLAKE3)
alias ArtifactId = ActionId;

/// Worker state enum (finite state machine)
enum WorkerState : ubyte
{
    Idle,       // Waiting for work
    Executing,  // Running build action
    Stealing,   // Attempting work theft
    Uploading,  // Uploading artifacts
    Failed,     // Permanent failure
    Draining    // Graceful shutdown
}

/// Action execution status
enum ResultStatus : ubyte
{
    Success,    // Completed successfully
    Failure,    // Command returned non-zero
    Timeout,    // Exceeded time limit
    Cancelled,  // Explicitly cancelled
    Error       // Internal error (sandbox, network, etc.)
}

/// Scheduling priority (higher = more urgent)
enum Priority : ubyte
{
    Low = 0,
    Normal = 50,
    High = 100,
    Critical = 200
}

/// Message compression algorithm
enum Compression : ubyte
{
    None = 0,
    Zstd = 1,
    Lz4 = 2
}

/// Security capabilities for hermetic execution
struct Capabilities
{
    bool network = false;           // Network access allowed?
    bool writeHome = false;         // Write to $HOME allowed?
    bool writeTmp = true;           // Write to /tmp allowed?
    string[] readPaths;             // Readable paths
    string[] writePaths;            // Writable paths
    size_t maxCpu = 0;              // Max CPU cores (0 = unlimited)
    size_t maxMemory = 0;           // Max memory bytes (0 = unlimited)
    Duration timeout = 1.seconds;   // Execution timeout
    
    /// Serialize to binary
    ubyte[] serialize() const pure @trusted
    {
        ubyte[] buffer;
        buffer.reserve(256);
        
        // Flags
        ubyte flags = 0;
        if (network) flags |= 0x01;
        if (writeHome) flags |= 0x02;
        if (writeTmp) flags |= 0x04;
        buffer.write!ubyte(flags, buffer.length);
        
        // Paths (length-prefixed arrays)
        buffer.write!uint(cast(uint)readPaths.length, buffer.length);
        foreach (path; readPaths)
        {
            buffer.write!uint(cast(uint)path.length, buffer.length);
            buffer ~= cast(ubyte[])path;
        }
        
        buffer.write!uint(cast(uint)writePaths.length, buffer.length);
        foreach (path; writePaths)
        {
            buffer.write!uint(cast(uint)path.length, buffer.length);
            buffer ~= cast(ubyte[])path;
        }
        
        // Resource limits
        buffer.write!ulong(maxCpu, buffer.length);
        buffer.write!ulong(maxMemory, buffer.length);
        buffer.write!long(timeout.total!"msecs", buffer.length);
        
        return buffer;
    }
    
    /// Deserialize from binary
    static Result!(Capabilities, BuildError) deserialize(const ubyte[] data) @system
    {
        if (data.length < 1)
            return Err!(Capabilities, BuildError)(
                new DistributedError("Invalid capabilities: empty data"));
        
        Capabilities caps;
        size_t offset = 0;
        
        // Make a mutable copy for read operations
        ubyte[] mutableData = cast(ubyte[])data.dup;
        
        try
        {
            // Flags
            auto flagSlice = mutableData[offset .. offset + 1];
            immutable flags = flagSlice.read!ubyte();
            offset += 1;
            caps.network = (flags & 0x01) != 0;
            caps.writeHome = (flags & 0x02) != 0;
            caps.writeTmp = (flags & 0x04) != 0;
            
            // Read paths
            auto readCountSlice = mutableData[offset .. offset + 4];
            immutable readCount = readCountSlice.read!uint();
            offset += 4;
            caps.readPaths.reserve(readCount);
            foreach (_; 0 .. readCount)
            {
                auto lenSlice = mutableData[offset .. offset + 4];
                immutable len = lenSlice.read!uint();
                offset += 4;
                caps.readPaths ~= cast(string)data[offset .. offset + len];
                offset += len;
            }
            
            // Write paths
            auto writeCountSlice = mutableData[offset .. offset + 4];
            immutable writeCount = writeCountSlice.read!uint();
            offset += 4;
            caps.writePaths.reserve(writeCount);
            foreach (_; 0 .. writeCount)
            {
                auto lenSlice2 = mutableData[offset .. offset + 4];
                immutable len = lenSlice2.read!uint();
                offset += 4;
                caps.writePaths ~= cast(string)data[offset .. offset + len];
                offset += len;
            }
            
            // Resource limits
            auto cpuSlice = mutableData[offset .. offset + 8];
            caps.maxCpu = cpuSlice.read!ulong();
            offset += 8;
            auto memSlice = mutableData[offset .. offset + 8];
            caps.maxMemory = memSlice.read!ulong();
            offset += 8;
            auto timeSlice = mutableData[offset .. offset + 8];
            immutable timeoutMs = timeSlice.read!long();
            caps.timeout = dur!"msecs"(timeoutMs);
            
            return Ok!(Capabilities, BuildError)(caps);
        }
        catch (Exception e)
        {
            return Err!(Capabilities, BuildError)(
                new DistributedError("Failed to deserialize capabilities: " ~ e.msg));
        }
    }
}

/// Input artifact specification
struct InputSpec
{
    ArtifactId id;      // Artifact identifier
    string path;        // Mounted path in sandbox
    bool executable;    // Executable bit?
}

/// Output artifact specification
struct OutputSpec
{
    string path;        // Path in sandbox
    bool optional;      // Failure if missing?
}

/// Resource usage metrics
struct ResourceUsage
{
    Duration cpuTime;       // Total CPU time
    size_t peakMemory;      // Peak memory usage (bytes)
    size_t diskRead;        // Disk bytes read
    size_t diskWrite;       // Disk bytes written
    size_t networkTx;       // Network bytes sent
    size_t networkRx;       // Network bytes received
}

/// System metrics (for health monitoring)
struct SystemMetrics
{
    float cpuUsage;         // CPU utilization [0.0, 1.0]
    float memoryUsage;      // Memory utilization [0.0, 1.0]
    float diskUsage;        // Disk utilization [0.0, 1.0]
    size_t queueDepth;      // Local queue size
    size_t activeActions;   // Currently executing
}

/// Build action request (coordinator → worker)
final class ActionRequest
{
    ActionId id;                    // Unique action identifier
    string command;                 // Shell command to execute
    string[string] env;             // Environment variables
    InputSpec[] inputs;             // Input artifacts
    OutputSpec[] outputs;           // Expected outputs
    Capabilities capabilities;      // Security sandbox
    Priority priority;              // Scheduling priority
    Duration timeout;               // Max execution time
    
    this(ActionId id, string command, string[string] env, 
         InputSpec[] inputs, OutputSpec[] outputs,
         Capabilities capabilities, Priority priority, Duration timeout) @safe
    {
        this.id = id;
        this.command = command;
        this.env = env;
        this.inputs = inputs;
        this.outputs = outputs;
        this.capabilities = capabilities;
        this.priority = priority;
        this.timeout = timeout;
    }
    
    /// Serialize to binary format
    ubyte[] serialize() const pure @trusted
    {
        ubyte[] buffer;
        buffer.reserve(4096);
        
        // Action ID
        buffer ~= id.hash;
        
        // Command (length-prefixed string)
        buffer.write!uint(cast(uint)command.length, buffer.length);
        buffer ~= cast(ubyte[])command;
        
        // Environment (count + key-value pairs)
        buffer.write!uint(cast(uint)env.length, buffer.length);
        foreach (key, value; env)
        {
            buffer.write!uint(cast(uint)key.length, buffer.length);
            buffer ~= cast(ubyte[])key;
            buffer.write!uint(cast(uint)value.length, buffer.length);
            buffer ~= cast(ubyte[])value;
        }
        
        // Inputs
        buffer.write!uint(cast(uint)inputs.length, buffer.length);
        foreach (input; inputs)
        {
            buffer ~= input.id.hash;
            buffer.write!uint(cast(uint)input.path.length, buffer.length);
            buffer ~= cast(ubyte[])input.path;
            buffer.write!ubyte(input.executable ? 1 : 0, buffer.length);
        }
        
        // Outputs
        buffer.write!uint(cast(uint)outputs.length, buffer.length);
        foreach (output; outputs)
        {
            buffer.write!uint(cast(uint)output.path.length, buffer.length);
            buffer ~= cast(ubyte[])output.path;
            buffer.write!ubyte(output.optional ? 1 : 0, buffer.length);
        }
        
        // Capabilities
        auto capsData = capabilities.serialize();
        buffer.write!uint(cast(uint)capsData.length, buffer.length);
        buffer ~= capsData;
        
        // Priority and timeout
        buffer.write!ubyte(priority, buffer.length);
        buffer.write!long(timeout.total!"msecs", buffer.length);
        
        return buffer;
    }
}

/// Build action result (worker → coordinator)
struct ActionResult
{
    ActionId id;                // Which action
    ResultStatus status;        // Outcome
    Duration duration;          // Execution time
    ArtifactId[] outputs;       // Generated artifacts
    string stdout;              // Captured stdout
    string stderr;              // Captured stderr
    int exitCode;               // Process exit code
    ResourceUsage resources;    // Resource consumption
}

/// Work steal request (worker → worker)
struct StealRequest
{
    WorkerId thief;     // Who wants work
    WorkerId victim;    // Who has work
    Priority minPriority = Priority.Low;  // Only steal if >= this
}

/// Work steal response (worker → worker)
struct StealResponse
{
    WorkerId victim;        // Who responded
    WorkerId thief;         // Who asked
    bool hasWork;           // Work available?
    ActionRequest action;   // Stolen action (if hasWork)
}

/// Heartbeat message (worker → coordinator)
struct HeartBeat
{
    WorkerId worker;        // Worker identifier
    WorkerState state;      // Current state
    SystemMetrics metrics;  // System metrics
    SysTime timestamp;      // When sent
}

/// Shutdown command (coordinator → worker)
struct Shutdown
{
    bool graceful;          // Finish current work?
    Duration timeout;       // Max wait time
}

/// Message envelope (wraps all messages)
struct Envelope(T)
{
    ProtocolVersion version_ = ProtocolVersion.V1;
    MessageId id;
    WorkerId sender;
    WorkerId recipient;
    SysTime timestamp;
    Compression compression = Compression.None;
    T payload;
    
    this(WorkerId sender, WorkerId recipient, T payload) @safe
    {
        this.id = MessageId.generate();
        this.sender = sender;
        this.recipient = recipient;
        this.timestamp = Clock.currTime;
        this.payload = payload;
    }
}

/// Distributed build errors
class DistributedError : BaseBuildError
{
    this(string message, string file = __FILE__, size_t line = __LINE__) @trusted
    {
        super(ErrorCode.DistributedError, message);
        addContext(ErrorContext("file", file));
        addContext(ErrorContext("line", line.to!string));
    }
    
    override ErrorCategory category() const pure nothrow
    {
        return ErrorCategory.System;
    }
    
    override bool recoverable() const pure nothrow
    {
        return false;
    }
}

/// Execution errors (sandbox, timeout, etc.)
class ExecutionError : DistributedError
{
    this(string message, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super("Execution failed: " ~ message, file, line);
    }
}

/// Network errors (connection, timeout, etc.)
class NetworkError : DistributedError
{
    this(string message, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super("Network error: " ~ message, file, line);
    }
}

/// Worker errors (unavailable, failed, etc.)
class WorkerError : DistributedError
{
    this(string message, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super("Worker error: " ~ message, file, line);
    }
}



