module engine.caching.actions.schema;

import std.datetime : SysTime;
import infrastructure.utils.serialization;

/// Serializable ActionId for action-level caching
@Serializable(SchemaVersion(1, 0))
struct SerializableActionId
{
    @Field(1) string targetId;
    @Field(2) uint actionType;      // Cast from ActionType enum
    @Field(3) string inputHash;
    @Field(4) @Optional string subId;
}

/// Serializable action entry for action-level caching
/// Schema version 1.0 - initial release
@Serializable(SchemaVersion(1, 0), 0x41435343) // "ACSC" - Action Cache Schema
struct SerializableActionEntry
{
    @Field(1) SerializableActionId actionId;
    @Field(2) string[] inputs;
    @Field(3) string[] inputHashKeys;
    @Field(4) string[] inputHashValues;
    @Field(5) string[] outputs;
    @Field(6) string[] outputHashKeys;
    @Field(7) string[] outputHashValues;
    @Field(8) string[] metadataKeys;
    @Field(9) string[] metadataValues;
    @Field(10) @Packed long timestamp;
    @Field(11) @Packed long lastAccess;
    @Field(12) string executionHash;
    @Field(13) bool success;
}

/// Serializable container for multiple action entries
@Serializable(SchemaVersion(1, 0), 0x41434348) // "ACCH" - Action Cache Container Hash
struct SerializableActionContainer
{
    @Field(1) uint version_ = 1;
    @Field(2) SerializableActionEntry[] entries;
}

/// Convert from runtime ActionId to serializable format
SerializableActionId toSerializableId(T)(auto ref const T actionId) @trusted
{
    SerializableActionId serializable;
    serializable.targetId = actionId.targetId;
    serializable.actionType = cast(uint)actionId.type;
    serializable.inputHash = actionId.inputHash;
    serializable.subId = actionId.subId;
    return serializable;
}

/// Convert from runtime ActionEntry to serializable format
SerializableActionEntry toSerializable(T)(auto ref const T entry) @trusted
{
    SerializableActionEntry serializable;
    serializable.actionId = toSerializableId(entry.actionId);
    serializable.inputs = entry.inputs.dup;
    serializable.outputs = entry.outputs.dup;
    serializable.timestamp = entry.timestamp.stdTime;
    serializable.lastAccess = entry.lastAccess.stdTime;
    serializable.executionHash = entry.executionHash;
    serializable.success = entry.success;
    
    // Convert associative arrays to parallel arrays
    foreach (k, v; entry.inputHashes)
    {
        serializable.inputHashKeys ~= k;
        serializable.inputHashValues ~= v;
    }
    
    foreach (k, v; entry.outputHashes)
    {
        serializable.outputHashKeys ~= k;
        serializable.outputHashValues ~= v;
    }
    
    foreach (k, v; entry.metadata)
    {
        serializable.metadataKeys ~= k;
        serializable.metadataValues ~= v;
    }
    
    return serializable;
}

/// Convert from serializable ActionId to runtime format
TId fromSerializableId(TId, TType)(auto ref const SerializableActionId serializable) @trusted
{
    TId actionId;
    actionId.targetId = cast(string)serializable.targetId;
    actionId.type = cast(TType)serializable.actionType;
    actionId.inputHash = cast(string)serializable.inputHash;
    actionId.subId = cast(string)serializable.subId;
    return actionId;
}

/// Convert from serializable ActionEntry to runtime format
T fromSerializable(T, TId, TType)(auto ref const SerializableActionEntry serializable) @trusted
{
    T entry;
    entry.actionId = fromSerializableId!(TId, TType)(serializable.actionId);
    entry.inputs = serializable.inputs.dup;
    entry.outputs = serializable.outputs.dup;
    entry.timestamp = SysTime(serializable.timestamp);
    entry.lastAccess = SysTime(serializable.lastAccess);
    entry.executionHash = cast(string)serializable.executionHash;
    entry.success = serializable.success;
    
    // Reconstruct associative arrays
    foreach (i; 0 .. serializable.inputHashKeys.length)
        entry.inputHashes[serializable.inputHashKeys[i]] = serializable.inputHashValues[i];
    
    foreach (i; 0 .. serializable.outputHashKeys.length)
        entry.outputHashes[serializable.outputHashKeys[i]] = serializable.outputHashValues[i];
    
    foreach (i; 0 .. serializable.metadataKeys.length)
        entry.metadata[serializable.metadataKeys[i]] = serializable.metadataValues[i];
    
    return entry;
}

