module engine.graph.caching.schema;

import infrastructure.utils.serialization;

/// Serializable build node for graph storage
/// Schema version 1.0 - initial release
@Serializable(SchemaVersion(1, 0))
struct SerializableBuildNode
{
    @Field(1) string targetId;
    @Field(2) SerializableTarget target;
    @Field(3) string[] dependencyIds;
    @Field(4) string[] dependentIds;
    @Field(5) uint status;               // BuildStatus enum
    @Field(6) string hash;
    @Field(7) @Packed uint retryAttempts;
    @Field(8) @Optional string lastError;
    @Field(9) @Packed uint pendingDeps;
}

/// Serializable target for graph storage
@Serializable(SchemaVersion(1, 0))
struct SerializableTarget
{
    @Field(1) string name;
    @Field(2) string type;
    @Field(3) string[] sources;
    @Field(4) string[] dependencies;
    @Field(5) string[] flags;
    @Field(6) string outputPath;
    @Field(7) string[] additionalKeys;
    @Field(8) string[] additionalValues;
}

/// Serializable build graph container
/// Schema version 1.0 - initial release
@Serializable(SchemaVersion(1, 0), 0x42475246) // "BGRF" - Build Graph Format
struct SerializableBuildGraph
{
    @Field(1) SerializableBuildNode[] nodes;
    @Field(2) string[] rootIds;
    @Field(3) uint validationMode;       // ValidationMode enum
    @Field(4) bool isValidated;
}

/// Convert from runtime Target to serializable format
SerializableTarget toSerializableTarget(T)(auto ref const T target) @trusted
{
    import std.conv : to;
    
    SerializableTarget serializable;
    serializable.name = target.name;
    serializable.type = target.type.to!string;
    serializable.sources = target.sources.dup;
    
    // Use deps field (not dependencies)
    static if (__traits(hasMember, T, "deps"))
        serializable.dependencies = target.deps.dup;
    else static if (__traits(hasMember, T, "dependencies"))
        serializable.dependencies = target.dependencies.dup;
    
    // Handle flags if present
    static if (__traits(hasMember, T, "flags"))
        serializable.flags = target.flags.dup;
    
    static if (__traits(hasMember, T, "outputPath"))
        serializable.outputPath = target.outputPath;
    
    // Serialize additional fields as key-value pairs
    static if (__traits(hasMember, T, "additionalFields"))
    {
        foreach (k, v; target.additionalFields)
        {
            serializable.additionalKeys ~= k;
            serializable.additionalValues ~= v;
        }
    }
    
    return serializable;
}

/// Convert from runtime BuildNode to serializable format
SerializableBuildNode toSerializable(TNode)(auto ref const TNode node) @trusted
{
    SerializableBuildNode serializable;
    serializable.targetId = node.id.toString();
    serializable.target = toSerializableTarget(node.target);
    
    // Convert IDs to strings
    foreach (dep; node.dependencyIds)
        serializable.dependencyIds ~= dep.toString();
    
    foreach (dep; node.dependentIds)
        serializable.dependentIds ~= dep.toString();
    
    serializable.status = cast(uint)node.status;
    serializable.hash = node.hash;
    serializable.retryAttempts = cast(uint)node.retryAttempts;
    serializable.lastError = node.lastError;
    serializable.pendingDeps = cast(uint)node.pendingDeps;
    
    return serializable;
}

/// Convert from serializable Target to runtime format
TTarget fromSerializableTarget(TTarget)(auto ref const SerializableTarget serializable) @trusted
{
    import std.conv : to;
    import infrastructure.config.schema.schema : TargetType;
    
    TTarget target;
    target.name = cast(string)serializable.name;
    target.type = serializable.type.to!TargetType;
    target.sources = serializable.sources.dup;
    
    // Use deps field (not dependencies)
    static if (__traits(hasMember, TTarget, "deps"))
        target.deps = serializable.dependencies.dup;
    else static if (__traits(hasMember, TTarget, "dependencies"))
        target.dependencies = serializable.dependencies.dup;
    
    static if (__traits(hasMember, TTarget, "flags"))
        target.flags = serializable.flags.dup;
    
    static if (__traits(hasMember, TTarget, "outputPath"))
        target.outputPath = cast(string)serializable.outputPath;
    
    // Reconstruct additional fields
    static if (__traits(hasMember, TTarget, "additionalFields"))
    {
        foreach (i; 0 .. serializable.additionalKeys.length)
            target.additionalFields[serializable.additionalKeys[i]] = serializable.additionalValues[i];
    }
    
    return target;
}

/// Convert from serializable BuildNode to runtime format (partial - needs graph context)
/// Returns serializable data that can be used to reconstruct the node
SerializableBuildNode fromSerializablePartial(ref const SerializableBuildNode serializable) @trusted
{
    // Return a mutable copy since full reconstruction requires graph context
    SerializableBuildNode result;
    result.targetId = serializable.targetId;
    result.target = cast(SerializableTarget)serializable.target;
    result.dependencyIds = serializable.dependencyIds.dup;
    result.dependentIds = serializable.dependentIds.dup;
    result.status = serializable.status;
    result.hash = serializable.hash;
    result.retryAttempts = serializable.retryAttempts;
    result.lastError = serializable.lastError;
    result.pendingDeps = serializable.pendingDeps;
    return result;
}

