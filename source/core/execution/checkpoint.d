module core.execution.checkpoint;

import std.stdio;
import std.file;
import std.path;
import std.datetime;
import std.algorithm;
import std.array;
import std.conv;
import core.graph.graph;
import utils.files.hash;
import errors.handling.result;

/// Build checkpoint - persists build state for resumption
struct Checkpoint
{
    string workspaceRoot;
    SysTime timestamp;
    BuildStatus[string] nodeStates;     // Target ID -> Status
    string[string] nodeHashes;          // Target ID -> Output hash
    size_t totalTargets;
    size_t completedTargets;
    size_t failedTargets;
    string[] failedTargetIds;
    
    /// Calculate completion percentage
    float completion() const pure nothrow @nogc @safe
    {
        if (totalTargets == 0)
            return 0.0;
        return (cast(float)completedTargets / cast(float)totalTargets) * 100.0;
    }
    
    /// Check if checkpoint is valid for given graph
    bool isValid(const BuildGraph graph) const @safe
    {
        // Check target count matches
        if (graph.nodes.length != totalTargets)
            return false;
        
        // Check all targets exist
        foreach (targetId; nodeStates.byKey)
        {
            if (targetId !in graph.nodes)
                return false;
        }
        
        return true;
    }
    
    /// Merge with current graph state (preserves successful builds)
    void mergeWith(BuildGraph graph) const @trusted
    {
        foreach (targetId, status; nodeStates)
        {
            if (targetId !in graph.nodes)
                continue;
            
            auto node = graph.nodes[targetId];
            
            // Only restore Success/Cached states
            // Failed/Pending nodes should retry
            if (status == BuildStatus.Success || status == BuildStatus.Cached)
            {
                node.status = status;
                if (auto hash = targetId in nodeHashes)
                    node.hash = *hash;
            }
        }
    }
}

/// Checkpoint manager - handles persistence
final class CheckpointManager
{
    private string checkpointDir;
    private string checkpointPath;
    private bool autoSave;
    
    @trusted // File system operations
    this(string workspaceRoot = ".", bool autoSave = true)
    {
        this.autoSave = autoSave;
        this.checkpointDir = buildPath(workspaceRoot, ".builder-cache");
        this.checkpointPath = buildPath(checkpointDir, "checkpoint.bin");
        
        if (!std.file.exists(checkpointDir))
            mkdirRecurse(checkpointDir);
    }
    
    /// Create checkpoint from build graph
    Checkpoint capture(const BuildGraph graph, string workspaceRoot = ".") const
    {
        Checkpoint checkpoint;
        checkpoint.workspaceRoot = absolutePath(workspaceRoot);
        checkpoint.timestamp = Clock.currTime();
        checkpoint.totalTargets = graph.nodes.length;
        
        foreach (targetId, node; graph.nodes)
        {
            checkpoint.nodeStates[targetId] = node.status;
            
            if (!node.hash.empty)
                checkpoint.nodeHashes[targetId] = node.hash;
            
            final switch (node.status)
            {
                case BuildStatus.Success:
                case BuildStatus.Cached:
                    checkpoint.completedTargets++;
                    break;
                
                case BuildStatus.Failed:
                    checkpoint.failedTargets++;
                    checkpoint.failedTargetIds ~= targetId;
                    break;
                
                case BuildStatus.Pending:
                case BuildStatus.Building:
                    break;
            }
        }
        
        return checkpoint;
    }
    
    /// Save checkpoint to disk
    void save(const ref Checkpoint checkpoint) @trusted
    {
        if (!autoSave)
            return;
        
        try
        {
            auto data = serialize(checkpoint);
            std.file.write(checkpointPath, data);
            
            writeln("Checkpoint saved: ", checkpoint.completedTargets, "/", 
                    checkpoint.totalTargets, " targets (", 
                    checkpoint.completion().to!string[0..min(5, checkpoint.completion().to!string.length)], "%)");
        }
        catch (Exception e)
        {
            // Non-fatal - just warn
            writeln("Warning: Failed to save checkpoint: ", e.msg);
        }
    }
    
    /// Load checkpoint from disk
    Result!(Checkpoint, string) load() @trusted
    {
        if (!std.file.exists(checkpointPath))
            return Result!(Checkpoint, string).err("No checkpoint found");
        
        try
        {
            auto data = cast(ubyte[])std.file.read(checkpointPath);
            auto checkpoint = deserialize(data);
            return Result!(Checkpoint, string).ok(checkpoint);
        }
        catch (Exception e)
        {
            return Result!(Checkpoint, string).err("Failed to load checkpoint: " ~ e.msg);
        }
    }
    
    /// Check if checkpoint exists
    @trusted // File system check
    bool exists() const nothrow
    {
        try
        {
            return std.file.exists(checkpointPath);
        }
        catch (Exception)
        {
            return false;
        }
    }
    
    /// Clear checkpoint
    void clear() @trusted
    {
        if (std.file.exists(checkpointPath))
        {
            try
            {
                std.file.remove(checkpointPath);
            }
            catch (Exception e)
            {
                writeln("Warning: Failed to clear checkpoint: ", e.msg);
            }
        }
    }
    
    /// Get checkpoint age
    Duration age() const @safe
    {
        if (!exists())
            return Duration.max;
        
        try
        {
            immutable modified = std.file.timeLastModified(checkpointPath);
            return Clock.currTime() - modified;
        }
        catch (Exception)
        {
            return Duration.max;
        }
    }
    
    /// Check if checkpoint is stale (> 24 hours)
    bool isStale() const @safe
    {
        return age() > 24.hours;
    }
    
    private ubyte[] serialize(const ref Checkpoint checkpoint) const pure @trusted
    {
        import std.bitmanip : nativeToBigEndian;
        
        ubyte[] buffer;
        buffer.reserve(4096); // Pre-allocate reasonable size
        
        // Magic number for validation
        buffer ~= nativeToBigEndian!uint(0x434B5054); // "CKPT"
        
        // Version
        buffer ~= cast(ubyte)1;
        
        // Workspace root
        buffer.writeString(checkpoint.workspaceRoot);
        
        // Timestamp (Unix time)
        buffer ~= nativeToBigEndian!long(checkpoint.timestamp.toUnixTime());
        
        // Counts
        buffer ~= nativeToBigEndian!uint(cast(uint)checkpoint.totalTargets);
        buffer ~= nativeToBigEndian!uint(cast(uint)checkpoint.completedTargets);
        buffer ~= nativeToBigEndian!uint(cast(uint)checkpoint.failedTargets);
        
        // Node states
        buffer ~= nativeToBigEndian!uint(cast(uint)checkpoint.nodeStates.length);
        foreach (targetId, status; checkpoint.nodeStates)
        {
            buffer.writeString(targetId);
            buffer ~= cast(ubyte)status;
        }
        
        // Node hashes
        buffer ~= nativeToBigEndian!uint(cast(uint)checkpoint.nodeHashes.length);
        foreach (targetId, hash; checkpoint.nodeHashes)
        {
            buffer.writeString(targetId);
            buffer.writeString(hash);
        }
        
        // Failed targets
        buffer ~= nativeToBigEndian!uint(cast(uint)checkpoint.failedTargetIds.length);
        foreach (targetId; checkpoint.failedTargetIds)
        {
            buffer.writeString(targetId);
        }
        
        return buffer;
    }
    
    private Checkpoint deserialize(ubyte[] data) const @trusted
    {
        import std.bitmanip : read, bigEndianToNative;
        
        size_t offset = 0;
        
        // Helper to read with offset management
        T readValue(T)(ref ubyte[] d, ref size_t off)
        {
            auto slice = d[off .. $];
            auto value = read!T(slice);
            off += T.sizeof;
            return value;
        }
        
        // Validate magic number
        immutable magic = readValue!uint(data, offset);
        if (magic != 0x434B5054)
            throw new Exception("Invalid checkpoint: bad magic number");
        
        // Version
        immutable version_ = readValue!ubyte(data, offset);
        if (version_ != 1)
            throw new Exception("Unsupported checkpoint version");
        
        Checkpoint checkpoint;
        
        // Workspace root
        checkpoint.workspaceRoot = readString(data, &offset);
        
        // Timestamp
        immutable unixTime = readValue!long(data, offset);
        checkpoint.timestamp = SysTime.fromUnixTime(unixTime);
        
        // Counts
        checkpoint.totalTargets = readValue!uint(data, offset);
        checkpoint.completedTargets = readValue!uint(data, offset);
        checkpoint.failedTargets = readValue!uint(data, offset);
        
        // Node states
        immutable stateCount = readValue!uint(data, offset);
        foreach (i; 0 .. stateCount)
        {
            auto targetId = readString(data, &offset);
            auto status = cast(BuildStatus)readValue!ubyte(data, offset);
            checkpoint.nodeStates[targetId] = status;
        }
        
        // Node hashes
        immutable hashCount = readValue!uint(data, offset);
        foreach (i; 0 .. hashCount)
        {
            auto targetId = readString(data, &offset);
            auto hash = readString(data, &offset);
            checkpoint.nodeHashes[targetId] = hash;
        }
        
        // Failed targets
        immutable failedCount = readValue!uint(data, offset);
        checkpoint.failedTargetIds.reserve(failedCount);
        foreach (i; 0 .. failedCount)
        {
            checkpoint.failedTargetIds ~= readString(data, &offset);
        }
        
        return checkpoint;
    }
}

/// Binary serialization helpers
private void writeString(ref ubyte[] buffer, string str) pure @trusted
{
    import std.bitmanip : nativeToBigEndian;
    
    // Length prefix
    buffer ~= nativeToBigEndian!uint(cast(uint)str.length);
    
    // String data
    buffer ~= cast(ubyte[])str;
}

private string readString(ubyte[] data, size_t* offset) @trusted
{
    import std.bitmanip : read;
    
    auto slice = data[*offset .. $];
    immutable len = read!uint(slice);
    *offset += uint.sizeof;
    
    if (*offset + len > data.length)
        throw new Exception("Invalid checkpoint: truncated string");
    
    auto str = cast(string)data[*offset .. *offset + len];
    *offset += len;
    
    return str;
}

