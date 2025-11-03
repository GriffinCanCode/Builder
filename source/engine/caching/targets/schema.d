module engine.caching.targets.schema;

import std.datetime : SysTime;
import infrastructure.utils.serialization;

/// Serializable cache entry for target-level caching
/// Schema version 1.0 - initial release
@Serializable(SchemaVersion(1, 0), 0x54435343) // "TCSC" - Target Cache Schema
struct SerializableCacheEntry
{
    @Field(1) string targetId;
    @Field(2) string buildHash;
    @Field(3) @Packed long timestamp;        // SysTime.stdTime
    @Field(4) @Packed long lastAccess;       // SysTime.stdTime
    @Field(5) string metadataHash;
    @Field(6) string[] sourceFiles;          // Keys from sourceHashes
    @Field(7) string[] sourceHashValues;     // Values from sourceHashes
    @Field(8) string[] metadataFiles;        // Keys from sourceMetadata
    @Field(9) string[] metadataValues;       // Values from sourceMetadata
    @Field(10) string[] depFiles;            // Keys from depHashes
    @Field(11) string[] depHashValues;       // Values from depHashes
}

/// Serializable container for multiple cache entries
@Serializable(SchemaVersion(1, 0), 0x54434348) // "TCCH" - Target Cache Container Hash
struct SerializableCacheContainer
{
    @Field(1) uint version_ = 1;
    @Field(2) SerializableCacheEntry[] entries;
}

/// Convert from runtime CacheEntry to serializable format
SerializableCacheEntry toSerializable(T)(auto ref const T entry) @trusted
{
    SerializableCacheEntry serializable;
    serializable.targetId = entry.targetId;
    serializable.buildHash = entry.buildHash;
    serializable.timestamp = entry.timestamp.stdTime;
    serializable.lastAccess = entry.lastAccess.stdTime;
    serializable.metadataHash = entry.metadataHash;
    
    // Convert associative arrays to parallel arrays for efficient serialization
    foreach (k, v; entry.sourceHashes)
    {
        serializable.sourceFiles ~= k;
        serializable.sourceHashValues ~= v;
    }
    
    foreach (k, v; entry.sourceMetadata)
    {
        serializable.metadataFiles ~= k;
        serializable.metadataValues ~= v;
    }
    
    foreach (k, v; entry.depHashes)
    {
        serializable.depFiles ~= k;
        serializable.depHashValues ~= v;
    }
    
    return serializable;
}

/// Convert from serializable format to runtime CacheEntry
T fromSerializable(T)(auto ref const SerializableCacheEntry serializable) @trusted
{
    import std.datetime : SysTime;
    
    T entry;
    entry.targetId = cast(string)serializable.targetId;
    entry.buildHash = cast(string)serializable.buildHash;
    entry.timestamp = SysTime(serializable.timestamp);
    entry.lastAccess = SysTime(serializable.lastAccess);
    entry.metadataHash = cast(string)serializable.metadataHash;
    
    // Reconstruct associative arrays
    foreach (i; 0 .. serializable.sourceFiles.length)
        entry.sourceHashes[serializable.sourceFiles[i]] = serializable.sourceHashValues[i];
    
    foreach (i; 0 .. serializable.metadataFiles.length)
        entry.sourceMetadata[serializable.metadataFiles[i]] = serializable.metadataValues[i];
    
    foreach (i; 0 .. serializable.depFiles.length)
        entry.depHashes[serializable.depFiles[i]] = serializable.depHashValues[i];
    
    return entry;
}

