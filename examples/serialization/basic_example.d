#!/usr/bin/env dub
/+ dub.sdl:
    name "serialization_basic"
+/

/**
 * Basic Serialization Example
 * 
 * Demonstrates simple schema definition and usage
 */

import std.stdio;
import std.datetime : Clock;
import infrastructure.utils.serialization;

/// Simple user data structure
@Serializable(SchemaVersion(1, 0), 0x55534552)  // Magic: "USER"
struct User
{
    @Field(1) uint id;
    @Field(2) string name;
    @Field(3) string email;
    @Field(4) @Packed long created;  // Timestamp as varint
}

/// Build cache entry (more complex)
@Serializable(SchemaVersion(1, 0))
struct BuildCacheEntry
{
    @Field(1) string targetId;
    @Field(2) string buildHash;
    @Field(3) long timestamp;
    @Field(4) string[] sourceFiles;
    @Field(5) string[string] metadata;  // Key-value pairs
}

void main()
{
    writeln("=== Basic Serialization Example ===\n");
    
    // Create user
    auto user = User(
        42,
        "Alice",
        "alice@example.com",
        Clock.currStdTime()
    );
    
    writeln("Original user:");
    writefln("  ID: %s", user.id);
    writefln("  Name: %s", user.name);
    writefln("  Email: %s", user.email);
    writeln();
    
    // Serialize
    ubyte[] data = Codec.serialize(user);
    writefln("Serialized to %d bytes", data.length);
    writeln();
    
    // Deserialize
    auto result = Codec.deserialize!User(data);
    if (result.isOk)
    {
        auto loaded = result.unwrap();
        writeln("Deserialized user:");
        writefln("  ID: %s", loaded.id);
        writefln("  Name: %s", loaded.name);
        writefln("  Email: %s", loaded.email);
        writefln("  Match: %s", loaded == user ? "✓" : "✗");
    }
    else
    {
        writefln("Error: %s", result.unwrapErr());
    }
    
    writeln("\n=== Complex Structure Example ===\n");
    
    // Create build cache entry
    auto entry = BuildCacheEntry(
        "//src:mylib",
        "abc123def456",
        Clock.currStdTime(),
        ["src/main.d", "src/lib.d", "src/util.d"],
        ["compiler": "ldc2", "version": "1.35.0", "flags": "-O3"]
    );
    
    writefln("Cache entry target: %s", entry.targetId);
    writefln("Source files: %d", entry.sourceFiles.length);
    writefln("Metadata keys: %d", entry.metadata.length);
    
    // Serialize
    data = Codec.serialize(entry);
    writefln("Serialized to %d bytes", data.length);
    
    // Deserialize
    auto entryResult = Codec.deserialize!BuildCacheEntry(data);
    if (entryResult.isOk)
    {
        auto loaded = entryResult.unwrap();
        writefln("Loaded target: %s", loaded.targetId);
        writefln("Source files match: %s", loaded.sourceFiles == entry.sourceFiles ? "✓" : "✗");
        writefln("Metadata match: %s", loaded.metadata == entry.metadata ? "✓" : "✗");
    }
    
    writeln("\n=== Schema Info ===\n");
    writeln(SchemaInfo!User.toString());
}

