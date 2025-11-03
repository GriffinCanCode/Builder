module engine.caching.distributed.remote.schema;

import std.datetime : SysTime;
import infrastructure.utils.serialization;

/// Serializable cache artifact metadata
@Serializable(SchemaVersion(1, 0), 0x41525446) // "ARTF" - Artifact
struct SerializableArtifactMetadata
{
    @Field(1) string contentHash;
    @Field(2) @Packed ulong size;
    @Field(3) @Packed ulong compressedSize;
    @Field(4) @Packed long timestamp;
    @Field(5) string workspace;
    @Field(6) bool compressed;
}

/// Convert ArtifactMetadata to serializable format
SerializableArtifactMetadata toSerializable(T)(auto ref const T meta) @trusted
{
    SerializableArtifactMetadata serializable;
    serializable.contentHash = meta.contentHash;
    serializable.size = meta.size;
    serializable.compressedSize = meta.compressedSize;
    serializable.timestamp = meta.timestamp.stdTime;
    serializable.workspace = meta.workspace;
    serializable.compressed = meta.compressed;
    return serializable;
}

/// Convert from serializable ArtifactMetadata to runtime format
TMeta fromSerializable(TMeta)(auto ref const SerializableArtifactMetadata serializable) @trusted
{
    TMeta meta;
    meta.contentHash = cast(string)serializable.contentHash;
    meta.size = cast(size_t)serializable.size;
    meta.compressedSize = cast(size_t)serializable.compressedSize;
    meta.timestamp = SysTime(serializable.timestamp);
    meta.workspace = cast(string)serializable.workspace;
    meta.compressed = serializable.compressed;
    return meta;
}

