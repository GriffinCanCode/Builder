module engine.caching.incremental.schema;

import std.datetime : SysTime;
import infrastructure.utils.serialization;

/// Serializable file dependency for incremental compilation
/// Schema version 1.0 - initial release
@Serializable(SchemaVersion(1, 0), 0x46445043) // "FDPC" - File Dependency Cache
struct SerializableFileDependency
{
    @Field(1) string sourceFile;
    @Field(2) string[] dependencies;
    @Field(3) string sourceHash;
    @Field(4) string[] depHashes;
    @Field(5) @Packed long timestamp;
}

/// Serializable container for file dependencies
@Serializable(SchemaVersion(1, 0), 0x46444348) // "FDCH" - File Dependency Container Hash
struct SerializableDependencyContainer
{
    @Field(1) uint version_ = 1;
    @Field(2) SerializableFileDependency[] dependencies;
}

/// Convert from runtime FileDependency to serializable format
SerializableFileDependency toSerializable(T)(auto ref const T dep) @trusted
{
    SerializableFileDependency serializable;
    serializable.sourceFile = dep.sourceFile;
    serializable.dependencies = dep.dependencies.dup;
    serializable.sourceHash = dep.sourceHash;
    serializable.depHashes = dep.depHashes.dup;
    serializable.timestamp = dep.timestamp.stdTime;
    return serializable;
}

/// Convert from serializable FileDependency to runtime format
T fromSerializable(T)(auto ref const SerializableFileDependency serializable) @trusted
{
    T dep;
    dep.sourceFile = cast(string)serializable.sourceFile;
    dep.dependencies = serializable.dependencies.dup;
    dep.sourceHash = cast(string)serializable.sourceHash;
    dep.depHashes = serializable.depHashes.dup;
    dep.timestamp = SysTime(serializable.timestamp);
    return dep;
}

